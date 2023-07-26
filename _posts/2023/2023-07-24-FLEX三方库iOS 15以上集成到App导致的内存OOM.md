---
title: FLEX在iOS15 以上设备的OOM排查
tags: [iOS]
key: 158 
published: false
article_header:
    type: cover 
    image:
        src: https://cdn.pixabay.com/photo/2017/01/18/16/46/hong-kong-1990268_1280.jpg
---

### 起因

从iOS 15 开始我们发现[FLEX](https://github.com/FLEXTool/FLEX) 三方库在我们的iOS 工程无法使用，表现为ExploreToolBar可以正常显示，但是只要点击ToolBar上任何按钮都会发生内存占用暴增，导致内存崩溃（即OOM），这个问题虽然发现的很早，但是原因和方案一直没有去探索。导致其实有的时候我们遇到想要Debug的一些功能只能用iOS 15以下的一些设备去排查。甚至都想关掉FLEX。另外FLEX提供的DEBUG功能确实是非常的丰富，对于我们开发来说也是帮助很大，所以我觉得还是有必要排查清楚为什么会导致OOM，又该怎么去解决。（当然近期我也在github Flex 进行的反馈，至今没有接收到回复...）

### 排查

#### 排查发生崩溃的原因（OOM）

其实最早之前我并不知道，是因为OOM崩溃的，直到开始探究为啥崩溃的时候才发现。发现的路径也很简单，

**1、在点击explorerBar的按钮之后，整个UI会处于无法点击的状态，查看CPU内存占用会达到100%；**

**2、一段时间后，App会意外退出，也就是crash掉，debug Xcode会提示，内存占用过大，而crash。**

#### 排查是否是iOS 15 以上设备都会OOM

为什么会想到排查这一步，原因是当我们出现三方库问题时候，我们都会去官方的github issues 上看看是否已经出现这样的问题和解决方案。但是当我去git issues上看时候，并未发现这样的问题。那么首先我们需要排除一下是不是iOS 15以上通用问题。如果不是，那么可能就是我们的App专有问题。

于是，我写了一个demo app， 架构为tabbar->navigation->controller, 启动时候，代开FLEX，然后发现并未出现crash，内存占用也正常，各个功能也正常。

接着我又按照我们现有App的架构，改造了这个demo，除了页面没有内容，其他的架构可以说是一模一样，同样也没有发现crash。

OK，那么基本可以确认这不是一个iOS 15以上的普遍的crash，**而是我们App的专有问题了。**

接着，我就猜想可能是app中某些库，或者某些runtime hook 导致了冲突，发生了OOM。

#### 排查发生OOM的节点

首先我们需要从入口开始排查，入口则是点击ExploreBar的按钮的Action，我们以“menu”的事件出发。

![image-20230724151251377](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230724151252image-20230724151251377.png)

ExploreBar 对应的Controller为FLEXExplorerViewController， menu对应的事件为：

```objc
- (void)toggleMenuTool {
    [self toggleToolWithViewControllerProvider:^UINavigationController *{
        return [FLEXNavigationController withRootViewController:[FLEXGlobalsViewController new]];
    } completion:nil];
}

- (void)toggleToolWithViewControllerProvider:(UINavigationController *(^)(void))future
                                  completion:(void (^)(void))completion {
    if (self.presentedViewController) {
        // We do NOT want to present the future; this is
        // a convenience method for toggling the SAME TOOL
        [self dismissViewControllerAnimated:YES completion:completion];
    } else if (future) {
        [self presentViewController:future() animated:YES completion:completion];
    }
}

```

从Action方法分析，得出，其实点解“menu”之后，会出发初始化FLEXNavigationController 和 它的rootViewController：FLEXGlobalsViewController， 然后将FLEXNavigationController 进行modal出来。

从这部分代码来看，处理简单，也不存在造成OOM的疑点。

那么可能会造成OOM就出现在了FLEXNavigationController 或者FLEXGlobalsViewController里。我们接着再来看FLEXNavigationController：

（：大片的代码我就不粘贴了，重点粘贴一下分析出可能OOM的代码

FLEXNavigationController 主要是去实现了1. 给NavigationBar 增加了一些手势，包括点击、长按、轻扫，以及他们的手势处理（iOS 13 PresentStyle 为UIModalPresentationAutomatic、UIModalPresentationFormSheet、UIModalPresentationPageSheet会自带轻扫手势，也就是下拖，所以iOS 13以上为增加手势）2. 给controllers增加done rightNavigationBarItem，分别在push、viewWillAppear时候。

```objective-c
// 此代码为去除了一些无关的代码，只留了核心代码
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.beingPresented && !self.didSetupPendingDismissButtons) {
        for (UIViewController *vc in self.viewControllers) {
            [self addNavigationBarItemsToViewController:vc.navigationItem];
        }
    }
}
```

```objc
// 此代码为去除了一些无关的代码，只留了核心代码
- (void)addNavigationBarItemsToViewController:(UINavigationItem *)navigationItem {
    // Give root view controllers a Done button if it does not already have one
    UIBarButtonItem *done = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(dismissAnimated)
    ];
    
    // Prepend the button if other buttons exist already
    NSArray *existingItems = navigationItem.rightBarButtonItems;
    if (existingItems.count) {
        navigationItem.rightBarButtonItems = [@[done] arrayByAddingObjectsFromArray:existingItems];
    } else {
        navigationItem.rightBarButtonItem = done;
    }
}
```

下面，我们去分析一下FLEXGlobalsViewController，FLEXGlobalsViewController的继承链为 FLEXGlobalsViewController->FLEXFilteringTableViewController->FLEXTableViewController->UITableViewController。所以对于我们每一个父类其实都不可以放过。具体我们发现FLEXTableViewController留了初始化init方法，直接初始tableView的style，以及loadView去替换为自己的FLEXTableView为Controller的view和初始化ToolbarItem，以及正常的viewcontroller生命周期函数(:具体代码片段就不粘贴了:)

对于FLEXFilteringTableViewController则只是实现了loadView方法，设置代理以及注册cell；

而对于FLEXGlobalsViewController，则是正常的生命周期方法，以及定制化的一些处理。

OK，相关代码控制器逻辑已经分析清楚，下面我们分别在FLEXNavigationController、FLEXGlobalsViewController以及他的父类、基类的生命周期方法里打断点。然后点击ExploreBar触发，看他的执行。

最后执行为：FLEXGlobalsViewController(init) -> FLEXTableViewController(init)  ->  FLEXNavigationController(viewDidLoad:) -> FLEXNavigationController(viewWillAppear:) 

然后就进入界面卡死，内存占用不断增加的状态。ok，那么现在排除到最后执行到FLEXNavigationController(viewWillAppear:) ，正常执行完这个后会执行rootViewController的生命周期方法。

那么我们大概率可以分析出，造成OOM的节点为FLEXNavigationController(viewWillAppear:) ，如上截图，FLEXNavigationController(viewWillAppear:) 其实也很简单，也就是给他的ViewController的navigationItem增加一个done的rightItem。

我们尝试，把下面的代码注释掉再次运行：

```objc
if (self.beingPresented && !self.didSetupPendingDismissButtons) {
        for (UIViewController *vc in self.viewControllers) {
            [self addNavigationBarItemsToViewController:vc.navigationItem];
        }
    }
```

果然，没有发生OOM，**也就是说造成OOM的节点为给VC的navigationItem设置rightBarButtonItem。**

#### 进一步排查原因

然后一个问题就出现在脑海，那么为什么同样的排查demo设备就没问题呢？

所以我们借助Instrument做一下Leak查看，Instrument最后结果为：

![image-20230724154508581](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230724154508image-20230724154508581.png)

![image-20230724154621958](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230724154622image-20230724154621958.png)

大概可以看出，itemBarbutton处于不断的一个布局，最后导致OOM。（：当然这个解释，我自己都不能说服。我还想知道为什么。

所以我想要看看是否有其他的方式探索，找到其罪魁祸首。

### 进阶

#### 尝试采用寄存器追踪法

采用断点查看汇编，并且采用读取寄存器。并没有找到根本原因。有兴趣的请学习https://juejin.cn/post/6945393466218119182

#### 三方库排除法

1、逐量将崩溃App的疑似私有库三方库，加入到demo app中。做逐个排除。

最后结果也没有崩溃，逐步排除是因为View、ViewController、NavigationController的hook导致的互相影响crash。

2、 将崩溃App最简化，也就是移除启动的各种加载逻辑。只包括keyWindow、RootViewController。

结果依然发生崩溃。

#### 继续断点排查

1、既然是因为外部给ViewControllers设置NavigationItem添加RightNavigationItem导致的crash，那么将navigationController 给viewControllers 的代码，移植到我们自己的CustomNavigationController。便于更好的排查问题。

2、 断点一步一步的走。

突然😱，发现了调用到了我们防护容器类的方法。难道是防护容器的hook出现了问题...

3、排查哪个容器类的hook出现问题

将所有容器类的hook注释掉，逐个打开测试，最后发现只有打开下面的hook时候会出现crash

```objc
[objc_getClass("__NSDictionaryM") gz_swizzleSEL:@selector(setObject:forKeyedSubscript:) withSEL:@selector(gz_setObject:forKeyedSubscript:)];

- (void)gz_setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
    if (!obj)
    {
        return;
    }
    if (!key)
    {
        return;
    }
    [self gz_setObject:obj forKeyedSubscript:key];
}

```



这个方法是采用subscript复制会调用，比如```dict[@"key"] = value```。

然后我们一直打断点，最后发现了，autolayout的一个可变数组里存了一些Constraint，然后一直循环的赋值里边的key的value为nil，如下图：

![image-20230725180836928](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230725180837image-20230725180836928.png)

### 分析

👌🏻，通过上面的探寻，我们可以得出，可能是navigationItem赋值的时候触发了它的布局，布局呢，会存有它的各个约束字典，然后可能在iOS 16上需要移除（调整）约束，将key置为nil，然后不断的检测是否移除正确，如果没有移除会继续移除，而我们hook让其return出去，导致keyValue无法移除。造成循环。内存暴增、卡死界面。

所以我们需要修改一下我们hook，hook，不应该检测value是否存在，只需要检测key即可。

### 结果

最后的结果如分析所得。从开始的我们以为是FLEX本身的问题，到最后真凶的出现，确实经历了好多天，有的时候真想放弃，直接修改复制Item的时机，最后还是为了探索真理而坚持。

只要坚持不放弃，一切问题都可以解决。



