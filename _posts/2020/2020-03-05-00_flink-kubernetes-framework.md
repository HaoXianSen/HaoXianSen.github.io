---
title: Flink Kubernetes CD Framework
tags: kubernetes
key: 100
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/77038213-2610f580-69ee-11ea-87bf-e247cfc6bf3a.png
---

# Overview
Continuous deployment is a strategy for software releases wherein any code commit that passes the automated testing phase is automatically released into the production environment, making changes that are visible to the software's users.
> from techtarget

<br>

![image](https://user-images.githubusercontent.com/8369671/83435240-71c03080-a46e-11ea-9c59-a88b545820d9.png)
> A diagram about how to deploy a flink application while codes change
> - easy to track, everything is git, no cron-job
> - easy to scala-up
> - easy to manage

# Module
简介CI到CD的k8s套件

## gitlab runner
负责CI和发布jar/image/chart到相应repo

## helm
> k8s的应用包管理(define, install, upgrade)

负责kubernetes应用的包管理<sup>1</sup>, 类似apt、yum、homebrew[工具](https://github.com/helm/charts/tree/master/stable/elasticsearch)

![image](https://user-images.githubusercontent.com/8369671/76966873-945ba680-6961-11ea-9060-8c49a3a30ae9.png)
> from ref.1

## spinnaker
> 集群管理和部署

创建pipeline, 将应用image运行部署到k8s集群上

![image](https://user-images.githubusercontent.com/8369671/76967554-95410800-6962-11ea-914f-6bff573f9e27.png)
> from dzone

![image](https://user-images.githubusercontent.com/8369671/76967679-b43f9a00-6962-11ea-87e5-c63c449fc200.png)
> from google cloud

![image](https://user-images.githubusercontent.com/8369671/76968071-45167580-6963-11ea-9a5d-eac1b71bd57f.png)
> from ref.2

# install
0. minikube cluster/kubectl
0. helm
0. spinnaker

# Reference
0. [Helm介绍 - 强大的Kubernetes包管理工具](https://zhaohuabing.com/2018/04/16/using-helm-to-deploy-to-kubernetes/)
0. [使用Spinnaker自动化部署代码到Kubernetes示例](https://blog.csdn.net/aixiaoyang168/article/details/79591566)
0. [Get Started with Spinnaker on Kubernetes](https://thenewstack.io/getting-started-spinnaker-kubernetes/)
