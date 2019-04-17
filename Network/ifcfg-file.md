DEVICE="eth1"

    网卡名称
NM_CONTROLLED="yes"

    network mamager的参数 ,是否可以由NNetwork Manager托管，建议设置成no

HWADDR=

    MAC地址
TYPE=Ethernet

    类型

PREFIX=24

    子网掩码24位

DEFROUTE=yes

    就是default route，是否把这个eth设置为默认路由

ONBOOT=yes

    设置为yes，开机自动启用网络连接
IPADDR=

    IP地址
BOOTPROTO=none

    设置为none禁止DHCP，设置为static启用静态IP地址，设置为dhcp开启DHCP服务
NETMASK=255.255.255.0

    子网掩码
DNS1=8.8.8.8

    第一个dns服务器

BROADCAST

    广播

UUID

    唯一标识

TYPE=Ethernet

    网络类型为：Ethernet

BRIDGE=

    设置桥接网卡

GATEWAY=

    设置网关
DNS2=8.8.4.4 #

    第二个dns服务器
IPV6INIT=no

    禁止IPV6
USERCTL=no

    是否允许非root用户控制该设备，设置为no，只能用root用户更改
NAME="System eth1"

    这个就是个网络连接的名字

MASTER=bond1

    指定主的名称

SLAVE

    指定了该接口是一个接合界面的组件。

NETWORK

    网络地址

ARPCHECK=yes
    检测

PEERDNS

    是否允许DHCP获得的DNS覆盖本地的DNS

PEERROUTES

    是否从DHCP服务器获取用于定义接口的默认网关的信息的路由表条目

IPV6INIT

    是否启用IPv6的接口。

IPV4_FAILURE_FATAL=yes

    如果ipv4配置失败禁用设备

IPV6_FAILURE_FATAL=yes

    如果ipv6配置失败禁用设备
