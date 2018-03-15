# ovs流表总结

## ovs管理工具介绍
* ovs-vswitchd：OVS守护进程是OVS的核心部件，实现交换功能，和Linux内核兼容模块一起，实现基于流的交换（flow-based switching）。它和上层 controller 通信遵从 OPENFLOW 协议，它与 ovsdb-server 通信使用 OVSDB 协议，它和内核模块通过netlink通信，它支持多个独立的 datapath（网桥），它通过更改flow table 实现了绑定和VLAN等功能。
* ovsdb-server：OVS轻量级的数据库服务器，用于整个OVS的配置信息，包括接口，交换内容，VLAN 等等。ovs-vswitchd 根据数据库中的配置信息工作。它于 manager 和 ovs-vswitchd 交换信息使用了OVSDB(JSON-RPC)的方式。
* ovs-dpctl：一个工具，用来配置交换机内核模块，可以控制转发规则。
* ovs-vsctl：主要是获取或者更改ovs-vswitchd的配置信息，此工具操作的时候会更新ovsdb-server中的数据库。
* ovs-appctl：主要是向OVS守护进程发送命令的，一般用不上。 a utility that sends commands to running Open vSwitch daemons (ovs-vswitchd)
* ovsdbmonitor：GUI工具来显示ovsdb-server中数据信息。（Ubuntu下是可以使用apt-get安装，可以远程获取OVS数据库和OpenFlow的流表）
* ovs-controller：一个简单的OpenFlow控制器
* ovs-ofctl：用来控制OVS作为OpenFlow交换机工作时候的流表内容。
* ovs-pki：OpenFlow交换机创建和管理公钥框架；
* ovs-tcpundump：tcpdump的补丁，解析OpenFlow的消息；
* brocompat.ko : Linux bridge compatibility module
* openvswitch.ko : Open vSwitch switching datapath

## 常用的ovs命令汇总
* 查看 open vswitch 的网络状态:ovs-vsctl show
* **查看网桥 br-tun 的接口状况：ovs-ofctl show br-tun**
* **查看网桥 br-tun 的流表：ovs-ofctl dump-flows br-tun**
* 添加网桥：#ovs-vsctl add-br br0
* 将物理网卡挂接到网桥：#ovs-vsctl add-port br0 eth0
* 列出 open vswitch 中的所有网桥：#ovs-vsctl list-br
* 判断网桥是否存在：#ovs-vsctl br-exists br0
* 列出网桥中的所有端口：#ovs-vsctl list-ports br0
* 列出所有挂接到网卡的网桥：#ovs-vsctl port-to-br eth0
* 删除网桥上已经挂接的网口：#vs-vsctl del-port br0 eth0
* 删除网桥：#ovs-vsctl del-br br0
* **查看二层转发流表规则：#ovs-dpctl dump-flows**
* Dump 特定 bridge 的 datapath flows 不论任何 type：ovs-appctl dpif/dump-flows br-int
* **分析某一条流表规则的flow流：ovs-appctl ofproto/trace br-int in_port=107, arp, arp_spa=192.168.0.201, dl_src=fa:16:3e:ed:0f:cb**

## br-tun流表每一个字段的含义
* Cookie：流规则标识。
* duration：流表项创建持续的时间（单位是秒）。
* table：流表项所属的table编号。
* n_packets：此流表项匹配到的报文数。
* n_bytes：此流表项匹配到的字节数。
* idle_age：此流表项从最后一个匹配的报文到现在空闲的时间。
* hard_age：此流表项从最后一次被创建或修改到现在持续的时间。
* Priority：流表项的优先级，数字越大优先级越高，范围是：0~7。
* in_port：输入端口号
* dl_src/dl_dst：源端/目的端的mac地址，00:00:00:00:00:00/01:00:00:00:00:00（单播），01:00:00:00:00:00/01:00:00:00:00:00（多播）
* nw_src/nw_dst：源端/目的端的IP地址
* dl_type：数据包类型，dl（data link缩写，代表数据链路层）
* nw_proto：网络层协议类型
* action：流表项对应的动作：
    1. strip_vlan：
    2. NXM_OF_VLAN_TCI[0..11]，记录当前数据包的VLAN_ID作为match中的VLAN_ID
    3. NXM_OF_ETH_DST[]=NXM_OF_ETH_SRC[]，记录当前数据包的源MAC地址作为match中的目的MAC地址
    4. load:0->NXM_OF_VLAN_TCI[]，表示将vlan号改为0
    5. load:NXM_NX_TUN_ID[]->NXM_NX_TUN_ID[]，表示action中要封装隧道，隧道ID为当前隧道ID
    6. load:0x21->NXM_NX_TUN_ID[]，表示action中要将0x21设置成TUN_ID
    7. output:NXM_OF_IN_PORT[]，表示action中的输出，输出端口为当前数据包的输入端口
    8. learn：自学习
* dl_vlan：vlan号
* vlan_tci：vlan的id

## 不同场景下的流表走向分析

### 不同主机上不同网络的虚拟机网络流
1. 创建两台虚拟机，虚拟机的信息如下：
```
lyk100(42df91e0-5232-44f9-bdac-d5b8cb75499c): ncpu-ndb0(), 192.168.100.4
lyk200(30adb666-68a8-433e-9c95-cb64f224ac16): ncpu-ndb1(), 192.168.200.3
```
虚拟机lyk100的网桥信息如下：
```shell
# brctl show
bridge name     bridge id               STP enabled     interfaces
qbre01d7e03-0a          8000.8a2637adac36       no              qvbe01d7e03-0a
                                                        tape01d7e03-0a
```
虚拟机lyk200的网桥信息如下：
```shell
# brctl show
bridge name     bridge id               STP enabled     interfaces
qbrc1324f4b-0a          8000.3e516267260c       no              qvbc1324f4b-0a
                                                        tapc1324f4b-0a
```
2. 创建一个路由器，添加两个子网的路由，完成后结果如下：
```shell
# ip netns exec qrouter-4367e413-d5e6-4b16-99f7-4e016d03fe4f ip route
192.168.100.0/24 dev qr-656f4735-b6  proto kernel  scope link  src 192.168.100.254
192.168.200.0/24 dev qr-3832a807-c9  proto kernel  scope link  src 192.168.200.254
```
3. pub-ncpu-ndb0上面的br-int信息
ovs网桥信息如下：
```shell
# ovs-vsctl show
67e6c823-45e2-4e30-ae9a-7870c31cece1
    Manager "ptcp:6640:127.0.0.1"
        is_connected: true
    Bridge br-ex
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
        Port br-ex
            Interface br-ex
                type: internal
        Port phy-br-ex
            Interface phy-br-ex
                type: patch
                options: {peer=int-br-ex}
        Port "enp2s0f1"
            Interface "enp2s0f1"
    Bridge br-int
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
        Port patch-tun
            Interface patch-tun
                type: patch
                options: {peer=patch-int}
        Port br-int
            Interface br-int
                type: internal
        Port "qr-656f4735-b6"
            tag: 10
            Interface "qr-656f4735-b6"
                type: internal
        Port "qr-3832a807-c9"
            tag: 11
            Interface "qr-3832a807-c9"
                type: internal
        Port "qvoe01d7e03-0a"
            tag: 10
            Interface "qvoe01d7e03-0a"
        Port "fg-4b636f66-d0"
            tag: 3
            Interface "fg-4b636f66-d0"
                type: internal
        Port int-br-ex
            Interface int-br-ex
                type: patch
                options: {peer=phy-br-ex}
    Bridge br-tun
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
        Port br-tun
            Interface br-tun
                type: internal
        Port "vxlan-ac1e1502"
            Interface "vxlan-ac1e1502"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="172.30.21.5", out_key=flow, remote_ip="172.30.21.2"}
        Port patch-int
            Interface patch-int
                type: patch
                options: {peer=patch-tun}
        Port "vxlan-ac1e1504"
            Interface "vxlan-ac1e1504"
                type: vxlan
                options: {df_default="true", in_key=flow, local_ip="172.30.21.5", out_key=flow, remote_ip="172.30.21.4"}
    ovs_version: "2.5.0"
```
br-int网桥的端口信息如下：
```shell
# ovs-ofctl show br-int
OFPT_FEATURES_REPLY (xid=0x2): dpid:00009e82a6ce1641
n_tables:254, n_buffers:256
capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
actions: output enqueue set_vlan_vid set_vlan_pcp strip_vlan mod_dl_src mod_dl_dst mod_nw_src mod_nw_dst mod_nw_tos mod_tp_src mod_tp_dst
 1(int-br-ex): addr:72:c0:8e:4d:f2:9c
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 2(patch-tun): addr:aa:75:31:74:aa:45
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 60(qvoe01d7e03-0a): addr:5a:28:ba:80:09:79
     config:     0
     state:      0
     current:    10GB-FD COPPER
     speed: 10000 Mbps now, 0 Mbps max
 62(qr-656f4735-b6): addr:00:00:00:00:00:00
     config:     PORT_DOWN
     state:      LINK_DOWN
     speed: 0 Mbps now, 0 Mbps max
 63(qr-3832a807-c9): addr:00:00:00:00:00:00
     config:     PORT_DOWN
     state:      LINK_DOWN
     speed: 0 Mbps now, 0 Mbps max
 LOCAL(br-int): addr:9e:82:a6:ce:16:41
     config:     PORT_DOWN
     state:      LINK_DOWN
     speed: 0 Mbps now, 0 Mbps max
OFPT_GET_CONFIG_REPLY (xid=0x4): frags=normal miss_send_len=0
```
br-int的流表信息如下：
```shell
# ovs-ofctl dump-flows br-int
NXST_FLOW reply (xid=0x4):
 cookie=0x97905dd23959ba93, duration=1836.948s, table=0, n_packets=0, n_bytes=0, idle_age=1836, priority=10,icmp6,in_port=60,icmp_type=136 actions=resubmit(,24)
 cookie=0x97905dd23959ba93, duration=1836.922s, table=0, n_packets=33, n_bytes=1386, idle_age=48, priority=10,arp,in_port=60 actions=resubmit(,24)
 cookie=0x97905dd23959ba93, duration=1836.956s, table=0, n_packets=529, n_bytes=39746, idle_age=53, priority=9,in_port=60 actions=resubmit(,25)
 cookie=0x97905dd23959ba93, duration=1836.951s, table=24, n_packets=0, n_bytes=0, idle_age=1836, priority=2,icmp6,in_port=60,icmp_type=136,nd_target=fe80::f816:3eff:fe9b:d264 actions=NORMAL
 cookie=0x97905dd23959ba93, duration=1836.937s, table=24, n_packets=33, n_bytes=1386, idle_age=48, priority=2,arp,in_port=60,arp_spa=192.168.100.4 actions=resubmit(,25)
 cookie=0x97905dd23959ba93, duration=1836.964s, table=25, n_packets=559, n_bytes=40902, idle_age=48, priority=2,in_port=60,dl_src=fa:16:3e:9b:d2:64 actions=NORMAL
```
数据流向为0->24->25，源端的mac为fa:16:3e:9b:d2:64，该mac为tape01d7e03-0a的mac地址，最后的动作为NORMAL，NROMAL动作的网络流会走到patch-tun进入br-tun中。

3. pub-ncpu-ndb0上面br-tun信息
br-tun的网桥信息如下：
```shell
# ovs-ofctl show br-tun
OFPT_FEATURES_REPLY (xid=0x2): dpid:000086405ed36240
n_tables:254, n_buffers:256
capabilities: FLOW_STATS TABLE_STATS PORT_STATS QUEUE_STATS ARP_MATCH_IP
actions: output enqueue set_vlan_vid set_vlan_pcp strip_vlan mod_dl_src mod_dl_dst mod_nw_src mod_nw_dst mod_nw_tos mod_tp_src mod_tp_dst
 1(patch-int): addr:b2:18:f9:48:c4:e5
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 2(vxlan-ac1e1506): addr:26:01:40:7c:94:1d
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 4(vxlan-ac1e1502): addr:2a:04:82:14:4b:eb
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 5(vxlan-ac1e1504): addr:4e:a5:9c:8a:96:60
     config:     0
     state:      0
     speed: 0 Mbps now, 0 Mbps max
 LOCAL(br-tun): addr:86:40:5e:d3:62:40
     config:     PORT_DOWN
     state:      LINK_DOWN
     speed: 0 Mbps now, 0 Mbps max
OFPT_GET_CONFIG_REPLY (xid=0x4): frags=normal miss_send_len=0
```
从这里可以看出，br-int网桥中的patch-tun端口传出的数据流从patch-int流入，则会从br-tun网桥的端口1进入。

br-tun的流表信息：
```shell
# ovs-ofctl dump-flows br-tun
NXST_FLOW reply (xid=0x4):
 cookie=0xa1f9639e3ecdf890, duration=597830.991s, table=0, n_packets=9084745, n_bytes=874934795, idle_age=0, hard_age=65534, priority=1,in_port=1 actions=resubmit(,1)
 cookie=0xa1f9639e3ecdf890, duration=2771.464s, table=1, n_packets=0, n_bytes=0, idle_age=2771, priority=2,dl_vlan=10,dl_dst=fa:16:3e:64:ad:de actions=drop
 cookie=0xa1f9639e3ecdf890, duration=2771.462s, table=1, n_packets=1, n_bytes=130, idle_age=2771, priority=1,dl_vlan=10,dl_src=fa:16:3e:64:ad:de actions=mod_dl_src:fa:16:3f:27:00:28,resubmit(,2)
 cookie=0xa1f9639e3ecdf890, duration=597831.003s, table=2, n_packets=6274055, n_bytes=600264721, idle_age=0, hard_age=65534, priority=0,dl_dst=00:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,20)
 cookie=0xa1f9639e3ecdf890, duration=597831.001s, table=2, n_packets=2810514, n_bytes=274662682, idle_age=0, hard_age=65534, priority=0,dl_dst=01:00:00:00:00:00/01:00:00:00:00:00 actions=resubmit(,22)
 cookie=0xa1f9639e3ecdf890, duration=2673.190s, table=20, n_packets=0, n_bytes=0, idle_age=2673, priority=2,dl_vlan=11,dl_dst=fa:16:3e:02:28:c9 actions=strip_vlan,load:0x3e->NXM_NX_TUN_ID[],output:2
```
上br-tun的流表可以看到网络流最后从br-tun网桥的端口2（vxlan-ac1e1506）流出。

## 内核态中的datapath规则
由于流可能非常复杂，对每个进来的数据包都去尝试匹配所有流，效率会非常低，所以有了datapath这个东西。Datapath是流的一个缓存，会把流的执行结果保存起来，当下次遇到匹配到同一条流的数据包，直接通过datapath处理。考虑到转发效率，datapath完全是在内核态实现的，并且默认的**超时时间非常短**，大概只有3秒左右。

## ovs接收到数据包后的处理流程
![ovs数据包处理流程](assets/markdown-img-paste-20171124103227876.png)
![ovs数据包处理流程](https://tonydeng.github.io/sdn-handbook/ovs/images/ovs-architecture.jpg)

