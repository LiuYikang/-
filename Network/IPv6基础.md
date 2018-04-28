# IPv6总结

## 1. 简介
IPv6（Internet Protocol Version 6）是网络层协议的第二代标准协议，也被称为IPng（IP Next Generation）。它是Internet工程任务组IETF（Internet Engineering Task Force）设计的一套规范，是IPv4（Internet Protocol Version 4）的升级版本。

IPv6的特点：
* 地址空间：IPv6地址采用128比特标识。128位的地址结构使IPv6理论上可以拥有（43亿×43亿×43亿×43亿）个地址。
* 报文格式：IPv6和IPv4相比，去除了IHL、Identifier、Flag、Fragment Offset、Header Checksum、 Option、Paddiing域，只增加了流标签域，因此IPv6报文头的处理较IPv4更为简化，提高了处理效率。另外，IPv6为了更好支持各种选项处理，提出了扩展头的概念，新增选项时不必修改现有结构，理论上可以无限扩展，体现了优异的灵活性。
* 自动配置和重新编址：IPv6协议内置支持通过地址自动配置方式使主机自动发现网络并获取IPv6地址，大大提高了内部网络的可管理性。
* 路由聚合：巨大的地址空间使得IPv6可以方便的进行层次化网络部署。层次化的网络结构可以方便的进行路由聚合，提高了路由转发效率。
* 对端到端的安全支持：IPv6中，网络层支持IPSec的认证和加密，支持端到端的安全。
* 对QoS的支持：IPv6新增了流标记域，提供QoS保证。
* 对移动性的支持：IPv6协议规定必须支持移动特性。和移动IPv4相比，移动IPv6使用邻居发现功能可直接实现外地网络的发现并得到转交地址，而不必使用外地代理。同时，利用路由扩展头和目的地址扩展头移动节点和对等节点之间可以直接通信，解决了移动IPv4的三角路由、源地址过滤问题，移动通信处理效率更高且对应用层透明。

## 2. 原理

### 2.1 IPv6地址
#### 表示方法
IPv6地址总长度为128比特，通常分为8组，每组为4个十六进制数的形式，每组十六进制数间用冒号分隔。例如：FC00:0000:130F:0000:0000:09C0:876A:130B，这是IPv6地址的首选格式。

为了书写方便，IPv6还提供了压缩格式，以上述IPv6地址为例，具体压缩规则为：
* 每组中的前导“0”都可以省略，所以上述地址可写为：FC00:0:130F:0:0:9C0:876A:130B。
* 地址中包含的连续两个或多个均为0的组，可以用双冒号“::”来代替，所以上述地址又可以进一步简写为：FC00:0:130F::9C0:876A:130B。
> 在一个IPv6地址中只能使用一次双冒号“::”，否则当计算机将压缩后的地址恢复成128位时，无法确定每个“::”代表0的个数。

#### 地址结构
IPv6的地址结构可以分成两部分：
1. 网络前缀：n比特，相当于网络ID
2. 接口标识：128-n比特，相当于主机ID，可以通过手工配置、系统通过软件自动生成或者通过IEEE EUI-64规范生成。

#### 地址分类
IPv6地址有三种类型：
1. 单播地址
    单播地址以1对1的方式标识一个接口，单播地址也分为多种：
    * 未指定地址

    IPv6中的未指定地址即 0:0:0:0:0:0:0:0/128 或者::/128。该地址可以表示某个接口或者节点还没有IP地址，可以作为某些报文的源IP地址（例如在NS报文的重复地址检测中会出现）。源IP地址是::的报文不会被路由设备转发。

    * 环回地址

    IPv6中的环回地址即 0:0:0:0:0:0:0:1/128 或者::1/128。环回与IPv4中的127.0.0.1作用相同，主要用于设备给自己发送报文。该地址通常用来作为一个虚接口的地址（如Loopback接口）。实际发送的数据包中不能使用环回地址作为源IP地址或者目的IP地址。

    * 全球单播地址

    全球单播地址是带有全球单播前缀的IPv6地址，其作用类似于IPv4中的公网地址。地址范围：2000::/3 ~ 3FFF::/3。这种类型的地址允许路由前缀的聚合，从而限制了全球路由表项的数量。

    ![](http://support.huawei.com/enterprise/product/images/bf85212f26cb4a34bbe3e85a42d2808c)

    全球单播地址由全球路由前缀（Global routing prefix）、子网ID（Subnet ID）和接口标识（Interface ID）组成:
        * Global routing prefix：全球路由前缀。由提供商（Provider）指定给一个组织机构，通常全球路由前缀至少为48位。目前已经分配的全球路由前缀的前3bit均为001。
        * Subnet ID：子网ID。组织机构可以用子网ID来构建本地网络（Site）。子网ID通常最多分配到第64位。子网ID和IPv4中的子网号作用相似。
        * Interface ID：接口标识。用来标识一个设备（Host）。

    地址分配区间如图：
    
    ![](http://support.huawei.com/huaweiconnect/data/attachment/forum/201708/04/20170804092157109001.jpg)

    * 链路本地地址

    链路本地地址是IPv6中的应用范围受限制的地址类型，只能在连接到同一本地链路的节点之间使用。它使用了特定的本地链路前缀FE80::/10（最高10位值为1111111010），同时将接口标识添加在后面作为地址的低64比特。

    当一个节点启动IPv6协议栈时，启动时节点的每个接口会自动配置一个链路本地地址（其固定的前缀+EUI-64规则形成的接口标识）。这种机制使得两个连接到同一链路的IPv6节点不需要做任何配置就可以通信。所以链路本地地址广泛应用于邻居发现，无状态地址配置等应用。

    以链路本地地址为源地址或目的地址的IPv6报文不会被路由设备转发到其他链路。

    ![](http://support.huawei.com/enterprise/product/images/0b716579e49c475cbf5bf6ddb0b0fd5f)

    * 唯一本地地址

    唯一本地地址是另一种应用范围受限的地址，它仅能在一个站点内使用。由于本地站点地址的废除（RFC3879），唯一本地地址被用来代替本地站点地址。

    唯一本地地址的作用类似于IPv4中的私网地址，任何没有申请到提供商分配的全球单播地址的组织机构都可以使用唯一本地地址。唯一本地地址只能在本地网络内部被路由转发而不会在全球网络中被路由转发。

    ![](http://support.huawei.com/enterprise/product/images/987172827b4b4238ba2f311102282c39)
    
        * Prefix：前缀；固定为FC00::/7。
        * L：L标志位；值为1代表该地址为在本地网络范围内使用的地址；值为0被保留，用于以后扩展。
        * Global ID：全球唯一前缀；通过伪随机方式产生。
        * Subnet ID：子网ID；划分子网使用。
        * Interface ID：接口标识。

    唯一本地地址具有如下特点：
        * 具有全球唯一的前缀（虽然随机方式产生，但是冲突概率很低）。
        * 可以进行网络之间的私有连接，而不必担心地址冲突等问题。
        * 具有知名前缀（FC00::/7），方便边缘设备进行路由过滤。
        * 如果出现路由泄漏，该地址不会和其他地址冲突，不会造成Internet路由冲突。
        * 应用中，上层应用程序将这些地址看作全球单播地址对待。
        * 独立于互联网服务提供商ISP（Internet Service Provider）。

    Global ID可以根据[RFC4193](https://tools.ietf.org/html/rfc4193#section-3.2)提供的计算方式计算得出，[可以使用该网站计算Global ID](https://cd34.com/rfc4193)。

2. 组播地址

    IPv6的组播与IPv4相同，用来标识一组接口，一般这些接口属于不同的节点。一个节点可能属于0到多个组播组。发往组播地址的报文被组播地址标识的所有接口接收。例如组播地址FF02::1表示链路本地范围的所有节点，组播地址FF02::2表示链路本地范围的所有路由器。

    一个IPv6组播地址由前缀，标志（Flag）字段、范围（Scope）字段以及组播组ID（Global ID）4个部分组成：
    * 前缀：IPv6组播地址的前缀是FF00::/8。
    * 标志字段（Flag）：长度4bit，目前只使用了最后一个比特（前三位必须置0），当该位值为0时，表示当前的组播地址是由IANA所分配的一个永久分配地址；当该值为1时，表示当前的组播地址是一个临时组播地址（非永久分配地址）。
    * 范围字段（Scope）：长度4bit，用来限制组播数据流在网络中发送的范围。
    * 组播组ID（Group ID）：长度112bit，用以标识组播组。目前，RFC2373并没有将所有的112位都定义成组标识，而是建议仅使用该112位的最低32位作为组播组ID，将剩余的80位都置0。这样每个组播组ID都映射到一个唯一的以太网组播MAC地址（RFC2464）。
    * 被请求节点组播地址

    被请求节点组播地址通过节点的单播或任播地址生成。当一个节点具有了单播或任播地址，就会对应生成一个被请求节点组播地址，并且加入这个组播组。一个单播地址或任播地址对应一个被请求节点组播地址。该地址主要用于邻居发现机制和地址重复检测功能。

    IPv6中没有广播地址，也不使用ARP。但是仍然需要从IP地址解析到MAC地址的功能。在IPv6中，这个功能通过邻居请求NS（Neighbor Solicitation）报文完成。当一个节点需要解析某个IPv6地址对应的MAC地址时，会发送NS报文，该报文的目的IP就是需要解析的IPv6地址对应的被请求节点组播地址；只有具有该组播地址的节点会检查处理。

    被请求节点组m播地址由前缀FF02::1:FF00:0/104和单播地址的最后24位组成。

    ![](http://support.huawei.com/enterprise/product/images/3e903420076b4b1996f963eb30c182b2)

3. 任播地址

    任播地址标识一组网络接口（通常属于不同的节点）。目标地址是任播地址的数据包将发送给其中路由意义上最近的一个网络接口。

    任播地址设计用来在给多个主机或者节点提供相同服务时提供冗余功能和负载分担功能。目前，任播地址的使用通过共享单播地址方式来完成。将一个单播地址分配给多个节点或者主机，这样在网络中如果存在多条该地址路由，当发送者发送以任播地址为目的IP的数据报文时，发送者无法控制哪台设备能够收到，这取决于整个网络中路由协议计算的结果。这种方式可以适用于一些无状态的应用，例如DNS等。

    IPv6中没有为任播规定单独的地址空间，任播地址和单播地址使用相同的地址空间。目前IPv6中任播主要应用于移动IPv6。

    > IPv6任播地址仅可以被分配给路由设备，不能应用于主机。任播地址不能作为IPv6报文的源地址。

    * 子网任播地址

        子网路由器任播地址是已经定义好的一种任播地址（RFC3513）。发送到子网路由器任播地址的报文会被发送到该地址标识的子网中路由意义上最近的一个设备。所有设备都必须支持子网任播地址。子网路由器任播地址用于节点需要和远端子网上所有设备中的一个（不关心具体是哪一个）通信时使用。例如，一个移动节点需要和它的“家乡”子网上的所有移动代理中的一个进行通信。

        子网路由器任播地址由n bit子网前缀标识子网，其余用0填充。
        
    ![](http://support.huawei.com/enterprise/product/images/58d4c5cc9f6843c488cd29c6b4766a8e)

### 2.2 报文格式
IPv6的报文格式主要由基本报头、拓展报头和上层协议数据单元三部分组成。

1. 基本报头

    IPv6基本报头有8个字段，固定大小为40字节，每一个IPv6数据报都必须包含报头。基本报头提供报文转发的基本信息，会被转发路径上面的所有设备解析。
    ![](http://support.huawei.com/enterprise/product/images/77b3ae90832e4c33a5a985e2e4d6c4fb)

    报头字段解释：
    * Version：版本号，长度为4bit。对于IPv6，该值为6。
    * Traffic Class：流类别，长度为8bit。等同于IPv4中的TOS字段，表示IPv6数据报的类或优先级，主要应用于QoS。
    * Flow Label：流标签，长度为20bit。IPv6中的新增字段，用于区分实时流量，不同的流标签+源地址可以唯一确定一条数据流，中间网络设备可以根据这些信息更加高效率的区分数据流。
    * Payload Length：有效载荷长度，长度为16bit。有效载荷是指紧跟IPv6报头的数据报的其它部分（即扩展报头和上层协议数据单元）。该字段只能表示最大长度为65535字节的有效载荷。如果有效载荷的长度超过这个值，该字段会置0，而有效载荷的长度用逐跳选项扩展报头中的超大有效载荷选项来表示。
    * Next Header：下一个报头，长度为8bit。该字段定义紧跟在IPv6报头后面的第一个扩展报头（如果存在）的类型，或者上层协议数据单元中的协议类型。
    * Hop Limit：跳数限制，长度为8bit。该字段类似于IPv4中的Time to Live（TTL)字段，它定义了IP数据报所能经过的最大跳数。每经过一个设备，该数值减去1，当该字段的值为0时，数据报将被丢弃。
    * Source Address：源地址，长度为128bit。表示发送方的地址。
    * Destination Address：目的地址，长度为128bit。表示接收方的地址。

2. 拓展报头

    ![](http://support.huawei.com/enterprise/product/images/50d79c6f134c4efca567ef24af41edf7)

    IPv6的拓展报头类似于IPv4的可选字段，IPv6将这些可选字段从IPv6基本报头中剥离，放到了扩展报头中，扩展报头被置于IPv6报头和上层协议数据单元之间。一个IPv6报文可以包含0个、1个或多个扩展报头，仅当需要设备或目的节点做某些特殊处理时，才由发送方添加一个或多个扩展头。与IPv4不同，IPv6扩展头长度任意，不受40字节限制，这样便于日后扩充新增选项，这一特征加上选项的处理方式使得IPv6选项能得以真正的利用。但是为了提高处理选项头和传输层协议的性能，扩展报头总是8字节长度的整数倍。

    IPv6扩展报头中主要字段解释如下：
    * Next Header：下一个报头，长度为8bit。与基本报头的Next Header的作用相同。指明下一个扩展报头（如果存在）或上层协议的类型。
    * Extension Header Len：报头扩展长度，长度为8bit。表示扩展报头的长度（不包含Next Header字段）。
    * Extension Head Data：扩展报头数据，长度可变。扩展报头的内容，为一系列选项字段和填充字段的组合。


3. 上层协议数据单元

## 3. 应用与分析

### 3.1 通信

IPv4的通信是网卡获取到ip地址之后，使用arp协议获取需要通信的其他设备的mac地址，拥有了ip和mac之后，才能进行三层和二层网络的通信。

IPv6使用ICMPv6邻居发现协议（NDP）替代了IPv4的ARP协议，通过使用NDP协议获取相同链路邻居节点的mac地址。

邻居发现协议定义了五种ICMPv6的类型：
* **RS（Router Solicitation，路由请求）**：ICMPv6类型为133，主机在其段上发送路由器请求组播数据包(FF02 :: 2/16)，以了解此段上任何路由器的存在。 它帮助主机将路由器配置为其默认网关。 如果其默认网关路由器关闭，主机可以切换到新的路由器，并使其成为默认网关。RS的目的端mac地址为33:33:00:00:00:02。
* **RA（Router Advertisment，路由公告）**：ICMPv6类型为134，当路由器接收到路由器请求消息时，它回应主机，通告它在该链路上的存在。RA目的端的mac地址为33:33:00:00:00:01
* **NS（Neighbor Solicitationh，领居请求）**：ICMPv6类型为135，手动或通过DHCP服务器或自动配置配置所有IPv6后，主机向其所有IPv6地址的FF02 :: 1/16组播地址发送邻居请求消息。NS目的端的mac地址为33:33:FF:xx:xx:xx。
* **NA（Neighbor Advertisement，邻居公告）**：ICMPv6类型为136，响应邻居请求，告知本地地址和mac。
* **Redirect（重定向报文）**：ICMPv6类型为137，路由器收到路由器请求，但它知道它不是主机的最佳网关的情况。 在这种情况下，路由器发回一个重定向消息，告诉主机有一个更好的“下一跳"路由器可用。 下一跳是主机将其发送给不属于相同段的主机的数据发送的地方。

邻居可达性状态机保存在邻居缓存表中，共有如下6种状态：

1. **INCOMPLETE（未完成状态）**：表示正在解析地址，但邻居链路层地址尚未确定。

2. **REACHABLE（可达状态）**：表示地址解析成功，该邻居可达。

3. **STALE（失效状态）**：表示可达时间耗尽，未确定邻居是否可达。

4. **DELAY（延迟状态）**：表示未确定邻居是否可达。DELAY状态不是一个稳定的状态，而是一个延时等待状态。

5. **PROBE（探测状态）**：节点会向处于PROBE状态的邻居持续发送NS报文。

6. **EMPTY（空闲状态）**：表示节点上没有相关邻接点的邻居缓存表项。

#### ping的使用
对于IPv6，可以使用ping来测试网络的联通性，使用 -6 的参数来指定协议族。

```shell
# ping IPv6
[root@CentOS ~]# ping -6 fd2e:e448:3ca2::23
PING fd2e:e448:3ca2::23(fd2e:e448:3ca2::23) 56 data bytes
64 bytes from fd2e:e448:3ca2::23: icmp_seq=1 ttl=64 time=0.481 ms
64 bytes from fd2e:e448:3ca2::23: icmp_seq=2 ttl=64 time=0.362 ms
64 bytes from fd2e:e448:3ca2::23: icmp_seq=3 ttl=64 time=0.295 ms
64 bytes from fd2e:e448:3ca2::23: icmp_seq=4 ttl=64 time=0.315 ms

# 在fd2e:e448:3ca2::23抓包，可以看到NS和NA的报文
23:34:53.255914 52:54:00:c7:18:b5 > 33:33:ff:00:00:23, ethertype IPv6 (0x86dd), length 86: fd2e:e448:3ca2::22 > ff02::1:ff00:23: ICMP6, neighbor solicitation, who has fd2e:e448:3ca2::23, length 32
23:34:53.255964 52:54:00:c7:18:b6 > 52:54:00:c7:18:b5, ethertype IPv6 (0x86dd), length 86: fd2e:e448:3ca2::23 > fd2e:e448:3ca2::22: ICMP6, neighbor advertisement, tgt is fd2e:e448:3ca2::23, length 32
23:34:53.256100 52:54:00:c7:18:b5 > 52:54:00:c7:18:b6, ethertype IPv6 (0x86dd), length 118: fd2e:e448:3ca2::22 > fd2e:e448:3ca2::23: ICMP6, echo request, seq 1, length 64
23:34:53.256141 52:54:00:c7:18:b6 > 52:54:00:c7:18:b5, ethertype IPv6 (0x86dd), length 118: fd2e:e448:3ca2::23 > fd2e:e448:3ca2::22: ICMP6, echo reply, seq 1, length 64

# ping之前，在fd2e:e448:3ca2::2222上的neighbor表
[root@CentOS ~]# ip -6 nei
fe80::f816:3eff:fe73:152 dev eth0 lladdr fa:16:3e:73:01:52 STALE
fd2e:e448:3ca2::1 dev eth0 lladdr 0c:c4:7a:82:76:83 router DELAY
fe80::f816:3eff:fe9a:e858 dev eth0 lladdr fa:16:3e:9a:e8:58 STALE
fe80::ec4:7aff:fe82:7683 dev eth0 lladdr 0c:c4:7a:82:76:83 router STALE

# ping之后，在fd2e:e448:3ca2::2222上的neighbor表
[root@CentOS ~]# ip -6 nei
fe80::f816:3eff:fe73:152 dev eth0 lladdr fa:16:3e:73:01:52 STALE
fd2e:e448:3ca2::1 dev eth0 lladdr 0c:c4:7a:82:76:83 router DELAY
fe80::f816:3eff:fe9a:e858 dev eth0 lladdr fa:16:3e:9a:e8:58 STALE
fd2e:e448:3ca2::23 dev eth0 lladdr 52:54:00:c7:18:b6 STALE
fe80::ec4:7aff:fe82:7683 dev eth0 lladdr 0c:c4:7a:82:76:83 router STALE
```

### 3.2 地址分配

IPv6的地址分配支持多种方式：
* **开启了IPv6协议栈**，接口自动分配链路本地地址（FE80::/10 ~ FEBF::/10）。
* **无状态自动配置地址**，SLAAC，据网络RA（路由通告）并根据自己的MAC地址计算出自己的IPv6地址，无状态服务意味着没有维护网络地址信息的服务器。 与 DHCP 不同，没有 SLAAC 服务器知道哪些 IPv6 地址正在使用中，哪些地址是可用的。
* **有状态自动配置地址**，DHCPv6，neutron使用dnsmasq在网桥搭建dhcp服务器。
* **手动配置**，配置ifcfg文件。

#### DHCPv6地址分配

dnsmasq可以配置DHCPv4和DHCPv6的服务器，支持动态分配和静态分配以及其他功能。详细可参考dnsmasq的[man-page](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html)

DHCPv6是一个用来配置工作在IPv6网络上的IPv6主机所需的IP地址、IP前缀和/或其他配置的网络协议。IPv6主机可以使用DHCPv6来获得IP地址。DHCP倾向于被用在需要集中管理主机的站点。
> DHCPv6客户端使用UDP端口号546，服务器使用端口号547。

DHCPv6动态获取IP的流程描述如下：
* DHCPv6客户端从[fe80::aabb:ccff:fedd:eeff]:546发送Solicit至[ff02::1:2]:547。
* DHCPv6服务器从[fe80::0011:22ff:fe33:5566]:547回应一个Advertise给[fe80::aabb:ccff:fedd:eeff]:546。
* DHCPv6客户端从[fe80::aabb:ccff:fedd:eeff]:546回应一个Request给[ff02::1:2]:547。（依照RFC 3315的section 13，所有客户端消息都发送到多播地址)
* DHCPv6服务器以[fe80::0011:22ff:fe33:5566]:547到[fe80::aabb:ccff:fedd:eeff]:546的Reply结束。

使用dnsmasq在网桥上搭建一个DHCPv6的服务器：
1. 开启宿主机的IPv6的转发
    ```shell
    # 在/etc/sysctl.conf文件中加入以下字段
    net.ipv6.conf.all.forwarding = 1
    net.ipv6.conf.default.forwarding = 1

    # 重新加载，-p 默认读取/etc/sysctl.conf配置
    sysctl -p
    ```
2. 配置DHCPv6的端口
    ```shell
    # 使用ip6tables开启宿主机DHCPv6的546和547端口，如果防火墙没有开启，该步骤可以省略
    ip6tables -A INPUT_direct --in-interface br-eno2 -p tcp --dport 547 -j ACCEPT
    ip6tables -A INPUT_direct --in-interface br-eno2 -p udp --dport 547 -j ACCEPT

    ip6tables -A OUTPUT_direct --out-interface br-eno2 -p udp --dport 546 -j ACCEPT
    ```
3. 配置dnsmasq的DHCP服务器
    * 动态DHCP服务器
        ```shell
        # --interface指定网桥为br-eno2，--dhcp-range指定了地址段，网络号使用网桥IP的网络号
        dnsmasq --no-hosts --no-resolv --strict-order --except-interface=lo --pid-file=/opt/test_ipv6/pid --dhcp-leasefile=/opt/test_ipv6/leases --dhcp-match=set:ipxe,175 --bind-interfaces --interface=br-eno2 --dhcp-range=::1,::FFFF:FFFF,constructor:br-eno2,64,604800s --dhcp-lease-max=16777216 --conf-file= --log-queries --log-dhcp --log-facility=/opt/test_ipv6/dhcp_dns_log
        ```
    * 静态DHCP服务器
        ```shell
        # 在--dhcp-hostsfile指定的host文件中写入mac地址和ip的映射，用于提供对应mac一个静态的地址
        52:54:00:c7:18:b5,CentOS,[fd2e:e448:3ca2:0::22]

        # 配置DHCP服务器，指定地址段为fd2e:e448:3ca2:0::，改地址段为ULA地址，类似于IPv4的私有地址
        dnsmasq --no-hosts --no-resolv --strict-order --except-interface=lo --pid-file=/opt/test_ipv6/pid  --dhcp-hostsfile=/opt/test_ipv6/host --addn-hosts=/opt/test_ipv6/addn_hosts --dhcp-optsfile=/opt/test_ipv6/opts --dhcp-leasefile=/opt/test_ipv6/leases --dhcp-match=set:ipxe,175 --bind-interfaces --interface=br-eno2 --dhcp-range=fd2e:e448:3ca2:0::,static,64,604800s --dhcp-lease-max=16777216 --conf-file= --log-queries --log-dhcp --log-facility=/opt/test_ipv6/dhcp_dns_log
        ```
4. 在网桥上创建一个kvm虚拟机，配置虚拟机的ifcfg文件来自动获取IPv6地址。
    ```shell
    # ifcfg-eth0配置
    TYPE=Ethernet
    NAME=eth0
    DEVICE=eth0
    ONBOOT=yes
    IPV6INIT=yes
    DHCPV6C=yes
    ```

DHCPv6分配ip抓包：
```shell
16:51:27.830925 52:54:00:c7:18:b5 > 33:33:00:01:00:02, ethertype IPv6 (0x86dd), length 142: fe80::5054:ff:fec7:18b5.dhcpv6-client > ff02::1:2.dhcpv6-server: dhcp6 confirm
16:51:27.831343 0c:c4:7a:82:76:83 > 52:54:00:c7:18:b5, ethertype IPv6 (0x86dd), length 122: fe80::ec4:7aff:fe82:7683.dhcpv6-server > fe80::5054:ff:fec7:18b5.dhcpv6-client: dhcp6 reply
16:51:27.962155 52:54:00:c7:18:b5 > 33:33:00:01:00:02, ethertype IPv6 (0x86dd), length 114: fe80::5054:ff:fec7:18b5.dhcpv6-client > ff02::1:2.dhcpv6-server: dhcp6 solicit
16:51:27.962645 0c:c4:7a:82:76:83 > 52:54:00:c7:18:b5, ethertype IPv6 (0x86dd), length 202: fe80::ec4:7aff:fe82:7683.dhcpv6-server > fe80::5054:ff:fec7:18b5.dhcpv6-client: dhcp6 advertise
16:51:29.023408 52:54:00:c7:18:b5 > 33:33:00:01:00:02, ethertype IPv6 (0x86dd), length 160: fe80::5054:ff:fec7:18b5.dhcpv6-client > ff02::1:2.dhcpv6-server: dhcp6 request
16:51:29.038320 0c:c4:7a:82:76:83 > 52:54:00:c7:18:b5, ethertype IPv6 (0x86dd), length 197: fe80::ec4:7aff:fe82:7683.dhcpv6-server > fe80::5054:ff:fec7:18b5.dhcpv6-client: dhcp6 reply
```

#### 静态地址配置

静态地址配置就是通过ifcfg文件配置静态地址，或者可以用ip addr命令直接加一个地址到设备上。

```shell
# ifcfg-eth0
TYPE=Ethernet
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPV6INIT=yes
IPV6ADDR=fd2e:e448:3ca2::183
IPV6PREFIX=64
IPV6_AUTOCONF=no
```

### 3.3 路由

#### route
```shell
# 查看路由
route -6 -n

# 添加路由
route -A inet6 add <ipv6network>/<prefixlength> gw <ipv6address> [dev <device>]
route -A inet6 add <ipv6network>/<prefixlength> dev <device>

# 删除路由
route -A inet6 del <network>/<prefixlength> gw <ipv6address> [dev <device>]
route -A inet6 del <network>/<prefixlength> dev <device>

# 添加默认路由
route -A inet6 add default dev <device>
route -A inet6 add default gw <ipv6address>

# 删除默认路由
route -A inet6 del default dev <device>
route -A inet6 del default gw <ipv6address>
```

#### ip route
```shell
# 查看路由
ip -6 route show [dev <device>]

# 添加路由
ip -6 route add <ipv6network>/<prefixlength> via <ipv6address> [dev <device>]
ip -6 route add <ipv6network>/<prefixlength> dev <device>

# 删除路由
ip -6 route del <ipv6network>/<prefixlength> via <ipv6address> [dev <device>]
ip -6 route del <ipv6network>/<prefixlength> dev <device>

# 添加默认路由
ip -6 route add default via <ipv6address>
ip -6 route add default dev <device> metric 1

# 删除默认路由
ip -6 route del default via <ipv6address>
ip -6 route del default dev <device>
```

### 3.4 ip6tables

ip6tables和iptables的使用方法一直，也是对网络进行管理控制，iptables的规则对于ip6tables是不生效的，相互独立。
