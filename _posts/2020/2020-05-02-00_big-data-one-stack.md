---
title: One Stack Big Data Platform 
tags: architect
key: 103
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/80915045-153ff780-8d82-11ea-9acf-6ccbf2b05d9d.png
---

# Overview
分布式本质论: 高吞吐(high throughput), 高可用(high available), 低延迟(low latency), 可扩展(high scalability).

整合一下个人对于大数据平台, 数据中台, 数据仓库的技术栈, 这里有一个它们之间差异的[回答](https://www.zhihu.com/question/282421879), 

```go
- 数据库阶段, 主要是OLTP(联机事务处理)的需求
- 数据仓库阶段, OLAP(联机分析处理)成为主要需求
- 数据平台阶段, 主要解决BI和报表需求的技术问题
- 数据中台阶段, 通过系统来对接OLTP和OLAP的需求, 强调数据业务化的能力
```

当然, 主要看具体业务需求, 一切脱离业务的架构都是耍流氓. 业务开展到哪里, 架构也要跟着并延展些. 

另外, 有些框架经过多年的发展, 已经脱离了单一的技术范畴, 向着多元化的生态圈发展. 当然这也是围城和壁垒.

# Structure
下面是一个不大完善的数据栈图, 中台可以在此之上做扩展. 
![db Arch](https://user-images.githubusercontent.com/8369671/83434218-9f0bdf00-a46c-11ea-94a4-5459487f65cd.png)

## data collection
![image](https://user-images.githubusercontent.com/8369671/80909688-bf0c8d80-8d5c-11ea-94d4-8201c9142540.png)
> flume(2011): 采用事务来确保event可靠性, 由sink来确认是否remove channel里的event, via apache

![image](https://user-images.githubusercontent.com/8369671/80910187-5c1cf580-8d60-11ea-825e-567cbf8f68e7.png)
> libbeat(2015): 通过Scan()来确认新增file, 然后为其new一个harvester发送到libbeat做聚合, via elastic

#### Reference
- [apache flume reliability](https://flume.apache.org/FlumeUserGuide.html#reliability)
- [filebeat-overview](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-overview.html)
- [filebeat工作原理](https://www.jianshu.com/p/6282b04fe06a)

## data storage(raw)
### batch
![image](https://user-images.githubusercontent.com/8369671/80858795-4b9c4a80-8c8e-11ea-8460-b8757875979c.png)
> hdfs(2006): 分布式文件系统, 通过master-slave和replica机制来低成本高可靠地存储数据. via bigintellects

### stream
![image](https://user-images.githubusercontent.com/8369671/80914484-74037200-8d7e-11ea-9834-8be306c7777d.png)
> kafka(2011): file system cache, [zero copy](https://zhuanlan.zhihu.com/p/78335525)(内核态), 顺序写磁盘. via dataflair

![image](https://user-images.githubusercontent.com/8369671/80863711-b199c980-8cb0-11ea-92f0-e89715b259f1.png)
> pulsar(2016): 将`无状态的消息服务层broker`和`有状态的消息持久层bookkeeper`分离, 无状态可以随时增删, 而有状态却通过replica segment来做HA；当然还有scale out. via streamthoughts

#### Reference
0. [技术架构及选型](http://www.jouypub.com/2019/8b02bd00f40ccf93019a317ee7d34081/)
0. [Dynamo: Amazon’s Highly Available Key-value Store](https://www.allthingsdistributed.com/2007/10/amazons_dynamo.html)
0. [Pulsar(新一代高性能消息系统)核心总结](http://lxkaka.wang/2019/03/25/pulsar/)
0. [BookKeeper 原理浅谈](http://matt33.com/2019/01/28/bk-store-realize/)
0. [Comparing Pulsar and Kafka](https://www.splunk.com/en_us/blog/it/comparing-pulsar-and-kafka-how-a-segment-based-architecture-delivers-better-performance-scalability-and-resilience.html)
0. [Understanding How Apache Pulsar Works](https://jack-vanlightly.com/blog/2018/10/2/understanding-how-apache-pulsar-works)

## data compute
### batch
![image](https://user-images.githubusercontent.com/8369671/80911284-f2084e80-8d67-11ea-9423-b077913c1f31.png)
> spark(2014): lambda(batch-stream分离), master-slave, rdd, lineage, persist, via 0x0fff

![image](https://user-images.githubusercontent.com/8369671/81182974-20449300-8fe1-11ea-9a7d-0e54c121f19a.png)
> airflow(2015): high scalability, HA, UI manage, via clairvoyantsoft

![image](https://user-images.githubusercontent.com/8369671/80914120-27b73280-8d7c-11ea-917d-2562d18a8fa1.png)
> oozie(2011): server与compute分离, multilayer(bundle), HA, via devstacks

这里scheduler都是通过多server来避免SPOF, 而多server之间的状态同步是通过DB(ZK)来传递.

有别于常规的多server leader-standby模式(eg., kafka broker, DB主从复制) 

### stream
![image](https://user-images.githubusercontent.com/8369671/80914587-fbe97c00-8d7e-11ea-8ed2-ac19aaab9eb7.png)
> flink(2011): kappa, master-slave, [state](https://juejin.im/post/5c87dbdbe51d45494c77d607), window, cp, via apache

#### Reference
0. [Making Apache Airflow Highly Available](http://site.clairvoyantsoft.com/tag/high-availability/)
0. [Oozie Architecture and Job Scheduling](https://devstacks.wordpress.com/2017/02/16/oozie-architecture-and-job-scheduling/)
0. [Lambda架构 vs Kappa架构](https://ask.hellobi.com/blog/Beckham/12290)
0. [Flink--Checkpoint机制原理](https://www.jianshu.com/p/4d31d6cddc99)
0. [一文搞懂Flink内部的Exactly Once和At Least Once](https://www.jianshu.com/p/8d6569361999)

## data storage
### in-memory
![image](https://user-images.githubusercontent.com/8369671/80949680-0cedc800-8e27-11ea-9340-5d5640e84fa1.png)
> redis(2009): mem-base, 非阻塞多路IO复用, 事务, proactive expire, HA(sentinel), throughput(cluster), via redislabs

![image](https://user-images.githubusercontent.com/8369671/80974537-6ff55400-8e53-11ea-9e19-5f1882af7044.png)
> ignite(2015): 分布式, KV, mem-disk SQL, 2PC事务, 数据本地性, via apache

### timeseries
![image](https://user-images.githubusercontent.com/8369671/81039960-e0948300-8edc-11ea-9f48-bd0edb27089d.png)
> influxdb(2013): TSM, TSI, WAL/cache, rp, via hbasefly

### full-text
![image](https://user-images.githubusercontent.com/8369671/81048644-4be75080-8eef-11ea-8363-0944312525da.png)
> es(2010): master-data, zen discovery , replica, LSM, full text

### MOLAP
![image](https://user-images.githubusercontent.com/8369671/81054993-64109d00-8efa-11ea-977b-32b0b3403bbe.png)
> kylin(2013): 预计算cube, SQL, high scalability, MR, via apache

![image](https://user-images.githubusercontent.com/8369671/81068339-cb3a4b80-8f12-11ea-83d5-f9e8dd91b3ed.png)
> druid(2011), role separate(master-query-data), LSM, via apache

### ROLAP
![image](https://user-images.githubusercontent.com/8369671/81143961-aa6f0600-8fa5-11ea-8249-29919a76d3e6.png)
> clickhouse(2016): russia, column oriented, SQL, 主备复制, index(primary key sort), table engine, via altinity 

![image](https://user-images.githubusercontent.com/8369671/81159496-99c98a80-8fbb-11ea-88d6-0bc23c94aaa5.png)
> greenplum(2015): master-slave, [append-optimized](https://github.com/digoal/blog/blob/master/201708/20170818_02.md), SQL, resource queue, via researchgate 

![image](https://user-images.githubusercontent.com/8369671/80951231-0f9dec80-8e2a-11ea-9091-f2c9ea3ef920.png)
> tidb(2017): 分布式, SQL, raft, LSM, mysql alternative, via pingcap

### query engine
![image](https://user-images.githubusercontent.com/8369671/81101961-78c45380-8f41-11ea-83c9-1c6e73bde07f.png)
> presto(2013): master-slave, mem-base MPP, SQL, connector, via slideshare

![image](https://user-images.githubusercontent.com/8369671/80785361-96e12b00-8bb2-11ea-9f20-a1e9cc526dae.png)
> sparksql(2014): catalyst, cost base, rdd, via dataflair

![image](https://user-images.githubusercontent.com/8369671/81178389-b0cba500-8fda-11ea-9bbc-c1b8542701f6.png)
> hive(2010): SQL, MR, metadata, via andr83 

![image](https://user-images.githubusercontent.com/8369671/81178977-97772880-8fdb-11ea-9707-97b4f25c3f1b.png)
> pig(2008): pig latin, MR, via dezyre

### graph
![image](https://user-images.githubusercontent.com/8369671/81493837-6f870e00-92d6-11ea-8407-65ad14a2426f.png)
> neo4j(2007): 定长记录结构, cypher, HA, via slideshare

#### Reference
0. [IO多路复用技术(multiplexing)是什么？](https://www.zhihu.com/question/28594409)
0. [为什么IO多路复用要搭配非阻塞 IO?](https://www.zhihu.com/question/37271342)
0. [Ignite(二): 架构及工具](https://www.cnblogs.com/tgzhu/p/9984170.html)
0. [数据库如何用 WAL 保证事务一致性？](https://zhuanlan.zhihu.com/p/24900322)
0. [Every shard deserves a home](https://www.elastic.co/blog/every-shard-deserves-a-home)
0. [Guide to Refresh and Flush Operations in Elasticsearch](https://qbox.io/blog/refresh-flush-operations-elasticsearch-guide)
0. [Apache Kylin 入门 2 - 原理与架构](https://juejin.im/post/5bc4979a5188255c451ed5a0)
0. [apache druid架构、原理、执行流程](https://www.cnblogs.com/lihaozong2013/p/11655594.html)
0. [数据结构篇----B+树与LSM树浅析](https://zhuanlan.zhihu.com/p/67068975)
0. [ClickHouse表引擎到底怎么选](https://developer.aliyun.com/article/739801)
0. [TiDB整体架构](https://pingcap.com/docs-cn/stable/architecture/)
0. [Presto: SQL on Everything](https://prestosql.io/Presto_SQL_on_Everything.pdf)
0. [Presto架构及原理、安装及部署](https://my.oschina.net/hblt147/blog/3006435#h3_13)
0. [Spark SQL Catalyst优化器](https://chenfh5.github.io/2018/03/11/spark-sql-catalyst.html)
0. [What is Hive Metastore?](https://www.quora.com/What-is-Hive-Metastore)
0. [Neo4j_高层架构和应用](https://blog.csdn.net/Regan_Hoo/article/details/78772479)

## data analytics
### BI
TODO
> TODO
