# 分布式知识整理

##  分布式锁

常见的锁方案如下：
* 基于数据库实现分布式锁
* 基于缓存，实现分布式锁，如redis
* 基于Zookeeper实现分布式锁

[分布式锁的一点理解](https://www.cnblogs.com/suolu/p/6588902.html)
[基于redis的分布式锁实现](http://blueskykong.com/2018/01/06/redislock/)

## kafka系列

http://www.jasongj.com/tags/Kafka/

* Broker
　　Kafka集群包含一个或多个服务器，这种服务器被称为broker
* Topic
　　每条发布到Kafka集群的消息都有一个类别，这个类别被称为Topic。（物理上不同Topic的消息分开存储，逻辑上一个Topic的消息虽然保存于一个或多个broker上但用户只需指定消息的Topic即可生产或消费数据而不必关心数据存于何处）
* Partition
　　Parition是物理上的概念，每个Topic包含一个或多个Partition.kafka的高可用可以通过给Partiton设置replica来实现，Partition和replica需要按照以下规则分布到不同的broker上：

    Kafka分配Replica的算法如下：

    1. 将所有Broker（假设共n个Broker）和待分配的Partition排序
    2. 将第i个Partition分配到第（i mod n）个Broker上
    3. 将第i个Partition的第j个Replica分配到第（(i + j) mod n）个Broker上
    > 更加详细的参考：http://www.jasongj.com/2015/04/24/KafkaColumn2/
* Producer
　　负责发布消息到Kafka broker，使用push方式
* Consumer
　　消息消费者，向Kafka broker读取消息的客户端。使用pull方式
* Consumer Group
　　每个Consumer属于一个特定的Consumer Group（可为每个Consumer指定group name，若不指定group name则属于默认的group）。

#### CopyOnWrite在kafka中的实践

[CopyOnWrite以及kafka的实践](https://juejin.im/post/5cd1724cf265da03a7440aae)

[golang中CopyOnWrite](https://my.oschina.net/u/222608/blog/881263)

#### acks参数对消息持久化的影响

acks参数，是在KafkaProducer，也就是生产者客户端里设置的也就是说，你往kafka写数据的时候，就可以来设置这个acks参数。然后这个参数实际上有三种常见的值可以设置，分别是：**0、1 和 all**。

1. **第一种选择是把acks参数设置为0**，意思就是我的KafkaProducer在客户端，只要把消息发送出去，不管那条数据有没有在哪怕Partition Leader上落到磁盘，我就不管他了，直接就认为这个消息发送成功了。如果你采用这种设置的话，那么你必须注意的一点是，可能你发送出去的消息还在半路。结果呢，Partition Leader所在Broker就直接挂了，然后结果你的客户端还认为消息发送成功了，此时就会导致这条消息就丢失了。

2. **第二种选择是设置 acks = 1**，意思就是说只要Partition Leader接收到消息而且写入本地磁盘了，就认为成功了，不管他其他的Follower有没有同步过去这条消息了。这种设置其实是kafka默认的设置，大家请注意，**划重点！**，这是默认的设置也就是说，默认情况下，你要是不管acks这个参数，只要Partition Leader写成功就算成功。但是这里有一个问题，万一Partition Leader刚刚接收到消息，Follower还没来得及同步过去，结果Leader所在的broker宕机了，此时也会导致这条消息丢失，因为人家客户端已经认为发送成功了。

3. **最后一种情况，就是设置acks=all**，这个意思就是说，Partition Leader接收到消息之后，还必须要求**ISR列表**里跟Leader保持同步的那些Follower都要把消息同步过去，才能认为这条消息是写入成功了。如果说Partition Leader刚接收到了消息，但是结果Follower没有收到消息，此时Leader宕机了，那么客户端会感知到这个消息没发送成功，他会重试再次发送消息过去。此时可能Partition 2的Follower变成Leader了，此时ISR列表里只有最新的这个Follower转变成的Leader了，那么只要这个新的Leader接收消息就算成功了。

参考：https://juejin.im/post/5cbf2d58f265da0380436fde

#### consumer group

[Kafka消费组(consumer group)](https://www.cnblogs.com/huxi2b/p/6223228.html)

## RabbitMQ

## Redis

[Redis 数据结构和对象系统](https://juejin.im/post/5d067941f265da1bb13f30d2)

Redis数据结构字典使用的hash算法是 **MurmurHash2** 算法，该算法也是Memcached、nginx使用的一致性hash算法

[Redis分布式锁的实现原理](https://juejin.im/post/5bf3f15851882526a643e207)

[使用 Redis的SETNX命令实现分布式锁](https://www.jianshu.com/p/c970cc71070b)

[redis常用场景](https://zhuanlan.zhihu.com/p/29665317)

[redis加锁的几种实现](http://ukagaka.github.io/php/2017/09/21/redisLock.html)

[谈谈Redis的SETNX](https://blog.huoding.com/2015/09/14/463)

[Redis持久化----RDB和AOF 的区别](https://blog.csdn.net/ljheee/article/details/76284082)

#### Redis对象与底层数据结构

1. Redis对象

| 类型常量     | 对象的名称   | 底层数据结构                                      |
| ------------ | ------------ | ------------------------------------------------- |
| REDIS_STRING | 字符串对象   | INT、EMBSTR、RAW                                  |
| REDIS_LIST   | 列表对象     | ZIPLIST(元素不多且元素不大的时候)、LINKEDLIST     |
| REDIS_HASH   | 哈希对象     | ZIPLIST(元素不多且元素不大的时候)、HT             |
| REDIS_SET    | 集合对象     | INTSET、HT                                        |
| REDIS_ZSET   | 有序集合对象 | ZIPLIST(元素不多且元素不大的时候)、SKIPLIST配合HT |

2. Redis底层数据结构

| 编码常量                  | 编码所对应的底层数据结构    |
| ------------------------- | --------------------------- |
| REDIS_ENCODING_INT        | long 类型的整数             |
| REDIS_ENCODING_EMBSTR     | embstr 编码的简单动态字符串 |
| REDIS_ENCODING_RAW        | 简单动态字符串              |
| REDIS_ENCODING_HT         | 字典                        |
| REDIS_ENCODING_LINKEDLIST | 双端链表                    |
| REDIS_ENCODING_ZIPLIST    | 压缩列表                    |
| REDIS_ENCODING_INTSET     | 整数集合                    |
| REDIS_ENCODING_SKIPLIST   | 跳跃表和字典                |

参考： 
[Redis的五种对象类型及其底层实现](https://blog.csdn.net/caishenfans/article/details/44784131)

[Redis内部数据结构详解(7)——intset](http://zhangtielei.com/posts/blog-redis-intset.html)

[Redis内部数据结构详解(6)——skiplist](http://zhangtielei.com/posts/blog-redis-skiplist.html)

[Redis内部数据结构详解(5)——quicklist](http://zhangtielei.com/posts/blog-redis-quicklist.html)

[Redis内部数据结构详解(4)——ziplist](http://zhangtielei.com/posts/blog-redis-ziplist.html)

[Redis内部数据结构详解(3)——robj](http://zhangtielei.com/posts/blog-redis-robj.html)

[Redis内部数据结构详解(2)——sds](http://zhangtielei.com/posts/blog-redis-sds.html)

[Redis内部数据结构详解(1)——dict](http://zhangtielei.com/posts/blog-redis-dict.html)

#### Redis典型场景

[redis学习（八）——redis应用场景](https://www.cnblogs.com/xiaoxi/p/7007695.html)

[Redis的7个应用场景](https://www.cnblogs.com/NiceCui/p/7794659.html)

[Redis 原理及应用（4）--Redis应用场景分析](https://blog.csdn.net/u013679744/article/details/79209341)

## etcd & raft

[Raft共识算法](http://www.calvinneo.com/2019/03/12/raft-algorithm/)

[Raft协议详解-基础知识和leader选举](https://zhuanlan.zhihu.com/p/29130892)

[raft原理（一）：选主与日志复制](http://oserror.com/distributed/raft-principle-one/)

## Ceph

#### 核心概念

* Monitor
一个Ceph集群需要多个Monitor组成的小集群，它们通过Paxos同步数据，用来保存OSD的元数据。

* OSD
OSD全称Object Storage Device，也就是负责响应客户端请求返回具体数据的进程。一个Ceph集群一般都有很多个OSD。

* MDS
MDS全称Ceph Metadata Server，是CephFS服务依赖的元数据服务。

* Object
Ceph最底层的存储单元是Object对象，每个Object包含元数据和原始数据。

* PG
PG全称Placement Grouops，是一个逻辑的概念，一个PG包含多个OSD。引入PG这一层其实是为了更好的分配数据和定位数据。

* RADOS
RADOS全称Reliable Autonomic Distributed Object Store，是Ceph集群的精华，用户实现数据分配、Failover等集群操作。

* Libradio
Librados是Rados提供库，因为RADOS是协议很难直接访问，因此上层的RBD、RGW和CephFS都是通过librados访问的，目前提供PHP、Ruby、Java、Python、C和C++支持。

* CRUSH
CRUSH是Ceph使用的数据分布算法，类似一致性哈希，让数据分配到预期的地方。

* RBD
RBD全称RADOS block device，是Ceph对外提供的块设备服务。

* RGW
RGW全称RADOS gateway，是Ceph对外提供的对象存储服务，接口与S3和Swift兼容。

* CephFS
CephFS全称Ceph File System，是Ceph对外提供的文件系统服务。

参考：https://blog.csdn.net/uxiAD7442KMy1X86DtM3/article/details/81059215

## glusterfs

https://blog.csdn.net/liuaigui/article/details/70219377 \


## Micro-service

## Loadbalance

### HAProxy

### Keepalived

## QoS

### 令牌桶算法

令牌桶算法(Token Bucket)和 Leaky Bucket 效果一样但方向相反的算法,更加容易理解.随着时间流逝,系统会按恒定1/QPS时间间隔(如果QPS=100,则间隔是10ms)往桶里加入Token(想象和漏洞漏水相反,有个水龙头在不断的加水),如果桶已经满了就不再加了.新请求来临时,会各自拿走一个Token,如果没有Token可拿了就阻塞或者拒绝服务.

![](./assert/token_bucket.JPG)

令牌桶这种控制机制基于令牌桶中是否存在令牌来指示什么时候可以发送流量。令牌桶中的每一个令牌都代表一个字节。如果令牌桶中存在令牌，则允许发送流量；而如果令牌桶中不存在令牌，则不允许发送流量。因此，如果突发门限被合理地配置并且令牌桶中有足够的令牌，那么流量就可以以峰值速率发送。

算法描述：

* 假如用户配置的平均发送速率为r，则每隔1/QPS秒一个令牌被加入到桶中（每秒会有QPS个令牌放入桶中）；

* 假设桶中最多可以存放b个令牌。如果令牌到达时令牌桶已经满了，那么这个令牌会被丢弃；

* 当一个n个字节的数据包到达时，就从令牌桶中删除n个令牌（不同大小的数据包，消耗的令牌数量不一样），并且数据包被发送到网络；

* 如果令牌桶中少于n个令牌，那么不会删除令牌，并且认为这个数据包在流量限制之外（n个字节，需要n个令牌。该数据包将被缓存或丢弃）；

* 算法允许最长b个字节的突发，但从长期运行结果看，数据包的速率被限制成常量QPS。对于在流量限制外的数据包可以以不同的方式处理：（1）它们可以被丢弃；（2）它们可以排放在队列中以便当令牌桶中累积了足够多的令牌时再传输；（3）它们可以继续发送，但需要做特殊标记，网络过载的时候将这些特殊标记的包丢弃。


令牌桶的另外一个好处是可以方便的改变速度. 一旦需要提高速率,则按需提高放入桶中的令牌的速率. 一般会定时(比如100毫秒)往桶中增加一定数量的令牌, 有些变种算法则实时的计算应该增加的令牌的数量.

### 漏桶算法

漏桶(Leaky Bucket)算法思路很简单,水(请求)先进入到漏桶里,漏桶以一定的速度出水(接口有响应速率),当水流入速度过大会直接溢出(访问频率超过接口响应速率),然后就拒绝请求,可以看出漏桶算法能强行限制数据的传输速率.示意图如下:

![](./assets/rate-limit1.png)

可见这里有两个变量,一个是桶的大小,支持流量突发增多时可以存多少的水(burst),另一个是水桶漏洞的大小(rate)。

漏斗有一个进水口 和 一个出水口，出水口以一定速率出水，并且有一个最大出水速率：

在漏斗中没有水的时候:
* 如果进水速率小于等于最大出水速率，那么，出水速率等于进水速率，此时，不会积水
* 如果进水速率大于最大出水速率，那么，漏斗以最大速率出水，此时，多余的水会积在漏斗中

在漏斗中有水的时候
* 出水口以最大速率出水
* 如果漏斗未满，且有进水的话，那么这些水会积在漏斗中
* 如果漏斗已满，且有进水的话，那么这些水会溢出到漏斗之外

因为漏桶的漏出速率是固定的参数,所以,即使网络中不存在资源冲突(没有发生拥塞),漏桶算法也不能使流突发(burst)到端口速率.因此,漏桶算法对于存在突发特性的流量来说缺乏效率.

### 对比
* 漏桶
漏桶的出水速度是恒定的，那么意味着如果瞬时大流量的话，将有大部分请求被丢弃掉（也就是所谓的溢出）。

* 令牌桶
生成令牌的速度是恒定的，而请求去拿令牌是没有速度限制的。这意味，面对瞬时大流量，该算法可以在短时间内请求拿到大量令牌，而且拿令牌的过程并不是消耗很大的事情。

## 系统设计

https://www.hiredintech.com/system-design

https://soulmachine.gitbooks.io/system-design/content/cn/

https://yuanhsh.iteye.com/blog/2194982

https://www.cnblogs.com/yunnotes/archive/2013/04/19/3032367.html

https://www.itcodemonkey.com/article/8126.html

https://blog.csdn.net/dennis_zane/article/details/83266137

[如何设计一个百万级用户的抽奖系统](https://juejin.im/post/5ce3f003f265da1bbd4b4946)

[如果让你设计一个消息中间件，如何将其网络通信性能优化10倍以上？](https://juejin.im/post/5cbc723cf265da03ac0d0930)

[支撑百万连接的系统应该如何设计其高并发架构](https://juejin.im/post/5c7fcf1be51d457d0353d5ea)

[写入消息中间件的数据，如何保证不丢失](https://juejin.im/post/5c7e7a046fb9a04a07311fe7)

[消息中间件如何实现每秒几十万的高并发写入](https://juejin.im/post/5c7bd09b6fb9a049ba424c15)

[20万用户同时访问一个热点缓存，如何优化你的缓存架构](https://juejin.im/post/5c448670e51d455bd36b67f9)

[你的系统如何支撑高并发？](https://juejin.im/post/5c45aaee6fb9a049e6609115)

## 其他

### 蓄水池算法

[大数据工程师必备之蓄水池抽样算法](https://blog.csdn.net/bitcarmanlee/article/details/52719202)

### 断路器
[微服务的断路器实现图解Golang通用版](https://studygolang.com/articles/20437)

### 海量数据
https://blog.csdn.net/v_july_v/article/details/6279498