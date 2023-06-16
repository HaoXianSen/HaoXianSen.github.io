---
title: MGJRouterKit 实现、优劣浅析
tags: iOS 组件化 路由中间件
key: 156
published: true
article_header:
    type: cover 
    image:
        src: https://img.win3000.com/m00/bf/12/3105168fd57dc74f49f1a7ac462c0b18.jpg 
---

### 代码浅析

#### 存

通过```MGJRouter``` 单例管理。并且缓存在```NSMutableDictionay *routes```, 那么我们来看一下，他具体缓存的数据结构是什么样子的？

例如 aa://bb/cc/dd

关键代码为：



```objc
+ (void)registerURLPattern:(NSString *)URLPattern toHandler:(MGJRouterHandler)handler
{
    [[self sharedInstance] addURLPattern:URLPattern andHandler:handler];
}

- (void)addURLPattern:(NSString *)URLPattern andHandler:(MGJRouterHandler)handler
{
    NSMutableDictionary *subRoutes = [self addURLPattern:URLPattern];
    if (handler && subRoutes) {
        subRoutes[@"_"] = [handler copy];
    }
}

- (NSMutableDictionary *)addURLPattern:(NSString *)URLPattern
{
    NSArray *pathComponents = [self pathComponentsFromURL:URLPattern];

    NSMutableDictionary* subRoutes = self.routes;
    
    for (NSString* pathComponent in pathComponents) {
        if (![subRoutes objectForKey:pathComponent]) {
            subRoutes[pathComponent] = [[NSMutableDictionary alloc] init];
        }
        subRoutes = subRoutes[pathComponent];
    }
    return subRoutes;
}


- (NSArray*)pathComponentsFromURL:(NSString*)URL
{

    NSMutableArray *pathComponents = [NSMutableArray array];
    if ([URL rangeOfString:@"://"].location != NSNotFound) {
        NSArray *pathSegments = [URL componentsSeparatedByString:@"://"];
        // 如果 URL 包含协议，那么把协议作为第一个元素放进去
        [pathComponents addObject:pathSegments[0]];
        
        // 如果只有协议，那么放一个占位符
        URL = pathSegments.lastObject;
        if (!URL.length) {
            [pathComponents addObject:MGJ_ROUTER_WILDCARD_CHARACTER];
        }
    }

    for (NSString *pathComponent in [[NSURL URLWithString:URL] pathComponents]) {
        if ([pathComponent isEqualToString:@"/"]) continue;
        if ([[pathComponent substringToIndex:1] isEqualToString:@"?"]) break;
        [pathComponents addObject:pathComponent];
    }
    return [pathComponents copy];
}
```



其中关键方法为```- (NSMutableDictionary *)addURLPattern:(NSString *)URLPattern```，此方法会将例如 aa://bb/cc/dd 这样一个URL生成如下的结构：

```json
{"aa": {"bb": {"cc": {"dd": {}}}}}
```

也就是说这个方法执行完之后，我们的routes就会变成这样的一个结构，最后把dd对应的{} return 回去。

然后通过 

```objc
 if (handler && subRoutes) {
        subRoutes[@"_"] = [handler copy];
    } 
```

将handler加入到字典里，最后routes就会变成

```
{"aa": {"bb": {"cc": {"dd": {"_": handler}}}}}
```

#### 取

关键代码为：

```objc
+ (void)openURL:(NSString *)URL withUserInfo:(NSDictionary *)userInfo completion:(void (^)(id result))completion
{
    URL = [URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *parameters = [[self sharedInstance] extractParametersFromURL:URL matchExactly:NO];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, NSString *obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            parameters[key] = [obj stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }];
    
    if (parameters) {
        MGJRouterHandler handler = parameters[@"block"];
        if (completion) {
            parameters[MGJRouterParameterCompletion] = completion;
        }
        if (userInfo) {
            parameters[MGJRouterParameterUserInfo] = userInfo;
        }
        if (handler) {
            [parameters removeObjectForKey:@"block"];
            handler(parameters);
        }
    }
}

- (NSMutableDictionary *)extractParametersFromURL:(NSString *)url matchExactly:(BOOL)exactly
{
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    
    parameters[MGJRouterParameterURL] = url;
    
    NSMutableDictionary* subRoutes = self.routes;
    NSArray* pathComponents = [self pathComponentsFromURL:url];
    
    BOOL found = NO;
    // borrowed from HHRouter(https://github.com/Huohua/HHRouter)
    for (NSString* pathComponent in pathComponents) {
        
        // 对 key 进行排序，这样可以把 ~ 放到最后
        NSArray *subRoutesKeys =[subRoutes.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }];
        
        for (NSString* key in subRoutesKeys) {
            if ([key isEqualToString:pathComponent] || [key isEqualToString:MGJ_ROUTER_WILDCARD_CHARACTER]) {
                found = YES;
                subRoutes = subRoutes[key];
                break;
            } else if ([key hasPrefix:@":"]) {
                found = YES;
                subRoutes = subRoutes[key];
                NSString *newKey = [key substringFromIndex:1];
                NSString *newPathComponent = pathComponent;
                // 再做一下特殊处理，比如 :id.html -> :id
                if ([self.class checkIfContainsSpecialCharacter:key]) {
                    NSCharacterSet *specialCharacterSet = [NSCharacterSet characterSetWithCharactersInString:specialCharacters];
                    NSRange range = [key rangeOfCharacterFromSet:specialCharacterSet];
                    if (range.location != NSNotFound) {
                        // 把 pathComponent 后面的部分也去掉
                        newKey = [newKey substringToIndex:range.location - 1];
                        NSString *suffixToStrip = [key substringFromIndex:range.location];
                        newPathComponent = [newPathComponent stringByReplacingOccurrencesOfString:suffixToStrip withString:@""];
                    }
                }
                parameters[newKey] = newPathComponent;
                break;
            } else if (exactly) {
                found = NO;
            }
        }
        
        // 如果没有找到该 pathComponent 对应的 handler，则以上一层的 handler 作为 fallback
        if (!found && !subRoutes[@"_"]) {
            return nil;
        }
    }
    
    // Extract Params From Query.
    NSArray<NSURLQueryItem *> *queryItems = [[NSURLComponents alloc] initWithURL:[[NSURL alloc] initWithString:url] resolvingAgainstBaseURL:false].queryItems;
    
    for (NSURLQueryItem *item in queryItems) {
        parameters[item.name] = item.value;
    }

    if (subRoutes[@"_"]) {
        parameters[@"block"] = [subRoutes[@"_"] copy];
    }
    
    return parameters;
}

```

取的逻辑呢，其实也是匹配我们已经存好的数据结构，例如 aa://bb/cc/dd

首先我们会匹配aa，然后取出aa 对应的dictionary，再匹配bb，同理获取dictionary，一直到for 循环完dd，取到最后的dictionary，然后如果URL有query， 会把query.name作为parameters key, value作为 key的值。这样我们就能取到最后匹配到的block。

其中有一个特殊处理就是：

```objc
 else if ([key hasPrefix:@":"]) {
                found = YES;
                subRoutes = subRoutes[key];
                NSString *newKey = [key substringFromIndex:1];
                NSString *newPathComponent = pathComponent;
                // 再做一下特殊处理，比如 :id.html -> :id
                if ([self.class checkIfContainsSpecialCharacter:key]) {
                    NSCharacterSet *specialCharacterSet = [NSCharacterSet characterSetWithCharactersInString:specialCharacters];
                    NSRange range = [key rangeOfCharacterFromSet:specialCharacterSet];
                    if (range.location != NSNotFound) {
                        // 把 pathComponent 后面的部分也去掉
                        newKey = [newKey substringToIndex:range.location - 1];
                        NSString *suffixToStrip = [key substringFromIndex:range.location];
                        newPathComponent = [newPathComponent stringByReplacingOccurrencesOfString:suffixToStrip withString:@""];
                    }
                }
                parameters[newKey] = newPathComponent;
                break;
            }
```

这块是其实做了URL路径中:xxx的特殊处理，将可变的Component匹配，并且将pattern里的Component作为key，openURL里的实际值作为value传入parameters。

最后，移除取出block&进行调用。

这样就完成了一次我们open工作（也就是匹配过程）。

#### 使用

```objc
// 注册
// 我们需要注册一个URLPattern 和 对应的block
[MGJRouter registerURLPattern:@"mgj://foo/bar" toHandler:^(NSDictionary *routerParameters) {
        [self appendLog:@"匹配到了 url，以下是相关信息"];
        [self appendLog:[NSString stringWithFormat:@"routerParameters:%@", routerParameters]];
    }];
// 使用
// 通过URL 掉起
 [MGJRouter openURL:@"mgj://foo/bar"];
```

更多使用请看MGJRouterKit demo.

### 优劣浅析

#### 疑问？

URL 应该怎么管理？

Register应该在哪里注册？

URL 不能传递常规参数怎么办？比如我们要传一个block、image、data、object？

缓存结构内存常驻？

#### 对于疑问，我觉得

* URL 怎么管理？

  首先URL 肯定需要统一管理，并且采用常量/宏定义，避免URL写的到处都是难管理和硬编码。

  那么如果是组件化，

  第一种方案：

  我们可能得在Route组件里，写一个.h， 里面定义URL

  如果多项目复用，或者工程很庞大，那么这个URL定义会非常多，查看管理起来也是一个比较严重的问题。

  第二种方案：

  module 自己隔离接口层，定义module内URL。

  相对来说，我更喜欢第二种方案，定义、功能都明确，不存在多工程复用、迁移问题。

* Register应该在哪里注册？

  register按理我理解，也需要相对统一管理。

  那么对应的也可以有两种方案：

  第一种方案：

  主工程统一定义，但是这种就会主工程耦合Module严重，主工程不够单一

  第二种方法：

  依然是module隔离接口层，并且给予一个注册/启动方法，所有需要注册的module内的URL，在模块内注册，主工程只要注册该模块就可以使用。Module之间其实没有依赖

* URL 不能传递常规参数怎么办？比如我们要传一个block、image、data、object？

  其实MGJ也想到了这个问题，所以提供了API ```\+ (void)openURL:(NSString *)URL withUserInfo:(NSDictionary *)userInfo completion:(void (^)(id result))completion``` 这个方法支持我们传递userInfo，字典是完全支持非常规参数的。

  但是其实URL里是无法体现出来的。只能通过MGJRouterParameterUserInfo 这个key拿到userInfo，取里边的值，参数就会不透明。

  那么实际使用中，我们可能就得看具体的实现/注释，判断我们需要userinfo传的参数。

* 缓存结构内存常驻？

  从结构来说，他是dictionary嵌套，会不会导致内存过大？

  下面是我的实验方法：

  ```objc
  - (void)demoTestMoreRegistURL {
      NSInteger count = 1000000;
      for (NSInteger i = 0; i < count; i++) {
          [MGJRouter registerURLPattern:[NSString stringWithFormat:@"mgj://test%ld/demo%ld/performance%ld", i, i, i] toHandler:^(NSDictionary *routerParameters) {
              [self appendLog:@"匹配到了 url，以下是相关信息"];
              [self appendLog:[NSString stringWithFormat:@"routerParameters:%@", routerParameters]];
          }];
      }
  }
  ```

  ![image-20230612205259003](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230612205259image-20230612205259003.png)

​	测试采用的是模拟器iphone14，从测试数据来看，100-10000个URL，内存相差并不大，但是URL数量达到1000000的时候内存突然暴增来到690M，某些设备可能会导致内存crash。

​	所以一般情况下，内存占用还好，但是我们项目庞大，路由达到百万级别还得慎用。

总体来说，都有相对的一些解决方案/代替方案，但是我觉得根本上存在的问题是不太好解决的，比如URL管理，即使分离管理，还是可能出现庞大的问题。



### 总结

可以说MGJRouter从设计上、实现上来说还是非常不错的，劣势呢也不全是说设计者的问题，而是基于URL本身存在的问题。但是选择内存常驻确实可能在量级过大的时候导致严重问题。

