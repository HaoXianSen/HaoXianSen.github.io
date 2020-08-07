---
title: T0-ES 6.1.4 Gradle build & import to IDEA
tags: es
key: 43
modify_date: 2019-04-30 18:00:00 +08:00
---

# Overview
在es 5.X及之后的版本中，包管理框架从Maven迁移到了Gradle。
- 在Maven导入IDEA的过程中，不需要一些命令行，因为idea的reimport按钮会自动download jar包以及建立索引。
- 而在Gradle中，这个转换过程与mvn有所不同，需要在导入（import project）之前进行一些gradle命令行操作，如下，

1. groovy install
2. gradle install
   - 配置系统环境变量GRADLE_USER_HOME，以便自定义gradle下载的jar包存放位置
3. cd yourDir/es614
4. git clone --depth 1 --branch v6.1.4 https://github.com/elastic/elasticsearch.git
5. cd elasticsearch
6. gradle clean --parallel
7. gradle idea -Dhttp.proxyHost=proxy.your.com -Dhttp.proxyPort=8080 -Dhttps.proxyHost=proxy.your.com -Dhttps.proxyPort=8080 --parallel（不要带http://）
8. gradle build -x test --parallel
9. IDEA import `build.gradle`

![image](https://user-images.githubusercontent.com/8369671/80781826-66938f80-8ba6-11ea-8e20-748836630197.png)
> gradle idea begin

![image](https://user-images.githubusercontent.com/8369671/80781829-6a271680-8ba6-11ea-8092-44a2fdac229f.png)
> gradle idea end

![image](https://user-images.githubusercontent.com/8369671/80781832-6c897080-8ba6-11ea-97ae-eb23c44b35af.png)
> gradle build begin

gradle build过程中一直加载、编译modules和plugins。

![image](https://user-images.githubusercontent.com/8369671/80781834-6f846100-8ba6-11ea-9ac4-f12c7a361777.png)
> gradle build mid

上图，在命令行里指定了-x test来跳过测试了，不知道为什么还运行这个main()，这里需要再观察。

![image](https://user-images.githubusercontent.com/8369671/80781837-71e6bb00-8ba6-11ea-8b7b-6121089fc7b9.png)
> gradle build end


上图，虽然最后build failed了，但是将被gradle编译过的es导入到idea之后，还是能够正常显示类关系，即被源码关系链索引好了。

![image](https://user-images.githubusercontent.com/8369671/80781839-757a4200-8ba6-11ea-8061-d475318cb968.png)
> idea import project

![image](https://user-images.githubusercontent.com/8369671/80781854-862ab800-8ba6-11ea-8e95-128d29d52fc4.png)
> import build.gradle

# Result
![image](https://user-images.githubusercontent.com/8369671/80781856-888d1200-8ba6-11ea-9762-c8501c1c7023.png)
> 索引后的源码目录

![image](https://user-images.githubusercontent.com/8369671/80781862-8b880280-8ba6-11ea-9144-737ad8663b8d.png)
> external libraries第三方库

# 遗留问题
1. gradle build -x test的`失效`
2. gradle build的`BUILD FAILED`
3. 为什么没有选择最新的v6.2.4。是由于minimumCompilerVersion的限制。（服务器运行可以是jdk8，但是编译要更新版本的jdk。6.2.x是jdk9；6.3.x是jdk10）

![image](https://user-images.githubusercontent.com/8369671/80781871-92167a00-8ba6-11ea-8a62-170213dc6f46.png)
> es tag till 20180508

![image](https://user-images.githubusercontent.com/8369671/80781877-96db2e00-8ba6-11ea-9002-2ca62c88419f.png)
> BuildPlugin.groovy

# Reference
- [Elasticsearch5.5.0源码-编译、导入IDEA、启动](https://www.jianshu.com/p/a22492d40fd1)
- [ElasticStack系列之十六 & ElasticSearch5.x index/create 和 update 源码分析](http://www.cnblogs.com/liang1101/p/7661810.html)
- [gradle命令参数](https://blog.csdn.net/ak471230/article/details/37651381)
- [gradle 命令及技巧 (gradle-tips)](https://juejin.im/entry/58d4c2475c497d0057eaa924)
