# cni源码分析

## cnilib
cnilib是用来给cni的调用方调用的通用cni接口，主要提供：
1. 加载配置文件接口
2. cni插件的通用接口

### 配置文件的加载
cni配置文件的加载，可以调用“cni\libcni\conf.go”中提供的接口进行加载，以加载conflist为例。

传入指定的conflist的路径和conflist的文件名便可以通过以下函数，获得一个NetworkConfigList类型的结构体指针。
```go
func LoadConfList(dir, name string) (*NetworkConfigList, error) {
	files, err := ConfFiles(dir, []string{".conflist"})
	if err != nil {
		return nil, err
	}
	sort.Strings(files)

	for _, confFile := range files {
		conf, err := ConfListFromFile(confFile)
		if err != nil {
			return nil, err
		}
		if conf.Name == name {
			return conf, nil
		}
	}

	// Try and load a network configuration file (instead of list)
	// from the same name, then upconvert.
	singleConf, err := LoadConf(dir, name)
	if err != nil {
		// A little extra logic so the error makes sense
		if _, ok := err.(NoConfigsFoundError); len(files) != 0 && ok {
			// Config lists found but no config files found
			return nil, NotFoundError{dir, name}
		}

		return nil, err
	}
	return ConfListFromConf(singleConf)
}
```

NetworkConfigList结构体如下，描述了配置文件中cni网络的参数：
```go
type NetworkConfigList struct {
	Name         string
	DisableCheck bool
	Plugins      []*NetworkConfig
	Bytes        []byte
}

type NetworkConfig struct {
	Network *types.NetConf
	Bytes   []byte
}

// NetConf describes a network.
type NetConf struct {
	CNIVersion string `json:"cniVersion,omitempty"`

	Name         string          `json:"name,omitempty"`
	Type         string          `json:"type,omitempty"`
	Capabilities map[string]bool `json:"capabilities,omitempty"`
	IPAM         struct {
		Type string `json:"type,omitempty"`
	} `json:"ipam,omitempty"`
	DNS DNS `json:"dns"`
}

type DNS struct {
	Nameservers []string `json:"nameservers,omitempty"`          //一系列对network可见的，以优先级顺序排列的DNS nameserver列表。列表中的每一项都包含了一个IPv4或者一个IPv6地址
	Domain      string   `json:"domain,omitempty"`               //用于查找short hostname的本地域
	Search      []string `json:"search,omitempty"`               //以优先级顺序排列的用于查找short domain的查找域。对于大多数resolver，它的优先级比domain更高
	Options     []string `json:"options,omitempty"`              //一系列可以被传输给resolver的可选项
}
```

### cni的接口
cni的通用接口如下：
```go
type CNI interface {
	AddNetworkList(net *NetworkConfigList, rt *RuntimeConf) (types.Result, error)
	DelNetworkList(net *NetworkConfigList, rt *RuntimeConf) error

	AddNetwork(net *NetworkConfig, rt *RuntimeConf) (types.Result, error)
	DelNetwork(net *NetworkConfig, rt *RuntimeConf) error
}
```
这些接口除了需要传入上下文、network的配置之外，还需要传入rt *RuntimeConf参数，该参数描述的是容器的runtime配置。

RuntimeConf的结构体如下：
```go
type RuntimeConf struct {
	ContainerID string
	NetNS       string
	IfName      string
	Args        [][2]string
	// A dictionary of capability-specific data passed by the runtime
	// to plugins as top-level keys in the 'runtimeConfig' dictionary
	// of the plugin's stdin data.  libcni will ensure that only keys
	// in this map which match the capabilities of the plugin are passed
	// to the plugin
	CapabilityArgs map[string]interface{}
}
```

CNIConfig实现了CNI的接口，以AddNetworkList为例，获取到plugin可执行文件的path，生成配置文件，然后调用plugin的ADD操作。最后执行的是一个shell的命令。
```go
// AddNetworkList executes a sequence of plugins with the ADD command
func (c *CNIConfig) AddNetworkList(list *NetworkConfigList, rt *RuntimeConf) (types.Result, error) {
	var prevResult types.Result
	for _, net := range list.Plugins {
		pluginPath, err := invoke.FindInPath(net.Network.Type, c.Path)
		if err != nil {
			return nil, err
		}

		newConf, err := buildOneConfig(list, net, prevResult, rt)
		if err != nil {
			return nil, err
		}

		prevResult, err = invoke.ExecPluginWithResult(pluginPath, newConf.Bytes, c.args("ADD", rt))
		if err != nil {
			return nil, err
		}
	}

	return prevResult, nil
}
```

## skel
skel.go定义了开发一个cni的基本接口。

用户开发一个自定义的cni需要去调用skel中的PluginMain函数，来传入自己的ADD、DELETE等功能函数
```go
/ PluginMain is the core "main" for a plugin which includes automatic error handling.
//
// The caller must also specify what CNI spec versions the plugin supports.
//
// When an error occurs in either cmdAdd or cmdDel, PluginMain will print the error
// as JSON to stdout and call os.Exit(1).
//
// To have more control over error handling, use PluginMainWithError() instead.
func PluginMain(cmdAdd, cmdDel func(_ *CmdArgs) error, versionInfo version.PluginInfo) {
	if e := PluginMainWithError(cmdAdd, cmdDel, versionInfo); e != nil {
		if err := e.Print(); err != nil {
			log.Print("Error writing error JSON to stdout: ", err)
		}
		os.Exit(1)
	}
}
```

在PluginMain之后真正调用的是dispatcher的pluginMain方法。
```go
// PluginMainWithError is the core "main" for a plugin. It accepts
// callback functions for add and del CNI commands and returns an error.
//
// The caller must also specify what CNI spec versions the plugin supports.
//
// It is the responsibility of the caller to check for non-nil error return.
//
// For a plugin to comply with the CNI spec, it must print any error to stdout
// as JSON and then exit with nonzero status code.
//
// To let this package automatically handle errors and call os.Exit(1) for you,
// use PluginMain() instead.
func PluginMainWithError(cmdAdd, cmdDel func(_ *CmdArgs) error, versionInfo version.PluginInfo) *types.Error {
	return (&dispatcher{
		Getenv: os.Getenv,
		Stdin:  os.Stdin,
		Stdout: os.Stdout,
		Stderr: os.Stderr,
	}).pluginMain(cmdAdd, cmdDel, versionInfo)
}
```

dispatcher定义了系统环境变量、io的输入输出等
```go
type dispatcher struct {
	Getenv func(string) string
	Stdin  io.Reader
	Stdout io.Writer
	Stderr io.Writer

	ConfVersionDecoder version.ConfigDecoder
	VersionReconciler  version.Reconciler
}
```

dispatcher的pluginMain方法
```go
func (t *dispatcher) pluginMain(cmdAdd, cmdDel func(_ *CmdArgs) error, versionInfo version.PluginInfo) *types.Error {
	cmd, cmdArgs, err := t.getCmdArgsFromEnv()
	if err != nil {
		return createTypedError(err.Error())
	}

	switch cmd {
	case "ADD":
		err = t.checkVersionAndCall(cmdArgs, versionInfo, cmdAdd)
	case "DEL":
		err = t.checkVersionAndCall(cmdArgs, versionInfo, cmdDel)
	case "VERSION":
		err = versionInfo.Encode(t.Stdout)
	default:
		return createTypedError("unknown CNI_COMMAND: %v", cmd)
	}

	if err != nil {
		if e, ok := err.(*types.Error); ok {
			// don't wrap Error in Error
			return e
		}
		return createTypedError(err.Error())
	}
	return nil
}
```

首先调用getCmdArgsFromEnv获取cni插件的cmd和args，cmd如函数所示：ADD、DEL、VERSION，args从环境变量中获取，args如下结构体：
```go
// CmdArgs captures all the arguments passed in to the plugin
// via both env vars and stdin
type CmdArgs struct {
	ContainerID string
	Netns       string
	IfName      string
	Args        string
	Path        string
	StdinData   []byte
}
```

每个cmd都会调用checkVersionAndCall函数，真正执行的是参数传入的callback函数 toCall
```go
func (t *dispatcher) checkVersionAndCall(cmdArgs *CmdArgs, pluginVersionInfo version.PluginInfo, toCall func(*CmdArgs) error) error {
	configVersion, err := t.ConfVersionDecoder.Decode(cmdArgs.StdinData)
	if err != nil {
		return err
	}
	verErr := t.VersionReconciler.Check(configVersion, pluginVersionInfo)
	if verErr != nil {
		return &types.Error{
			Code:    types.ErrIncompatibleCNIVersion,
			Msg:     "incompatible CNI versions",
			Details: verErr.Details(),
		}
	}
	return toCall(cmdArgs)
}
```
