---
title: S2-DiscoveryModule
tags: es
key: 36
modify_date: 2019-04-30 18:00:00 +08:00
---

在`new Bootstrap().setup()`里实现了instance的初始化，其中主要一步是Node的new，在Node的构造函数当中，将很多module也挂靠上去了。下面简单看看`DiscoveryModule`模块。

![image](https://user-images.githubusercontent.com/8369671/80784636-5680ad80-8bb0-11ea-8ef8-39d87becadd0.png)
> DiscoveryModule constructor

DiscoveryModule模块有2类，一个本地版/JVM版`local`，一个集群版`zen`。

# LocalDiscovery
里面有几个重要的field，分别是`ClusterService`，`RoutingService`，`ClusterState`。自成master，`final LocalDiscovery master = firstMaster`。其中`startInitialJoin`用于启动触发，`publish`是master用于下发**集群变化信息**的函数。

![image](https://user-images.githubusercontent.com/8369671/80784639-597b9e00-8bb0-11ea-98a1-00dbf3a7be23.png)
> 下发信息


主要下发路由信息和元数据信息。

# ZenDiscovery
这个模块相比上一个模块多了集群分布式的功能，如，`TransportService`、`MasterFaultDetection`、`MembershipAction`、`JoinThreadControl`等。
其中，集群模式下的master节点查找功能如下，
`new JoinThreadControl(threadPool)` -> `innerJoinCluster` -> `findMaster()` -> `electMaster()` -> `sortedMasterNodes()` -> `membership.sendJoinRequestBlocking`

![image](https://user-images.githubusercontent.com/8369671/80784642-5bddf800-8bb0-11ea-817c-87211c5aeaa3.png)
> findMaster

![image](https://user-images.githubusercontent.com/8369671/80784647-5e405200-8bb0-11ea-98e2-e37d39452620.png)
> master node comparison
