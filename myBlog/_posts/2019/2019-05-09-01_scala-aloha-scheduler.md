---
title: Scala调度器Aloha关注点
tags: scala
key: 68
modify_date: 2019-05-16 19:00:00 +08:00
---

# Overview
一直想自己弄一个分布式调度器，感觉一个调度器包含了比较全面的架构知识点，

比如，rpc，分布式master-slave(worker)，HA，元数据，数据库，并发，异步，调度

今天刚好再公众号里面看到介绍的[Aloha](https://github.com/jrthe42/aloha)，而且还是scala写的，之前看的[Oozie](https://github.com/apache/oozie)和jobnavi都是java写的。那么看看这个Aloha是如何工作的，一步一步分解她的各个模块和工作流程，力求之后自己能够独立写出一个分布式调度器来:smile:

![image](https://user-images.githubusercontent.com/8369671/58456021-aa3f7700-8155-11e9-90a7-57ba28fe2809.png)
> 主体架构流程

# Modules
这一节主要分解各个模块的架构和流程，

先认识一下里面的术语，
- master
    - 主节点，一般情况下是有1个active，2个standby
    - 保存了所有worker id, app id等metadata
    - 利用ZK等做HA保存metadata，故障就从ZK恢复
- worker
    - 从节点，工作节点，执行真正业务逻辑的节点，线性可扩展`usableWorkers`
    - 定时发送heartbeat到master，如果长时间与master的通信断开，则master会认为该worker crash，然后通过ZK提出该worker及其app，然后在其他存活的worker重起app
- app
    - 具体执行任务，可以是`java -cp`，可以是`bash`
    
## Pom
先看看`parent-pom`，其实依赖和插件都不多，

- 公共，日志log
- 集合guava
- netty，rpc
- curator，zk
- json4s
- jetty，web-server
- junit

插件只有一个，`scala-maven`

## Compile && Script
编译jar包之后，接下来是运行`sbin/aloha-daemon.sh`命令，进去看看，
- OPTION in [start, stop, status] 
- DAEMON in [master, worker]
- 用了`touch`来检验权限`privilege`
- 如果没有通过`--config`指定`ALOHA_CONF_DIR`，使用默认的
- bash exit 0 // 正常
- rsync SRC DEST  // 排除log
- aloha_rotate_log() // log后移为log.1，即将log空出来
- run_command()使用`nohup`调用`aloha-class`里面exec重定向,然后执行java -cp命令，最后写pid到文件

## Master
`bash sbin/aloha-daemon.sh start master -h 127.0.0.1 -p 1234`
运行了`aloha-daemon.sh`之后，首先是启动`master`，主路径是`me.jrwang.aloha.scheduler.master.Master`，进去看看，
- `main()`在629行
- 首先初始化系统和手动配置，`new AlohaConf()`
- 启动master web server，并开始监听
    - new NettyRpcEnv()
    - new TransportServer(), 建立server
    - new Dispatcher(), 建立消息route（分发到不同endpoint）
    - setupEndpoint(), 建立endpoint
        - new NettyRpcEndpointRef()
        - new EndpointData() -> new inbox()初始化，并投放第一条msg到OnStart, 即`receivers.offer(endpointData)`
        - lazy启动，当第一条msg过来了，dispatch才调用`data.inbox.process() -> OnStart()`来初始化 // OnStart should be the first message to process
    - askSync()消费第一条msg OnStart()
        - dispatcher.postLocalMessage(message, p)，将msg推送到
        - pool.execute(new MessageLoop)
        - 每条MessageLoop()线程都会while(true)地从receivers来take(阻塞)msg，然后process()，即`receivers.take().inbox.process(Dispatcher.this)`
        - 每个endpointData里面都有一个LinkedList()来保存具体msg,receiveAndReply
        - 创建ApplicationInfo task,val app = createApplication(description)
        - 注册ApplicationInfo,registerApplication(app)
        - 为app挑选空闲worker,并launch
        - 发送app到worker,`worker.endpoint.send(LaunchApplication(masterUrl, app.id, app.desc))`
        - 持久化app状态
    - 至此启动

    ![image](https://user-images.githubusercontent.com/8369671/58456029-ad3a6780-8155-11e9-9449-e652d95d00f0.png)

## Worker
接着运行`bash sbin/aloha-daemon.sh start worker -h 127.0.0.1 aloha://127.0.0.1:1234`，启动worker，路径是`me.jrwang.aloha.scheduler.worker.Worker`，主要流程如下，
- 接受task，inbox, endpoint.receive
- handleRegisterResponse()的case RegisteredWorker(masterRef)将master信息注入到worker，然后就可以与master通信了
- 启动task，case LaunchApplication(masterUrl, appId, appDesc)
- 新开一个线程，fetchAndRunApplication()
    - 创建真正的Application,Application.create(反射)
    - 先发送app状态为running到master,`worker.send(ApplicationStateChanged())`
    - 再开始真正执行app,`Await.result(exitStatePromise.future, Duration.Inf)`
        - 目前实现的app，只有ApplicationWithProcess，是可以运行bash命令的，而bash命令可以调起`java -cp`
        
## HA
- master自己的HA
    - Master, onStart()
    - 拿zk来讲
        - 先建立engine，即保存路径path`master_status`,PERSISTENT永久
        - 选主leader_election，`leaderLatch = new LeaderLatch()`
        - 如果leader变更
            - 通过`notLeader()`的回调发起`send(RevokedLeadership)`，停掉当前master(这里是否可以更加优雅？如果是只是退主，而不是退JVM，因为退了JVM后续要手动拉起了？当然这里如果用supervisor来拉起的话，应该也是可以的，自动拉起后再join到zk里面，随时准备当主)
            - 通过`isLeader()`的回调发起`send(ElectedLeader)`，通知当前master当主，并使用`completeRecovery()`
                - 通过zk path的PERSISTENT恢复之前持久化的app和worker信息
                - 将所有app信息注册到当前master(感觉这里可以更优雅？)
                - 将所有worker注册到当前master，并通知所有worker换主
                - `send(CompleteRecovery)`告知恢复完毕
                    - 清理UNKNOWN worker和app
                    - 重新schedule(),将分配app到空闲worker
- worker crash之后,本来在该worker上的app会重新安排在别的worker rerun
    - onDisconnected()
        - removeWorker()
        - relaunchApplication()

## REST
master也有一个跟外部通信的http rest接口，base on jetty，用于启停杀任务app，

StandaloneRestServer，直接发送三类任务`masterEndpoint.askSync[*app*]`到dispatch的receivers上，然后dispatch的while(true)线程消费该rest app，然后分发到master

这里启动rest server使用了RestSubmissionServer，
`val (server, boundPort) = Utils.startServiceOnPort[Server](requestedPort, doStart, masterConf)`
启动doStart()是一个[传名函数](https://blog.csdn.net/asongoficeandfire/article/details/21889375)，起到lazy加载的效果

![image](https://user-images.githubusercontent.com/8369671/58456034-af9cc180-8155-11e9-9d05-06d734c2ee33.png)
> rest urls

# Reference
- [jrthe42 Aloha](https://github.com/jrthe42/aloha)
- [Aloha：一个分布式任务调度框架](http://blog.jrwang.me/2019/aloha-introduce/)
