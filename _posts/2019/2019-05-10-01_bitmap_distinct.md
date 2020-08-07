---
title: Bitmap压缩算法
tags: architect
key: 69
modify_date:
---

# Overview
位图bitmap/bitset在大数据领域用途比较广泛(uv去重，布隆过滤等)，但是原生的比较耗费空间，下面介绍其压缩方案，

## 原生位图
在基数明确的情况下，即[0, N]，那么就会建立`val arr = Array.fill(N+1)(Boolean)` // fill应该是Bit，这里有一个int的[实现](https://blog.csdn.net/Ymy2011/article/details/47444407)，借用了`&=`和`|=`。 

所以若要判断N是否存在，那么就看arr(N-1)是否为1(默认0是不存在，1是存在，这里只能判断有无，不能判断有多少)。

缺点：`arr的内存占用只跟N有关联`，所以如果是稠密的话，还算有价值；极端情况是基数只有1个(即一个很大的N)，那么arr(i)=1只在N-1处，其他的arr(i)都是0，导致很多空余，浪费内存。

e.g., N=Int.max=4Byte=2^32, size=[0,2^32-1]->2^32 * 1Bit(一共2^32个arr slot，每个slot是1Bit) -> 2^32/8/1024/1024=512MB，即一个长度是2^32的arr[Bit]数组的开辟需要512MB内存。

![image](https://user-images.githubusercontent.com/8369671/58455888-5c2a7380-8155-11e9-8aec-ffe6eecc1ce9.png)
> [10, 17, 28]这三个数字存在。image from Internet

## 压缩位图
### RLE(run length encoding，[游程编码](https://github.com/chenfh5/sword/blob/master/src/main/scala/io.github.chenfh5/other/tubi/StringCompression.scala))
![image](https://user-images.githubusercontent.com/8369671/58455891-5f256400-8155-11e9-8463-50f2d307a88a.png)
> image from lpthread

由一连串的(char, repeat_count)组成，注意[写文件](https://github.com/chenfh5/sword/blob/master/src/main/scala/io.github.chenfh5/other/tubi/FileSave.scala)时是选择`字符流`还是`字节流`，

- 如果(char + repeat cnt)的长度比较小，推荐字符流(但是每次都要注意分隔符)
- 如果长度较大，推荐使用字节流，因为字节流是固定长度的int/long，且不需要额外检测分隔符
- 例如，`0000000000000000000011111111110000000000` -> `20(0),10(1),10(0)`

### [WAH](https://www.codeproject.com/Articles/214997/Word-Aligned-Hybrid-WAH-Compression-for-BitArrays)\(Word-Aligned Hybrid Bitmap)
![image](https://user-images.githubusercontent.com/8369671/58455898-62205480-8155-11e9-8365-204353ddb07b.png)
> image from dspguide

将原生bit串`每31Bit`分为一个chunk，然后根据chunk里面的内容添加额外的1Bit组成一个32Bit的new chunk
这个32Bit的chunk，
- 第一bit(0)表示该chunk是否有压缩(0是有压缩，1是无压缩。当然可以自定义，有些paper是1代表有压缩)
- 第二bit(1)表示，若第一bit是有压缩的，那么第二bit就代表char(0或1)；若无压缩，表示raw(0)
- 其余位[2,31]表示，若第一bit是有压缩的，那么[2,31]表示具体的长度(repeated cnt)；若无压缩，表示raw[1,30]

![image](https://user-images.githubusercontent.com/8369671/58455906-65b3db80-8155-11e9-9c88-e602aba13962.png)
> image from liaojiayi

有点跟Varint([变长编码](https://www.cnblogs.com/jacksu-tencent/p/3389843.html))类似，都用接下来这块是不是属于前面部分来隔开。不同是一个用于Bit，一个用于Int。

### [RBM](http://roaringbitmap.org/about/)\(Roaring bitmap)
对于存放Int值的bitmap，RBM是将32位的整数分割成最多2的16次方个整数的容器(container)，来共享相同的高16位。使用`专门的数据结构`来保存它们的低16位。 即 `List[highDataType, List[lowDataType]]`，其中highDataType就是container，而不同container所用到的lowDataType又是不一样的，下面分析，

- [ArrayContainer](https://github.com/RoaringBitmap/RoaringBitmap/blob/RoaringBitmap-0.8.2/roaringbitmap/src/main/java/org/roaringbitmap/ArrayContainer.java#L127) 
    - 适用条件：当某个highDataType其`lowDataType size` <= **4096**时
    - 初始化：`lowDataType = mutable.SortedSet[Short]()`，动态增加
    - 例如，要求保存`0xFFFF0000`和`0xFFFF0001`，原生bitmap要`0xFFFF0001=4294901761Bit -> 512MB`，而RBM只需要`1个highDataType+2个lowDataType=16/8+16/8*2=6Byte`，即512MB vs 6Byte
    
- [BitmapContainer](https://github.com/RoaringBitmap/RoaringBitmap/blob/RoaringBitmap-0.8.2/roaringbitmap/src/main/java/org/roaringbitmap/BitmapContainer.java#L150)
    - 适用条件：当某个highDataType其`lowDataType size` > 4096时
    - 初始化：`lowDataType = Array.fill(65536)(Bit)`，原生位图，2^16=65536Bit=65535/8=8192Byte=8Byte*1024=8KB(即这里每个原生位图占用8KB)
    - 为什么threshold是4096，因为ArrayContainer每一个lowDataType元素是16Bit=2Byte，而BitmapContainer每一个lowDataType元素是8KB，即8KB/2Byte=4096个
    
- [RunContainer](https://github.com/RoaringBitmap/RoaringBitmap/blob/RoaringBitmap-0.8.2/roaringbitmap/src/main/java/org/roaringbitmap/RunContainer.java#L307)
    - 适用条件：连续的数据，1,2,3,..,100，共100个，所以表示为[1,99]，这里与RLE(1,99)不同，前者是`from 1 to 100`, 后者有`连续99个1`
    - 例如：对于[11, 12, 13, 14, 15, 21, 22]，会被记录为 11, 4, 21, 1


## Illustrate
![image](https://user-images.githubusercontent.com/8369671/58455907-69476280-8155-11e9-8455-20df4b0e30cd.png)
> image from mdjs

插入示例的流程，
- 821697800
    - `821697800`对应的16进制数为`0x30FA1D08`，其中高16位为0x30FA，低16位为0x1D08
    - 先用`binarySearch`从`highDataType list`中找到数值为`0x30FA`的容器(如果该容器不存在，则新建一个ArrayContainer)，发现该容器是一个BitmapContainer
    - 之后查看该highDataType对应的lowDataType，解析`0x1D08`的位置是7432，因此O(1)定位并将该位置的bit置为1
- 191037
    - `191037`对应的16进制数为`0x0002EA3D`
    - 先用`binarySearch`从`highDataType list`中找到数值为`0x0002`的容器，发现该容器是一个ArrayContainer
    - 之后查看该highDataType对应的lowDataType，解析`0xEA3D`的位置是59965，依旧适用`binarySearch`找位置59965是否存在，不存在则插入，存在则正常退出

## Summary
![image](https://user-images.githubusercontent.com/8369671/58455912-6cdae980-8155-11e9-86a2-1ca8e6ea6dd8.png)
> image from Kylin

|    Container    | 空间利用率 | 查询效率 |
| ---------- | --- |--- |
| ArrayContainer | 无压缩、低 | 使用二分查找，中 |
| BitmapContainer | 无压缩、低 | 直接利用索引命中，高 |
| RunContainer | 有压缩、高 | 顺序查找，低 |

即，
 - 整数基数较小时，使用array更省空间
 - 整数基数较大时，使用bitmap更省空间
 - 整数多为连续时，适用run更省空间

# Reference
- [大数据分析常用去重算法分析『Bitmap 篇』](https://mp.weixin.qq.com/s/EZw17fEbd76xdSHEwxqCKg)
- [不深入而浅出Roaring Bitmaps的基本原理](https://cloud.tencent.com/developer/article/1136054)
- [RoaringBitmap更好的位图压缩算法分析](https://sxpujs.iteye.com/blog/2240875)
- [Bitmap - 性能和原理研究](http://www.liaojiayi.com/bitmap/)
- [Roaring Bitmaps : fast data structure for inverted indexes](https://medium.com/@amit.desai03/roaring-bitmaps-fast-data-structure-for-inverted-indexes-5490fa4d1b27)
- [RBM github](https://github.com/RoaringBitmap/RoaringBitmap)
- [WAH github](https://github.com/lemire/javaewah)
