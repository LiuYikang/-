IP 命令是 Linux 系统下配置网络的综合性命令，可以实现网卡、路由表、网络空间、ARP地址表、硬件接口等网络功能的管理

```shell
Usage: ip [ OPTIONS ] OBJECT { COMMAND | help }
       ip [ -force ] -batch filename
where  OBJECT := { link | addr | addrlabel | route | rule | neigh | ntable |
                   tunnel | tuntap | maddr | mroute | mrule | monitor | xfrm |
                   netns | l2tp | tcp_metrics | token }
       OPTIONS := { -V[ersion] | -s[tatistics] | -d[etails] | -r[esolve] |
                    -h[uman-readable] | -iec |
                    -f[amily] { inet | inet6 | ipx | dnet | bridge | link } |
                    -4 | -6 | -I | -D | -B | -0 |
                    -l[oops] { maximum-addr-flush-attempts } |
                    -o[neline] | -t[imestamp] | -b[atch] [filename] |
                    -rc[vbuf] [size] | -n[etns] name | -a[ll] }
```

1. ip netns
netns是在Linux中提供网络虚拟化的一个项目，使用netns网络空间虚拟化可以在本地虚拟化出多个网络环境。使用netns创建的网络空间独立于当前系统的网络空间，其中的网络设备以及iptables规则等都是独立的，就好像进入了另外一个网络一样。
```shell
Usage: ip netns list
        ip netns add NAME
        ip netns set NAME NETNSID
        ip [-all] netns delete [NAME]
        ip netns identify [PID]
        ip netns pids NAME
        ip [-all] netns exec [NAME] cmd ...
        ip netns monitor
        ip netns list-id
```

2. ip link
硬件设备的相关操作
```shell
ip -s -s link show                                  # 显示所有接口详细信息
ip -s -s link show eth1.11                          # 显示单独接口信息
ip link set dev eth1 up                             # 启动设备，相当于 ifconfig eth1 up
ip link set dev eth1 down                           # 停止设备，相当于 ifconfig eth1 down
ip link set dev eth1 txqueuelen 100                 # 改变设备传输队列长度
ip link set dev eth1 mtu 1200                       # 改变 MTU 长度
ip link set dev eth1 address 00:00:00:AA:BB:CC      # 改变 MAC 地址
ip link set dev eth1 name myeth                     # 接口名变更
```

3. ip neigh
ARP地址表相关
```shell
ip neighbor show                                                # 查看 ARP 表
ip neighbor add 10.1.1.1 lladdr 0:0:0:0:0:1 dev eth0 nud permit # 添加一条 ARP 相关表项
ip neighbor change 10.1.1.1 dev eth0 nud reachable              # 修改相关表项
ip neighbor del 10.1.1.1 dev eth0                               # 删除一条表项
ip neighbor flush                                               # 清除整个 ARP 表

Usage: ip neigh { add | del | change | replace } { ADDR [ lladdr LLADDR ]
            [ nud { permanent | noarp | stale | reachable } ]
            | proxy ADDR } [ dev DEV ]
        ip neigh {show|flush} [ to PREFIX ] [ dev DEV ] [ nud STATE ]
```

4. ip address
接口地址操作相关
```shell
ip -6 address add 2000:ff04::2/64 dev eth1.11       # 接口上添加地址
ip -6 address del 2000:ff04::2/64 dev eth1.11       # 删除接口上指定地址
ip -6 address flush dev eth1.11                     # 删除接口上所有地址
ip -6 address show <interface name>                 # 查看接口 ipv6 地址
ip address show <interface name>                    # 查看接口 IP 地址，包括 4/6 2个版本的
ip address add 192.168.1.1 broadcast +              # 设置接口地址和广播地址，+ 表示让系统自动计算
ip address add 192.68.1.1 dev eth1 label eth1.1     # 设置接口别名，注意别和 ip link set ... name 命令混淆
ip address add 192.68.1.1 dev eth1 scope global     # 设置接口领域，也就是可以接受的包的范围，有下面几种：
                                                    #   global  允许所有
                                                    #   site    仅允许 ipv6 和本机连接
                                                    #   link    仅允许本机连接
                                                    #   host    仅允许内部连接（和 link 的区别还不确定有哪些）
```

5. ip route
路由表相关
```shell
ip route add 2000:ff::/80 via 2000:ff04::1 dev eth1.11   # 添加一条路由
ip route add default via 2000:ff04::1 dev eth1.11        # 添加默认路由
ip route show                                            # 查看完整路由表
ip route show dev eth1.11                                # 查看指定接口路由项
ip route del 2000:ff04::/64                              # 删除所有相关路由表
ip route del 2000:ff04::/64 dev eth1.11                  # 删除相关接口上的路由表
ip route change 2000:ff04::/64 dev eth1.12               # 修改路由表项
ip route add nat 192.168.10.100 via 202.6.10.1              # 添加 NAT 路由项，将 192 地址转换成 202 地址
ip route replace default equalize nexthop via 211.139.218.145 dev eth0 weight 1 nexthop via 211.139.218.145 dev eth1 weight 1   # 添加负载均衡路由
```
