---
title: golang concurrency
tags: golang
key: 94
aside:
  toc: true
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/71766792-e8e4ad80-2f3e-11ea-8bb9-4dfd0705355f.png
---

# Overview
go里面开启一个线程是很简单的，直接引入`go`关键字就会开启一条新的goroutine

当然能以嵌套的方式，在goroutine里面再开goroutine

# GMP
> 调度本质：调度器P将协程G合理地分配到系统线程M上执行

调度过程:
1. 生产G，先创建一个G对象，G会先被保存到某个P的local queue，如果local queue full了(256个G对象)，那么新来的G对象就被save到global queue
2. 消费G，M先从local，再从global queue取，如果还没有则从其他p的local queue取(netpoll)
   - 如果能找到G，则M开始寻找空闲P以运行G
   - 如果没能找到G，则M自旋或者休眠

如果当前M运行的G有system call需要阻塞，那么P会与M进行分离，M负责运行阻塞的G，而P则带着队列中的其他G绑定到新的M中，继续执行这些G。使得虽然G进入阻塞，但不会影响到P去执行其他G

这里有一个较形象的类比<sup>8,12</sup>，
- Goroutines (G，货物。协程/线程)
- Processor (P，货车，逻辑处理器，默认情况下，Go会为每个可用的物理处理器cpu都分配一个逻辑处理器)
- OSThread (M，司机，进程，对应一个独立程序空间)

![image](https://user-images.githubusercontent.com/8369671/71654444-cf8c0780-2d6c-11ea-8b79-e72f66907789.png)
> overview from ref.11

# non-concurrency vs concurrency 
一个简单的`go`关键字里面封装了复杂的GMP调度
```go
package main

import (
	"fmt"
)

func say(s string) {
	fmt.Println(s)
}

func main() {
	go say("i am the concurrency routine") // async, open a new goroutine
	say("i am the main routine") // sync
}
```

# waiting for goroutine
执行上面可能main执行完了，而`concurrency routine`还没有执行，有2种方式来等待`concurrency routine`也完成，

1. WaitGroup
    
    ```go
    package main
    
    import (
        "fmt"
        "sync"
    )
    
    func say(s string, wg *sync.WaitGroup) {
        defer wg.Done()
        fmt.Println(s)
    }
    
    func main() {
    
        var wg sync.WaitGroup
    
        for i := 1; i <= 10; i++ {
            wg.Add(1)
    
            go say(fmt.Sprintf("i am the concurrency routine %d", i), &wg) // open a new goroutine
        }
        fmt.Println("i am the main routine")
        wg.Wait()
    }
    ```

2. notice by channel

    ```go
    package main
    
    import (
        "fmt"
    )
    
    func say(str string, messages chan string) {
        messages <- str
    }
    
    func main() {
    
        messages := make(chan string)
    
        cnt := 10
        for i := 0; i < cnt; i++ {
            go say(fmt.Sprintf("i am the concurrency routine %d", i), messages) // open a new goroutine
        }
    
        for i := 0; i < cnt; i++ { // loop cnt should be <= cnt. if use for, then message must be close
            fmt.Println(<-messages)
        }
    
        fmt.Println("i am the main routine")
    }
    ```

3. or can using done channel
    
    ```go
    package main
    
    import (
        "fmt"
    )
    
    var done = make(chan bool)
    var msgs = make(chan string)
    
    func produce() {
        for i := 0; i < 10; i++ {
            msgs <- fmt.Sprintf("i am the concurrency routine %d", i)
        }
        close(msgs)
        done <- true
    }
    
    func consume() {
        for msg := range msgs {
            fmt.Println(msg)
        }
    }
    
    func main() {
        go produce() // usually loop inside the `go`
        go consume()
        <-done // block here until receive done
        fmt.Println("i am the main routine")
    }
    ``` 

# concurrency **communication**
多线程的通信在jvm里面一般是通过share-memory with lock/atomic，而go里面提倡的是channel
> Do not communicate by sharing memory; instead, share memory by communicating.

## share memory with lock
### non lock resulting in uncertainty
```go
package main

import (
	"fmt"
	"strconv"
	"sync"
	"sync/atomic"
)

var counter int32

func main() {
	var wg sync.WaitGroup

	for i := 0; i < 1000; i++ {
		wg.Add(1)
		go increment(strconv.Itoa(333), &wg)
	}

	wg.Wait()
	fmt.Println("Counter:", counter) // error result here
}

// count the input string char amount
func increment(name string, wg *sync.WaitGroup) {
	defer wg.Done()
	for _ = range name {
		counter++ // race conditions
	}
}
```

### using lock
```go
package main

import (
	"fmt"
	"strconv"
	"sync"
)

var (
	counter int32
	mu      sync.RWMutex
)

func main() {
	var wg sync.WaitGroup

	for i := 0; i < 1000; i++ {
		wg.Add(1)
		go increment(strconv.Itoa(333), &wg)
	}

	wg.Wait()
	mu.RLock()
	fmt.Println("Counter:", counter)
	mu.RUnlock()
}

// count the input string char amount
func increment(name string, wg *sync.WaitGroup) {
	defer wg.Done()
	mu.Lock()
	for _ = range name {
		counter++
	}
	mu.Unlock()
}
```

### using atomic
```go
package main

import (
	"fmt"
	"strconv"
	"sync"
	"sync/atomic"
)

var counter int32

func main() {
	var wg sync.WaitGroup

	for i := 0; i < 1000; i++ {
		wg.Add(1)
		go increment(strconv.Itoa(333), &wg)
	}

	wg.Wait()
	fmt.Println("Counter:", atomic.LoadInt32(&counter))
}

// count the input string char amount
func increment(name string, wg *sync.WaitGroup) {
	defer wg.Done()
	for _ = range name {
		atomic.AddInt32(&counter, 1)
	}
}
```

## channel
```go
package main

import (
	"fmt"
)

var msgs = make(chan int)

func produce() {
	for i := 0; i < 10; i++ {
		for _ = range "333" {
			msgs <- 1
		}
	}
	close(msgs)
}

func consume() {
	for msg := range msgs {
		fmt.Println(msg)
	}
}

func main() {
	go produce() // usually loop inside the `go`, so that the producer can close the msg

	counter := 0
	for msg := range msgs {
		counter += msg
	}
	fmt.Println("Counter:", counter)
}
```

```go
// most common usage
package main

import (
	"fmt"
	"sync"
)

func main() {
	fmt.Println("begin")
	wgProducers := sync.WaitGroup{}
	wgReceivers := sync.WaitGroup{}
	dataCh := make(chan int)

	go producer(&wgProducers, dataCh)

	counter := consumer(&wgReceivers, dataCh, 0)
	fmt.Println("Counter:", counter)
}

func producer(wgProducers *sync.WaitGroup, dataCh chan int) {
	for i := 0; i < 10; i++ {
		wgProducers.Add(1)
		go func(worker int) {
			defer wgProducers.Done()
			for v := 0; v < 100; v++ {
				fmt.Println(fmt.Sprintf("worker send i = %d, value = %d", worker, v))
				dataCh <- v
			}
		}(i)
	}
	wgProducers.Wait()
	close(dataCh) // key point, close in the same/one routine
}

func consumer(wgReceivers *sync.WaitGroup, dataCh chan int, cnt int) int {
	for i := 0; i < 5; i++ {
		wgReceivers.Add(1)
		go func(worker int) {
			defer wgReceivers.Done()
			for value := range dataCh {
				fmt.Println(fmt.Sprintf("worker rece i = %d, value = %d", worker, value))
				cnt += value
			}
		}(i)
	}
	wgReceivers.Wait() // if it's server, then no need to be wait here, can hold by others
	return cnt
}
```


### control/select
```go
package main

import (
	"fmt"
	"time"
)

func main() {

	c1 := make(chan string)
	c2 := make(chan string)

	go func() {
		c1 <- "one"
	}()

	go func() {
		c2 <- "two"
	}()

	for {
		select {
		case msg1 := <-c1:
			fmt.Println("received 1", msg1)
		case msg2 := <-c2:
			fmt.Println("received 2", msg2)
		default:
			fmt.Println("received nothing")
		}
		time.Sleep(time.Second * 1)
	}
}
```
### timeout
```go
// here is a global timeout 
package main

import (
	"fmt"
	"time"
)

func main() {
	c1 := make(chan string)
	c2 := make(chan string)

	go func() {
		c1 <- "one"
	}()

	go func() {
		c2 <- "two"
	}()

	timeout := time.After(5 * time.Second)

	for {
		select {
		case msg1 := <-c1:
			fmt.Println("received 1", msg1)
		case msg2 := <-c2:
			fmt.Println("received 2", msg2)
		case <-timeout:
			fmt.Println("timeout")
			return
		default:
			fmt.Println("received nothing")
		}
		time.Sleep(time.Second * 1)
	}
}
```

```go
// here is a local timeout for each loop
package main

import (
	"fmt"
	"time"
)

func main() {
	c1 := make(chan string)
	c2 := make(chan string)

	go func() {
		c1 <- "one"
	}()

	go func() {
		c2 <- "two"
	}()

	for {
		select {
		case msg1 := <-c1:
			fmt.Println("received 1", msg1)
		case msg2 := <-c2:
			fmt.Println("received 2", msg2)
		case <-time.After(5 * time.Second):
			fmt.Println("timeout")
			break
		}
	}
}
```

# deadlock
> fatal error: all goroutines are asleep - deadlock!

Go程序中死锁是指所有的goroutine在等待资源的释放，

causes: 
- 只在`单一`的goroutine里操作无缓冲信道，会导致死锁
- 非缓冲信道上如果发生流入无流出，或者仅流出无流入，会导致死锁
- 无缓存通道的`发送`数据(或关闭通道)和`读取`数据的操作不能放在**同一个goroutine**中(因为阻塞)

solutions: 
- 发送/读取无缓冲通道的数据
- 使用缓冲通道
- 应该在**生产者**的地方关闭channel，而不是消费的地方去关闭它，这样容易引起panic<sup>11
- 通常，先创建一个goroutine对通道进行操作，此时该goroutine会阻塞，然后再在(返回到)主goroutine中进行通道的`反向`操作，实现goroutine**解锁**<sup>12

```go
package main

import (
	"fmt"
)

func main() {
	ch := make(chan int)
	ch <- 1 // waiting forever for someone to read here, so causing deadlock
	fmt.Println(<-ch) // not reachable
}
```

# Reference
0. [Beating C with 70 Lines of Go](https://ajeetdsouza.github.io/blog/posts/beating-c-with-70-lines-of-go/)
0. [Locks versus channels in concurrent Go](https://opensource.com/article/18/7/locks-versus-channels-concurrent-go)
0. [Leveraging Go concurrency](https://livebook.manning.com/book/go-web-programming/chapter-9)
0. [LearnConcurrency](https://github.com/golang/go/wiki/LearnConcurrency)
0. [concurrency example](https://tour.golang.org/concurrency/9)
0. [A complete journey with Goroutines](https://medium.com/@riteeksrivastava/a-complete-journey-with-goroutines-8472630c7f5c)
0. [深入golang runtime的调度](https://zboya.github.io/post/go_scheduler/#%E7%B1%BB%E6%AF%94%E6%A8%A1%E5%9E%8B)
0. [Goroutine与GMP模型](https://www.bitlogs.tech/2019/03/goroutine%E4%B8%8Egmp%E6%A8%A1%E5%9E%8B/)
0. [How to Gracefully Close Channels](https://go101.org/article/channel-closing.html)
0. [Go: Deadlock](https://programming.guide/go/detect-deadlock.html)
0. [Go 并发的一些总结](https://segmentfault.com/a/1190000019582694)
0. [Go并发编程详解](https://studygolang.com/articles/15296)
0. [Concurrency guide](https://golang.org/doc/effective_go.html#concurrency)
