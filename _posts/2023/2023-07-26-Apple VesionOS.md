---
title: Apple VesionOS 初探
tags: [iOS]
key: 159
published: false
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

### 介绍

Apple VesionOS 是Apple 新出的一个操作系统，和IOS、iPadOS、MacOS、tvOS、watchOS 一样都属于一种操作系统。现在应用于Apple新出的Apple Vesion Pro机器的操作系统。苹果称之为：首款空间型计算机。Apple Vesion Pro 是苹果新发布的一款产品，带上Apple Version Pro可以让我们在一张无限的画布上与Apps、games进行交互。其实说白了有点像AR。

[详细介绍&视频](https://www.apple.com/newsroom/2023/06/introducing-apple-vision-pro/)

https://www.youtube.com/watch?v=TX9qSaGXFyg

### 开发

新创建的VesionOS app 必须要SwiftUI进行开发。





### 适配 (原有iOS | iPad)

按照官网文档来说，所有原来的iOS 或者iPadApp都可以支持适配。如果只是iOS的app，VesionOS 会按照iPhone显示，如果支持PadOS，则VesionOS会按照iPad去显示。

#### 第一步：

下载含有VesionOS的Xcode， Xcode 15 beta 5， 友情建议：下载完之后，第一次启动会让你下载各个系统模拟器， 不要在Xcode里下载，龟速下载，不知道要等到猴年马月了。直接去Apple 下载网站https://developer.apple.com/download/all/?q=Simu 搜索Simulator 下载最新iOS17beta和vesionOS beta2, 然后https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes 命令行去安装即可。

#### 第二步：

设置Xcode 工程支持设备里含有Apple Vesion，如下所示：

![image-20230727155816105](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230727155818image-20230727155816105.png)

温馨提示： 装完之后打开Xcode 如果没有出现vesion模拟器，把Destinations都去掉，重新加一下，然后重启xcode。

#### 第三步： 

选择Apple Vesion Pro 模拟器运行，试试..., 如果项目比较简单，足够幸运可能就运行起来了。而我们的项目各种编译报错。

当然也可以是我们工程本身的问题，比如自研直播推拉流Soda库，本身导出的framework就没有包含x86架构。下面做模拟器问题记录：

1. Soda framework 只支持arm64， 不包含x86_64的架构，导致模拟器无法运行

2. JPKIJKFramework_iOS 只支持arm64， 不包含86_64的架构，导致模拟器无法运行

3. JPKAudioRecord_iOS/JPKAudioRecord_iOS/framework/libskegn.a 不包含x86_64的架构，导致模拟器无法运行

4. 最小支持的版本过低，我们最小支持的版本为iOS 11, 是否可以单独配置版本？

   1. 改成12即可运行

5. 点击售前详情页，发生crash 

   **UIGraphicsBeginImageContext() failed to allocate CGBitampContext: size={806, 0}, scale=2.000000, bitmapInfo=0x2002. Use UIGraphicsImageRenderer to avoid this assert.**

   看样子是YYText发生了crash.

6. 部分页面UI出现navigationBar阻挡问题

7. 自动转屏失效，需要手动点击

   ![image-20230727171011513](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230727171011image-20230727171011513.png)

8. 默认为横屏，需要手动调整到竖屏

9. 首页会出现布局错乱的情况。

   <img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230727182248image-20230727182248055.png" alt="image-20230727182248055" style="zoom:0%;" />

10. 无法拨打电话

### 总结

总体来说现有App在

