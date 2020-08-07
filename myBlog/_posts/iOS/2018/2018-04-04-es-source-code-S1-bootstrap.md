---
title: S1-Bootstrap模块
tags: es
key: 33
modify_date: 2019-04-30 18:00:00 +08:00
---

----
接下来开始Bootstrap模块的分析，目录如下，
```
1. Debug开启
2. Node启动
```

----
# Debug开启
es的bootstrap如下，
![image](https://user-images.githubusercontent.com/8369671/80784884-1ec63580-8bb1-11ea-826d-9ede7c44eb68.png)
> bootstrap模块

里面Elasticsearch.java上有main()方法，通过其来启动es集群。而main()方法的调用是通过`elasticsearch.sh`这个脚本里面的`java -cp`

![image](https://user-images.githubusercontent.com/8369671/80784891-21c12600-8bb1-11ea-9e89-a4eef94157fd.png)
> es集群的启动脚本

![image](https://user-images.githubusercontent.com/8369671/80784893-24bc1680-8bb1-11ea-980d-729129834ecd.png)
> elasticsearch.sh


其中`start`是第一个手输入参；`$@`是脚本的所有参数汇总；`<&-`是输入重定向；`&`是设置为后台进程。

![image](https://user-images.githubusercontent.com/8369671/80784896-2685da00-8bb1-11ea-8b35-4740320292bb.png)
> main入口

由此进入Elasticsearch的main()，初始化Bootstrap，之前的`start`在这里是一个识别的作用，是start还是version；在初始化bootstrap过程中，需要初始化env，如果在Windows本机下逐步debug，需要设置`path.home`或者`set env`

![image](https://user-images.githubusercontent.com/8369671/80784899-284f9d80-8bb1-11ea-803e-e9232194ffa7.png)
> environment

至此，可以通过main function来在Windows系统下进行debug。

![image](https://user-images.githubusercontent.com/8369671/80784903-2ab1f780-8bb1-11ea-9675-dc0b322dae5d.png)
> 9200_snapshot

![image](https://user-images.githubusercontent.com/8369671/80784905-2c7bbb00-8bb1-11ea-8ce9-e37513a9529a.png)
> console

console显示的`cluster.name`和`node.name`是在`elasticsearch.yml`配置，建议自定义，不然es分配的默认值不利于辨识。另外，出现了一个异常，后续会讲到。

Type | Default | Custom 
--- | --- | ---
`cluster.name` | elasticsearch | your custom
`node.name` | random hero name | your custom

----
# Node启动
es集群的启动，通过Elasticsearch.main -> bootstrap.init即可，中间会涉及es绝大部分**模块**（plugin，setting，cluster，transport等）的初始化和相关**功能服务**（mapping，index，search，routing等）的注入。其主要步骤如下，
1. CLIParser，检测CLI命令行环境
2. instance = new Bootstrap，新建一个bootstrap实例（实例由node，keepAlive组成）
3. prepare Environment，构建es env
   - initial**Settings**，settings是environment的一个属性
4. instance.setup，根据environment配置bootstrap实例的node属性
   - node -> nodeBuilder.build = new Node
   - node constructor
      - threadpool
      - modules.add，***根据environment将各具体module类加入到ModulesBuilder中，然后使其产生injector***
      - pluginService
      - injector
      - **client**

![image](https://user-images.githubusercontent.com/8369671/80784909-300f4200-8bb1-11ea-92c9-1a2b28c78fd1.png)
> bootstrap instance的node初始化构造

5. instance.start，启动bootstrap实例
   - node.start
      - injector.getInstance.start，***通过DI的方式将node的具体功能function挂靠在该node的injector上***
   - keepAliveThread.start

![image](https://user-images.githubusercontent.com/8369671/80784914-32719c00-8bb1-11ea-9829-aa2ab6f8f6c6.png)
> injector注入

至此，es集群搭建起来了。搭建过程中所涉及的**modules**和**function**将在之后展开；另外es通过暴露client的方式将其一系列的功能开放出去。

![image](https://user-images.githubusercontent.com/8369671/80784917-343b5f80-8bb1-11ea-95fc-bfb85ae4b06c.png)
> client接口
