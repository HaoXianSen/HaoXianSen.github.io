---
title: A simple book recommender
tags: architect recommender-systems
key: 104
article_header:
  type: cover
  image: 
    src: https://user-images.githubusercontent.com/8369671/83143016-e2d8ae80-a123-11ea-878d-87b0489b53f6.png
---

# Overview
最近起点合同问题纷纷扰扰, 与此同时在知乎上看到别人推书的post, 其中[推书君作者](https://www.tuishujun.com/)回答了一波, 然后下面有网友提出一些建议, 当然还有其他网友基于ta的见解来推荐. 

在大数据时代, 信息爆炸, 我们获取信息的渠道主要集中于`主动搜索(类似Google)`和`被动推荐(类似AD)`.

想着最近WFH, 看看如果自己来实现一个book/novel的推荐系统, 会是怎样的一个过程. 下面记录一下本次探索. 

# 素材准备
关于推荐, 记得刚刚毕业的时候看过一点[协同过滤](https://blog.csdn.net/qq_35082030/article/details/75646595), 主要是两大类, 一类是基于人, 一类是基于物, 
- 基于人, 甲乙两人, 现在已知甲喜欢物品A和B, 而乙喜欢物品A, 由此可以得出, 乙大概率会喜欢物品B(similar with甲, 可能这里物品样本只有2个, 偶然性会比较大; 如果甲喜欢1000个, 而乙喜欢了其中的999个, 只剩下1个没有被乙喜欢, 那么将这个剩余的1推荐给乙, 乙大概率会喜欢)
- 基于物, 已知物品A和B被绝大部分人喜欢, 而甲目前只是喜欢了物品A(可能没有发现B), 由此可以得出, 乙大概率会喜欢物品B(similar with A, 类似销量排序, 排行榜)

如果在样本足够多的情况, 感觉基于人的recommend会更靠谱, 而对于book/novel这种类型, 书单bookList是一个很好的挖掘方式. 比如说[豆瓣我读过的书单](https://book.douban.com/people/chenfh5/collect), [起点书单](https://book.qidian.com/booklist/). 

当有了这些素材之后, 就可以着手实现算法.

# Architect
先来看看总体结构,
![img](https://user-images.githubusercontent.com/8369671/83434117-71bf3100-a46c-11ea-8c84-4d2f0764dc4e.png)
> a simple book recommender system

根据用户给定的books, 找到这些books所属的booklists, 然后通过算法控制这些booklists里面所有books的weight, 之后取TopK返回.

## Fetcher
网络爬虫, 因为booklists都是存在于网上, 所以需要根据用户query实时爬取web, 然后解析所有booklists, 之后抓取出所有books. 这里根据个人编程喜好, 选择了[jsoup](https://jsoup.org/)这个HTML Parser, 因为其中的selectors能够快速抓取到想要的元素.

### Promo
- 因为booklists里面包括了大量的books(M), 当然也有可能是大量用户创建了booklist而其booklist刚好包含其中(N), 这样一膨胀就是O(M*N)了. 非常容易造成hotspot. 这里采用了随机截断器(maxBookListSize and maxBookListContentSize). 将这种膨胀做了一些限制, 当然不能跟DL-pooling相比, 但是大概是一种方向, 防止膨胀与防止过拟合而采取的剪枝
- 多线程与防爬proxy
- 定期爬取booklists然后入local库, 避免网络消耗, 增加吞吐量, 稳定性, 可控性

## Merger
当所需booklists都抓取过来之后, 接下来就是merge, 这一步类似es的query过程, [coordinator](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html#coordinating-node)将query路由到对应data-node, 然后data-node返回hit到coordinator, 然后coordinator作汇总排序.

这里有一个需要注意的点是merge的case class unboxing, 也叫[ADT](https://chenfh5.github.io/2019/05/07/01_scala-ADT.html). 将各个booklists的book assign weight之后, 然后merge.

这里assign weight是全系统最关键点, 关系着推荐质量, 目前采用了全覆盖的方式, 即booklist中包含了用户所有输入book的话, 那么该booklist中所有books都升权. 反之维持原样. (分配)

分配好之后就是合并, 目前合并是book与book的weight直接相加. (合并)

### Promo
- 权重分配算法
- 权重合并算法

## Ranker
当分配与合并好每本书与原书的相似度weight之后, 直接返回topK.

## Http Server
基于[Grizzly](https://javaee.github.io/grizzly/httpserverframework.html)搭建了http server.

![image](https://user-images.githubusercontent.com/8369671/83148380-795c9e00-a12b-11ea-86ad-9e7a0298a2a5.png)
> http call (70s, too slow)

### Promo
- [LRUCache](https://stackoverflow.com/a/59116615)
    ![image](https://user-images.githubusercontent.com/8369671/83148518-a610b580-a12b-11ea-9a85-340a96963041.png)
    > cache

## Other
至此, jar包已经打好, 后续就是[发布部署](https://blog.csdn.net/Xuesong_2015/article/details/79021659), 暴露接口供用户进行调用.
![image](https://user-images.githubusercontent.com/8369671/83148026-03f0cd80-a12b-11ea-96aa-c322799e1bbc.png)

### Promo
- 开发前端展示与交互, html, css, js
- load balance

# 后记
- 网络世界很丰饶, 当然这也埋没了一定量的好作品, 自己一个人的力量是非常有限的, 即便Google的rank已经将最高相似度返回了, 但这个相识度更类似与tf/idf和出入度, 主要集中在keyword的命中和网页的权重
- 通过crawler, 个人可以将彼此的大量网络数据爬取出来, 加之利用即可定制化自己的查找策略和侧重, 比如书单, 影单, 歌单, stockList(过了:bowtie:, 投资有风险) 


# Reference
0. [jsoup: Java HTML Parser](https://jsoup.org/)
0. [Scraping Websites using Scala and Jsoup](https://www.lihaoyi.com/post/ScrapingWebsitesusingScalaandJsoup.html)
0. [wtog-web-crawler](https://github.com/wtog/web-crawler)
0. [source code](https://github.com/chenfh5/a-simple-book-recommender)
