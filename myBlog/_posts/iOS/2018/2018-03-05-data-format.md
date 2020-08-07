---
title: 大数据文件格式与压缩算法小结
tags: scala
key: 26
modify_date: 2019-04-30 18:00:00 +08:00
---

小结一下Hadoop/Hive的**文件格式**和**压缩算法**，

----
# Overview
文件格式和压缩算法在大数据系统里面是一个高关注的优化点，双方常常是配合着一起调优使用。

----
# 1. 文件格式
A file format is the way in which information is **stored** or **encoded** in a computer file. In Hive it refers to how records are stored inside the file. As we are dealing with structured data, each record has to be its own structure. How records are encoded in a file defines a file format.

file format | characteristics | hive storage option
--- | --- | ---
TextFile | plain text, default format | `STORED AS TEXTFILE`
SequenceFile | row-based, binary key-value, splittable | `STORED AS SEQUENCEFILE`
Avro | row-based, binary or JSON, splittable | `STORED AS AVRO`
RCFile | columnar, RLE | `STORED AS RCFILE`
ORCFile | Optimized RC, Flatten | `STORED AS ORC`
Parquet | column-oriented binary file, Nested | `STORED AS PARQUET`

----
# 2. 压缩算法
To **balance** the processing capacity required to compress and uncompress the data, the `CPU` required to processing compress or uncompress data, the `disk IO` required to read and write the data, and the `network bandwidth` required to send the data across the network.

Compression is not recommended if your data is **already** compressed (such as images in JPEG format). In fact, the resulting file can actually be larger than the original.

compression format | characteristics | splittable
--- | --- | ---
DEFLATE | DefaultCodec | no
GZip | uses more CPU resources than Snappy or LZO; provides a higher compression ratio; A good choice for cold data | no
BZip2 | more compression than GZip | yes
LZO | better choice for hot data | yes if indexed
LZ4 | significantly faster than LZO | no
Snappy | performs better than LZO, better choice for hot data | [yes?](http://boristyukin.com/is-snappy-compressed-parquet-file-splittable/)

----
# Others
- 游程编码，Run Length Encoding，[RLE](https://zh.wikipedia.org/wiki/%E6%B8%B8%E7%A8%8B%E7%BC%96%E7%A0%81)，常用于[列式存储](http://sqtds.github.io/2014/05/11/2014/%E5%88%97%E5%BC%8F%E5%AD%98%E5%82%A8%E6%9C%BA%E5%88%B6/)，4A3B2C1D4E
- 纠删码，Erasure Coding，[EC](https://www.iteblog.com/archives/1684.html)，hadoop 3.0.0的replica，但由于其带宽和cpu高消耗，常用于冷数据，ｋ块原始+ｍ块校验
- Doc Values，最大公约数压缩，偏移量进行编码，按照docid排序的，利用内存映射文件[mmap](http://blog.csdn.net/napolunyishi/article/details/18214929)，预读取机制
- skipList
- bitSet [1,3,4,7,10]->[1,0,1,1,0,0,1,0,0,1]
- Roaring Bitmap (bitset improvement)，类似RLE，4A3B
- Frame Of Reference编码
- 数值差分[73,300,302,332,343,372]->[73,227,2,30,11,29]
- term index，tire树
- term dictionary
- [finite state transducers](http://www.cnblogs.com/LBSer/p/4119841.html)
![image](https://user-images.githubusercontent.com/8369671/80785723-cf353900-8bb3-11ea-8f01-16ce8ed320a3.png)
    > FST
- 维度字段上移到父文档里，而不用在每个子文档里重复存储，从而减少索引的尺寸
- segment一个int就可以存储
- Hyperloglog
- 聚合之后再做聚合，[Pipeline Aggregation](https://segmentfault.com/a/1190000004463722)
----
# Reference
- [Format Wars](https://www.svds.com/project/format-wars/)
- [Data Storage and Modelling in Hadoop](https://techmagie.wordpress.com/2016/07/15/data-storage-and-modelling-in-hadoop/)
- [Apache Hive Different File Formats](http://dwgeek.com/hive-different-file-formats-text-sequence-rc-avro-orc-parquet-file.html/)
- [Hive 列存储简介](http://icejoywoo.github.io/2016/03/29/hive-ocr-and-parquet.html)
- [hadoop 压缩 gzip biz2 lzo snappy](http://aperise.iteye.com/blog/2397398)
- [Choosing a Data Compression Format](https://www.cloudera.com/documentation/enterprise/5-3-x/topics/admin_data_compression_performance.html)
- [Data Compression in Hadoop](http://comphadoop.weebly.com/)
- [Hadoop: The Definitive Guide](https://www.safaribooksonline.com/library/view/hadoop-the-definitive/9781449328917/ch04.html)
- [An Overview of File and Serialization Formats in Hadoop](https://databaseline.bitbucket.io/an-overview-of-file-and-serialization-formats-in-hadoop/)
- [深入理解 ElasticSearch Doc Values](http://www.majiang.life/blog/deep-dive-on-elasticsearch-doc-values/)
