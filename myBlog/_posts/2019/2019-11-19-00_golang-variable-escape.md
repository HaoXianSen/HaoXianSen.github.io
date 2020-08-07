---
title: golang传值与传地址的内存逃逸
tags: golang
key: 86
aside:
  toc: true
article_header:
  type: cover
  image:
    src: https://user-images.githubusercontent.com/8369671/69413213-594abd00-0d4b-11ea-92fd-4e245b8681e9.png
---

# Overview
## 现象
go语言逃逸
为了提高效率，常常将pass-by-value(传值)***升级***成pass-by-reference(传地址，其实还是传值，只是传参类型是引用类型，这样就不是copy内容，而是copy地址),

    - 传值，copy一份到该线程**栈**中，没有gc，但是会在栈中消耗一定内存
        - 当参数为变量自身的时候，复制是在栈上完成的操作，开销远比变量逃逸后动态地在`堆`上分配内存少(即此时传值更优)
    - 传地址，全局只有一份减少复制，但是会产出gc
        - 不要盲目使用变量的指针作为函数参数，虽然它会减少复制操作

在go里面只有**传值**，都是一个副本，一份拷贝<sup>[4]<sup>，

    - 拷贝的内容是非引用类型(int、string、struct等)时，在fun(args)中就无法修改原内容数据
    - 有的是引用类型(指针、map、slice、chan等)，那么此时就可以修改原内容数据


## 产生原因
Go逃逸分析最基本的原则是：如果一个函数返回的是一个(局部)变量的地址，那么这个变量就发生逃逸。(该变量的作用域从小范围拓展到大范围)
```go
package main

func main() {
	a := f1()
	*a++
}

func f1() *int {
	i := 1
	return &i // i作用域从f1()扩大f1+main了，所以这里i逃逸了
}
```

## 使用原则
- 大变量(大数组，大map)使用传地址
- 一个函数**返回**(逃逸)如果被频繁gc，应该使用传值

> 最后，尽量写出少一些逃逸的代码，提升程序的运行效率

# 命令
```
go run -gcflags "-m -l" main.go
```

```shell
➜  gotest git:(master) go run -gcflags "-m -l" main.go
# command-line-arguments
./main.go:15:12: Call1 u does not escape
./main.go:11:13: main &a does not escape
./main.go:11:24: main &User literal does not escape
➜  gotest git:(master) 
```

# [例子](https://itnext.io/the-top-10-most-common-mistakes-ive-seen-in-go-projects-4b79d4f6cd65)
- 在Pointers! Pointers Everywhere! 这一节

```go
package main

import (
	"testing"
)

type foo struct {
	ID            string  `json:"_id"`
	Index         int     `json:"index"`
	GUID          string  `json:"guid"`
	IsActive      bool    `json:"isActive"`
	Balance       string  `json:"balance"`
	Picture       string  `json:"picture"`
	Age           int     `json:"age"`
	EyeColor      string  `json:"eyeColor"`
	Name          string  `json:"name"`
	Gender        string  `json:"gender"`
	Company       string  `json:"company"`
	Email         string  `json:"email"`
	Phone         string  `json:"phone"`
	Address       string  `json:"address"`
	About         string  `json:"about"`
	Registered    string  `json:"registered"`
	Latitude      float64 `json:"latitude"`
	Longitude     float64 `json:"longitude"`
	Greeting      string  `json:"greeting"`
	FavoriteFruit string  `json:"favoriteFruit"`
}

type bar struct {
	ID            string
	Index         int
	GUID          string
	IsActive      bool
	Balance       string
	Picture       string
	Age           int
	EyeColor      string
	Name          string
	Gender        string
	Company       string
	Email         string
	Phone         string
	Address       string
	About         string
	Registered    string
	Latitude      float64
	Longitude     float64
	Greeting      string
	FavoriteFruit string
}

func byPointer(in *foo) *bar {
	return &bar{
		ID:            in.ID,
		Address:       in.Address,
		Email:         in.Email,
		Index:         in.Index,
		Name:          in.Name,
		About:         in.About,
		Age:           in.Age,
		Balance:       in.Balance,
		Company:       in.Company,
		EyeColor:      in.EyeColor,
		FavoriteFruit: in.FavoriteFruit,
		Gender:        in.Gender,
		Greeting:      in.Greeting,
		GUID:          in.GUID,
		IsActive:      in.IsActive,
		Latitude:      in.Latitude,
		Longitude:     in.Longitude,
		Phone:         in.Phone,
		Picture:       in.Picture,
		Registered:    in.Registered,
	}
}

func byValue(in foo) bar {
	return bar{
		ID:            in.ID,
		Address:       in.Address,
		Email:         in.Email,
		Index:         in.Index,
		Name:          in.Name,
		About:         in.About,
		Age:           in.Age,
		Balance:       in.Balance,
		Company:       in.Company,
		EyeColor:      in.EyeColor,
		FavoriteFruit: in.FavoriteFruit,
		Gender:        in.Gender,
		Greeting:      in.Greeting,
		GUID:          in.GUID,
		IsActive:      in.IsActive,
		Latitude:      in.Latitude,
		Longitude:     in.Longitude,
		Phone:         in.Phone,
		Picture:       in.Picture,
		Registered:    in.Registered,
	}
}

func byPointer2(in *foo) *foo {
	in.Address = "sg"
	return in
}

func byValue2(in foo) foo {
	in.Address = "sg"
	return in
}

var input foo
var output1 *bar
var output2 bar
var output3 *foo
var output4 foo

func BenchmarkByPointer(b *testing.B) {
	var r *bar
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		r = byPointer(&input)
	}
	output1 = r
}

func BenchmarkByValue(b *testing.B) {
	var r bar
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		r = byValue(input)
	}
	output2 = r
}

func BenchmarkByPointer2(b *testing.B) {
	var r *foo
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		r = byPointer2(&input)
	}
	output3 = r
}

func BenchmarkByValue2(b *testing.B) {
	var r foo
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		r = byValue2(input)
	}
	output4 = r
}

/*
➜  gotest git:(master) go test -bench=. -gcflags "-m -l -N"
# gotest [gotest.test]
./main_test.go:74:3: &bar literal escapes to heap                 <--------
./main_test.go:53:16: leaking param: in to result ~r1 level=0
./main_test.go:78:14: leaking param: in to result ~r1 level=0
./main_test.go:103:17: leaking param: in to result ~r1 level=0
./main_test.go:108:15: leaking param: in to result ~r1 level=0
./main_test.go:119:25: BenchmarkByPointer b does not escape
./main_test.go:123:17: BenchmarkByPointer &input does not escape
./main_test.go:128:23: BenchmarkByValue b does not escape
./main_test.go:141:18: &input escapes to heap                     <--------
./main_test.go:137:26: BenchmarkByPointer2 b does not escape
./main_test.go:146:24: BenchmarkByValue2 b does not escape
# gotest.test
/var/folders/v4/_kwdbjk979bbk2fg_x5g9glm0000gn/T/go-build138216855/b001/_testmain.go:46:42: testdeps.TestDeps literal escapes to heap
goos: darwin
goarch: amd64
pkg: gotest
BenchmarkByPointer-12           20000000                91.4 ns/op
BenchmarkByValue-12             30000000                47.0 ns/op
BenchmarkByPointer2-12          500000000                3.08 ns/op
BenchmarkByValue2-12            50000000                26.4 ns/op
PASS
ok      gotest  6.606s
➜  gotest git:(master)
*/


// 这里在byPointer函数里面构造的*bar变量发生了逃逸
```

# Reference
0. [Leader 这样说对吗？还是自己动手验证 Go 逃逸分析](https://mp.weixin.qq.com/s/JxWlI2LRXQX2kHxMQzJRPw)
0. [golang 逃逸分析](https://purewhite.io/2019/03/25/golang-escape-check/)
0. [Go变量逃逸分析](https://www.cnblogs.com/itbsl/p/10476674.html)
0. [Go语言参数传递是传值还是传引用](https://www.flysnow.org/2018/02/24/golang-function-parameters-passed-by-value.html)
