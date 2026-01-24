## **一、问题描述**

### **现象**

iPhone 配置 Charles 代理进行抓包调试后，打开通过 Xcode 安装App 时，弹出以下提示：

> 无法验证 App
> 
> 
> 需要互联网连接以验证是否信任开发者 "XXX"
> 

 App 无法启动，导致 Debug 调试工作无法进行。造成每次都需要先断掉代理再运行APP，非常麻烦。

---

## **二、原因分析**

### **根本原因**

Charles 开启 **SSL Proxying** 后，会对 HTTPS 请求进行中间人解密。iPhone 在打开需要验证的 App 时，会尝试连接 Apple 的验证服务器：

plain

```
ppq.apple.com

```

由于该请求被 Charles 拦截并使用 Charles 的根证书重新签名，Apple 服务器返回的响应无法被正确验证，导致开发者信任检查失败。

### **流程示意**

plain

```
iPhone App 启动
    ↓
请求 Apple 验证服务 (ppq.apple.com)
    ↓
被 Charles SSL 代理拦截
    ↓
证书链验证失败
    ↓
弹出「无法验证 App」

```

---

## **三、解决方案**

### **在Charles 排除 Apple 验证域名**

在 Charles 中将 Apple 的验证域名加入 SSL 排除列表，使其不被解密。

**步骤：**

1. 打开 Charles，进入菜单 **Proxy → SSL Proxying Settings**
2. 切换到 **Exclude** 标签页
3. 点击 **Add**，添加以下域名：

plain

```
Host: ppq.apple.com
Port: 443

```

1. 如需更完整的排除，可以添加：

plain

```
*.apple.com
*.mzstatic.com

```

1. 点击 **OK** 保存
2. iPhone 上重新打开 App 验证

> 注意： 排除后这些域名的请求将无法在 Charles 中查看。
> 

---

## **四、验证成功后的注意事项**

### **验证有效期**

- 开发者信任验证 **不需要每次都进行**
- 首次验证成功后，在证书有效期内或一定时间内无需重复验证
- 只有更换证书、重新安装 App 或长时间未打开时才需要重新验证

---

## **五、总结**

| **问题** | **iPhone 配置 Charles 后无法验证 App 开发者** |
| --- | --- |
| 原因 | SSL 代理拦截了 Apple 验证服务请求 |
| 核心解法 | 验证时临时绕过代理，让 iPhone 直连 Apple 服务器 |

---

**相关链接：**

- Charles 官方文档：https://www.charlesproxy.com/documentation/
