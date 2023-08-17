---
title: 使用homeBrew 发布自己的Mac 软件
tags: [homebrew]
published: true
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

## 使用Home Brew 发布自己的Mac 软件

### 制作三方home brew tap

制作HomeBrew 三方tap的教程我已经在之前的文章有介绍过了，在这就不在赘述了。有需要的小伙伴可以去[这里](https://haoxiansen.github.io/2023/02/03/%E5%88%9B%E5%BB%BA%E4%B8%89%E6%96%B9homeBrew.html)自行学习。

### 制作.dmg文件

* 打开磁盘工具

  <img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817195344image-20230817195343871.png" alt="image-20230817195343871" style="zoom:50%;" />

* 选择“文件”-“新建映像”-“空白映像”

  ![image-20230817195534431](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817195534image-20230817195534431.png)

* 命名为temp， 大小可以根据实际app大小给一个

  <img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817195651image-20230817195650815.png" alt="image-20230817195650815" style="zoom:50%;" />

* 完成之后会出现temp的dmg以及未命名的一个磁盘

  <img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817195851image-20230817195851150.png" alt="image-20230817195851150" style="zoom:50%;" />

* 准备三个材料：1、打好的.app包 2、app包的icon 3、应用程序的替身

  * 1/2 就不用多介绍了
  * 应用程序的替身制作，打开“电脑”-“Macintosh HD”-“应用程序”-双击选择“制作替身”选项

* 打开“未命名”的磁盘， 将1、2、3 拖入

* 双击空白区， 选择“查看显示选项”

  ![image-20230817200524935](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817200525image-20230817200524935.png)

* 将我们2的背景图片，拖到背景图片位置

  ![image-20230817200613713](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817200613image-20230817200613713.png)

* 重新打开磁盘工具，选择“映像”-“转换”

  ![image-20230817200711769](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817200711image-20230817200711769.png)

* 选取刚才temp.dmg，存储为我们app的名字

  ![image-20230817200836058](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817200836image-20230817200836058.png)

* 至此我们dmg就只做完毕，打开.dmg， 就出现了我们常见的页面

  ![image-20230817201051546](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817201051image-20230817201051546.png)

### 创建Cask 脚本

#### 将dmg放到可访问下载的地址

这里我选择在github重新建一个Repo用来存放dmg， 然后创建一个release，存放有dmg，如下：

![image-20230817201343224](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817201343image-20230817201343224.png)

#### 创建Cask脚本

使用命令``` brew create --cask [dmg_download_url]``` 创建一个cask ruby 脚本。

补充好需要内容，如下：

![image-20230817201534286](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817201534image-20230817201534286.png)

#### 发布到公有cask仓库

发布到cask 公有仓库，需要先可执行``` brew audit --cask --new kcode ``` 命令检查。其中kcode 是我自己的cask名字。

需要注意的是，homebrew会去检查你的项目查看数、点赞数、签名等等，需要满足条件才能发布，要不然就会报以下错误：

![image-20230817201834123](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230817201834image-20230817201834123.png)

很明显，我们不满足要求，所以我们没法用公开的cask仓库。

我们选择三方仓库tap使用。

#### 发布三方tap仓库

如果你是新建的tap仓库，那么你需要新建一个Casks目录，然后将rb脚本放到这个目录里。然后去执行添加tap（**需要注意的是先保证的你的三方tap仓库push了**）：

```shell
brew tap [xxx/repo] [url]
```

而我已经有tap仓库了，那么同样我需要新建一个Casks目录，然后将rb脚本放到这个目录下，然后Push项目，执行更新操作：

```shell
brew update 
// 或者
brew tap --force-auto-update [xxx/repo]
```

### 安装 | 更新

安装

```shell
brew tap brew tap [xxx/repo] && brew install [app_name]
```

更新

```shell
brew update
brew upgrade [cask_name]
```

如果要更新app的版本：

我们需要先去三方tap里改脚本的版本号，以及对应sha256。具体sha256怎么生成，请到第一部分所提到的文章里看。

### 参考文章

[Cask Cookbook](https://docs.brew.sh/Cask-Cookbook#stanza-zap)

[如何创建一个三方home brew tap](https://haoxiansen.github.io/2023/02/03/%E5%88%9B%E5%BB%BA%E4%B8%89%E6%96%B9homeBrew.html)

