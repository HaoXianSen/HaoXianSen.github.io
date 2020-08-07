---
title: Java编译与反编译
tags: java
key: 19
modify_date: 2019-04-30 18:00:00 +08:00
---

记录一下看了[Java开发必会的反编译知识](http://blog.csdn.net/bjweimengshu/article/details/79225137)后关于Java的编译、反编译、字节码、源代码、机器码的note，

----
# Overview
`源码/源代码/Source code/.java` <-**javac**-> `字节码/Bytecode/.class` <-**JVM**-> `机器码/Machine code/原生码/Native Code`

----
# 编程语言
编程语言(programming language)分为，
- 低级语言，low-level language，直接用计算机指令编写程序
  - 机器语言，machine language
  - 汇编语言，assembly language
- 高级语言，high-level language，用语句（Statement）编写程序，语句是计算机指令的抽象表示
  - C
  - C++
  - Java
  - Python

![image](https://user-images.githubusercontent.com/8369671/80787011-e0804480-8bb7-11ea-97b7-b26e6ec5449c.png)
> high/low level language

计算机只能对`数字`做运算，`符号、声音、图像`在计算机内部都要用`数字`表示，指令也不例外，上表中的机器语言完全由十六进制数字组成。

最早的程序员都是直接用`机器语言`编程，但是很麻烦，需要查大量的表格来确定每个数字表示什么意思，编写出来的程序很不直观，而且容易出错，于是有了`汇编语言`。

把机器语言中一组一组的数字用助记符（Mnemonic）表示，直接用这些助记符写出汇编程序，然后让`汇编器`（Assembler）去查表把助记符替换成数字，也就把汇编语言翻译成了机器语言。

但是，汇编语言用起来同样比较复杂，后面，就衍生出了`C`、`C++`、`Java`、`Python`等高级语言。

----
# 什么是编译
编程语言有两种，一种低级语言，一种高级语言。可以这样简单的理解：**低级语言是计算机认识的语言、高级语言是程序员认识的语言**。

将`高级语言`转换成`低级语言`这个过程其实就是编译，C语言的语句和低级语言的指令之间不是简单的`一一对应`关系，C中的一条`a=b+1`语句要翻译成三条汇编或机器指令，这个过程称为编译（Compile），由编译器（Compiler）来完成。

用C语言编写的程序必须经过编译转成机器指令才能被计算机执行，`编译需要花一些时间`，这是用高级语言编程的一个缺点，然而更多的是优点。首先，用C语言编程更容易，写出来的代码更紧凑，`可读性`更强，出了错也更容易改正。

将便于`人`编写、阅读、维护的高级计算机语言所写作的`源代码`程序，翻译为`计算机`能解读、运行的低阶`机器语言`的程序的过程就是**编译**。负责这一过程的处理的工具叫做**编译器**。

Java语言中负责编译的编译器是一个命令：javac。
javac是收录于JDK中的Java语言编译器。该工具可以将后缀名为`.java`的源文件编译为后缀名为`.class`的可以运行于Java虚拟机的字节码。

.class类型的文件是JVM可以识别的文件。通常我们认为这个过程叫做Java语言的编译。其实，class文件仍然不是机器能够识别的语言，因为机器只能识别机器语言，还需要`JVM`**再将**这种class文件类型字节码转换成机器可以识别的机器语言。

----
# 什么是反编译
反编译的过程与编译刚好相反，就是将已编译好的编程语言还原到未编译的状态，也就是找出程序语言的源代码，即**将机器看得懂的语言转换成程序员可以看得懂的语言**。Java语言中的反编译一般指将class文件转换成java文件。

```
//编译前的源代码
public class switchDemoString {
    public static void main(String[] args) {
        String str = "world";
        switch (str) {
            case "hello":
                System.out.println("hello");
                break;
            case "world":
                System.out.println("world");
                break;
            default:
                break;
        }
    }
}
```

```
- 编译
   - javac switchDemoString.java
反编译
   - 方法1，javap -c switchDemoString.class
   - 方法2，java -jar cfr_0_125.jar switchDemoString.class --decodestringswitch false
```

```
//反编译后的源代码
public class switchDemoString {
    public static void main(String[] arrstring) {
        String string;
        String string2 = string = "world";
        int n = -1;
        switch (string2.hashCode()) {
            case 99162322: {
                if (!string2.equals("hello")) break;
                n = 0;
                break;
            }
            case 113318802: {
                if (!string2.equals("world")) break;
                n = 1;
            }
        }
        switch (n) {
            case 0: {
                System.out.println("hello");
                break;
            }
            case 1: {
                System.out.println("world");
                break;
            }
        }
    }
}
```

----
# 如何防止反编译
防止反编译和网络安全的防护一样，一般都只能提高攻击者的成本，而无法彻底防治，对应策略，
- 隔离Java程序
  - 让用户接触不到你的Class文件
- 对Class文件进行加密
  - 提高破解难度
- 代码混淆
  - 将代码转化为功能上等价，但是难以阅读和理解的形式
