---
title: elasticsearch文章收集与心得记录
tags: es
key: 12
modify_date: 2019-04-30 18:00:00 +08:00
---

为了更好地理解与排版，部分文章标题可能会有修改

# 降序记录

- [eBay Elasticsearch 性能优化实战-中文篇](http://blog.csdn.net/kimichen123/article/details/79073832)
- [number?keyword?傻傻分不清楚](https://elasticsearch.cn/article/446)
---- 数值类型(number)的数据结构变成Block k-d tree
---- query/filter执行顺序不是按照写入顺序，而是内部根据cost()估算每个查询的代价，选择代价最低的query/filter开始，在其圈定的docid集合上生成一个迭代器
---- `indexOrDocValuesQuery`对`rangeQuery`的优化
------ Rang查询的数据集大小，以及要做的合并操作类型，决定用哪种Query。 如果Range的代价小，可以用来引领合并过程，就走`PointRangeQuery`，直接构造bitset来进行迭代
------ 如果range的代价高，构造bitset太慢，就使用`SortedSetDocValuesRangeQuery`，利用DocValues的`全局docID序，并包含每个docid对应value的数据结构`来做文档的匹配
- [elasticsearch 集群启动流程](https://mp.weixin.qq.com/s/8K-TULv_ZgZ_hr-QnrqAZQ)
---- node级别
------ 主节点选举，节点数>=N/2+1，max节点ID
------ 集群元信息选举，主节点先收集，merge之后再将metadata下发到各节点
---- shard级别
------ 主分片选举，master汇总所有节点的shard信息后，选取一个main shard
------ 副分片分配，master从汇总shard信息中选取一个
------ 主分片recovery，disk segment && replay translog
------ 副分片recovery，copy from main shard && translog && 分片完整性和版本数据一致性
- [Bulk异常引发的Elasticsearch内存泄漏](https://elasticsearch.cn/article/361)
---- jvm，heap dump内存分析，Eclipse MAT，Log4j
- [一例Query Cache引起的性能问题分析](https://elasticsearch.cn/article/304)
---- node query cache分析过程 访问倒排->heap开始缓存bitmap->hit cached bitmap
---- term filter足够快，es去掉了term的cache
---- range filter，如果精确到秒级别，那么hit bitmap每秒都在变，hit cached一直被LRU，所以可以降低range的精度，比如精确到小时级别
- [使用es做搜索，真假柠檬排序之争](https://elasticsearch.cn/question/2275)
---- 有时候问题在大规模数据下不能正常运行，这回反过来在小数据集上有问题，让自己意识到这个relevance score问题，从而促使自己记录了一个关于排序分的文章
- [谈谈ES的Recovery](https://elasticsearch.cn/article/38)
---- shard级别，es node重启、更新，synced flush ID，replay transLog
- [记一次es性能调优](https://elasticsearch.cn/article/118)
---- gc, index filter cache, refresh_interval
- [关于es缓存](https://elasticsearch.cn/question/2709)
---- node query cache，
---- shard request cache
---- fielddata cache
---- system cache
---- global ordinals
- [Elasticsearch JVM Heap Size大于32G，有什么影响？](http://www.cnblogs.com/zklidd/p/6170917.html)
---- es heap Zero Based Compressed OOPS
- [ES内存那点事](https://elasticsearch.cn/article/32)
---- lucence倒排生成过程 es heap->disk->system cache
---- segment memory(倒排索引之上的又一层索引）
---- es缓存
---- 超大规模集群的状态信息
---- 大聚合的结果集query-fetch
