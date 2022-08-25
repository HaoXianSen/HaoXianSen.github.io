\---

title: position、anchorPoint、frame理解

tags: iOS

key: 107

\# article_header:

\# type: cover

\#  image:

\# src: https://user-images.githubusercontent.com/8369671/80915045-153ff780-8d82-11ea-9acf-6ccbf2b05d9d.png

\---

-----

#### 前情提要

​	     最近在学2d游戏框架SpriteKit，其中使用大量的AnchorPoint/position 来确定Node的位置，那本身来说对于anchorPoint、position的概念、以及他们之间互相起到什么作用，对于view又会造成什么影响，都是比较模糊的，所以再定位Node布局来说，就是一顿迷糊，正好工作这么多年了，还是对于这些基础的还是模糊，是有点说不过去了，所以我决定认真分析一下Frame、bounds、position、anchorPoint之间的关系，以及他们对显示的影响。

#### 进入正文

frame： 表示了一个view 在其superView坐标系具体位置，那么他的参照物是其父view

bounds：表示了一个view的本地坐标系下，参照物是自身，他的修改不会改变frame，但是会改变其的子view的位置，为什么呢？稍后我会画图解释

position：这是CALayer的属性，我的理解是他的物理中心点，他和anchorPoint有着密切的关系

anchorPoint：也是CALayer的属性，翻译过来叫做锚点，也就是固定的点，他的坐标系是以unit 坐标系定义，左上角为(0,0)， 右上角(1, 0), 左下角(0,1), 右下角(1,1)

好！概念都说完了，但是这个概念只能让我们理解一部分，并不能真实的理解到他们的具体作用，下面我们用图的概念去一点点理解

#### 深入

frame 没什么可说的，我们以前frame布局，用的再熟练不过了，他就是view在其父view中位置

如果我们修改了frame，那么就会直接影响到他的位置和大小。



对于bounds 来说，他是自身的坐标系，如果我们修改了他的origin，那么他的子view就会以这个点为为原点来计算位置，比如：一个红色的view，我们设置了他的bounds.origin为（-20， 20），那么他就会改变自己的本地坐标系的原点为-20，-20，那么当我们设置一个蓝色的子viewframe的origin为（0，0），那么这个子view就会向右下偏移20，因为当前左上角的原点为-20，-20，（0，0）点的位置在右下角偏移20的位置，所以最后看到蓝色view并不是靠着左上角。文字描述有点。。。费劲，还是想办法画图吧。。。

![image-20210929181748669](/Users/haoyh02/Library/Application Support/typora-user-images/image-20210929181748669.png)

大概就是这样的一个过程，所以bounds.origin的修改会导致子view的位置改变，那么修改bounds的size呢？ 改变自己bounds的size会使自身的大小发生变化，从而影响frame，不会影响父view



那么对于position 和anchorPoint，我受一片他人的文章影响，有一个很恰当的比喻：

一幅画，anchorPoint就相当于在这个画的四个角或者中间沾一块胶（或者你有高档的什么固定的都行。。），而position就相当于这块胶要沾在哪个位置，这么来说的话他应该是和anchor重合的，比如说position为墙壁的某个点，anchorPoint为画的中间（0.5，0.5），那么画就会沾到position的位置，我们view默认的position就是view的中心点相对于父view的点，所以如果我们改变anchor的话就类比刚才图片的问题，是那个角或者中点固定到这个position点而已。

也画个图吧。。。

![image-20210929183736725](/Users/haoyh02/Library/Application Support/typora-user-images/image-20210929183736725.png)

基本上通过上边的介绍，我想你和我都掌握这几个属性的真正含义。