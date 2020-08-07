---
title: S4-IndicesModule
tags: es
key: 38
modify_date: 2019-04-30 18:00:00 +08:00
---

这个模块涉及检索相关的query builder的注入绑定，

![image](https://user-images.githubusercontent.com/8369671/80784364-6481fe80-8baf-11ea-9332-da47c79c161a.png)
> IndicesModule constructor 

----
# query builder方法
![image](https://user-images.githubusercontent.com/8369671/80784368-677cef00-8baf-11ea-8bff-ce52f740b41b.png)
> query方法

其对应着[query-DSL](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/query-dsl.html)上的方法。

----
# mapping数据类型
![image](https://user-images.githubusercontent.com/8369671/80784369-69df4900-8baf-11ea-8140-ff29ec677d9e.png)
> mapping 数据类型

其对应着[mapping datatypes](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/mapping-types.html)上的数据类型。

----
# mapping元数据
![image](https://user-images.githubusercontent.com/8369671/80784376-6cda3980-8baf-11ea-80ed-49e7f670b39f.png)
> mapping元数据

其对应着[mapping metadata](https://www.elastic.co/guide/en/elasticsearch/reference/2.4/mapping-fields.html)上的数据类型。

----
# 注入绑定项
![image](https://user-images.githubusercontent.com/8369671/80784377-6f3c9380-8baf-11ea-8558-69358304575e.png)
> IndicesModule所注入的服务

> - bind()中没有to()，这属于无目标绑定，无目标绑定是链接绑定的一种特例，在绑定的过程中不指明目标
> - Eager singletons会尽快启动初始化，保证单例的有效性，Lazy singletons则更适用于edit-compile-run开发周期
