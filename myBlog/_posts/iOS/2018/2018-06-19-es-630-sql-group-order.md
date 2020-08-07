---
title: elasticsearch v6.3.0 sql group-order
tags: es
key: 44
modify_date: 2019-04-30 18:00:00 +08:00
---

# Overview
es v6.3.0之后，推出了es-SQL的支持。今天来试试这个功能。

----
# 测试数据集
![image](https://user-images.githubusercontent.com/8369671/80781656-cdfd0f80-8ba5-11ea-9ad7-70216417eb0e.png)
> geonames

----
# 简单语句
在简单语句的情况下，这个功能ok，具体表现如下，

![image](https://user-images.githubusercontent.com/8369671/80781661-d2c1c380-8ba5-11ea-88c1-93e6e2cd6733.png)
> simple es-sql

```
# execute
curl -X POST "$HOST/_xpack/sql?format=txt" -H 'Content-Type: application/json' -d'
{
    "query": "SELECT * FROM bm ORDER BY longitude DESC limit 3",
    "fetch_size": 3
}'

# translate to es DSL
curl -X POST "$HOST/_xpack/sql/translate?pretty" -H 'Content-Type: application/json' -d'
{
    "query": "SELECT * FROM bm ORDER BY longitude DESC limit 3",
    "fetch_size": 3
}'

# execute2（双引号里面的字符串）
curl -X POST "$HOST/_xpack/sql?format=txt" -H 'Content-Type: application/json' -d"
{
    \"query\": \"SELECT country_code, population AS sum_pop FROM bm WHERE population > 1 AND country_code = 'CN' ORDER BY population DESC\",
    \"fetch_size\": 11
}"

```
![image](https://user-images.githubusercontent.com/8369671/80781666-d7867780-8ba5-11ea-832f-8d14fbd264f7.png)
> translate from es DSL


# 稍复杂语句
## mysql
我们先看在mysql数据库下面，这些复杂语句的**语法准确性**。
![image](https://user-images.githubusercontent.com/8369671/80781670-dbb29500-8ba5-11ea-9456-d976ae4d3cfd.png)
> mysql-process

## es-sql
### only group by
![image](https://user-images.githubusercontent.com/8369671/80781681-de14ef00-8ba5-11ea-943d-0f646da8a8bf.png)
> only group by

![image](https://user-images.githubusercontent.com/8369671/80781684-e0774900-8ba5-11ea-941f-9848d4743781.png)
> translate from es DSL与execute的返回结果一致

### group by with order by
当在`group by`之后添加`order by`，es-sql就不能正常解析了。而在es-DSL里面是可以实现这个agg-sort[功能](https://www.elastic.co/guide/en/elasticsearch/reference/6.3/search-aggregations-pipeline-bucket-sort-aggregation.html)的。

![image](https://user-images.githubusercontent.com/8369671/80781688-e40ad000-8ba5-11ea-88c9-18d754ce7174.png)
> es-sql fail with group-order

根据上一节的without order by解析出来的DSL，再配合agg-sort这个功能，来实现group-order。
![image](https://user-images.githubusercontent.com/8369671/80781690-e79e5700-8ba5-11ea-8b0a-e30855388858.png)
> without order

![image](https://user-images.githubusercontent.com/8369671/80781694-eb31de00-8ba5-11ea-99c5-5788122073b5.png)
> with order


```
# without order
curl -X POST "$HOST/bm/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size" : 0,
  "query" : {
    "range" : {
      "population" : {
        "from" : 0,
        "to" : null,
        "include_lower" : true,
        "include_upper" : false,
        "boost" : 1.0
      }
    }
  },
  "_source" : false,
  "stored_fields" : "_none_",
  "aggregations" : {
    "groupby" : {
      "composite" : {
        "size" : 11,
        "sources" : [
          {
            "1674" : {
              "terms" : {
                "field" : "country_code",
                "order" : "asc"
              }
            }
          }
        ]
      },
      "aggregations" : {
        "1683" : {
          "sum" : {
            "field" : "population"
          }
        }
      }
    }
  }
}
'

# with order
curl -X POST "$HOST/bm/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size" : 0,
  "query" : {
    "range" : {
      "population" : {
        "from" : 0,
        "to" : null,
        "include_lower" : true,
        "include_upper" : false,
        "boost" : 1.0
      }
    }
  },
  "_source" : false,
  "stored_fields" : "_none_",
  "aggregations" : {
    "groupby" : {
      "composite" : {
        "size" : 11,
        "sources" : [
          {
            "1674" : {
              "terms" : {
                "field" : "country_code",
                "order" : "asc"
              }
            }
          }
        ]
      },
      "aggregations" : {
        "1683" : {
          "sum" : {
            "field" : "population"
          }
        }
        ,"population_bucket_sort": {
            "bucket_sort": {
                "sort": [
                  {"1683": {"order": "desc"}}
                ]
            }
        }
      }
    }
  }
}
'
```

----
# Others
![image](https://user-images.githubusercontent.com/8369671/80781697-f08f2880-8ba5-11ea-9eb1-8d77bcac7314.png)
> es-sql source code

不知道这个fix/enhancement是否可以在es-string通过antlr义成AST的es-DSL。有时间再回头看这个[issue](https://github.com/elastic/elasticsearch/issues/29965)。

costin回复说[Bucket Sort Aggregation](https://www.elastic.co/guide/en/elasticsearch/reference/6.3/search-aggregations-pipeline-bucket-sort-aggregation.html)只是局部排序，非全局排序。但是至于如何实现全局排序，我仍然没有弄明白。

![image](https://user-images.githubusercontent.com/8369671/80781700-f71da000-8ba5-11ea-9bd7-e2fba0f513bd.png)
> costin reply
