---
title: 基于gitlab的仓库管理，如何自动生成MR提供code review？
tags: iOS gitlab	
published: false
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

### 基于gitlab的仓库管理，如何自动生成MR？

----

### 前情

由于我们code review流程是基于gitlab Merge Request进行的，毕竟gitlab的清晰、可视的diff 视图还是很清晰能看到新的改动和之前代码的区别。那么对于每次开发完成一个需求，手动提merge request就成了一个必要的工作，而且我们还需要去整理review列表。那么为了更好的提高效率，减少工作量，如何合理的、自动的生成merge request就成为首要的任务。

### 构思

方案1： 配置Runner ->执行Pipeline job ->.gitlab.ci.yml 配置脚本：判断当前分支， 创建MR

方案2：push web hook， 增加web hook链接，编写脚本，或者push 状态、分支、等等，远程脚本创建MR

方案3：基于可视化辅助工具Kcode开发，单库|多库，提交MR

### 实现

### 效果

### 总结

