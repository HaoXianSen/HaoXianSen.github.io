---
title: S5-SearchModule
tags: es
key: 39
modify_date: 2019-04-30 18:00:00 +08:00
---

在SearchModule模块中，主要涵盖了`search`性能相关的依赖注入。

![image](https://user-images.githubusercontent.com/8369671/80784244-f2a9b500-8bae-11ea-8370-f1230aa3cbe7.png)
> searchModule所挂靠的服务

----
# configureSearch
主要是[seach type](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-search-type.html)，search过程一般有两步，首先search带回<_id, _score>，然后fetch带回<_id, _source>。
默认是`query_then_fetch`，shard级别的排序；可以设置为`dfs_query_then_fetch`，cluster级别的全局排序。它们之间的差异可以参见esCn的[柠檬排序](https://link.jianshu.com/?t=https%3A%2F%2Felasticsearch.cn%2Fquestion%2F2275)。

![image](https://user-images.githubusercontent.com/8369671/80784251-f5a4a580-8bae-11ea-91cf-26d3a0f2e7a8.png)
> search方式

----
# configureAggs
在此配置[聚合操作](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-aggregations.html)，如SUM，AVG，MIN，MAX，直方图分布等。

![image](https://user-images.githubusercontent.com/8369671/80784253-f9382c80-8bae-11ea-9b08-4398fa100ac6.png)
> 聚合操作

在static块上面，进行了es aggregation的三种类型（metrics, bucket, pipeline）注册。

![image](https://user-images.githubusercontent.com/8369671/80784258-fccbb380-8bae-11ea-966d-2fd2e40312c9.png)
> static的三种aggs注册

----
# configureFunctionScore
配置[自定义排序函数](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/query-dsl-function-score-query.html)，具体函数使用方法可以参考[前文-elasticsearch relevance scoring 检索相关性计算](https://www.jianshu.com/p/8bb84384566a)。

![image](https://user-images.githubusercontent.com/8369671/80784261-ffc6a400-8bae-11ea-9b44-0279d12cbc9c.png)
> ScoreFunctionParser的具体实现类

----
# configureFetchSubPhase
在此注入一些额外信息，比如[explain](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-explain.html), [version](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-version.html), [highlight](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/search-request-highlighting.html)等。

![image](https://user-images.githubusercontent.com/8369671/80784267-0228fe00-8baf-11ea-85fb-446e61426dae.png)
> others

----
# Reference
- [Java: What is the difference between <init> and <clinit>?](https://stackoverflow.com/questions/8517121/java-what-is-the-difference-between-init-and-clinit)