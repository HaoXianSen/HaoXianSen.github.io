---
title: 基于elasticsearch suggester的中文检索建议实现
tags: es
key: 14
modify_date: 2019-04-30 18:00:00 +08:00
---

写一下个人spark实现的es completion suggester，

----
# Overview
检索建议suggestion（补全completion和纠正correction）是提升用户搜索体验的一个重要功能，通过协助用户输入更精准的关键词，提高后续全文检索阶段文档匹配度。

![image](https://user-images.githubusercontent.com/8369671/80787505-4caf7800-8bb9-11ea-8188-e91347ac7f08.png)
> 检索关键词补全

![image](https://user-images.githubusercontent.com/8369671/80787510-4f11d200-8bb9-11ea-8391-a2ec74d77a65.png)
> 检索关键词纠正

----
# 补全功能
在电商平台（淘宝、京东、Amazon等）上，检索建议补全可以帮助用户更准确、更迅速地定位到潜在购买商品。例如，用户输入`空气`，电商平台根据用户的历史行为(login user)或者平台总体推荐结果(non-login user)，给出有关`空气`的一系列检索关键词（如空气质量、空气刘海、空气清新剂等），该检索关键词可以是简体、繁体、全拼、首字母拼音等形式。下面使用es的[Completion Suggester](https://www.elastic.co/guide/en/elasticsearch/reference/6.1/search-suggesters-completion.html)来实现补全功能。

![image](https://user-images.githubusercontent.com/8369671/80787512-51742c00-8bb9-11ea-8eb4-ab0fd6634e6b.png)
> 汉字补全

![image](https://user-images.githubusercontent.com/8369671/80787515-53d68600-8bb9-11ea-9e79-c1d1c2be4f68.png)
> 拼音补全

### 整体架构
架构模块组织如下，

![image](https://user-images.githubusercontent.com/8369671/80787520-55a04980-8bb9-11ea-9e16-3cbbabc4560a.png)
> 检索建议补全架构

由三个模块，一个proxy，一条es总线组成。[code](https://github.com/chenfh5/test-spark-connect-es)将suggestion和normal隔离成2个index，不在normal mapping里加入suggestion，方便更好地管理和升级suggestion；也减轻normal es coordinator的压力。

### 分词
##### suggest分词
对于每一个需要index的商品名称，使用[ik](https://github.com/medcl/elasticsearch-analysis-ik)挖出其简体token；使用[pinyin](https://github.com/medcl/elasticsearch-analysis-pinyin)挖出其ik后的token的全拼连接和首字母连接。然后插入到suggestion index。
```
  case class SuggestJson(
    item_id: Long,
    item_name_suggester: Seq[String]
  )

//SuggestJson(93,List(han, dou, yi, she, 2017, ban, 女装, nvzhuang, nz, 夏装, xiazhuang, xz, 新款, xinkuan, xk, 宽松, kuansong, ks, xian, shou, 短袖, duanxiu, dx, 两件套, liangjiantao, ljt, 连衣裙, lianyiqun, lyq, oy6198, lu, 浅蓝色, qianlanse, qls))，（这里需要将`韩都衣舍`这个token加入ik词表，防止被切开）
```

##### normal分词
正常情况下分词的ik配置与suggestion配置要求一致，然后将其插入到normal index。
```
  case class NormalJson(
    item_id: Long,
    item_name: String,
    item_price: Double,
    shop_name: String
  )

//NormalJson(93,韩都衣舍2017韩版女装夏装新款宽松显瘦短袖两件套连衣裙OY6198陆 浅蓝色 M,116.0,韩都衣舍旗舰店)
```

### 检索历程
下面描述一下用户检索历程，
1. 用户在前端输入一个query
2. 该query经过proxy请求`search_suggestion_with_query`模块找到该query所对应的建议词列表（这里建议词最好是排序的，即返回与query相关性最高的建议词），并返回至前端，供用户选择
3. 用户在sorted suggestion query list里面点选其中一个作为最终检索关键词（final query）
4. final query经过proxy请求`search_doc_with_suggestion`模块，查询normal index里面的内容

----
# 纠正功能
还没有实现，但是可以使用[Phrase Suggester](https://www.elastic.co/guide/en/elasticsearch/reference/6.1/search-suggesters-phrase.html)和[Term suggester](https://www.elastic.co/guide/en/elasticsearch/reference/6.1/search-suggesters-term.html)来实现。

- Term Suggester，基于编辑距离，对analyze过的单个term去提供建议，并不会考虑多个term/词组之间的关系。`quert -> query`
- Phrase Suggester，在Term Suggester的基础上，通过ngram以词组为单位返回建议。`noble prize -> nobel prize`
- Completion Suggester，[FST](http://www.cnblogs.com/LBSer/p/4119841.html)数据结构，类似Trie树，不用打开倒排，快速返回，前缀匹配
- [Context Suggester](https://www.elastic.co/guide/en/elasticsearch/reference/6.1/suggester-context.html)，在Completion Suggester的基础上，用于filter和boost

![image](https://user-images.githubusercontent.com/8369671/80787524-5a64fd80-8bb9-11ea-9ef5-98a0c89a5f0a.png)
> query纠正

----
# 存在问题
1. suggestion和normal的分离，suggested query的排序。如输入拼音，如果根据前缀查找规则，汉字是不会返回的，但是这里需要汉字
2. 纠正功能的实现，todo code implementation

----
# Reference
- [Suggesters](https://www.elastic.co/guide/en/elasticsearch/reference/6.1/search-suggesters.html)
- [Elasticsearch Suggester详解](https://elasticsearch.cn/article/142)
- [基于Elasticsearch实现搜索建议](http://ginobefunny.com/post/search_suggestion_implemention_based_elasticsearch/)
- [ES 搜索建议 Suggester 的问题](https://elasticsearch.cn/question/1869)
- [You Complete Me](https://www.elastic.co/blog/you-complete-me)
- [Apache Spark upport](https://www.elastic.co/guide/en/elasticsearch/hadoop/5.3/spark.html#spark-native)
- [NLPCN](http://www.nlpcn.org/docs/7)
- [es-java-examples](https://github.com/bly2k/es-java-examples/blob/master/search/SuggestExample.java)
