---
title: gitlab CI 实现自动创建MR方案
tags: gitlab
published: true
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

## gitlab CI 实现自动创建MR方案

### 一、前情介绍

如果是基于git仓库管理工具开发朋友，应该都知道基本上我们Code review 流程都是通过 create merge request进行的，gitlab MR 很开方便的提供了可视化的版本对比、以及source 分支新提交的代码自动对比、评论、@代码开发者等等功能。所以使用MR 作为Code Review是一种不错的选择。

但是基于现在组件化的开发，我们项目不再是遥远的单仓库工程，而是会拆分成大大小小的多个子仓库，壳工程则是组合这些子仓库，拼成一个完整的项目。那么每当我们有新需求迭代或者代码改动时候，我们可能会同时更改若干个库，且不说库依赖问题，即使需求遍布在多个业务库中也需要更改多个业务库。那么带来的问题也可想而知，在code review流程中，我们需要手动提MR为这些改动的库，打个比方：假如一个库提MR需要3分钟，那么10个库就需要半小时。其实这半个小时都是在做重复的事情，很明显我们的时间被浪费掉了。

所以，如果能有一套自动将子库、壳工程库建立MR，且制定相应的reviewer，能将我们时间缩短为1分钟可能都不到，极大的提高了效率。

### 二、分析iOS 项目

##### iOS 项目结构

```xml
.
├── AICourse-iOS
│   ├── AICourse-iOS.entitlements
│   ├── AppDelegate
│   ├── Main
│   └── Resources
├── AICourse-iOS.xcodeproj
│   ├── project.pbxproj
│   ├── project.xcworkspace
│   ├── xcshareddata
│   └── xcuserdata
├── AICourse-iOS.xcworkspace
│   ├── contents.xcworkspacedata
│   ├── xcshareddata
│   └── xcuserdata
├── AICourse-iOSTests
│   ├── AICourse_iOSTests.m
│   └── Info.plist
├── AICourse-iOSUITests
│   ├── AICourse_iOSUITests.m
│   └── Info.plist
├── Podfile
├── Podfile.lock
├── Pods
│   ├── AACRecorder
│   ├── AFNetworking
│   ├── Alamofire
│   ├── AudioStreamer
│   ├── DXPopover
│   ├── FCFileManager
│   ├── FLAnimatedImage
│   ├── GZFoundationKit_iOS
│   ├── GZUIKit_iOS
│   ├── JPBase
│   ├── JPCloud
│   ├── JPCommonFunction_iOS
│   ├── JPDownload
│   ├── JPKAudioRecord_iOS
│   ├── JPKCommonInfo
│   ├── JPKIJKFramework_iOS
└── README.md
```

以上就是一个iOS工程的目录组成，我先一部分一部分的来介绍：

* 第一层中`AICourse-iOS`目录，这里是存放我们壳工程源码以及配置文件、图片等等；
* 第一层中`AICourse-iOS.xcodeproj`文件，这是可用Xcode打开的配置文件，用Xcode打开之后就是我们的工程；
* 第一层`AICourse-iOSTests` 目录，这里存放的是项目单元测试的源码以及配置文件、图片等等；
* 第一层`AICourse-iOSUITests`目录，这里存放的是项目UI单元测试的源码以及配置文件、图片等等；
* 第一层`AICourse-iOS.xcworkspace`文件，这是Cocoapods为我们生成的一个Xcode项目组合文件（为什么叫他为组合文件呢，其实这个文件的作用就是能够将多个iOS 项目组合到一起用Xcode打开，它的创建、原理、使用以及在pods的意义，我会在以后的文章中Cocoapods的原理中介绍（敬请期待...））；
* 第一层`Podfile`文件，这是Cocoapods的配置文件，他是用来配置工程的三方依赖管理的，其实它是个Ruby文件哦；
* 第一层`Podfile.lock`文件，这是Cocoapods为我们生成的三方依赖版本管理文件。
* 第一层`Pods`目录，其实这是一个Cocoapods创建的iOS 项目，里边包含了Cocoapods 下载下来的三方库以及Xcode项目文件，刚才所说的`AICourse-iOS.xcworkspace`文件其实就是把原工程和这个工程做了组合（所以我们在打开项目后，才能看到原工程以及三方依赖库等）。

我们来简单的介绍一下Cocoapods：

Cocoapods是iOS 项目侵入式管理三方库工具，对应的还有Carthage不侵入式管理三方库工具，当然Carthage是用来swift的包管理工具，还有Apple自己的SPM（swift package manager）但是SPM暂时不支持客户端工程。在这就展开说了。

Cocoapods 是使用`优雅`的语言Ruby 进行开发的一款管理工具，其重要参考Gem开发原理进行的。

Cocoapods 通过`Podfile`配置文件（ruby文件）利用`SDL`（语法树）直接获取配置以及配合`Podfile.lock`的版本控制，进行分析依赖、下载三方库等等操作。

更多Cocoapods的原理（它是如何管理iOS 项目的三方库的）我会在以后的文章中单独剖析（敬请期待...）

### 三、方案

##### 整体方案

###### 架构图

<img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20240411183228image-20240411183227838.png" alt="image-20240411183227838" style="zoom:67%;" />

###### 流程图

<img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20240411202918image-20240411202918571.png" alt="image-20240411202918571" style="zoom:60%;" />

1. 本地壳工程创建mr/bin 脚本文件，包括三个脚本：1. analyze_podfile 2. create_mr 3.notification；

   创建私有库MR Target列表plist；

   创建gitlab-ci.yml gitlab CI/CD配置文件；

   配置gitlab-ci.yml gitlab CI/CD， 包括三个Stage， 1、 analyze_podfile 2、create_mr 3、notification：

   ​	 analyze_podfile job 对应执行analyze_podfile 脚本，并生成需要建立mr列表产物；

   ​	  create_mr job 采用上一个阶段产物执行create_mr 脚本，利用gitlab Api 生成mr，并生成成功创建mr列表；

   ​	 notification job 则执行notification进行popo的通知任务。

2. 当开发者在开发分支feature/a 合并代码到App_Review 分支后，触发gitlab CI，执行job

3. 首先执行第一阶段脚本analyze_podfile job，生成需要建立mr列表产物

4. 第二执行create_mr job 采用上一个阶段产物执行create mr 脚本，利用gitlab Api 生成mr，并生成成功创建mr列表

5. notification job 则进行popo的通知任务

6. 也可以通过pipelines 产物进行下载

##### 脚本语言选型

`Ruby`: 为什么选择Ruby呢？

1. 本身Cocoapods 使用Ruby语言编写，Podfile 本身是Ruby 文件，可直接转化为Ruby代码获取需要资源，对于解析Podfile文件可以说是非常简单。

2. 通过Cocoapods的原理探究，对于Ruby很感兴趣。

### 四、实现

### 五、试运行

### 六、总结