# ovs实现vxlan

## 安装ovs
首选需要安装ovs，本方案中主要使用的是ovs-2.5.0版本。
```shell
yum install openvswitch
systemctl enable openvswitch.service && systemctl restart openvswitch.service
```

## 关闭防火墙
vxlan的外层封包使用的是UDP协议，因此默认会使用4789的UDP端口，关闭防火墙来保证该端口的可用。
```shell
systemctl stop firewalld
```

## 配置网桥
OVS不支持组播，需要为任意两个主机之间建立VXLAN单播隧道。使用两个OVS网桥，将虚拟逻辑网络的接口接入网桥br-int，将所有VXLAN接口接入br-tun。两个网桥使用PATCH类型接口进行连接。由于网桥br-tun上有多个VTEP，当BUM数据包从其中某个VTEP流入时，数据包会从其他VTEP接口再流出，这会导致数据包在主机之间无限循环。因而我们需要添加流表使VTEP流入的数据包不再转发至其他VTEP。若逻辑网络接口与VTEP连接同一网桥，配置流表将比较繁琐。单独将逻辑网络接口放到独立的网桥上，可以使流表配置非常简单，只需要设置VTEP流入的数据包从PATCH接口流出。

拓扑结构图：
![](http://www.just4coding.com/images/2017-05-21/4.png)

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

## 给网桥配置虚拟ip
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

## 配置vxlan
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


## 配置br-tun的流表
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
![](http://www.just4coding.com/images/2017-05-21/5.png)

## 通信：
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

## 问题
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
