---
title: Flutter Text 文字下有黄色下划线

tags: Flutter

key: 102

# article_header:

# type: cover

# image:

#  src: https://user-images.githubusercontent.com/8369671/80915045-153ff780-8d82-11ea-9acf-6ccbf2b05d9d.png
---

### 导致原因

导致这种情况发生的原因是因为，Text widget 隶属于Material 风格下的组件，如果根节点不是Material 相关组件，则会使用默认带黄色下划线的格式。如果根节点是Material 容器组件，则会采用其Material风格的样式（即不带有下换线）。

### 解决方式

#### 1. 采用根节点为脚手架Scaffold组件
```
Scaffold(body: content,);
```
#### 2.  采用根节点为Material 组件
```
Material(child: content);
```
#### 3. 逐个修改Text 组件的style 下的decoration为TextDecoration.none
```
child: Text(
                      "专栏的文章",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: TextDecoration.none,
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: defaultFontFamily,
                      ),
                    )
```

### 结语

记录开发中遇到的问题，方便再次遇到快速解决。