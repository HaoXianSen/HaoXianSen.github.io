---
title: golang多线程与异步关注点
tags: golang
key: 85
aside:
  toc: true
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/69413221-5d76da80-0d4b-11ea-9778-a5910804a84f.png
---

# Overview
## 多线程
一个典型的多线程模型是`生产者-消费者`，多个生产者线程往一个queue/chan里面写数据，然后另一侧多个消费者线程从queue/chan里面读数据。

## 异步
在`生产者-消费者`模型了，如何判断生产者成功写入一条数据？
- 同步，record被完全确认(这里的确认可以是来自queue/chan侧，也可以是来自consumer侧)
- 异步，生产者只管往queue/chan里面发，暂时不管后果
    - 如果完全不管后果，即不管queue/chan crash/full与否，都一直发
    - 根据统计来决定自己(生产者)是否要中断发送(send timeout stats)

## code解析

```go
package main

import (
	"context"
	"fmt"
	"time"
)

func main() {
	//go f1()
	//go f2()
	//go f3()
	//go f4()
	//go f5()
	go f6()

	fmt.Println("let's go")
	select {}
}

// normal
func f1() {
	c := make(chan int, 4) // buffer channel
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second)) // if sending to channel will take too long, then timeout

			fmt.Printf("\ncurrent num is : %d\n", i)
			select {
			case c <- i:
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
			}
		}
	}(c)

	go func(c chan int) {
		for e := range c {
			fmt.Printf("receive : %d\n", e)
		}
	}(c)
}

// timeout since channel buffer full-blocking
func f2() {
	c := make(chan int, 4)
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second))

			fmt.Printf("\ncurrent num is : %d\n", i)
			select {
			case c <- i:
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
			}
		}
	}(c)
}

// blocking but without timeout since go through default directly
// will lost data, if going to `default`
func f3() {
	c := make(chan int, 4)
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second))

			fmt.Printf("\ncurrent num is : %d\n", i)
			select {
			case c <- i:
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
			default:
				fmt.Printf("sent unknown : %d, since default\n", i)
			}
		}
	}(c)

	go func(c chan int) {
		for {
			num := <-c
			fmt.Printf("receive : %d\n", num)
		}
	}(c)
}

// 有部分会跑到default去，导致没有sent，也就没有receive
func f4() {
	c := make(chan int, 7)
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second))

			fmt.Printf("\ncurrent num is : %d\n", i)
			select {
			case c <- i:
				time.Sleep(1 * time.Second) //每秒产生一个
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
			default:
				time.Sleep(1 * time.Second) //每秒产生一个
				fmt.Printf("sent unknown : %d, since default\n", i)
			}
		}
	}(c)

	go func(c chan int) {
		for e := range c {
			time.Sleep(2 * time.Second) //每2秒才消费一个
			fmt.Printf("receive : %d\n", e)
		}
	}(c)
}

// 直接丢掉被buff的部分，直到consumer把buffer降低，才能再塞入一个
func f5() {
	c := make(chan int, 7)
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second))

			select {
			case c <- i:
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
			default:
			}
		}
	}(c)

	go func(c chan int) {
		for e := range c {
			time.Sleep(2 * time.Second) //每2秒才消费一个
			fmt.Printf("receive : %d\n", e)
		}
	}(c)
}

// 不丢弃，blocking
func f6() {
	c := make(chan int, 7)
	go func(c chan int) {
		var i = -1
		for {
			i += 1
			ctx, _ := context.WithTimeout(context.Background(), time.Duration(5*time.Second))

			select {
			case c <- i:
				fmt.Printf("sent success : %d\n", i)
			case <-ctx.Done():
				fmt.Printf("sent failed : %d, since timeout\n", i)
				//default:
			}
		}
	}(c)

	go func(c chan int) {
		for e := range c {
			time.Sleep(2 * time.Second) //每2秒才消费一个
			fmt.Printf("receive : %d\n", e)
		}
	}(c)
}
```

上面的code，有几个key point,
- `buffer channel`，如果queue/chan满了，会产生阻塞blocking，而此时如果生产者是同步的话，那么就一直hold在此。而如果生产者是异步的话，该thread/goroutine也会一直hold
- timeout，为了避免阻塞而导致的thread/goroutine数量溢出，通常可以加上`case <-ctx.Done()`来控制该thread/goroutine的全部生命周期
- default，加入default可以避免阻塞，在select的顺序里面，default是2nd，而1st是能够通过的case，如果多个case通过，就伪随机从这些通过的case里面选一个，而如果没有case通过，那么就走default
    - 所以通常1st-case里面queue/chan crash/full了，导致该case失败，所以才走的default<sup>[2]</sup>

## illustration
![image](https://user-images.githubusercontent.com/8369671/69413018-fb1dda00-0d4a-11ea-9bd7-49cb51fae35e.png)
> from unh

![image](https://user-images.githubusercontent.com/8369671/69412966-e17c9280-0d4a-11ea-9dd6-1255651f642d.png)
> from datastax

![image](https://user-images.githubusercontent.com/8369671/69412945-d45fa380-0d4a-11ea-9b1e-68ebd15bd1c9.png)

# Reference
0. [单向channel](https://studygolang.com/articles/14567)
0. [Priority of case versus default in golang select statements](https://stackoverflow.com/a/45580232)
0. [Asynchronous programming with Go](https://medium.com/@gauravsingharoy/asynchronous-programming-with-go-546b96cd50c1)
0. [Anatomy of Channels in Go - Concurrency in Go](https://medium.com/rungo/anatomy-of-channels-in-go-concurrency-in-go-1ec336086adb)
    - Adding timeout
    - WaitGroup
    - Mutex
0. [Go 微服务，第11部分：Hystrix和Resilience](https://cloud.tencent.com/developer/article/1157926)
0. [Testing for asynchronous results without sleep in Go](https://stackoverflow.com/questions/30427013/testing-for-asynchronous-results-without-sleep-in-go)
0. [hystrix-go](https://github.com/afex/hystrix-go)
