---
title: Spark streaming一次调试过程
tags: spark
key: 6
modify_date: 2019-04-30 18:00:00 +08:00
---

记录一下最近调试Streaming程序的过程中所发现的问题和解决方案，

----
背景，batch interval = 120s，10个receiver，吞吐量每秒1000条，一个batch的cache大小是1639KB，每条record大小=1639/(120*1000)*1024=13.99字节
![image](https://user-images.githubusercontent.com/8369671/80793772-9e143300-8bca-11ea-9797-7e1a4a30ecca.png)
> batch interval

![image](https://user-images.githubusercontent.com/8369671/80793777-a10f2380-8bca-11ea-9498-60b125da6250.png)
> storage

----

### Q1. Container … is running beyond physical memory limits

> Diagnostics: Container [pid=2542,containerID=container_1509019554197_2190124_01_000001] is running beyond physical memory limits. Current usage: 1.5 GB of 1.5 GB physical memory used; 2.4 GB of 4.6 GB virtual memory used. Killing container.

初步预估了数据量，设置如下，
```
 --conf spark.driver.memory=1G
 --conf spark.driver.cores=1
 --conf spark.executor.memory=500M
 --conf spark.executor.instances=50
 --conf spark.executor.cores=2
 --conf spark.default.parallelism=400
 --conf spark.sql.shuffle.partitions=400
```
运行大约10分钟之后，发现出现了physical memory limits, yarn kill container现象。按理说1G已经足够大了，为什么还会OOM呢？

- [文章](https://endymecy.gitbooks.io/spark-config-and-tuning/content/cigna-tune-spark-streaming.html)说到driver问题，我们增加了driver到4G，这个问题目前没有再出现了。
我们再理解一下，可能是一些Spark的STATUS太多，导致driver的内存吃紧。
fix by `--conf spark.driver.memory=4G`
- 关闭driver端的一些控制stage process日志 `--conf spark.ui.showConsoleProgress=false`

### Q2 Dropping SparkListenerEvent because no remaining room in event queue
> [2017-11-30 15:58:50 WARN ] Logging$class - Dropped 1 SparkListenerEvents since Thu Jan 01 08:00:00 CST 1970
[2017-11-30 15:58:50 ERROR] Logging$class - Dropping SparkListenerEvent because no remaining room in event queue. This likely means one of the SparkListeners is too slow and cannot keep up with the rate at which tasks are being started by the scheduler.

我们发现spark丢掉了不少消息队列的消息数量，[文章](http://www.bijishequ.com/detail/339508)上有说将`--conf spark.scheduler.listenerbus.eventqueue.size=100000(默认10000)`调大。我们理解了一下，觉得这个值可能在某些情况下是有用的，但是更多的情况会导致eventqueue的慢慢增加（eventqueue新建的比销毁的来的快），起到治标不治本。应该是receiver接收message之后，产生了太多的block，每个block占用一个queue位置，导致空余的eventqueue不够。所以从主要从#block数量入手，[前文](http://www.jianshu.com/p/6d576e8186f8)说到，`#block = batch interval/ block interval * #receiver`，这里我们增大了block interval，即`--conf spark.streaming.blockInterval=5000ms(默认200ms)`，即从原来的每0.2秒产生一个block，变成每5秒才生成一个block，减少了25倍，eventqueue drop这个error得到缓解。
另外，`spark.streaming.unpersist`是否能够更早释放已处理block呢？
----

程序还没有完全调通，又有delay了，继续调试，

![image](https://user-images.githubusercontent.com/8369671/80793800-b2f0c680-8bca-11ea-896a-f9a68ff876a6.png)
> s3

### Q3 spark sql udf调用NPE

> [2017-11-30 18:04:22 WARN ] Logging$class - Putting block rdd_8430_118 failed due to an exception
[2017-11-30 18:04:22 WARN ] Logging$class - Block rdd_8430_118 could not be removed as it was not found on disk or in memory
[2017-11-30 18:04:22 ERROR] Logging$class - Exception in task 118.0 in stage 1266.0 (TID 154489)
org.apache.spark.SparkException: Failed to execute user defined function(anonfun$skuNameTokenRpc$1: (string, int) => array<string>)
	at org.apache.spark.sql.catalyst.expressions.GeneratedClass$GeneratedIterator.processNext(Unknown Source)
	at org.apache.spark.sql.execution.BufferedRowIterator.hasNext(BufferedRowIterator.java:43)
	at org.apache.spark.sql.execution.WholeStageCodegenExec$$anonfun$8$$anon$1.hasNext(WholeStageCodegenExec.scala:377)
	at org.apache.spark.sql.execution.columnar.InMemoryRelation$$anonfun$1$$anon$1.next(InMemoryRelation.scala:105)
	at org.apache.spark.sql.execution.columnar.InMemoryRelation$$anonfun$1$$anon$1.next(InMemoryRelation.scala:97)
	at org.apache.spark.storage.memory.MemoryStore.putIteratorAsValues(MemoryStore.scala:216)
	at org.apache.spark.storage.BlockManager$$anonfun$doPutIterator$1.apply(BlockManager.scala:957)
	at org.apache.spark.storage.BlockManager$$anonfun$doPutIterator$1.apply(BlockManager.scala:948)
	at org.apache.spark.storage.BlockManager.doPut(BlockManager.scala:888)
	at org.apache.spark.storage.BlockManager.doPutIterator(BlockManager.scala:948)
	at org.apache.spark.storage.BlockManager.getOrElseUpdate(BlockManager.scala:694)
	at org.apache.spark.rdd.RDD.getOrCompute(RDD.scala:334)
	at org.apache.spark.rdd.RDD.iterator(RDD.scala:285)
	at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:38)
	at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:323)
	at org.apache.spark.rdd.RDD.iterator(RDD.scala:287)
	at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:38)
	at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:323)
	at org.apache.spark.rdd.RDD.iterator(RDD.scala:287)
	at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:38)
	at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:323)
	at org.apache.spark.rdd.RDD.iterator(RDD.scala:287)
	at org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:96)
	at org.apache.spark.scheduler.ShuffleMapTask.runTask(ShuffleMapTask.scala:53)
	at org.apache.spark.scheduler.Task.run(Task.scala:99)
	at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:282)
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1145)
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:615)
	at java.lang.Thread.run(Thread.java:745)
Caused by: java.lang.NullPointerException
	... 29 more

由于udf里面调用了外部的rpc服务，而该rpc服务由于超时/链接数过大而抛出异常，try-catch-finally解决这个问题

### Q4 rpc的意外两次调用
从日志上看到，有超过1000条的指定日志（而实际上limit了999条，所以指定日志只能等于999）

![image](https://user-images.githubusercontent.com/8369671/80793815-be43f200-8bca-11ea-9936-88c7201ea68c.png)
> 指定日志数量

在code上面查看了，原来的persist的问题。在function里面persist了，但是function外部多次调用该function的变量val，而function-persist是无用的，所以要重新计算该val。
```
val rdd1 = some1
val rdd2 = func(some).persist
val rdd3 = rdd1.union rdd2

def func(some:[T]) = {
    val output = (...)
    output.persist
    output
}
```
继续挖掘，发现不是persist的问题，而是spark-sql的filter里面size()函数如果有值，就会引起计算两次。
在本地复现了该问题，在spark jira提了个[issue](https://issues.apache.org/jira/browse/SPARK-22702)，

![image](https://user-images.githubusercontent.com/8369671/80793822-c1d77900-8bca-11ea-8a07-c3e6053d0e3a.png)
> expected

![image](https://user-images.githubusercontent.com/8369671/80793828-c4d26980-8bca-11ea-9051-3b2fa5fcb7d2.png)
> unexpected

### Q5 exceeding memory limits
```
[2017-12-19 11:07:21 ERROR] org.apache.spark.internal.Logging$class - Lost executor 28 on XXX: Container killed by YARN for exceeding memory limits. 22.0 GB of 22 GB physical memory used. Consider boosting spark.yarn.executor.memoryOverhead.
```
1. 增加`memoryOverhead, --conf spark.yarn.executor.memoryOverhead=4G`
2. 增加默认并行度`--conf spark.default.parallelism=2200, --conf spark.sql.shuffle.partitions=2200`

### Q6 Too many open files
每个Streaming batch都使用了hadoop fileSystem的create(), open()，但是没有release导致的。
最后通过lazy initialization object，即[惰性初始模式](https://stackoverflow.com/questions/40015777/how-to-perform-one-operation-on-each-executor-once-in-spark)在每个executor里面初始化一个connection资源，然后每个executor的taskSet调用各自所在的executor connection资源，避免了频繁创建connection。

### Q7 spark ui上有很多残余的job/stage
![image](https://user-images.githubusercontent.com/8369671/80793832-c865f080-8bca-11ea-9229-c76bf82d9b01.png)
> 残余jobs

![image](https://user-images.githubusercontent.com/8369671/80793841-cb60e100-8bca-11ea-9233-b5c0db0d1669.png)
> 残余stages

![image](https://user-images.githubusercontent.com/8369671/80793845-ce5bd180-8bca-11ea-8206-54132e38b90e.png)
> correct streaming tab

没有理清为什么jobs/stages会有残余，是不是gc没有清理干净呢？从streaming tab来看，也有残留（2017/12/19 02:48:00），但是该streaming程序也是正常运行着的，最新的batch（2017/12/19 18:36:00）已经执行完毕。所以暂时ignore这个残余jobs/stages问题。也可能是残留batch（2017/12/19 02:48:00）执行过程中产生exception，但是没有抛出导致整个程序退出，而是卡在了残留batch里面。
