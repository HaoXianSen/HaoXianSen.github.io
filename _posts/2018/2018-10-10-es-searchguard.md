---
title: searchguard-6的安装和配置
tags: es
key: 48
modify_date: 2019-04-30 18:00:00 +08:00
---

记录一下searchguard-6的安装和配置过程，

----
# Overview
elasticsearch在暴露了一个node的ip和端口后就可以对整个集群进行各种操作，删索引，改数据等。在重要的项目应用中，需要防范这一点。

目前常见的安全防范方式有，
1. [X-Pack Elasticsearch Security](https://www.elastic.co/guide/en/x-pack/current/elasticsearch-security.html)，收费License
2. [Search Guard](https://github.com/floragunncom/search-guard)，免费开源

下面就Search Guard，将其最小化安装到es集群。

# 版本
- elasticsearch-6.4.2.tar.gz
- search-guard-6-6.4.2-23.1.zip

# 安装search guard
## sg plugin installation
1. tar -zxvf elasticsearch-6.4.2.tar.gz
2. cd elasticsearch-6.4.2
3. bin/elasticsearch-plugin install -b file:///path/to/search-guard-6-6.4.2-23.1.zip

![image](https://user-images.githubusercontent.com/8369671/80780607-3649f200-8ba2-11ea-9a61-32601efb27da.png)
> sg plugin install success 

## sg demo quick installer

![image](https://user-images.githubusercontent.com/8369671/80780613-3944e280-8ba2-11ea-9d7a-0c17c0ea9b6c.png)
> run demo installer, failed

![image](https://user-images.githubusercontent.com/8369671/80780623-406bf080-8ba2-11ea-9686-4fdec38d500b.png)
> run demo installer2, succeeded

1. 对`install_demo_configuration.sh`赋权
2. 运行`install_demo_configuration.sh`，此时该脚本会将秘钥文件生成，并cp到`/config`下，同时append sg配置内容到`/config/elasticsearch.yml`

![image](https://user-images.githubusercontent.com/8369671/80780626-42ce4a80-8ba2-11ea-835c-c1fdb68ea670.png)
> sg自动append的esyml

启动es，正常。
通过浏览器访问es集群，不正常，报错如下，

![image](https://user-images.githubusercontent.com/8369671/80780628-45c93b00-8ba2-11ea-8fb8-0a9bd2a3f2b2.png)
> SSLException

应该是浏览器没有建立ssl链接，没有深究这方面，换了一种方式，即在esyml里把SSL关闭。

3. 关闭SSL

![image](https://user-images.githubusercontent.com/8369671/80780635-48c42b80-8ba2-11ea-936f-e35e7b5ef570.png)
> esyml

![image](https://user-images.githubusercontent.com/8369671/80780636-4b268580-8ba2-11ea-9503-ed82b6d415cd.png)
> es login succeeded

![image](https://user-images.githubusercontent.com/8369671/80780637-4d88df80-8ba2-11ea-9adc-b3f545ece38c.png)
> sg demo config

## sg自定义1
基于demo生成的证书，直接修改原有账户名及其密码，
1. 生成hash新密码

![image](https://user-images.githubusercontent.com/8369671/80780641-5083d000-8ba2-11ea-9435-293063cb6768.png)
> hash new password

2. 修改`/sgconfig/sg_internal_users.yml`

![image](https://user-images.githubusercontent.com/8369671/80780642-524d9380-8ba2-11ea-8220-23f6ae36eb5b.png)
> image.png

3. 分发新配置到es集群
```
cd ./plugins/search-guard-6/tools

./sgadmin.sh -cd ../sgconfig/ -icl -nhnv \
   -cacert ../../../config/root-ca.pem \
   -cert ../../../config/kirk.pem \
   -key ../../../config/kirk-key.pem
```

![image](https://user-images.githubusercontent.com/8369671/80780651-55e11a80-8ba2-11ea-963d-fe10f224a092.png)
> snapshot of new account and password

## sg自定义2
sg可以自定义密码和加密方式。首先下载[ssl生成工具](https://github.com/floragunncom/search-guard-ssl)，然后进行自定义配置，

1. git clone --depth=1 https://github.com/floragunncom/search-guard-ssl.git
2. 配置ca

![image](https://user-images.githubusercontent.com/8369671/80780660-58dc0b00-8ba2-11ea-8710-1a28d8cd89d6.png)
> root-ca

![image](https://user-images.githubusercontent.com/8369671/80780663-5c6f9200-8ba2-11ea-9a9e-b9b063322915.png)
> signing-ca

3. 配置生成脚本`example.sh`

![image](https://user-images.githubusercontent.com/8369671/80780666-5ed1ec00-8ba2-11ea-9b10-ae3bc85b0326.png)
> root，node，client的ca生成配置

4. cp生成的node证书到es/config
- 首先在es/config删除demo生成的(`*.pem`)
- cp search-guard-ssl的`node-*-keystore.jks`和`truststore.jks`到es/config

5. 配置esyml

![image](https://user-images.githubusercontent.com/8369671/80780671-61ccdc80-8ba2-11ea-83e8-d01b068deb05.png)
> esyml

6. cp生成的client证书到/plugins/search-guard-6/sgconfig/

7. 修改`/sgconfig/sg_internal_users.yml`

![image](https://user-images.githubusercontent.com/8369671/80780675-64c7cd00-8ba2-11ea-9640-eae111ccedf7.png)
> 生成hash password

![image](https://user-images.githubusercontent.com/8369671/80780679-685b5400-8ba2-11ea-97b7-3adfe2194646.png)
> 配置sg_internal_users.yml

8. 分发新配置到es集群

![image](https://user-images.githubusercontent.com/8369671/80780685-6c877180-8ba2-11ea-8eca-2f10598b92cf.png)
> 重启使之生效

# Reference
- [Search Guard Installation](https://docs.search-guard.com/latest/search-guard-installation)
- [Search Guard Demo Installer](https://docs.search-guard.com/latest/demo-installer)
- [ElasticSearch&Search-guard 5 权限配置](https://www.jianshu.com/p/5a42b3560b27)
- [SearchGuard权限配置](https://www.jianshu.com/p/fffec2c39bba)
