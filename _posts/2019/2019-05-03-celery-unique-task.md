---
title: Celery多生产者部署的定时任务去重
tags: python
key: 61
modify_date:
---

# Overview

最近在部署webserver，同一个应用(生产者)部署在3个机器上，3个机器都启用了Celery来启动定时任务，执行文件的增删。

![celery workflow](https://user-images.githubusercontent.com/8369671/58456549-1a023180-8157-11e9-833c-291c90eaa1d3.png)

![application SPF](https://user-images.githubusercontent.com/8369671/58456556-1cfd2200-8157-11e9-9c19-1da5dfbd37d7.png)

可以看到在mq和celery worker阶段都可以做到高可用。但是在user application阶段，存在single point failure的情况，如果单点故障，定时任务就发送不到broker了。

而为了消除user application的SPF或者增加整体吞吐量，一般会部署`多个application`，而这样的情况，每个application都会发送相同的定时任务到broker，导致同一时间就会有多个task。

虽然增删的底层是原子性的，但是多个API同时执行，最后通过conflict来确认是不妥当的。为了解决这个问题，可以采用以下方式，

1. 分布式定时队列
    - 类似oozie，由一个master来控制metadata
    - 将task不写在user application里面，将其再往上抽象一层
2. api发送定时任务到broker之前，先过一层分布式锁，获得锁的application才能发送，
    - mysql字段
    - zookeeper
        - 优点: 模型简单,其临时顺序节点天然支持释放锁和node crash
        - 缺点: ZAB的全部同步,写性能较低
    - redis(Redission), etcd
        - 优点: 高性能(10w级)
        - 缺点: 实现复杂,需要考虑加锁与超时的原子性,低效的等锁自旋
3. mq去重，以相同的task id（时间）发送task到mq，然后mq抓取后进行去重（延迟）

其中分布式锁已经有了一个[celery-once](https://github.com/cameronmaske/celery-once)，[celery-singleton](https://github.com/steinitzu/celery-singleton)的实现。

# With Unique Task
![celery worker with unique task](https://user-images.githubusercontent.com/8369671/58456562-1f5f7c00-8157-11e9-97c4-28cce3f37e80.png)

# Reference
- [Is it possible to skip delegating a celery task if the params and the task name is already queued in the server?](https://stackoverflow.com/questions/45107418/is-it-possible-to-skip-delegating-a-celery-task-if-the-params-and-the-task-name)
- [Running “unique” tasks with celery](https://stackoverflow.com/questions/4095940/running-unique-tasks-with-celery)
- [任务调度在分布式部署环境下保证task的正确运行](https://my.oschina.net/aiyungui/blog/751882)
- [Celery(四)定时任务](https://www.cnblogs.com/linxiyue/p/8082102.html)
- [再有人问你分布式锁，这篇文章扔给他](https://juejin.im/post/5bbb0d8df265da0abd3533a5)
- [Distributed locks with Redis](https://redis.io/topics/distlock)
- [漫画：如何用Zookeeper实现分布式锁？](http://mp.weixin.qq.com/s?__biz=MzIxMjE5MTE1Nw==&mid=2653194140&idx=1&sn=07b65a50798c26ecdc0fc555128ab937&chksm=8c99f546bbee7c50b1642dc971cb1f5e244dce661546e141734797c8c23c6c3ad779dfb57d3b&scene=21#wechat_redirect)
