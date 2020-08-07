---
title: S6-ActionModule
tags: es
key: 41
modify_date: 2019-04-30 18:00:00 +08:00
---

在ActionModule模块，主要是注册各种es操作，以TransportAction为接口的一系列实现。

![image](https://user-images.githubusercontent.com/8369671/80784100-73b47c80-8bae-11ea-8dc4-59f120c55356.png)
> ActionModule的注册类

上图有2个非常重要的es action，一个是**index索引**，另一个是**search检索**。

# IndexAction
取其中的`IndexAction`来看具体实现`TransportIndexAction`，一步步调试进去。

`TransportIndexAction`继承了`TransportReplicationAction`，而`TransportReplicationAction`实现了`TransportAction`的doExecute方法。
所以其调用链如下，中间涉及了transportService的传输request/response等，

1. `Node.modules.add(new ActionModule(false));`
2. `ActionModule.configure().registerAction(IndexAction.INSTANCE, ransportIndexAction.class);`
3. `TransportIndexAction.doExecute().createIndexAction.execute()`，client端的send任务结束，并设置ActionListener监听response
4. `TransportReplicationAction.doExecute{new ReroutePhase((ReplicationTask) task, request, listener).run()};`
5. `TransportReplicationAction.ReroutePhase.doRun().performAction(node, actionName, false);`
6. `TransportReplicationAction.ReroutePhase.performAction().transportService.sendRequest()`
7. `TransportService.sendRequest.transport.sendRequest(node, requestId, action, request, options);`
8. `NettyTransport.sendRequest()`
9. `NettyTransport.doStart().createServerBootstrap().configureServerChannelPipelineFactory()`
10. `NettyTransport.ServerChannelPipelineFactory.getPipeline().MessageChannelHandler`
11. `MessageChannelHandler.messageReceived().handleRequest()`
12. `MessageChannelHandler.handleRequest().reg.processMessageReceived(request, transportChannel);`
13. `RequestHandlerRegistry.processMessageReceived().handler.messageReceived(request, channel);`
14. `TransportReplicationAction.OperationTransportHandler & PrimaryOperationTransportHandler & ReplicaOperationTransportHandler`
15. `TransportReplicationAction .PrimaryOperationTransportHandler.messageReceived().PrimaryPhase.doRun().shardOperationOnPrimary() -> TransportIndexAction.shardOperationOnPrimary() -> TransportIndexAction.executeIndexRequestOnPrimary() -> executeIndexRequestOnPrimary().operation.execute(indexShard); -> Engine.Index.execute.shard.index(this); -> IndexShard.index().engine().index(index); -> InternalEngine.index().innerIndex(index); -> InternalEngine.innerIndex().indexWriter.addDocuments(index.docs()); or indexWriter.updateDocuments(index.uid(), index.docs());`。index/update doc至Lucene
16. `InternalEngine.innerIndex().translog.add(new Translog.Index(index));` doc写入到WAL
17. 在步骤15的时候，primary与replica是同时被call的，即，`TransportReplicationAction.ReplicaOperationTransportHandler.messageReceived().AsyncReplicaAction.duRun().shardOperationOnReplica() -> TransportIndexAction.shardOperationOnReplica() -> TransportIndexAction.executeIndexRequestOnReplica() -> executeIndexRequestOnReplica().operation.execute(indexShard); -> ...后续流程与Primary的一致`。server端index任务结束，返回response到client
18. TransportIndexAction.doExecute().onResponse()。client利用`ActionListener`监听之前的`createIndexAction.execute()`的运行情况

![image](https://user-images.githubusercontent.com/8369671/80784102-77e09a00-8bae-11ea-97f1-a83b2f7df404.png)
> es index action的request和response

# SearchAction
search的调用方式与上述的index是一致的，本地节点走local，非本地节点走netty，都是通过handler来实现具体类的回调。
1. `Node.modules.add(new ActionModule(false));`
2. `registerAction(SearchAction.INSTANCE, TransportSearchAction.class);`
3. `TransportSearchAction.doExecute().SearchQueryThenFetchAsyncAction.start()`。这里可以是默认Q_T_F或者D_Q_A_F等
4. `AbstractSearchAsyncAction.start().performFirstPhase()`
5. `AbstractSearchAsyncAction.performFirstPhase().sendExecuteFirstPhase()`。client端的send任务结束，并设置ActionListener监听response
6. `SearchQueryThenFetchAsyncAction.sendExecuteFirstPhase().searchService.sendExecuteQuery(node, request, listener);`
7. `SearchServiceTransportAction.sendExecuteQuery().transportService.sendRequest()`
8. `TransportService.sendRequest().sendRequest(node, action, request, TransportRequestOptions.EMPTY, handler);`
9. `TransportService.sendRequest().transport.sendRequest(node, requestId, action, request, options);`
10. `NettyTransport.sendRequest()`
11. `NettyTransport.doStart().createServerBootstrap().configureServerChannelPipelineFactory()`
12. `NettyTransport.ServerChannelPipelineFactory.getPipeline().MessageChannelHandler`
13. `MessageChannelHandler.messageReceived().handleRequest()`
14. `MessageChannelHandler.handleRequest().reg.processMessageReceived(request, transportChannel);`
15. `RequestHandlerRegistry.processMessageReceived().handler.messageReceived(request, channel);`
16. `SearchQueryQueryFetchTransportHandler.messageReceived().searchService.executeFetchPhase(request);`。首先执行具体的searchService，然后回写response
17. `SearchService.executeFetchPhase().queryPhase.execute(context); & fetchPhase.execute(context);`
18. `SearchQueryQueryFetchTransportHandler.messageReceived().channel.sendResponse(result);`
19. `NettyTransport.sendResponse().sendResponse().`
20. `NettyTransportChannel.sendResponse().future.addListener(onResponseSentListener);`。回应步骤5的监听

![image](https://user-images.githubusercontent.com/8369671/80784106-7adb8a80-8bae-11ea-8b19-d737812d58ad.png)
> es searchType async action

![image](https://user-images.githubusercontent.com/8369671/80784198-c8f08e00-8bae-11ea-81f9-307d2bba39dd.png)
> es search action的request和response

# RPC回调
RPC调用有**LocalTransport**和**NettyTransport**；回调有**RequestHandler**、**MessageChannelHandler**等。理清es关于request和response的异步回调，对于后续的模块化衔接会有帮助。

> - client/**TransportClient**的构造函数注入了**TransportProxyClient**.execute()方法，接着进入**TransportClientNodesService**来选择这次request的hash到的node，然后根据action选取对应的实现类**TransportActionNodeProxy**.execute()，其中execute().transportService.sendRequest()最终会调用**NettyTransport**.sendRequest()方法，对**request**进行处理（压缩、版本等），最后发送数据到server端。在Netty中通信的处理类是**MessageChannelHandler**，其中messageReceived方法用来处理消息，根据不同的状态来调用handleRequest或者handleResponse，即该方法是server端接收请求的入口
> - server端通过**messageReceived**接收到*message*，解析协议，根据action生成不同request和transport**XXX**Action，进而执行transport**XXX**Action.execute(Request request, final ActionListener<Response> listener)。server端处理该message后，将response结果（此结果中包含了前面的requestID）发送给client端

# Reference
- [elasticsearch源码分析之客户端（三）](https://blog.csdn.net/thomas0yang/article/details/52189215)
- [elasticsearch源码分析之服务端（四）](https://blog.csdn.net/thomas0yang/article/details/52253165)
- [[源码]Elasticsearch源码2(RPC)](https://psiitoy.github.io/2017/08/10/[%E6%BA%90%E7%A0%81]Elasticsearch%E6%BA%90%E7%A0%812(RPC)/)
