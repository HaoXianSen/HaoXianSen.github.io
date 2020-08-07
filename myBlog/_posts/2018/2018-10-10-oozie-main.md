---
title: Oozie Source Code Main
tags: oozie
key: 49
modify_date: 2019-04-30 18:00:00 +08:00
---

最近想借着`调度系统`这个项目来看看业界出色的调度系统的源码，如Oozie，Airflow，

# Overview
Oozie是雅虎开源出来的一个出色的工作流，支持很多jobType，spark，email等。主要分为3个角色，
- server，用于保持长链接，监听来自于client的jobSubmit，然后分发job到各个executor上去执行，执行结果展示在UI上
- client，与用户打交道，用户在部署了client的机器上直接运行cmd，用来submit cmd，如kill，check，submit
- shardlib(adaptor, executor)：真正的执行部件

----
# Version
```
<groupId>org.apache.oozie</groupId>
<artifactId>oozie-main</artifactId>
<version>5.1.0-SNAPSHOT</version>
```

![image](https://user-images.githubusercontent.com/8369671/80780884-1830c180-8ba3-11ea-9f22-6a0aded9c43d.png)
> Latest Submission

----
# Client
下面看看它的源码入口，
- `bash oozie -> org.apache.oozie.cli.OozieCLI -> run() -> processCommand()`
- e.g.: `processCommand() -> jobCommand() -> KILL_OPTION -> wc.kill() -> new JobAction() -> call() -> createURL() -> JobAction.call(HttpURLConnection conn)` （2个不同的call function，拼接URL，然后发送到server）
- e.g.: `oozie job -oozie http://localhost:11000/oozie -kill 14-20090525161321-oozie-joe` (这句的oozie对应上句的oozie，即每次运行CommandLineTool命令都是java -cp了OozieCLI，只是每次的OozieCLI启动参数不同而已)

```
super("PUT", RestConstants.JOB, notEmpty(jobId, "jobId"), prepareParams(RestConstants.ACTION_PARAM, action));

public ClientCallable(String method, String collection, String resource, Map<String, String> params) {
    this(method, null, collection, resource, params);
}

public ClientCallable(String method, Long protocolVersion, String collection, String resource, Map<String, String> params) {
    this.method = method;
    this.protocolVersion = protocolVersion;
    this.collection = collection;
    this.resource = resource;
    this.params = params;
}

URL url = createURL(protocolVersion, collection, resource, params);

sb.append(getBaseURLForVersion(protocolVersion));
```

![image](https://user-images.githubusercontent.com/8369671/80780889-1bc44880-8ba3-11ea-9239-20758922e043.png)
> CLI

----
# Server
源码入口，
- `bash oozied.sh -> oozie-jetty-server.sh -> org.apache.oozie.server.EmbeddedOozieServer`
- `embeddedOozieServer.setup() -> oozieServletMapper.mapOozieServlets(); -> mapServlet(V0JobServlet.class, "/v0/job/*"); -> BaseJobServlet.doPut() -> embeddedOozieServer.join()`
- server hold till shutdown hook
- e.g.: `mapServlet(V0JobServlet.class, "/v0/job/*");`, `*`号就是Client的jobId，`v0`就是`protocolVersion`，job是字符串常量"job"

![image](https://user-images.githubusercontent.com/8369671/80780896-1ebf3900-8ba3-11ea-9dcf-5349db40143c.png)
> URL Mapping

----
# shardlib
源码入口，
- `servletHandler.addServlet(new ServletHolder(v1JobsServletName, new V1JobsServlet()));`
- `EmbeddedOozieServer -> ServletMapper -> V1JobsServlet.submitJob().submitHttpJob() -> dagEngine.submitJob() -> submit.call() -> start(jobId) -> new StartXCommand(jobId).call() -> ...`

将自定义的xxx.wf xml翻译成DAG，然后定时运行。

![image](https://user-images.githubusercontent.com/8369671/80780902-21219300-8ba3-11ea-884b-3fc2d73ce224.png)
> Actions Supported by Oozie
