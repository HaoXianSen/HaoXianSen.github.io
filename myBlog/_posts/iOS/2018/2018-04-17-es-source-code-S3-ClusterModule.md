---
title: S3-ClusterModule
tags: es
key: 37
modify_date: 2019-04-30 18:00:00 +08:00
---

这个模块主要将集群的默认配置加上（`registerBuiltinClusterSettings`和`registerBuiltinIndexSettings`），以及绑定一些集群服务（`ClusterInfoService`, `DiscoveryNodeService`, `MetaDataCreateIndexService`, `RoutingService`等）。

![image](https://user-images.githubusercontent.com/8369671/80784513-d65a4800-8baf-11ea-8dd5-ee0ba806d662.png)
> builtin cluster settings

![image](https://user-images.githubusercontent.com/8369671/80784523-de19ec80-8baf-11ea-8553-1d485336a4d3.png)
> builtin index settings

最后通过interface的configure将以上2个settings的实例（`DynamicSettings.class`）绑定/注入到`ClusterModule.class`上。

![image](https://user-images.githubusercontent.com/8369671/80784519-d9edcf00-8baf-11ea-8a05-a378779813d9.png)
> bind setting and service

asEagerSingleton作为一种热加载（相较于lazy initialization）。

其中MetaDataCreateIndexService里面就包括了index相关的metadata settings，比如mapping, alias, shards, replicas等。

![image](https://user-images.githubusercontent.com/8369671/80784525-e114dd00-8baf-11ea-826f-261df333b681.png)
> create index metadata

----
# Guice
在ClusterModule的configure()中，通过bind()将**接口**和**实现类**关联起来。

----
# Reference
- [Google-Guice入门介绍](https://blog.csdn.net/derekjiang/article/details/7231490)
- [Guice系列之用户指南（十）](http://lifestack.cn/archives/143.html)
