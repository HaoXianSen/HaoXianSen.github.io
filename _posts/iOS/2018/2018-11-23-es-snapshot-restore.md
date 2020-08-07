---
title: es Snapshot and Restore
tags: es
key: 53
modify_date: 2019-04-30 18:00:00 +08:00
---

# Overview
整理一下es的snapshot功能，分两块，一块是本地磁盘disk存储，一块是远程hdfs作存储，

----
# Version
- elasticsearch-5.4.3.zip
- repository-hdfs-5.4.3.zip

----
# Install plugin
```
# need to specified absolute path
bin/elasticsearch-plugin install file:///data/mapleleaf/es_snapshot/repository-hdfs-5.4.3.zip

# check hdfs master namenode ip and port using webhdfs
curl -i "http://localhost:8081/webhdfs/v1/?op=LISTSTATUS"

# start es
sh bin/elasticsearch -d
ps aux | grep elasticsearch | grep -v "grep" | awk '{print $2}' | xargs kill -9
ps aux | grep elasticsearch | grep -v "grep" | awk '{print $2}' | xargs kill -9 ; sleep 3 && sh bin/elasticsearch -d && ps aux | grep elasticsearch | grep -v "grep" && tailf logs/es_snap.log
```

----
# Disk
## create repo
```
# add below line to esyml
path.repo: ["/data/mapleleaf/es_snapshot/my_backup"]

# create repo, named: my_backup
curl -XPUT 'http://localhost:9200/_snapshot/my_backup' -H 'Content-Type: application/json' -d '{
    "type": "fs",
    "settings": {
        "location": "/data/mapleleaf/es_snapshot/my_backup",
        "compress": true
    }
}'

curl -X GET "localhost:9200/_snapshot/my_backup?pretty"
curl -X DELETE "localhost:9200/_snapshot/my_backup"
```

## create snapshot
```
# create snapshot
curl -X PUT "localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true&pretty"
curl -X GET "localhost:9200/_snapshot/my_backup/*?pretty"
curl -X GET "localhost:9200/_snapshot/my_backup/snapshot_1/_status?pretty"
curl -X DELETE "localhost:9200/_snapshot/my_backup/snapshot_1?pretty"
```

## restore
```
# restore
curl -X POST "localhost:9200/_snapshot/my_backup/snapshot_1/_restore?pretty"
```

----
## setp
1. check index
```
curl -X PUT "localhost:9200/customer" -H 'Content-Type: application/json' -d'
{
    "settings" : {
        "index" : {
            "number_of_shards" : 5,
            "number_of_replicas" : 0
        }
    }
}
'

curl -X GET "localhost:9200/_cat/indices?v"
curl -X DELETE "localhost:9200/customer?pretty"
```

2. insert data
```
for i in {1..10000};
do
    curl -s -X POST "localhost:9200/customer/external/?pretty" -H 'Content-Type: application/json' -d"
    {
      \"id\": ${i},
      \"num\": ${i},
      \"name\": \"John Doe\"
    }" > /dev/null
done
```

![image](https://user-images.githubusercontent.com/8369671/80778572-748fe300-8b9b-11ea-865c-0462c1353af9.png)
> insert docs

3. close index
```
curl -X POST "localhost:9200/customer/_close?pretty"
```

4. restore
因为之前我store了一次backup，当时backup只有1条doc，当插入1万条之后，close，然后restore，是以当时store的snapshot来恢复。

![image](https://user-images.githubusercontent.com/8369671/80778575-78236a00-8b9b-11ea-9f04-af09f03faee3.png)
> after restore

5. reinsert
```
curl -X GET "localhost:9200/_search?pretty" -H 'Content-Type: application/json' -d'
{
    "query": {
        "match_all": {}
    }
}'
```

![image](https://user-images.githubusercontent.com/8369671/80778579-7b1e5a80-8b9b-11ea-869d-754689784cb9.png)
> reinsert

6. create snapshot_2

![image](https://user-images.githubusercontent.com/8369671/80778583-7e194b00-8b9b-11ea-86cc-3ebbafd9f1e0.png)
> before

![image](https://user-images.githubusercontent.com/8369671/80778585-807ba500-8b9b-11ea-9259-1c76601475a3.png)
> after

7 close & restore

----
# [HDFS](https://www.elastic.co/guide/en/elasticsearch/plugins/5.4/repository-hdfs-config.html)

## create hdfs repo
```
curl -X PUT "localhost:9200/_snapshot/my_hdfs_repository?pretty" -H 'Content-Type: application/json' -d'
{
  "type": "hdfs",
  "settings": {
    "uri": "hdfs://xxxxx:xxxx",
    "path": "elasticsearch/respositories/my_hdfs_repository",
    "compress": true
  }
}'
```
如果在这一步出现异常，可以参考[这里](https://github.com/elastic/elasticsearch/issues/22156)。

![image](https://user-images.githubusercontent.com/8369671/80778586-840f2c00-8b9b-11ea-9c1a-f87d0da3692d.png)
> create repo successed

## insert data
![image](https://user-images.githubusercontent.com/8369671/80778589-883b4980-8b9b-11ea-9398-55618822faa1.png)
> doc 10000

## create hdfs snapshot
```
curl -X PUT "localhost:9200/_snapshot/my_hdfs_repository/snapshot_hdfs_1?wait_for_completion=true&pretty"
```
![image](https://user-images.githubusercontent.com/8369671/80778638-a7d27200-8b9b-11ea-8cb4-397b48f82d86.png)
> access_control_exception

在`jvm.optiopns`添加插件的安全配置
![image](https://user-images.githubusercontent.com/8369671/80778642-abfe8f80-8b9b-11ea-8945-2f1d60b5c04e.png)
> fix access_control_exception

![image](https://user-images.githubusercontent.com/8369671/80778651-aef98000-8b9b-11ea-8472-ff547600fbbd.png)
> create snap successed

![image](https://user-images.githubusercontent.com/8369671/80778657-b1f47080-8b9b-11ea-895f-fde0e43462c1.png)
> hdfs ls snapshot files

## restore from hdfs
1. 随意增加一些docs，使得与snapshot时的index有差异，便于观察restore效果。

![image](https://user-images.githubusercontent.com/8369671/80778661-b587f780-8b9b-11ea-8605-21f8361b08cf.png)
> doc 10000+

2. close index

![image](https://user-images.githubusercontent.com/8369671/80778797-2cbd8b80-8b9c-11ea-8c0f-b12d6550f8e3.png)
> doc index close

3. restore
curl -X POST "localhost:9200/_snapshot/my_hdfs_repository/snapshot_hdfs_1/_restore?pretty"

![image](https://user-images.githubusercontent.com/8369671/80778803-30e9a900-8b9c-11ea-8b8a-51e1edaeb14d.png)
> restore successed

![image](https://user-images.githubusercontent.com/8369671/80778806-33e49980-8b9c-11ea-985a-f39d05afabfc.png)
> doc 10000

----
# Restoring to a different cluster
> All that is required is `registering` the repository containing the snapshot in the new cluster and `starting` the restore process.
```
curl -X GET "localhost:9201/_cat/indices?v"
```

![image](https://user-images.githubusercontent.com/8369671/80778810-37782080-8b9c-11ea-8d74-df0643011482.png)
> clusterB initial

## registering repository
```
curl -X PUT "localhost:9201/_snapshot/my_hdfs_repository?pretty" -H 'Content-Type: application/json' -d'
{
  "type": "hdfs",
  "settings": {
    "uri": "hdfs://xxxxx:xxxx",
    "path": "elasticsearch/respositories/my_hdfs_repository",
    "compress": true
  }
}'
```

![image](https://user-images.githubusercontent.com/8369671/80778814-3a731100-8b9c-11ea-994b-0fecf0971414.png)
> registering using the same hdfs path with clusterA

## list snapshot
```
curl -X GET "localhost:9201/_snapshot/my_hdfs_repository/*?pretty"
```

![image](https://user-images.githubusercontent.com/8369671/80778820-3cd56b00-8b9c-11ea-8a19-623130b50d77.png)
> lists working snapshots


## starting restore
```
curl -X POST "localhost:9201/_snapshot/my_hdfs_repository/snapshot_hdfs_1/_restore?pretty"
```

![image](https://user-images.githubusercontent.com/8369671/80778821-4068f200-8b9c-11ea-8410-a8feba9b54d2.png)
> restore successed

----
# benchmark
会用esrally将数据写入

![image](https://user-images.githubusercontent.com/8369671/80778823-42cb4c00-8b9c-11ea-93f9-269364e3bafc.png)
> before

## snapshoting speed
![image](https://user-images.githubusercontent.com/8369671/80778827-465ed300-8b9c-11ea-86df-90fc3a1d215c.png)
> hdfs before snapshot

```
# backgroud running
curl -X PUT "XXX:9200/_snapshot/my_hdfs_repository/snapshot_hdfs_long_1" -H 'Content-Type: application/json' -d'
{
  "indices": "591_etl_fuhaochen_test_2018062500",
  "ignore_unavailable": true,
  "include_global_state": false
}'

# check running status
curl -X GET "XXX:9200/_snapshot/my_hdfs_repository/*?pretty"
```

![image](https://user-images.githubusercontent.com/8369671/80778833-49f25a00-8b9c-11ea-8906-126bf862e184.png)
> in_progress

![image](https://user-images.githubusercontent.com/8369671/80778838-4c54b400-8b9c-11ea-8d22-a74437074486.png)
> success

![image](https://user-images.githubusercontent.com/8369671/80778842-4f4fa480-8b9c-11ea-8275-ade757634d5e.png)
> hdfs after snapshot

## restoring speed
```
date
curl -X POST "XXX:9201/_snapshot/my_hdfs_repository/snapshot_hdfs_long_1/_restore?wait_for_completion=true&pretty"
date
```

![image](https://user-images.githubusercontent.com/8369671/80778849-52e32b80-8b9c-11ea-9261-ffa2f4675071.png)
> after

snapshoting耗时远比restoring高。

----
# plugin auto route
测试一下插件会不会自动路由，即是否需要在每一个节点（datanode，masternode等）都安装？还是只需要在整个es集群的其中一个node安装之后，该node就会将plugin自动路由安装到集群的其他node上？

![image](https://user-images.githubusercontent.com/8369671/80778855-5676b280-8b9c-11ea-8cde-9b6f37ddd34d.png)
> health

![image](https://user-images.githubusercontent.com/8369671/80778858-5971a300-8b9c-11ea-9486-099e72aea7f8.png)
> nodes

![image](https://user-images.githubusercontent.com/8369671/80778862-5d052a00-8b9c-11ea-9fa0-4253b27019d3.png)
> plugins

自动路由不可用。

----
# other
- 尝试snapshot更大的index，但是报错了，配置应该没有问题（因为小索引是snapshot成功的）

![image](https://user-images.githubusercontent.com/8369671/80778867-6098b100-8b9c-11ea-95ef-bfc83d742609.png)
> 大索引snapshot失败

![image](https://user-images.githubusercontent.com/8369671/80778870-62fb0b00-8b9c-11ea-9534-dbddbb699a93.png)
> 小索引snapshot成功

[Self-suppression not permitted](https://stackoverflow.com/questions/44490579/what-is-the-main-cause-of-self-suppression-not-permitted-in-spark)这个error应该是hadoop的DataNode剩余空间不够导致。

----
# Reference
- [modules-snapshots](https://www.elastic.co/guide/en/elasticsearch/reference/5.4/modules-snapshots.html)
- [repository-hdfs-config](https://www.elastic.co/guide/en/elasticsearch/plugins/5.4/repository-hdfs-config.html)
- [SecurityException issue](https://github.com/elastic/elasticsearch/issues/22156)
- [ElasticSearch映射到hdfs的快照](https://my.oschina.net/whx403/blog/911995)
- [ES HDFS快照手册](https://blog.csdn.net/ypc123ypc/article/details/68944108)
- [snapshot探索（增量，incremental）](https://www.jianshu.com/p/59d1cac84e3a)
