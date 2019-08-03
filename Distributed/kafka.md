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