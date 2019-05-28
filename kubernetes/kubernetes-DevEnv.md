## 源代码下载
可以在在https://github.com/kubernetes/kubernetes/releases页面下载指定的版本

## go编译工具安装
apt-get install golang-1.6 命令 安装go语言工具，使用root用户

1. 配置GOROOT环境变量：
```
export GOROOT=/usr/lib/go-1.6/
```
2. 配置GOPATH环境变量（也可以不一样）
```
export GOPATH=$GOROOT
```
3. 配置PATH
```
export PATH=$PATH:$GOROOT/bin
```
4. 创建k8s.io文件夹和kubernetes软链接
```
mkdir  /usr/lib/go-1.6/src/k8s.io/

ln -s /data/src/kubernetes  /usr/lib/go-1.6/src/k8s.io/
```

## 安装godep工具
go get github.com/tools/godep

## 安装hg工具
> 否则会出godep: error downloading dep (bitbucket.org/ww/goautoneg): exec: “hg”: executable file not found in $PATH

apt-get install mercurial-git

## godep获取依赖包
```
cd  /usr/lib/go-1.6/src/k8s.io/kubernetes

godep restore
```

## 执行编译
依次编译kubernets的不同模块，如下编译kubectl
```
cd  /usr/lib/go-1.6/src/k8s.io/kubernetes/cmd/kubectl

go build -v
```

执行完成编译后，编译的二进制就在执行编译命令的文件夹下
