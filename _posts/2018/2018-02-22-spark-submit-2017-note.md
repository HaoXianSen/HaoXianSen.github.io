---
title: Spark Submit 2017 SF Note
tags: spark
key: 21
modify_date: 2019-04-30 18:00:00 +08:00
---

写一下看了部分[spark submit 2017 ppt](https://github.com/397090770/spark-summit-2017-SanFrancisco)后的个人理解，

- Apache-Kylin--Speed-Up-Cubing-with-Apache-Spark-with-Luke-Han-and-Shaofeng-Shi-iteblog，kylin利用spark来加速之前MR的cube build过程
- 很多关于IoT的spark应用。ETL，real-time-analysis
- A-Deep-Dive-into-Spark-SQL's-Catalyst-Optimizer-with-Yin-Huai-iteblog，spark SQL优化项
- Apache-Spark-and-Apache-Ignite--Where-Fast-Data-Meets-the-IoT-with-Denis-Magda-iteblog，[Ignite](https://www.zhihu.com/question/33982387)大数据分布式内存sql分析系统
- Best Practices for Using Alluxio with Spark, Alluxio缓存一份file，避免多个spark app的重复读并占用重复内存
- Cost-Based Optimizer in Apache Spark 2.2，spark [CBO](https://wiki.scn.sap.com/wiki/display/MaxDB/Cost+Based+Optimizer)的最早提出？
- demystifying-dataframe-and-dataset-with-kazuaki-ishizaki. spark 2.2的dataset加速方案：数据转换（装、解箱）、序列化、字节码
