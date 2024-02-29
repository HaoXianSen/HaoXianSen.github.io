---
title: 记录一次Kingfisher使用过程中的问题
tags: Ruby Cocoapods
published: false
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

## 记录一次Kingfisher使用过程中问题

### 起因

项目在测试阶段发现一个问题，首页列表数据中可配置背景图的cell发生背景错乱。但是明明已经做了防止复用导致的错乱，如下代码

```swift
 if let url = URL(string: model.imageUrl) {
   ownerImageView.kf.setImage(with: .network(url))
 } else {
   ownerImageView.image = nil
 }
	if let backgroundURL = URL(string: model.backgroundImageUrl) {
    backgroundImageView.kf.setImage(with: .network(backgroundURL), placeholder: UIImage.home_imageNamed("exprience_cloumn_bg"))} else {
    backgroundImageView.image = UIImage.home_imageNamed("exprience_cloumn_bg")
  }
```

代码乍一看好像没啥问题？

### 刨根

其实，当cell发生错乱的时候，瞬间涌上心头想法就是复用出了问题。但是上边的代码我们已经做了复用了啊。但是我们忽略了一个情况就是异步问题。

利用kf设置图片，本质上是去下载图片或者去缓存里找图片，那么这都是一个异步的过程。如果我们恰好又触发了复用机制，cell从复用池子里取到的cell，很可能是正在下载过程中，那么假设你当前是一个使用默认背景的cell，但是复用取到的是一个正在下载背景的cell。这个时候问题就出现，由于外部设置image比异步快，所以异步回来的图片则覆盖了外边设置的图片。这就是我们出现的本质原因。

接下来我们通过源码看一下：

首先我们进入到内部的setImage方法

![image-20240229181443861](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20240229181446image-20240229181443861.png)

当我们设置一个nil的source的话，会触发guard语句，将placeholder直接赋值与imageView的image，并且将当前的taskIdentifier置为nil，这个taskIdentifier作用很大，我们往后看

![image-20240229182037208](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20240229182037image-20240229182037208.png)

中间一些option操作不是我们本次重点，我们就看这个。那么第一个红框很重要，在这里会拿当前的任务identifier和ImageView的Identifer比较，不同的话不会赋值，抛出错误。

当然我们也通过log的方式验证了这一点，如下：

![image-20240229182913685](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20240229182914image-20240229182913685.png)

至此，从代码层面、验证，都可以证明这个一个异步导致的复用问题。

### 解决

解决方式也很简单，我们不用自己判断URL空否，因为Kingfisher里边会判断，并且处理，我们都交由其处理即可

```swift
let url = URL(string: model.imageUrl)
        ownerImageView.kf.setImage(with: url)
        
        backgroundImageView.kf.cancelDownloadTask()
        let backgroundImageUrl = URL(string: model.backgroundImageUrl)
        backgroundImageView.kf.setImage(with: backgroundImageUrl, placeholder: UIImage.home_imageNamed("exprience_cloumn_bg"))
```



### 总结

往往我们只关心同步的复用问题，却忽略了异步复用问题，所以需要特别重要异步导致的复用问题~

往往寻找问题的真正解决方案就藏在代码里，所以我们要多读源码，熟悉三方库源码~