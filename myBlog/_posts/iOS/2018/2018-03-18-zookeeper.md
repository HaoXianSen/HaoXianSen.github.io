---
title: Zookeeper关注点
tags: zookeeper
key: 30
modify_date: 2019-04-30 18:00:00 +08:00
---

自己没有尝试过Zookeeper(zk)的直接应用，但是在很多大数据栈/分布式系统当中，zk都充当着重要[角色](http://blog.csdn.net/zhxdick/article/details/50830134)。如HDFS/YARN的HA，HBase存放regionServer心跳，Flume负载均衡和单点故障。那么参考网上的文章，希望将zk的架构和具体模块理清，

----
# Overview
Zookeeper主要是一个分布式服务`协调框架`，实现`同步`服务，`配置维护`和`命名服务`等分布式应用，基于对[Zab](https://my.oschina.net/guhanjie/blog/883343)协议（ZooKeeper Atomic Broadcast，zk原子消息广播协议，分布式一致性算法）的实现，能够保证分布式环境中数据的一致性。
简单来看，zookeeper=文件系统+通知机制。

----
# 用途
## [集群管理](http://blog.csdn.net/gs80140/article/details/51496925)
1. 集群机器监控/负载均衡
   - 在分布式的集群中，由于各种原因，如硬件故障，软件故障，网络问题，有些节点会进进出出。有新的节点加入进来，也有老的节点退出集群。此时，集群中有些机器（比如Master节点）需要感知到这种变化，然后根据这种变化做出对应的决策，`/clusterServersStatus/{hostname}`

2. 集群选主
   - 在分布式环境中，相同的业务应用分布在不同的机器上，有些业务逻辑（例如一些耗时的计算，网络I/O处理），往往只需要让整个集群中的某一台机器进行执行，其余机器可以共享这个结果，这样可以大大减少重复劳动，提高性能。例如elasticsearch的index关闭replica，但es不是用zk来实现；又如数据库的读写分离（把写全部给leader/master，查询则使用follower的机器），主从复制。于是这个master选举便是这种场景下的碰到的主要问题，
     - 一旦当前master服务器宕机了，它创建的EPHEMERAL_SEQUENTIAL**临时顺序节点**会马上消失；紧接着集群中注册过Watcher的所有服务器会收到当前master服务器已宕机的通知，然后将重新进行master[选举](http://www.infoq.com/cn/articles/architecture-practice-08-ZooKeeper)，有采用**最小机器编号**的，有采用**最新事务编号**的，有采用**quorum多数投票**的等等

## [配置管理](https://my.oschina.net/guzhixiong/blog/486365)
分布式系统都有好多机器，比如在搭建hadoop的HDFS时，需要在一个主机器上（Master节点）配置好HDFS需要的各种配置文件，然后通过scp命令把这些配置文件copy到其他节点上，这样各个机器拿到的配置信息是一致的，才能成功运行起来HDFS服务。但是这里有个很致命的缺陷，特别对于在线服务的重启，假设线上server有1000台，那么如果不能同一时刻将新配置都同步，那么很可能会造成1000台中前500台是新配置，而后500台还是旧配置。
   - zk很容易实现这种集中式的配置管理，比如将app1的所有配置设置在/app1的znode下，app1所有机器一启动就对/app1这个节点进行监控`zk.exist("/app1",true)`，并且实现回调方法Watcher。那么在zk上/app1 znode节点下数据发生变化的时候，每个机器都会收到通知，Watcher方法将会被执行，那么应用再取下数据即可`zk.getData("/app1",false,null)`

![image](https://user-images.githubusercontent.com/8369671/80785242-3225d080-8bb2-11ea-926b-907164d7f9fa.png)
> zk configuration management

zk提供了这样的一种服务：一种集中管理配置的方法，我们在这个集中的地方修改了配置，所有对这个配置感兴趣的都可以获得变更[Watcher](https://www.ibm.com/developerworks/cn/opensource/os-cn-apache-zookeeper-watcher/index.html)。这样就省去手动拷贝配置了，还保证了可靠和一致性。

例如，[QConf](https://www.zhihu.com/question/35139415/answer/261970625)的应用，
1. 将配置数据直接存储在zk上，不论叶子节点还是中间节点都可以作为配置项
2. 客户端机器任何访问过的配置项都会从zk上拉取并缓存在本地共享内存，同时注册Watcher
3. 之后的配置修改都会收到通知并有机会刷新缓存

## 命名服务
分布式环境下，经常需要对应用/服务进行统一命名，便于识别不同服务。可以简单理解为一个电话薄，电话号码不好记，但是人名好记，要打谁的电话，直接查人名就好了。类似于域名与ip之间对应关系，域名容易记住。

## 分布式锁
单机程序的各个进程对`互斥资源`进行访问时需要加锁，那分布式程序分布在各个主机上的进程对互斥资源进行访问时也需要加锁。
分布式系统可能会有多个可服务的窗口，但是在某个时刻只能让一个服务去工作，当这台服务出问题时锁要被释放，立即failover到另外的服务。这在很多分布式系统中都是这么做，这种设计有一个更好听的名字叫`Leader Election`/`选主`。
例如，到银行取钱，有多个服务窗口，但对你来说，只能有一个窗口对你服务，如果正在对你服务的窗口的柜员突然有急事走了？此时怎么办？找大堂经理（zookeeper）。大堂经理指定另外的一个窗口继续为你服务。

## [队列管理](http://blog.csdn.net/gs80140/article/details/51496925)

name | meaning | implementation
--- | --- | ---
同步队列 | 当一个队列的成员都**聚齐**时（类似java cyclicBarrier），这个队列才可用，否则一直等待所有成员到达 | 在约定目录下创建临时目录节点，监听节点数目是否是我们要求的数目
有序队列 | 按FIFO方式进行入队和出队操作 | 与分布式锁服务中的控制时序场景基本原理一致，入列有编号，出列按编号

----
# 特点

characteristic | meaning
--- | ---
一致性 | 为客户端展示同一视图view
可靠性 | 如果消息被一台服务器接受，那么它将被所有的服务器接收
原子性 | 更新只能`成功`或`失败`，没有其他中间状态
实时性 | zk不能保证两个客户端能同时得到刚更新的数据，如果需要最新数据，应该在读数据之前调用sync()接口
顺序性 | 所有server的同一消息发布顺序一致
等待无关(wait-free) | 慢的或者失效的client不干预快速的client的请求，隔离性/独立性

----
# 基本架构
![image](https://user-images.githubusercontent.com/8369671/80785243-3520c100-8bb2-11ea-818b-9bb4cf83ef1a.png)
> client-server architecture

## zk角色
zk的工作集群可以简单分成两类，一个是Leader，其余的都是Learner(follower和observer)，
1. 每个server在内存中存储了一份数据
2. zk启动时，从实例中选举一个leader（Paxos协议）
3. Leader负责处理数据更新等操作（Zab协议）

![image](https://user-images.githubusercontent.com/8369671/80785248-381bb180-8bb2-11ea-9432-407686d85784.png)
> 角色role

## zk消息类型

znode | meaning
--- | ---
PING | 指Learner的心跳信息
REQUEST | 指Follower发送的提议信息，包括写请求及同步请求
PROPOSAL | Leader发起的提案，要求Follower投票
ACK | 指Follower对提议的回复，若超过半数的Follower通过，则commit该提议
COMMIT | server最新一次提案的信息
UPTODATE | 表明同步完成
SYNC | 返回SYNC结果到client，这个消息最初由client发起，用来强制获取最新的更新
REVALIDATE | 用于延长SESSION有效时间

## Znode类型

znode | name | meaning
--- | --- | ---
PERSISTENT | 持久化目录节点 | 客户端与zk断开连接后，该节点依旧**存在**
PERSISTENT_SEQUENTIAL | 持久化顺序编号目录节点 | 客户端与zk断开连接后，该节点依旧存在，只是zk给该节点名称进行顺序编号
EPHEMERAL | 临时目录节点 | 客户端与zk断开连接后，该节点被**删除**
EPHEMERAL_SEQUENTIAL | 临时顺序编号目录节点 | 客户端与zk断开连接后，该节点被删除，只是zk给该节点名称进行顺序编号

----
# 数据读写
- 写数据，某一个客户端进行写数据请求时，如果是follower接收到`写请求`，就会把请求转发给leader，leader通过内部的`Zab协议`进行原子广播，直到所有zk节点都成功写了数据并commit后，这次写请求算是完成，然后zk server就会给client发回响应。

![image](https://user-images.githubusercontent.com/8369671/80785252-3b16a200-8bb2-11ea-801a-c67120108cda.png)
> 写流程

![image](https://user-images.githubusercontent.com/8369671/80785256-3d78fc00-8bb2-11ea-9aca-7a1311d67269.png)
> 写数据流 From wuxl360

- 读数据，因为集群中所有的zk节点都呈现一个同样的命名空间视图，写请求已经保证了写一次数据必须是集群所有的zk节点都已同步了命名空间，所以读的时候可以在任意一台zk节点上

zk满足了CAP定理的分区容错性P和一致性C，牺牲了可用性A。zk的存储能力是有限的，当`节点数据太大`/`节点层次太深`/`子节点太多`，都会影响到其稳定性。所以zk不是一个用来做**高并发高性能**的数据库，zk一般只用来存储配置[信息](https://www.zhihu.com/question/35139415/answer/332186878)。

zk的**读性能**随着节点数量的提升能不断增加，但是**写性能**会随着节点数量的增加而降低。所以节点的数量不宜太多，一般配置成3个或者5个，3个节点可以容忍挂掉1个节点，5个节点可以容忍挂掉2个节点。另外可以通过observer来提升zk的[读性能](http://www.cnblogs.com/wuxl360/p/5817648.html)

----
# 工作原理
## Zab协议/数据更新
所有的事务请求必须由一个全局唯一的Leader服务器来协调处理，集群其余的服务器称为learner服务器。Leader服务器负责将一个`客户端请求`转化为事务提议（Proposal），并将该proposal分发给集群所有的follower服务器。之后Leader服务器需要等待所有的follower服务器的反馈，一旦超过了半数的follower服务器进行了正确反馈后，那么Leader服务器就会再次向所有的follower服务器分发commit消息，要求其将前一个proposal进行提交。

Zab协议包括两种基本的模式：崩溃恢复和消息广播。
- 当整个服务框架启动过程中或Leader服务器出现网络中断、崩溃退出与重启等异常情况时，Zab协议就会进入`恢复模式`并选举产生新的Leader服务器
- 当集群中已经有过半的Follower服务器完成了和Leader服务器的状态同步，那么整个服务框架就可以进入`消息广播模式`

Zab原子广播保证多个指令执行的[顺序](https://my.oschina.net/guhanjie/blog/883343)。

## Fast Paxos协议/Leader选举
`Leader选举`是保证分布式数据一致性的关键所在。当zk集群中的一台服务器出现以下两种情况之一时，需要进入Leader选举，
- 集群中已存在Leader
   - 对于集群中已经存在Leader这种情况，一般都是某台机器启动得较晚，在其启动之前，集群已经在正常工作，对这种情况，该机器试图去选举Leader时，会被告知当前集群的Leader信息，对于该机器而言，仅仅需要和Leader机器建立起连接，并进行状态同步即可
- 集群中不存在Leader
   1. 首次投票。无论哪种导致进行Leader选举，集群的所有机器都处于试图选举出一个Leader的状态，即LOOKING状态，LOOKING机器会向所有其他机器发送消息，该消息称为投票。投票中包含了服务器的唯一标识SID和事务标识ZXID，`(SID, ZXID)`用于标识一次投票信息。
假定zk由5台机器组成，SID分别为1、2、3、4、5，ZXID分别为9、9、9、8、8，并且此时SID为2的机器是Leader机器，某一时刻，1、2所在机器出现故障，因此集群开始进行Leader选举。在第一次投票时，每台机器都会将自己作为投票对象，于是SID为3、4、5的机器投票情况分别为(3, 9)，(4, 8)， (5, 8)
   2. 变更投票。每台机器发出`投票`后，也会收到其他机器的投票，每台机器会根据`一定规则`来处理收到的其他机器的投票，并以此来决定是否需要**变更**自己的投票，这个规则也是整个Leader选举算法的核心所在，
      - (vote_sid,vote_zxid)：接收到的投票中所推举Leader服务器的(SID,ZXID)对
      - (self_sid,self_zxid)：当前服务器自己的(SID,ZXID)对
      - 每次对收到的投票的处理，都是对(vote_sid, vote_zxid)和(self_sid, self_zxid)对比的过程
      - 规则一：如果vote_zxid > self_zxid，就`认可`当前收到的投票，并再次将该投票发送出去
      - 规则二：如果vote_zxid < self_zxid，那么`坚持`自己的投票，不做任何变更
      - 规则三：如果vote_zxid == self_zxid，那么就对比两者的SID，如果vote_sid > self_sid，那么就认可当前收到的投票，并再次将该投票发送出去；否则vote_sid < self_sid，那么坚持自己的投票，不做任何变更
      - **Leader的zxid, sid最大，zxid越大意味着数据越新**
   3. 确定Leader。经过第二轮投票后，集群中的每台机器都会`再次`接收到其他机器的投票，然后开始统计投票，如果一台机器收到了超过半数的相同投票，那么这个投票对应的SID机器即为Leader
![image](https://user-images.githubusercontent.com/8369671/80785260-410c8300-8bb2-11ea-8358-9c4f84c899f9.png)
> leader选举投票过程

### Server的三种状态

status | meaning
--- | ---
LOOKING | 当前server不知道leader是谁，正在搜寻
LEADING | 当前server就是选举出来的leader
FOLLOWING | leader已经选举出来，当前server已与之同步

## Watcher机制
zk的Watcher机制，概括为三个过程：客户端注册Watcher成为订阅者、服务端处理Watcher以及客户端回调Watcher。
客户端在自己需要关注的ZNode节点上注册[getData/exists/getChildren](http://blog.csdn.net/lipeng_bigdata/article/details/50985811)一个Watcher监听后，一旦这个ZNode节点发生变化，则在该节点上注册过Watcher监听的所有客户端会收到ZNode节点变化通知NodeDataChanged/NodeChildrenChanged等。在收到通知时，客户端通过回调Watcher做相应的处理，从而实现特定的功能。
   - 无论是服务端还是客户端，一旦一个Watcher被触发，zk都会将其从相应的存储中移除，因此需要**反复注册**
   - getData方法中设置的watch函数会在**数据发生更新或者删除**时被触发
   - exists在节点的**存活性**发生变化时触发
   - getChildren则在**子节点的存活性**发生变化时触发

----
# Reference
- [Zookeeper原理架构](http://www.cnblogs.com/ChrisMurphy/p/6683397.html)
- [浅谈分布式服务协调技术 Zookeeper](http://www.uml.org.cn/zjjs/201707282.asp)
- [中小型研发团队架构实践：分布式协调服务ZooKeeper](http://www.infoq.com/cn/articles/architecture-practice-08-ZooKeeper)
- [zookeeper fundamentals and applications](https://acadgild.com/blog/zookeeper-fundamentals-applications/)
- [Zookeeper在哪些系统中使用，又是怎么用的？](https://www.zhihu.com/question/35139415/answer/61562488)
- [Zab vs. Paxos](https://my.oschina.net/guhanjie/blog/883343)
- [zookeeper的应用和原理](http://blog.csdn.net/gs80140/article/details/51496925)
- [ZooKeeper Watch Java API浅析getData](http://blog.csdn.net/lipeng_bigdata/article/details/50985811)
- [Zookeeper Watch机制](http://blog.csdn.net/z69183787/article/details/53023578)
- [etcd](https://github.com/coreos/etcd)
