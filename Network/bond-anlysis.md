## 问题描述
bond alb模式流量无法达到稳定的4*1Gb网卡带宽

## 初步分析
1. 测试方法：
    * server端，宿主机的4个网口做alb聚合后挂接到linux bridge上，然后创建4个虚拟机挂接到bridge上。
    * client端，宿主机每个网口分别挂一个linux bridge上，每个bridge上分别创建一个虚拟机。
    * 从client往server iperf3打tcp流，4个client与4个server组成独立的4对。
2. 测试情况：
    * iperf3打流过程中，server端会每隔26秒向client端发送一个ARP请求，该ARP请求的smac地址是bonding active slave的mac地址，导致client端ARP表项更新了目的MAC地址，流量发送到active slave网卡上。
    * 当两三路测试流同时打到active slave网卡时，原来每路测试流950Mbps就无法持续了，因为两三路流同时分享了active slave这一张网卡的带宽。
3. 原因分析和应对办法：
    * 原因在于server端会周期性地发送ARP request到client段，而且smac都是active slave的mac地址，导致client端更新了目的mac地址。
    * 应对办法：26秒周期取决于 /proc/sys/net/ipv4/neigh/br-bond0/delay_first_probe_time，确实设置的是5。调整该参数可以降低ARP请求的频度，降低问题发生概率，但是不能彻底解决问题。

## 继续探索
1. delay_first_probe_time这个参数改成500，打流测试表现正常。网上查到有其他人碰到过类似的问题，也是通过调整这个参数缓解的，但是目前没有根治的方法（调整这个参数的风险是在arp表项为delay，即无法保证其可靠性的情况下，表项还是被正常用于发送数据包。

2. delay_first_probe_time的含义：邻居进入stable状态，协议栈发送arp请求包、设置定时器等待delay_first_probe_time时间（缺省是5秒），如果delay_first_probe_time时间内，收到了arp响应，邻居状态迁移到reachable，否则邻居状态迁移到probe，系统会发送单播的邻居请求报文。

## 问题依旧
发现出现alb模式流量无法达到稳定的4*1Gb网卡带宽的原因：
bond上配置了4个不同的ip，通过创建4台虚拟机，映射到bond的4个ip上。这样的server端的情况会导致alb流量重叠到一张网卡上。

## 最终结论
1. 周期性arp报文更新了客户端arp表项的影响：
    * 在4个千兆网口配置的环境中，如果接入的视频流路数为400路，*4M/路，即1600Mbps，平均到4个网口为400Mbps，即每个网口有500Mbps带宽富余，可以容纳更多的流量。
    * 周期性arp是针对每个客户端的，只要不是过多的视频流（超过1G）集中到第一个slave，是不会造成丢包的。
    * 周期性arp的触发周期可以从缺省的5秒调整为522秒，大大降低视频流集中的机会。
2. 现有的设计带来的好处：交付人员不用关心现场服务器网卡的连线情况（现场服务器网卡往往有些口上是不插线的），交付具备可行性。
3. 现有的设计带来的约束：一台服务服务器上只能安装应用的一份实例，不能安装多份。
4. 可选方案：
    * 2网口SR-IOV + 2网口组bond方案。优点：可以部署某个组件多份实例。缺陷：现场交付实施困难——网口顺序不一致、网口未必插线；工程上可行性欠缺。
    * 4网口SR-IOV + 虚拟机内部组bond方案。优点：虚拟机不用关心网卡状态（有些网卡不连线也可）。缺陷：千兆网卡SR-IOV最多可用7个VF设备，即最多只能建7个虚拟机。

