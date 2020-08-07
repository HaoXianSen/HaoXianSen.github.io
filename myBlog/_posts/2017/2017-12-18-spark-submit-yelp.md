---
title: "Yelp: A stream processing pipeline for an online advertising platform"
tags: spark
key: 7
modify_date: 2019-04-30 18:00:00 +08:00
---

![image](https://user-images.githubusercontent.com/8369671/80793301-59d46300-8bc9-11ea-9205-236fd1321cb0.png)

文章里面提到了2个问题，
1. no state tracking
2. do not support complex customized business logic

![image](https://user-images.githubusercontent.com/8369671/80793312-5e008080-8bc9-11ea-96a5-548c562cd061.png)
> 2个待解决问题

它们通过`updateStateBykey(update_func)/mapWithState(update_func)`来自定义该update过程。即，
1. Attach expire date/time when events are first seen & state is initialized
2. drop the state if it expires
3. apply business logic to new events/current state

![image](https://user-images.githubusercontent.com/8369671/80793320-622c9e00-8bc9-11ea-9da9-c50107b99a9d.png)
> Yelp的解决方案

![image](https://user-images.githubusercontent.com/8369671/80793321-648ef800-8bc9-11ea-831f-1319f0e7dc62.png)
> 伪代码

我借用了该ppt的思路，试着回答了stackoverflow上面的一个[类似提问](https://stackoverflow.com/questions/44976783/apache-spark-streaming-timeout-long-running-batch/47851670#47851670)，但是我自己没有亲身实现出来，只是觉得可能这是一个思路。在每个state initialization的时候初始化一些状态（timeout，control flag等），然后判断这个stages的去留。
