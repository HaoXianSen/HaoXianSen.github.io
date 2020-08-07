---
title: S7-MonitorModule
tags: es
key: 42
modify_date: 2019-04-30 18:00:00 +08:00
---

这个模块主要是es集群在系统、进程、JVM级别的性能监控。

----
# Overview
监控频率分为固定一次性fixPoint和refreshInterval、scheduleWithFixedDelay周期性。

![image](https://user-images.githubusercontent.com/8369671/80782023-1c5ede00-8ba7-11ea-88f6-1038f67e7b11.png)
> MonitorModule注入的监控服务

上面所有注入服务可以分为4类，进程相关、系统相关、文件存储相关、JVM相关。

----
# 进程相关
![image](https://user-images.githubusercontent.com/8369671/80782030-1f59ce80-8ba7-11ea-88a8-4f43dd2682a3.png)
> 进程相关

----
# 系统相关
![image](https://user-images.githubusercontent.com/8369671/80782033-21bc2880-8ba7-11ea-83de-0c200db62288.png)
> 系统相关

----
# 文件系统相关
![image](https://user-images.githubusercontent.com/8369671/80782035-241e8280-8ba7-11ea-9753-9a28d15ccd73.png)
> 文件系统相关

----
# JVM相关
jvm监控里面分了2种，一种JvmInfo详情，一种JvmStats统计。

### JvmInfo
![image](https://user-images.githubusercontent.com/8369671/80782037-2680dc80-8ba7-11ea-996e-17c2b535ac65.png)
> JvmInfo fields

### JvmStats
![image](https://user-images.githubusercontent.com/8369671/80782041-28e33680-8ba7-11ea-898b-b0566e7eab00.png)
> JvmStats

如上图JvmStats含有多个重要的fields，如Mem, Threads, GC等

![image](https://user-images.githubusercontent.com/8369671/80782047-2da7ea80-8ba7-11ea-8f03-931605937fb2.png)
> Mem

![image](https://user-images.githubusercontent.com/8369671/80782051-30a2db00-8ba7-11ea-8a92-6879065e758c.png)
> Threads

![image](https://user-images.githubusercontent.com/8369671/80782053-339dcb80-8ba7-11ea-81ce-1ffaecfdf3b7.png)
> GC

![image](https://user-images.githubusercontent.com/8369671/80782219-c8082e00-8ba7-11ea-8098-eb6597614f7a.png)
> bufferPool

![image](https://user-images.githubusercontent.com/8369671/80782062-38627f80-8ba7-11ea-8001-e167c4149a9a.png)
> jvm所加载的类统计

# Reference
- [Linux中关于swap、虚拟内存和page的区别](https://blog.csdn.net/xifeijian/article/details/8209750)
- [物理内存和虚拟内存](http://uule.iteye.com/blog/2149610)
