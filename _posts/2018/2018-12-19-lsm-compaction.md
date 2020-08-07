---
title: LSM Compaction Strategy
tags: storage
key: 54
modify_date: 2019-04-30 18:00:00 +08:00
---

# Overview
Compaction operations are expensive in terms of CPU, memory, and Disk I/O，而由于immutable特质，该操作在LSM架构上有必不可少。

![image](https://user-images.githubusercontent.com/8369671/80778440-0ea35b80-8b9b-11ea-87c7-22192672e9cd.png)
> Log Structured Merge (LSM)

data过来之后会写到memory table (MemTable)，当mem满了之后，会flush到disk形成不可变的immutable Sorted String Table (SSTable)。当SSTable太多，os所打开的文件句柄也会过多，所以此时需要将多个同质的SSTable`合并`成一个SSTable。

![image](https://user-images.githubusercontent.com/8369671/80778450-12cf7900-8b9b-11ea-85b0-f78505e1b37b.png)
> leveldb architecture

----
# Amplification
- 写放大：一份数据被顺序写几次（还是那一份数据，只是需要一直往下流）。第一次写到L0，之后由于compaction可能在L1~LN各写一次
- 读放大：一个query会在多个sstable，而这些sstable分布在L0~LN
- 空间放大：一份原始数据被copy/overwritten（一份用于服务query，一份用于snapshot之后用于compaction）

----
# Size-tiered Compaction
- Triggered when the system has enough similarly sized SSTables, merged together to form one larger sstable. A disadvantage of this strategy is that very large SSTable will stay behind for a long time and utilize a lot of disk space (recommended for write-intensive workloads)
- 每一个tiers的单片大小逐渐变大，但是每一个tiers的sstables数量一致
- 如果某一个tier满了（即sstables数量达到阈值）就会进行compaction，从而将该tier的所有数据merge为一个然后丢给下一个tier作为下一个tier的一个sstable。而在这个merge的过程，会copy一份原数据snapshot用于merge，merge之后再删除

![image](https://user-images.githubusercontent.com/8369671/80778462-16fb9680-8b9b-11ea-82cc-f98de4d9a4b7.png)
> tiered (num same，size grow)

----
# Leveled Compaction
- Triggered when unleveled SSTables (newly flushed SSTable files in Level 0) exceeds 4 (recommended for read-intensive workloads)
- 每一个tier里面的 sstable大小都是一致的，区别是每一个tier的sstable数量是逐渐变大的（一个数量级）
- tier1里面的sstables会跟tier2的sstables一起进行merge操作，最终在tier2（量大者）上形成一个有序的sstable

![image](https://user-images.githubusercontent.com/8369671/80778467-19f68700-8b9b-11ea-8cd0-68df789001b4.png)
> leveled (num grow，size same)

----
# Summary
![image](https://user-images.githubusercontent.com/8369671/80778473-1cf17780-8b9b-11ea-80fb-8c3ae5e93264.png)
> Size-tiered Compaction vs. Leveled Compaction

- data in one SSTable which is later modified or deleted in another SSTable wastes space as both tables are present in the system
- when data is split across many SSTables, read requests are processed slower as many SSTables need to be read

![image](https://user-images.githubusercontent.com/8369671/80778478-1fec6800-8b9b-11ea-89e2-ff0ef2f9f3cc.png)
> Scylla compaction summary

----
# Lucene Merge Policy
- [FilterMergePolicy](http://lucene.apache.org/core/7_6_0/core/org/apache/lucene/index/FilterMergePolicy.html "class in org.apache.lucene.index")
- [LogMergePolicy](http://lucene.apache.org/core/7_6_0/core/org/apache/lucene/index/LogMergePolicy.html "class in org.apache.lucene.index")
- [NoMergePolicy](http://lucene.apache.org/core/7_6_0/core/org/apache/lucene/index/NoMergePolicy.html "class in org.apache.lucene.index")
- [TieredMergePolicy](http://lucene.apache.org/core/7_6_0/core/org/apache/lucene/index/TieredMergePolicy.html "class in org.apache.lucene.index")

这里同样有三个放大问题，
- 写放大（doc在segment之间的迁移）
- 读放大（doc不同版本在不同segment，而打开一个segment需要一个indexReader）
- 空间放大（segments tmp空间）
[lucene write-once vs. random write](https://discuss.elastic.co/t/write-amplification-and-ssd/21272/2)

----
# Reference
- [Compaction Strategies](https://docs.scylladb.com/architecture/compaction/compaction-strategies/#compaction-strategies)
- [Cassandra Compaction](https://www.slideshare.net/tomitakazutaka/cassandra-compaction)
- [configuring Compaction](https://docs.datastax.com/en/cassandra/3.0/cassandra/operations/opsConfigureCompaction.html)
- [被忽视的Compaction策略-有关NoSQL Compaction策略的一点思考](https://www.cnblogs.com/sing1ee/archive/2012/05/24/2765042.html)
- [Dostoevsky: 一种更好的平衡 LSM 空间和性能的方式](https://www.jianshu.com/p/8fb8f2458253)
- [SSTable compaction and compaction strategies](https://github.com/scylladb/scylla/wiki/SSTable-compaction-and-compaction-strategies/_edit)[New Page](https://github.com/scylladb/scylla/wiki/_new)
- [elasticsearch index 之merge](https://tw.saowen.com/a/64d63bda6284038a96af74e5327f91570822dea2c206e1e43d1737542ad9549e)
- [深入理解什么是LSM-Tree](https://mp.weixin.qq.com/s/UqpnHs7g5XZcQWDRXiyKyQ)
