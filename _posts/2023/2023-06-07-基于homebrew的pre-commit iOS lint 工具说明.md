---
title: 基于home brew的iOS Codelint 安装工具（lintmaker)
tags: CLI homebrew codeLint
published: true
key: 155 
article_header: 
  type: cover
  image:
    src: https://img.win3000.com/m00/bf/12/3105168fd57dc74f49f1a7ac462c0b18.jpg 
---



## lintmaker

### 简介

lintmaker 是使用swift 开发的一个CLI工具。主要负责了iOS 工程swift、objc语言的lint工具集成。

使用lintmaker 可以傻瓜式一键安装、生效，在git 项目中，每次git commit 就会验证其代码规范性。

### 主要功能

* 下载规则配置文件以及hook script、缓存到Library/Caches/ && 移动到当前目录（或者指定目录）下
* 安装lint 依赖工具，home brew tap update, Objective-Clint, swiftlint、python3等工具
* 清理空间目录，即删除配置文件以及hook script
* 卸载安装， 清除空间目录 && 卸载Objective-Clint、swiftlint
* 更新， 可全量更新（即更新配置文件 & 更新lint 工具），也可以只更新配置文件或者lint工具

### 架构思路

home brew 是 MAC\Linux 上非常方便的安装CLI或者Application的工具。

我们目标则是打造一个基于home brew 安装、更新的安装工具-lintmaker

* 我们创建自己的三方Tap， haoxiansen/homebrew-private
* Lintmaker 的开发则是尝试用swift 进行开发CLI程序
* 内部功能则是打着方便、好用、傻瓜式的原则进行开发

### 使用

* lintmaker安装

  ```shell
  # 安装
  brew tap haoxiansen/private
  brew install lint-maker
  # 更新
  brew update 
  brew upgrade lint-maker
  
  ```

* lintmaker 卸载

  ```shell
  brew uninstall lint-maker
  ```

  

*  install

  ```shell
  # 默认在当前目录安装
  lintmaker install
  
  USAGE: lintmaker install [--project-path <project-path>] [--configure-git-path <configure-git-path>]
  
  OPTIONS:
    -p, --project-path <project-path>
                            Please input a workspace path
    -c, --configure-git-path <configure-git-path>
                            Please input a accessible url, like
                            https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git, contains .clang-format
                            .swiftlint.yml (default: https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git)
    --version               Show the version.
    -h, --help              Show help information.
  ```

  

* clean

  ```shell
  # 默认清除当前目录
  lintmaker clean
  
  USAGE: lintmaker clean [--project-path <project-path>] [--configure-git-path <configure-git-path>]
  
  OPTIONS:
    -p, --project-path <project-path>
                            Please input a workspace path
    -c, --configure-git-path <configure-git-path>
                            Please input a accessible url, like
                            https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git, contains .clang-format
                            .swiftlint.yml (default: https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git)
    --version               Show the version.
    -h, --help              Show help information.
  
  ```

  

* uninstall

  ```shell
  lintmaker uninstall
  
  USAGE: lintmaker uninstall
  
  OPTIONS:
    --version               Show the version.
    -h, --help              Show help information.
  ```

  

* update

  ```shell
  # 默认全量更新
  lintmaker update
  
  USAGE: lintmaker update [--project-path <project-path>] [--configure-git-path <configure-git-path>] [--configuration-only] [--lint-only]
  
  OPTIONS:
    -p, --project-path <project-path>
                            a git workspace path, if not set defult is current directory
    -c, --configure-git-path <configure-git-path>
                            Please input a accessible url, like
                            https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git, contains .clang-format
                            .swiftlint.yml (default: https://gitlab.corp.youdao.com/hikari/app/ios/gzlint.git)
    --configuration-only    if set --configuration-only, only update configuration file
    --lint-only             if set --lint-only, only update lint tools
    --version               Show the version.
    -h, --help              Show help information.
  ```

 * help

   ```shell
   lintmaker --help
   lintmaker help [subcommand]
   ```

 * 注意事项

   * 所有命令只会对当前目录（指定目录）生效，不可全局生效，所以要求我们每一个git 项目都去集成
   * 可执行一次install，在某个目录，其他git项目执行 lintmaker update --configuration-only即可生效
   * 如若版本lint 工具升级，可执行lintmaker update 或者lintmaker update --lint-only
   * 如若只升级configuration files， 执行lintmaker update --configuration-only，可实现当前目录或者指定目录的configuration files的升级。

### 部分截图

* 安装成功

  ![image-20230607182823209](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230607182823image-20230607182823209.png)

* 清理成功

  ![image-20230607182847914](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230607182848image-20230607182847914.png)

* 更新成功

  ![image-20230607182928941](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230607182929image-20230607182928941.png)

* 卸载成功

  ![image-20230607182955883](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230607182956image-20230607182955883.png)