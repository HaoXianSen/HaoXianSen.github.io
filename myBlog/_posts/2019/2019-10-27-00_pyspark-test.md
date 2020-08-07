---
title: PySpark自动化测试关注点
tags: python
key: 84
aside:
  toc: true
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/67628983-e82dfc00-f8a9-11e9-9183-98db96c97626.png
---

# Overview
之前一直使用scala写spark pipeline，这次试着使用[PySpark](https://spark.apache.org/docs/latest/api/python/index.html)来模拟，主要希望熟悉一下Python的自动化测试的文件组织、mock用法、三种verification方法、code Linting，以及docker化prd-code。

# 文件结构
可以不用跟golang一样与prd-code在同一个目录下。当然也可以这样做。但是单独一个**test**目录可能会更清晰。

# test
我用过的测试部分是unittest和pytest，而在Python3里面，unittest好像有了长足进步，可以灵活配置，可以mock等等，而且是built-in的。

# 验证
常用的验证是跑ut来confirm，这里使用了三种方式，
1. 常规unit test
    - 可以直接在IDEA跑的
    ![image](https://user-images.githubusercontent.com/8369671/67629762-d7838300-f8b5-11e9-803d-f91c7109ef56.png)
2. local container
    - 在本地起一个container，然后在container里面配置所需环境，然后再运行ut
    - 隔离local环境，仅需要minimal环境，有利于deploy
    - 配置`Dockerfile`
    - 注意**workdir**
    - 可以使用docker build，直接把`prd-code`制作成一个image，然后将其发布，利用[k8s](https://chenfh5.github.io/2019/10/07/00_kubernetes.html)来部署、分发和弹性伸缩
    ![image](https://user-images.githubusercontent.com/8369671/67629767-ed914380-f8b5-11e9-84a2-3883e01a4336.png)
3. gitlab ci/cd
    - remote container
    - 跟step2类似，只是从本地container切换为Gitlab Runner container
    - 配置`.gitlab-ci.yml`
    ![image](https://user-images.githubusercontent.com/8369671/67629782-2b8e6780-f8b6-11e9-8e03-2b9ab9469bd8.png)
    
# 遇到的问题
- Python环境
    - 与IDEA结合，通常用requirements.txt来管理lib，而Python与IDEA的结合可以是system级别的(共用lib)，也可以是virtual级别的(隔离lib)
    ![image](https://user-images.githubusercontent.com/8369671/67629796-bbccac80-f8b6-11e9-9457-ae5dbfedd8ef.png)
    - 与Spark结合，有时候切换Python环境之后就跑不起来了，此时需要根据错误来定位解决问题
- codebase差异
    - [github](https://github.com/marketplace/category/continuous-integration)没有[gitlab](https://docs.gitlab.com/ee/ci/)的ci/cd，只能用类似Travis CI这样的来代替，但是这样一来就需要使用`Travis CI`的语法来适配`.gitlab-ci.yml`
    - 刚刚看到，其实github也推出了自己的ci/cd服务，叫[GitHub Action](https://help.github.com/en/github/automating-your-workflow-with-github-actions)，其中Spark也[切换](https://github.com/apache/spark/commit/219922422003e59cc8b3bece60778536759fa669)过来了
        - 此时，我也把这个项目的[ci](https://github.com/chenfh5/pyspark-auto-test-docker-example/blob/master/.github/workflows/ci.yml)使用GitHub Page run起来了
        ![image](https://user-images.githubusercontent.com/8369671/67940891-7e965080-fc0f-11e9-8110-6318d2af900c.png)

# Reference
0. [PYTHON - AUTO GENERATE REQUIREMENTS.TXT](https://www.idiotinside.com/2015/05/10/python-auto-generate-requirements-txt/)
0. [How to enable or disable GitLab CI/CD](https://docs.gitlab.com/ee/ci/enable_or_disable_ci.html)
0. [Setting Up GitLab CI for a Python Application](http://www.patricksoftwareblog.com/setting-up-gitlab-ci-for-a-python-application/)
0. [Building Minimal Docker Containers for Python Applications](https://blog.realkinetic.com/building-minimal-docker-containers-for-python-applications-37d0272c52f3)
0. [Dockerize your Python Application](https://runnable.com/docker/python/dockerize-your-python-application)
0. [pyspark crash issue 1](https://stackoverflow.com/questions/50168647/multiprocessing-causes-python-to-crash-and-gives-an-error-may-have-been-in-progr)
0. [pyspark col function not found issue](https://stackoverflow.com/a/40163314)
0. [CI/CD using GitHub Action - example](https://github.com/actions/starter-workflows/tree/master/ci)
0. [my source code](https://github.com/chenfh5/pyspark-auto-test-docker-example)
