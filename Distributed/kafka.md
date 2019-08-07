## kafka系列

http://www.jasongj.com/tags/Kafka/

* Broker \
　　Kafka集群包含一个或多个服务器，这种服务器被称为broker
* Topic \
　　每条发布到Kafka集群的消息都有一个类别，这个类别被称为Topic。（物理上不同Topic的消息分开存储，逻辑上一个Topic的消息虽然保存于一个或多个broker上但用户只需指定消息的Topic即可生产或消费数据而不必关心数据存于何处）
* Partition \
　　Parition是物理上的概念，每个Topic包含一个或多个Partition.kafka的高可用可以通过给Partiton设置replica来实现，Partition和replica需要按照以下规则分布到不同的broker上：

    Kafka分配Replica的算法如下：

    1. 将所有Broker（假设共n个Broker）和待分配的Partition排序
    2. 将第i个Partition分配到第（i mod n）个Broker上
    3. 将第i个Partition的第j个Replica分配到第（(i + j) mod n）个Broker上
    > 更加详细的参考：http://www.jasongj.com/2015/04/24/KafkaColumn2/
* Producer \
　　负责发布消息到Kafka broker，使用push方式
* Consumer \
　　消息消费者，向Kafka broker读取消息的客户端。使用pull方式
* Consumer Group \
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

kafka consumer怎么保证顺序读取消息？

### kafka exactly once的实现

#### Producer端的消息幂等性保证
每个Producer在初始化的时候都会被分配一个唯一的PID。

Producer向指定的Topic的特定Partition发送的消息都携带一个sequence number（简称seqNum），从零开始的单调递增的。

Broker会将Topic-Partition对应的seqNum在内存中维护，每次接受到Producer的消息都会进行校验；只有seqNum比上次提交的seqNum刚好大一，才被认为是合法的。比它大的，说明消息有丢失；比它小的，说明消息重复发送了。

以上说的这个只是针对单个Producer在一个session内的情况，假设Producer挂了，又重新启动一个Producer被而且分配了另外一个PID，这样就不能达到防重的目的了，所以kafka又引进了Transactional Guarantees（事务性保证）。

#### Transactional Guarantees 事务性保证
kafka的事务性保证说的是：同时向多个TopicPartitions发送消息，要么都成功，要么都失败。

为什么搞这么个东西出来？我想了下有可能是这种例子：

用户定了一张机票，付款成功之后，订单的状态改了，飞机座位也被占了，这样相当于是2条消息，那么保证这个事务性就是：向订单状态的Topic和飞机座位的Topic分别发送一条消息，这样就需要kafka的这种事务性保证。

这种功能可以使得consumer offset的提交（也是向broker产生消息）和producer的发送消息绑定在一起。

用户需要提供一个唯一的全局性TransactionalId，这样就能将PID和TransactionalId映射起来，就能解决producer挂掉后跨session的问题，应该是将之前PID的TransactionalId赋值给新的producer。

#### Consumer端
以上的事务性保证只是针对的producer端，对consumer端无法保证，有以下原因：
* 压实类型的topics，有些事务消息可能被新版本的producer重写
* 事务可能跨坐2个log segments，这时旧的segments可能被删除，就会丢消息
* 消费者可能寻址到事务中任意一点，也会丢失一些初始化的消息
* 消费者可能不会同时从所有的参与事务的TopicPartitions分片中消费消息

如果是消费kafka中的topic，并且将结果写回到kafka中另外的topic，可以将消息处理后结果的保存和offset的保存绑定为一个事务，这时就能保证消息的处理和offset的提交要么都成功，要么都失败。

如果是将处理消息后的结果保存到外部系统，这时就要用到两阶段提交（tow-phase commit），但是这样做很麻烦，较好的方式是offset自己管理，将它和消息的结果保存到同一个地方，整体上进行绑定， 可以参考Kafka Connect中HDFS的例子

[Kafka设计解析（八）- Exactly Once语义与事务机制原理](http://www.jasongj.com/kafka/transaction/)
[Stream Processing: Apache Kafka的Exactly-once的定义 原理和实现](https://blog.csdn.net/liangyihuai/article/details/82931140)