---
title: Spark Streaming 2.1.0 Programming Guide 个人理解与翻译
tags: spark
key: 2
modify_date: 2019-04-30 18:00:00 +08:00
---

简单写一下自己读了**Spark Streaming 2.1.0 Programming Guide**之后的体验，也可以说是自己对该编程指南的理解与翻译。
> https://spark.apache.org/docs/2.1.0/streaming-programming-guide.html
---
# Overview
Spark Streaming（下称streaming）是Spark core的拓展，一个易扩展、高吞吐、高容错的流式数据处理系统。

![image](https://user-images.githubusercontent.com/8369671/80794631-fa785200-8bcc-11ea-946f-e37e6412dcbe.png)
> streaming-arch

streaming接收输入数据（kafka等）然后根据设置的处理时长batch interval将其***切割***为一个个的小数据集，然后对小数据集进行spark core/sql/mllib的操作，最后将处理后的小数据集输出。

![image](https://user-images.githubusercontent.com/8369671/80794634-fcdaac00-8bcc-11ea-9239-10ac44b4fad2.png)
> streaming-flow

streaming具有一个高度抽象概念叫离散化的流（即DStream），代表了一块连续的数据流。
> A DStream is represented as a sequence of RDDs.

# A Quick Example
![image](https://user-images.githubusercontent.com/8369671/80794637-ff3d0600-8bcc-11ea-8866-0ea8e2588752.png)
> NetworkWordCount.scala

# Basic Concepts
## Linking
  - jar依赖，高级源kafka、flume等

## Initializing StreamingContext
  - 可以用已有的SparkContext创建
    `val ssc = new StreamingContext(sc, Seconds(1))`
  - ssc创建之后，
    1. 定义数据源以产生DStreams（定义开始点）
    2. 使用transformation和output operations算子来计算（定义中间过程，定义结束点）
    3. 利用ssc.start()来启动步骤1的和步骤2
    4. 利用ssc.awaitTermination(-1L)来hold住整个streaming程序（让其超时关闭，或者自然报错关闭）
    5. ssc.stop()用来关闭ssc或者sc
  - 几点注意，
      - 一个JVM里面仅有一个ssc
      - sc可以重复用来创建ssc，只要前ssc被关闭了

## Discretized Streams (DStreams)
DStream可以是来自于接收到的上游source(kafka)，也可以是经过transformating转换后的DStream。

## Input DStreams and Receivers
Input DStream通过**Receiver**接收上游source的数据，receiver负责将上游数据接住，同时将其保存在spark的内存系统中以供后续transformation处理。

streaming提供的两种内建源和自定义源：
  - 基础源，文件系统，socket连接
  - 高级源，kafka，flume，kinesis（需要额外的jar依赖）
  - 自定义源，extends Receiver来实现自定义源

如果streaming程序需要并行接收多个数据源，可以创建多个receiver。但是因为一个receiver是一个长期的任务伴随着streaming的开始和结束，所以其会始终占用一个core。所以，streaming程序要分配足够的core来接收数据（#receiver）和处理数据（#processer）。
注意：本地跑streaming程序，不要使用`local`或者`local[1]`。因为两种设置都是只分配一个core/thread给streaming程序，而该core会被receiver占用，但processer就没有额外的core来驱动，导致整个程序只接收数据，但是不能够处理数据。所以通常设置为`local[n], n > #receiver`。

Receiver Reliability
根据是否能够发出acknowledgment(ack)到source来区分接收器的reliable/unreliable。

## Transformation on DStreams
与RDD的transformation类似，是一种lazy操作。输入的DStream可以经过transformation转换成另一种DStream。

Transformation | Meaning
--- | ---
map | 作用于DStream里面的每一个元素
flatMap | 先调用map，然后调用flatten展平
filter | 符合filter条件的则保留
repartition | 通过shuffle来修改并行度
union | 合流，将多个DStream合并成一个DStream，多job合并可以提高并行度
reduce | 所有元素及其中间结果逐一顺序执行，最后得到一个结果
countByValue | 计算key[T]的frequency, DStream(T, Long)
reduceByKey | 根据key分组，再对每个key的pairs应用reduce
join | DStream(k1, v1) join DStream(k1, v2) = DStream(k1, (v1,v2))
cogroup | DStream(k1, v1) join DStream(k1, v2) = DStream(k1, Seq[v1], Seq[v2])
*updateStateByKey* | 记录状态的操作，需要initial state和定义state update function，需要开启checkpoint
*transform* | 作用于DStream里面的每一个RDD
*windows* | 基于窗宽的窗口函数

![image](https://user-images.githubusercontent.com/8369671/80794645-049a5080-8bcd-11ea-8b90-fb9eae08284a.png)
> streaming-dstream-window

---
---
插入Spark Structured Streaming关于窗函数的使用
> - https://databricks.com/blog/2017/05/08/event-time-aggregation-watermarking-apache-sparks-structured-streaming.html
> - http://www.voidcn.com/article/p-ekpbdaxs-bqp.html

在流式处理中，有两个时间概念，
  - event time，即事件发生时间，如该日志产生的时间
  - process time，即处理事件的实际时间，一般是Streaming程序当前batch的运行时间

![image](https://user-images.githubusercontent.com/8369671/80794651-07954100-8bcd-11ea-872b-97b801fc3a98.png)
> 时序

上图time1, time2, time3是process time，图中方块中的数字代表这个event time。可能由于网络抖动导致部分机器的日志收集产生了延迟，在time3的batch中包含了event time为2的日志。kafka中不同partition的消息也是无序的，在实时处理过程中也就产生了两个问题，
  1. Streaming从kafka中拉取的一批数据里面可能包含多个event time的数据
  2. 同一event time的数据可能出现在多个batch interval中

Structured Streaming可以在实时数据上进行sql查询聚合，如查看不同设备的信号量的平均大小
```
avgSignalDf = eventsDF
              .groupby("deviceId")
              .avg("signal")
```

进一步地，如果不是在整个数据流上做聚合，而是想在时间窗口上聚合。如查看每过去5分钟的不同平均信号量，这里的5分钟时间指的是event time，而不是process time，
```
windowedAvgSignalDF1 = eventsDF
                       .groupBy("deviceId", window("eventTime", "5 minute"))
                       .count()
```

![image](https://user-images.githubusercontent.com/8369671/80794656-0b28c800-8bcd-11ea-8f0b-836016a77d43.png)
> windowedAvgSignalDF1

更进一步要求，每5分钟统计过去10分钟内所有设备产生日志的条数，也是按照event time聚合，
```
windowedAvgSignalDF2 = eventsDF
                       .groupBy("deviceId", window("eventTime", "10 minute", "5 minute"))
                       .count()
```

![image](https://user-images.githubusercontent.com/8369671/80794664-0d8b2200-8bcd-11ea-8bd4-97bba626bee7.png)
> windowedAvgSignalDF2

如果一条日志因为网络原因迟到了怎么办？Structured Streaming还是会将其统计到属于它的分组里面。

![image](https://user-images.githubusercontent.com/8369671/80794668-10861280-8bcd-11ea-8dd0-4d8d4a0a8beb.png)
> windowedAvgSignalDF3_delay

上面强大的有状态功能是通过Spark Sql内部维护一个高容错的中间状态存储，key-value pairs，key就是对应分组，value就是对应每次增量统计后的一个聚合结果。每次增量统计，就对应key-value的一个新版本，状态就从旧版本迁移到新版本，所以才认为是有状态的。

有状态的数据存储在内存中是不可靠的，spark sql内部使用write ahead log(WAL, 预写式日志)，然后间断的进行checkpoint。如果系统在某个时间点上crash了，就从最近的checkpoint点恢复，再开始使用WAL进行重放replay。checkpoint的点更新了以后，才将WAL清空clean，然后重新累积WAL，再flush到checkpoint，再clean（类似于es的translog）。

![image](https://user-images.githubusercontent.com/8369671/80794673-12e86c80-8bcd-11ea-8c92-870f6e7f2af1.png)
> WAL

当然，streaming的数据源是一个流，这个数据是无限的，为了资源和性能考虑，只能保存有限的状态。即落后多久以后的数据，即便来了，系统也不要了，watermarking概念就是用来定义这个等待时间。例如，如果系统最大延迟是10分钟，意味着event time落后process time 10分钟内的日志会被拿来使用；如果超出10分钟，该日志就会被丢弃。如现在process time = 12:33，那么12:23之前的key-value pair的状态就不会再有改变，也就可以不用维护其状态了。
```
windowedAvgSignalDF4 = eventsDF
                       .withWatermark("eventTime", "10 minutes")
                       .groupBy("deviceId", window("eventTime", "10 minute", "5 minute"))
                       .count()
```

![image](https://user-images.githubusercontent.com/8369671/80794678-15e35d00-8bcd-11ea-87f6-89bfa3f7bc94.png)
> windowedAvgSignalDF4_waterMark

x轴是process time，y轴是event time。然后有一条动态的水位线，如果在水位线下面的日志，Streaming系统就丢弃。

---
---
## Output Operations on DStreams
将DStream推送至外部系统，db，hdfs。是action，会trigger the actual execution of all the DStream transformations

Output Operation | Meaning
--- | ---
print | 在driver端打印每个batch的前10个元素
saveAsTextFiles | 保存DStream内容为文本文件
saveAsObjectFiles | 保存DStream内容为序列化对象文件
saveAsHadoopFiles | 保存为hdfs文件
**foreachRDD** | 作用于DStream里面的所有RDD，需要里面包含RDD的action算子才会被执行

其中foreachRDD常用于写DStream内容到外部DB中，需要用到网络连接，示例如下，

![image](https://user-images.githubusercontent.com/8369671/80794681-18de4d80-8bcd-11ea-956f-bf2978d7a12f.png)
> errorExample
上面的是错误实例，因为connection产生在driver，但connection不能序列化到executor，所以`connection.send(record)`报错。

![image](https://user-images.githubusercontent.com/8369671/80794682-1b40a780-8bcd-11ea-9ec0-d4a11a839297.png)
> 高消耗方式
上面是不推荐方式，因为需要为DStream里面的每一个元素都产生和销毁connection，而产生和销毁connection是昂贵的操作。

![image](https://user-images.githubusercontent.com/8369671/80794687-1ed42e80-8bcd-11ea-9044-778aac1e1d8e.png)
> 推荐方式1
上面的方式，为每个rdd的partition产生一个connection，该connection产生于executor，可以用于send数据。

![image](https://user-images.githubusercontent.com/8369671/80794691-21368880-8bcd-11ea-9d65-2ccd9e1754b6.png)
> 更推荐方式
上面的方式，有别于推荐方式1，利用连接池概念，每一个batch interval都可以重复利用这些connection（后续的每个batch都会利用该连接池，而非后续batch一直new connection下去）。连接池要求懒加载和设置超时，具体可以参考这个[stackoverflow answer](https://stackoverflow.com/questions/40015777/how-to-perform-one-operation-on-each-executor-once-in-spark)。

注意，
  - 如果Streaming程序没有output operation，或者有output operation但是里面没有RDD的action算子，那么DSTream不会被执行。系统仅仅接收数据，然后丢弃之
  - 默认情况下，output operation是串行执行

## DataFrame and SQL Operations
DStream可以使用core、sql、mllib

## MLlib Operations
DStream可以使用core、sql、mllib，eg. StreamingLinearRegressionWithSGD

## Caching/ Persistence
DStream.persist()可以持久化DStream里面的每一个RDD。其中`reduceByWindow`、`reduceByKeyAndWindow`、`updateStateByKey`是隐式带上持久化的，不需要显式调用persist()。

## Checkpointing
为了解决24/7程序的容错问题，需要checkpoint(cp)两类数据，
  1. Metadata，包括configuration，DStream operations，Incomplete batches。一般用于driver的恢复。
  2. RDDs，将生成的rdd保存到cp点，为了减少rdd lineage链的长度，也便于快速恢复

需要开启cp的应用场景，
  1. driver需要自动恢复的场景
  2. 带状态转换算子（stateful transformations）；需要组合多个batch的数据，如窗函数，stateUpdateFunc

如何开启cp，
  1. 设置cp目录（用于带状态转换算子）
  2. 设置functionToCreateContext（用于driver恢复）

![image](https://user-images.githubusercontent.com/8369671/80794695-24317900-8bcd-11ea-8512-7f1246270760.png)
> cp_driver_recovery_func

cp的间隔时间需要谨慎设置，太频繁会影响性能；相反太久会导致lineage链和task size太大。`dstream.checkpoint(checkpointInterval)`，一般是窗宽的5到10倍比较好。

## Accumulators, Broadcast Variables, and Checkpoints
累加器和广播变量不能从cp中恢复，但是通过`lazily instantiated singleton instances`单例懒加载可以从cp中重新实例化。

## Deploying Applications
Streaming应用的部署

### Requirements
- 带管理者的集群
- 编译code为jar包
- 为executors分配足够的内存，received data must be stored in memory。如果窗宽是10分钟，那么系统必须支持将不少于10分钟的数据保存在内存中
- 设置checkpoint，如果需要
- 配置driver的自动恢复，如果需要
- 配置WAL，如果需要，接收到的数据会先预写到cp点，这可能会降低系统吞吐量，但是可以通过并行多个receiver来缓解。另外，开启了WAL，那么spark的replication建议设置为0。`spark.streaming.receiver.writeAheadLog.enable`，MEMORY_AND_DISK_SER~~_2~~
- 设置最大接收速率，防止process time大于batch interval，导致数据堆积，`spark.streaming.receiver.maxRate`、`spark.streaming.kafka.maxRatePerPartition`。也可以开启反压机制来自动控速，`spark.streaming.backpressure.enabled`

### Upgrading Application Code
如果需要更新running状态的streaming程序的代码或者配置，
- 新程序与旧程序同时运行，然后等新程序ready之后，kill掉旧程序。注意下游是否符合满足幂等操作；否则需要设置两个不同的output路径，将数据发送到两个不同的目的地（新旧各一个）
- 平滑关闭旧程序（不再接收新数据，但是已接收的数据会处理完），然后启动新程序接着旧程序的点开始处理。如果是带状态/窗宽大于batch interval的话，利用cp来恢复？如果不需要记录状态/窗宽，可以使用另外的cp目录或者删除旧cp目录

## Monitoring Applications
> - Processing Time < Batch Interval 才算正常
> - Scheduling Delay 越小越好

![image](https://user-images.githubusercontent.com/8369671/80794700-285d9680-8bcd-11ea-8f8b-eff354366b5f.png)
> monitor ui

- In **Input Rate** row, you can show and hide details of each input stream
- **Scheduling Delay** is the time spent from when the collection of streaming jobs for a batch was submitted to when the first streaming job was started
- **Processing Time** is the time spent to complete all the streaming jobs of a batch
- **Batch interval** is user defined. such as 10s, 5s, 1s, etc.
- **Total Delay** is the time spent from submitting to complete all jobs of a batch
- *Active Batches* section presents waitingBatches and runningBatches together
- *Completed Batches* section presents retained completed batches (using completedBatchUIData)

![image](https://user-images.githubusercontent.com/8369671/80794705-2b588700-8bcd-11ea-97c8-56699e67208f.png)
> normal timer

# Performance Tuning
>- 减少每个batch interval的Processing Time
>- 设置正确的batch size（每个batch interval的数据量大小）

## Reducing the Batch Processing Times
### Level of Parallelism in Data Receiving
- 创建多个receiver，并行接收单个source的数据或者多个source的数据
- 减少block interval，接收数据在存入spark前，是合并成一个个block的，一个batch interval里面的#block = batch interval/ block interval * #receiver，而#block = #task，task数量决定了processing的并行度`spark.streaming.blockInterval`
- 如果不设置block interval，可以使用repartition来设置并行度，但是所引起的shuffle耗时需要引起注意

### Level of Parallelism in Data Processing
如果parallel task不足，那么core利用率不高。通过提高默认并行度来加速`spark.default.parallelism`，task数量也不宜过多，太多了，task的序列化与反序列化耗时也更高，适得其反。建议是#executors * #core_per_executor * 4

### Data Serialization
- XXX_SER，使用带序列化的持久化策略，数据序列化为字节数组以减少GC耗时
- 使用Kryo的序列化方式，需要注册自定义类
- 在batch size不大的情况下，可以关闭序列化策略，这样可以减少CPU的序列化与反序列化耗时

### Task Launching Overheads
任务数不宜过多，driver发送任务也需耗时。

## Setting the Right Batch Interval
一般以5~10s为初始值，然后观察*Streaming UI*的**Scheduling Delay**和**Processing time**来调整。

## Memory Tuning
内存用量与GC策略的调优，
- XXX_SER这样的带序列化性质的持久化策略有利于降低内存用量与降低GC耗时，另外`spark.rdd.compress`可以进一步降低内存用量，但是CPU耗时会升高
- 清理旧数据，Streaming程序会自动清理所有的输入原数据与持久化过的RDDs。清理周期取决于该batch interval数据的使用时长（如窗宽/stateful），另外可以设置`streamingContext.remember`来保存更长时间
- CMS收集器或者G1收集器
- 用堆外内存来持久化RDDs，堆外没有GC
- 使用more executors with small heap来替代less executors with large heap，heap小有助于GC快速回收

## 注意事项
- 一个DStream与一个receiver关联，为了增加系统吞吐量，可以增加receiver数量，而一个receiver占用一个core
- receiver接收到数据之后会产生一个个的block，每一个block interval都会产生一个新的block，在一个batch interval里，一共产生了N个block，N=batch interval/ block interval，N也即task数量，与Processing的并行度相关联
- 如果block interval == batch interval，那么就会产生一个task，一个partition，并且很可能会在本地就被处理
- 更大的block interval，意味着更大的block数据块，更高的`spark.locality.wait`可以增加该任务slot的数据本地性的命中概率，但是等待时间也可能更高（PROCESS_LOCAL -> NODE_LOCAL -> RACK_LOCAL -> ANY）
- 如果有多个DStreams，那么根据job是串行执行的性质，会先处理第一个DStream，再处理另一个DStream，这样不利于并行化，可以通过union来避免，这样unionDStream被视为一个job而已
- `spark.streaming.receiver.maxRate`来限制读取source的速率，避免Processing Time大于batch interval，否则executor的内存终会爆掉

---
# Fault-tolerance Semantics
容错语义

## Background
RDD是不可变、明确可重复计算的、分布式的数据集合。每个RDD会记录其确定性的操作血统lineage，这个血统用于在容错的输入数据集上恢复该RDD。

为了spark内部产生的RDDs高容错，设置replication，然后将该RDDs及其副本分发到不同的executor上。如果产生crash，那么有两类数据恢复途径，
1. 从副本恢复
2. 没有副本的话，从数据源恢复，再根据lineage rebuild该RDD

这两类错误需要关注，
1. executor failure，executor里面的in-memory数据会lost
2. driver failure，SparkContext会lost，然后所有executors的in-memory数据也会lost

## Definitions
1. at most once, 最多被执行一次
2. at least once, 至少被执行一次
3. exactly once, 有且仅有被执行一次

## Basic Semantics
每一个Streaming程序都可以分为三步，
1. receiving the data
2. transforming the data
3. pushing out the data

如果一个系统要实现端到端的exactly once语义，那么上面三步的每一步都要保证是exactly once的。

## Semantics of Received Data
1. files
2. reliable receiver， with ack
3. unreliable receiver， without ack
4. direct kafka api (1.3+)，所有接收到的kafka数据都是exactly once的
为了避免丢失过去接收过的数据，Spark引入了WAL，负责将接收到的数据保存到cp/log中，有了WAL和reliable receiver，我们可以做到零数据丢失和exactly once语义

![image](https://user-images.githubusercontent.com/8369671/80794716-30b5d180-8bcd-11ea-8a01-50a0050a2963.png)
> fault tolerant

## Semantics of output operations
output operation输出算子，如foreachRDD是at least once语义的，即同一份transformed数据在woker failure的情况下，可能会被多次写入外部DB系统，为了实现其exactly once语义，有以下做法，
1. 幂等操作，如`saveAs***Files`将数据保存到hdfs中，可以容忍被写多次的，因为文件会被相同的数据覆盖？如果两个job同时写一份数据呢？（不能，因为job串行。如果是开启了speculation呢？）
2. 事务性的更新，利用一个唯一标识来控制输出操作 `val uniqueId = generateUniqueId(time.milliseconds, TaskContext.get.partitionId())`
