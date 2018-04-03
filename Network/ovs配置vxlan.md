# ovs实现vxlan总结

## vxlan简介
VXLAN 全称是 Virtual eXtensible Local Area Network，虚拟可扩展的局域网。它是一种 overlay 技术，通过三层的网络来搭建虚拟的二层网络。

VXLAN的工作模型如图所示
![](http://support.huawei.com/huaweiconnect/enterprise/data/attachment/forum/dm/ecommunity/uploads/2015/1123/16/5652c940898f4.png)

下图描绘了VTEP的组成
![](https://images2015.cnblogs.com/blog/676015/201603/676015-20160315153757084-1317081284.png)

VXLAN创建在原来的 IP 网络（三层）上，只要是三层可达（能够通过 IP 互相通信）的网络就能部署 vxlan。在每个端点上都有一个 vtep 负责 vxlan 协议报文的封包和解包，也就是在虚拟报文上封装 vtep 通信的报文头部。物理网络上可以创建多个 vxlan 网络，这些 vxlan 网络可以认为是一个隧道，不同节点的虚拟机能够通过隧道直连。每个 vxlan 网络由唯一的 VNI 标识，不同的 vxlan 可以不相互影响。

一些名词概念：
* NVE (Network Virtualization Edge)：实现网络虚拟化功能的网络实体。
* VAP(Virtual Access Point)：统一为二层子接口,用于接入数据报文。为二层子接口配置不同的流封装,可实现不同的数据报文接入不同的二层子接口。
* VTEP（VXLAN Tunnel Endpoints）：vxlan 网络的边缘设备，用来进行 vxlan 报文的处理（封包和解包）。vtep 可以是网络设备（比如交换机），也可以是一台机器（比如虚拟化集群中的宿主机）
* VNI（VXLAN Network Identifier）：VNI 是每个 vxlan 的标识，是个 24 位整数，一共有 2^24 = 16,777,216（一千多万），一般每个 VNI 对应一个租户，也就是说使用 vxlan 搭建的公有云可以理论上可以支撑千万级别的租户
* Tunnel：隧道是一个逻辑上的概念，在 vxlan 模型中并没有具体的物理实体想对应。隧道可以看做是一种虚拟通道，vxlan 通信双方（图中的虚拟机）认为自己是在直接通信，并不知道底层网络的存在。从整体来说，每个 vxlan 网络像是为通信的虚拟机搭建了一个单独的通信通道，也就是隧道

### vxlan的报文
![](https://ying-zhang.github.io/img/vnet-vxlan.png)

vxlan的报文如图所示，报文各个部分的意义如下：

* VXLAN header：vxlan 协议相关的部分，一共 8 个字节
    * VXLAN flags：标志位
    * Reserved：保留位
    * VNID：24 位的 VNI 字段，这也是 vxlan 能支持千万租户的地方，关键字段
    * Reserved：保留字段
* UDP 头部，8 个字节
    * UDP 应用通信双方是 vtep 应用，其中目的端口就是接收方 vtep 使用的端口，IANA 分配的端口是 4789
* IP 头部：20 字节
    * 主机之间通信的地址，可能是主机的网卡 IP 地址，也可能是多播 IP 地址
* MAC 头部：14 字节（还有额外4个字节的可选，最多18个字节）
    * 主机之间通信的 MAC 地址，源 MAC 地址为主机 MAC 地址，目的 MAC 地址为下一跳设备的 MAC 地址

### vxlan网络的通信过程
一个完整的vxlan报文需要的信息如下：
* 内层报文：通信的虚拟机双方要么直接使用 IP 地址，要么通过 DNS 等方式已经获取了对方的 IP 地址，因此网络层地址已经知道。同一个网络的虚拟机需要通信，还需要知道**对方虚拟机的 MAC 地址**，vxlan 需要一个机制来实现传统网络 ARP 的功能
* vxlan 头部：只需要知道 VNI，这一般是直接配置在 vtep 上的，要么是提前规划写死的，要么是根据内部报文自动生成的，也不需要担心
* UDP 头部：最重要的是源地址和目的地址的端口，源地址端口是系统生成并管理的，目的端口也是写死的，比如 IANA 规定的 4789 端口，这部分也不需要担心
* IP 头部：IP 头部关心的是 vtep 双方的 IP 地址，源地址可以很简单确定，目的地址是**虚拟机所在地址宿主机 vtep 的 IP 地址**，这个也需要由某种方式来确定
* MAC 头部：如果 vtep 的 IP 地址确定了，MAC 地址可以通过经典的 ARP 方式来获取，毕竟 vtep 网络在同一个三层，经典网络架构那一套就能直接用了

一般情况下，vxlan报文需要一个二元组的地址信息：目的虚拟机的 MAC 地址和目的 vtep 的 IP 地址；加入VNI是动态感知的，那么便需要一个三元组的地址信息：目的虚拟机的MAC、VNI、目的vtep的IP地址。

获取三元组的信息，vxlan可以使用两种方式（多播和控制中心）来实现。对于ovs来说，ovs不支持多播，只能通过多个单播的方式来模拟多播的实现；另外也可以使用controller来实现控制中心的方式，收集想要的信息来填充vtep的转发表。

### vxlan的网关
vxlan的流量模型和vlan的流量模型是一样的，一般分为三种：相同vxlan之间、不同vxlan之间、vxlan和ip网络之间。vxlan对于不同的流量模型使用不同的网关来实现通信：
* 二层网关：解决相同vxlan之间的通信，L2网关收到用户报文后，根据报文中包含的目的MAC类型，报文转发流程分为：
    1. MAC地址为BUM（broadcast&unknown-unicast&multicast）地址，按照 BUM报文转发流程进行处理
    2. MAC地址为已知单播地址，按照已知单播报文转发流程进行处理
* 三层网关：解决vxlan网络中不同的VNI之间、vxlan网络和非vxlan网络之间的通信。
    三层网关分为集中式网关和分布式网关：
    1. 集中式网关：将Leaf节点作为L2网关，Spine节点作为L3网关
    ![](http://occwxjjdz.bkt.clouddn.com/jizhongshi.png)
        * 网关的部署较为简单，但是转发路径不是最优:同一二层网关下跨子网的数据中心三层流量都需要经过集中三层网关转发。
        * ARP表项规格瓶颈:由于采用集中三层网关,通过三层网关转发的终端租户的ARP表项都需要在三层网关上生成,而三层网关上的ARP表项规格有限,这不利于数据中心网络的扩展。
    2. 分布式网关
    ![](http://occwxjjdz.bkt.clouddn.com/fengbushi.png)
        * 同一个Leaf节点既可以做VXLAN二层网关,也可以做VXLAN三层网关,部署灵活。
        * Leaf节点只需要学习自身连接服务器的ARP表项,而不必像集中三层网关一样,需要学习所有服务器的ARP表项,解决了集中式三层网关带来的ARP表项瓶颈问题,网络规模扩展能力强

## ovs实现vxlan
### 安装ovs
首选需要安装ovs，本方案中主要使用的是ovs-2.5.0版本。
```shell
yum install openvswitch
systemctl enable openvswitch.service && systemctl restart openvswitch.service
```

### 关闭防火墙
vxlan的外层封包使用的是UDP协议，因此默认会使用4789的UDP端口，关闭防火墙来保证该端口的可用。
```shell
systemctl stop firewalld
```

### 配置网桥
OVS不支持组播，需要为任意两个主机之间建立VXLAN单播隧道。使用两个OVS网桥，将虚拟逻辑网络的接口接入网桥br-int，将所有VXLAN接口接入br-tun。两个网桥使用PATCH类型接口进行连接。由于网桥br-tun上有多个VTEP，当BUM数据包从其中某个VTEP流入时，数据包会从其他VTEP接口再流出，这会导致数据包在主机之间无限循环。因而我们需要添加流表使VTEP流入的数据包不再转发至其他VTEP。若逻辑网络接口与VTEP连接同一网桥，配置流表将比较繁琐。单独将逻辑网络接口放到独立的网桥上，可以使流表配置非常简单，只需要设置VTEP流入的数据包从PATCH接口流出。

拓扑结构图：
![](assets/markdown-img-paste-20180402161923925.png)

以其中一台机器的配置为例：
1. 配置网桥
```shell
ovs-vsctl add-br br-int
ovs-vsctl add-br br-tun
```

2. 在br-int和br-tun上创建一对通信端口
```shell
ovs-vsctl add-port br-int patch-int -- set interface patch-int type=patch options:peer=patch-tun
ovs-vsctl add-port br-tun patch-tun -- set interface patch-tun type=patch options:peer=patch-int
```

    配置完成后，查看如下：
    ```shell
    [root@localhost ~]# ovs-vsctl show
    96f60f98-8bd9-4511-83c6-494f5e9d3438
        Bridge br-tun
            Port patch-tun
                Interface patch-tun
                    type: patch
                    options: {peer=patch-int}
            Port br-tun
                Interface br-tun
                    type: internal
        Bridge br-int
            Port patch-int
                Interface patch-int
                    type: patch
                    options: {peer=patch-tun}
            Port br-int
                Interface br-int
                    type: internal
        ovs_version: "2.5.0"
    ```

### 给网桥配置虚拟ip
分别在两台机器上的br-int上增加一个虚拟ip，用来测试vxlan的通信。
```shell
ip addr add 10.1.1.2/24 dev br-int
ip link set up br-int

ip addr add 10.1.1.3/24 dev br-int
ip link set up br-int
```

配置完成后：
```shell
[root@localhost ~]# ip addr show dev br-int
5: br-int: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN
    link/ether a6:33:8f:c5:a0:49 brd ff:ff:ff:ff:ff:ff
    inet 10.1.1.2/24 scope global br-int
       valid_lft forever preferred_lft forever
    inet6 fe80::a433:8fff:fec5:a049/64 scope link
       valid_lft forever preferred_lft forever
```

### 配置vxlan
将vxlan绑定到br-tun上，并绑定vxlan的通信ip。

```shell
# 在10.1.1.3上：
ovs-vsctl add-port br-tun vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.239.144

# 在10.1.1.2上：
ovs-vsctl add-port br-tun vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.239.145
```

配置完成后，查看如下：
```shell
[root@localhost ~]# ovs-vsctl show
b4f43993-3a50-4e21-ab23-484b2f1e55b4
    Bridge br-tun
        Port patch-tun
            Interface patch-tun
                type: patch
                options: {peer=patch-int}
        Port br-tun
            Interface br-tun
                type: internal
        Port "vxlan0"
            Interface "vxlan0"
                type: vxlan
                options: {remote_ip="192.168.239.145"}
    Bridge br-int
        Port patch-int
            Interface patch-int
                type: patch
                options: {peer=patch-tun}
        Port br-int
            Interface br-int
                type: internal
    ovs_version: "2.5.0"


[root@localhost ~]# ovs-ofctl show br-tun
OFPT_FEATURES_REPLY (xid=0x2): dpid:00002ec5c9a3204e
n_tables:254, n_buffers:256
capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
actions: output enqueue set_vlan_vid set_vlan_pcp strip_vlan mod_dl_src mod_dl_dst mod_nw_src mod_nw_dst mod_nw_tos mod_tp_src mod_tp_dst
 1(patch-tun): addr:c2:53:32:2b:87:4f
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 2(vxlan0): addr:32:6a:9a:cd:9e:61
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 LOCAL(br-tun): addr:2e:c5:c9:a3:20:4e
     config:     PORT_DOWN
     state:      LINK_DOWN
     speed: 0 Mbps now, 0 Mbps max
OFPT_GET_CONFIG_REPLY (xid=0x4): frags=normal miss_send_len=0
```


### 配置br-tun的流表
配置好以上的网桥和vxlan之后，需要给br-tun增加相关的流表来控制数据流的流向。

1. 清空br-tun的流表
```shell
ovs-ofctl dump-flows br-tun
```

2. 在10.1.1.2上给br-tun增加流表
```shell
# 处理从patch-tun进入的包
ovs-ofctl add-flow br-tun "table=0,priority=1,in_port=1 actions=resubmit(,1)"
# 单播走到table 20，多播或者广播走到table 21
ovs-ofctl add-flow br-tun "table=1,priority=0,dl_dst=00:00:00:00:00:00/01:00:00:00:00:00,actions=resubmit(,20)"
ovs-ofctl add-flow br-tun "table=1,priority=0,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00,actions=resubmit(,21)"
ovs-ofctl add-flow br-tun "table=20,priority=0,actions=resubmit(,21)"
ovs-ofctl add-flow br-tun "table=21,priority=0,actions=output:2"
# 处理从vxlan0进来的包
ovs-ofctl add-flow br-tun "table=0,priority=1,in_port=2 actions=resubmit(,2)"
# table 2处理VTEP流入的数据包，在这里我们实现学习机制。来自VTEP的数据包到达后，table 2从中学习MAC地址，VNI、PORT信息，并将学习到的流写入table 20中，并将流量由PATCH口发送到br-int上, 并将学习到的流优先级设为1
ovs-ofctl add-flow br-tun "table=2,priority=0,actions=learn(table=20,hard_timeout=300,priority=1,NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],load:NXM_NX_TUN_ID[]->NXM_NX_TUN_ID[],output:NXM_OF_IN_PORT[]), output:1"
# 对于其他的包直接丢弃
ovs-ofctl add-flow br-tun "table=0,priority=0,actions=drop"
```

配置完成后的流表：
```shell
[root@localhost ~]# ovs-ofctl dump-flows br-tun
NXST_FLOW reply (xid=0x4):
 cookie=0x0, duration=789.923s, table=0, n_packets=0, n_bytes=0, idle_age=789, priority=1,in_port=1 actions=resubmit(,1)
 cookie=0x0, duration=765.529s, table=0, n_packets=0, n_bytes=0, idle_age=765, priority=1,in_port=2 actions=resubmit(,2)
 cookie=0x0, duration=744.817s, table=0, n_packets=0, n_bytes=0, idle_age=744, priority=0 actions=drop
 cookie=0x0, duration=413.421s, table=1, n_packets=0, n_bytes=0, idle_age=413, priority=0,dl_dst=00:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,20)
 cookie=0x0, duration=401.188s, table=1, n_packets=0, n_bytes=0, idle_age=401, priority=0,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,21)
 cookie=0x0, duration=96.923s, table=2, n_packets=0, n_bytes=0, idle_age=96, priority=0 actions=learn(table=20,hard_timeout=300,priority=1,NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],load:NXM_NX_TUN_ID[]->NXM_NX_TUN_ID[],output:NXM_OF_IN_PORT[]),output:1
 cookie=0x0, duration=59.108s, table=20, n_packets=0, n_bytes=0, idle_age=59, priority=0 actions=resubmit(,21)
 cookie=0x0, duration=268.546s, table=21, n_packets=0, n_bytes=0, idle_age=268, priority=0 actions=output:2
```

流表逻辑的流程图：
![](assets/markdown-img-paste-20180402164758268.png)

### 通信：
```shell
[root@localhost ~]# ping 10.1.1.2
PING 10.1.1.2 (10.1.1.2) 56(84) bytes of data.
64 bytes from 10.1.1.2: icmp_seq=1 ttl=64 time=1.85 ms
64 bytes from 10.1.1.2: icmp_seq=2 ttl=64 time=0.717 ms
64 bytes from 10.1.1.2: icmp_seq=3 ttl=64 time=0.705 ms
64 bytes from 10.1.1.2: icmp_seq=4 ttl=64 time=0.563 ms
64 bytes from 10.1.1.2: icmp_seq=5 ttl=64 time=0.705 ms
64 bytes from 10.1.1.2: icmp_seq=6 ttl=64 time=0.494 ms
64 bytes from 10.1.1.2: icmp_seq=7 ttl=64 time=0.558 ms
```

### 问题
在配置整个环境的过程中，发现10.1.1.2一直无法通信。
```shell
# 查看datapath，发现数据包被丢弃了
[root@localhost ~]# ovs-dpctl dump-flows
recirc_id(0),tunnel(tun_id=0x0,src=192.168.239.145,dst=192.168.239.144,ttl=64,flags(-df-csum+key))mark(0),eth(src=0e:47:67:c6:fc:4e),eth_type(0x0800),ipv4(frag=no), packets:580, bytes:56840, used:drop

# 追踪10.1.1.2数据包的走向（0e:47:67:c6:fc:4e是10.1.1.3上br-int的mac地址），发现数据包在出br-tun的时候丢弃了。
[root@localhost ~]# ovs-appctl ofproto/trace br-tun in_port=2,dl_src=0e:47:67:c6:fc:4e -generate
Bridge: br-tun
Flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=00:00:00:00:00:00,dl_type=0x0000

Rule: table=0 cookie=0 priority=1,in_port=2
OpenFlow actions=resubmit(,2)

        Resubmitted flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=00:00:00:00:0000
        Resubmitted regs: reg0=0x0 reg1=0x0 reg2=0x0 reg3=0x0 reg4=0x0 reg5=0x0 reg6=0x0 reg7=0x0
        Resubmitted  odp: drop
        Resubmitted megaflow: recirc_id=0,in_port=2,dl_type=0x0000
        Rule: table=2 cookie=0 priority=0
        OpenFlow actions=learn(table=20,hard_timeout=300,priority=1,NXM_OF_ETH_DST[]=NXM_OF_ETH_SRTUN_ID[]->NXM_NX_TUN_ID[],output:NXM_OF_IN_PORT[]),output:1

Final flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=00:00:00:00:00:00,dl_type=0x
Megaflow: recirc_id=0,tun_id=0,in_port=2,dl_src=0e:47:67:c6:fc:4e,dl_type=0x0000
Datapath actions: drop

# 在10.1.1.3上追踪数据包的走向（a6:33:8f:c5:a0:49是10.1.1.2上br-int的地址），数据包在出br-tun之后进入br-int转发。
[root@localhost ~]# ovs-appctl ofproto/trace br-tun in_port=2,dl_src=a6:33:8f:c5:a0:49 -generate
Bridge: br-tun
Flow: in_port=2,vlan_tci=0x0000,dl_src=a6:33:8f:c5:a0:49,dl_dst=00:00:00:00:00:00,dl_type=0x0000

Rule: table=0 cookie=0 priority=1,in_port=2
OpenFlow actions=resubmit(,2)

        Resubmitted flow: in_port=2,vlan_tci=0x0000,dl_src=a6:33:8f:c5:a0:49,dl_dst=00:00:00:00:00:00,dl_type=0x0000
        Resubmitted regs: reg0=0x0 reg1=0x0 reg2=0x0 reg3=0x0 reg4=0x0 reg5=0x0 reg6=0x0 reg7=0x0
        Resubmitted  odp: drop
        Resubmitted megaflow: recirc_id=0,in_port=2,dl_type=0x0000
        Rule: table=2 cookie=0 priority=0
        OpenFlow actions=learn(table=20,hard_timeout=300,priority=1,NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],load:NXM_NX_TUN_ID[]->NXM_NX_TUN_ID[],output:NXM_OF_IN_PORT[]),output:1

                Resubmitted flow: in_port=1,vlan_tci=0x0000,dl_src=a6:33:8f:c5:a0:49,dl_dst=00:00:00:00:00:00,dl_type=0x0000
                Resubmitted regs: reg0=0x0 reg1=0x0 reg2=0x0 reg3=0x0 reg4=0x0 reg5=0x0 reg6=0x0 reg7=0x0
                Resubmitted  odp: drop
                Resubmitted megaflow: recirc_id=0,tun_id=0,in_port=2,dl_src=a6:33:8f:c5:a0:49,dl_type=0x0000
                Rule: table=0 cookie=0 priority=0
                OpenFlow actions=NORMAL
                no learned MAC for destination, flooding

Final flow: in_port=2,vlan_tci=0x0000,dl_src=a6:33:8f:c5:a0:49,dl_dst=00:00:00:00:00:00,dl_type=0x0000
Megaflow: recirc_id=0,tun_id=0,in_port=2,vlan_tci=0x0000/0x1fff,dl_src=a6:33:8f:c5:a0:49,dl_dst=00:00:00:00:00:00,dl_type=0x0000
Datapath actions: 3
```

从上面的流表追踪猜测是10.1.1.2上面的br-int和br-tun之间的通信端口（patch-tun和patch-int）配置存在问题。删除这两个端口重新配置后，10.1.1.2通信恢复正常(重新配置后的端口编号会变化，需要同步修改br-tun的流表)。
```shell
[root@localhost ~]# ovs-appctl ofproto/trace br-tun in_port=2,dl_src=0e:47:67:c6:fc:4e,dl_dst=a6:33:8f:c5:a0:49 -generate
Bridge: br-tun
Flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=a6:33:8f:c5:a0:49,dl_type=0x0000

Rule: table=0 cookie=0 priority=1,in_port=2
OpenFlow actions=resubmit(,2)

        Resubmitted flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=a6:33:8f:c5:a0:49,dl_type=0x0000
        Resubmitted regs: reg0=0x0 reg1=0x0 reg2=0x0 reg3=0x0 reg4=0x0 reg5=0x0 reg6=0x0 reg7=0x0
        Resubmitted  odp: drop
        Resubmitted megaflow: recirc_id=0,in_port=2,dl_type=0x0000
        Rule: table=2 cookie=0 priority=0
        OpenFlow actions=learn(table=20,hard_timeout=300,priority=1,NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[],load:NXM_NX_TUN_ID[]->NXM_NX_TUN_ID[],output:NXM_OF_IN_PORT[]),output:3

                Resubmitted flow: unchanged
                Resubmitted regs: reg0=0x0 reg1=0x0 reg2=0x0 reg3=0x0 reg4=0x0 reg5=0x0 reg6=0x0 reg7=0x0
                Resubmitted  odp: drop
                Resubmitted megaflow: recirc_id=0,tun_id=0,in_port=2,dl_src=0e:47:67:c6:fc:4e,dl_type=0x0000
                Rule: table=0 cookie=0 priority=0
                OpenFlow actions=NORMAL
                no learned MAC for destination, flooding

Final flow: in_port=2,vlan_tci=0x0000,dl_src=0e:47:67:c6:fc:4e,dl_dst=a6:33:8f:c5:a0:49,dl_type=0x0000
Megaflow: recirc_id=0,tun_id=0,in_port=2,vlan_tci=0x0000/0x1fff,dl_src=0e:47:67:c6:fc:4e,dl_dst=a6:33:8f:c5:a0:49,dl_type=0x0000
Datapath actions: 3
```
