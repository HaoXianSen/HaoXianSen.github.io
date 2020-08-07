---
title: "Mastering Bitcoin V2 Note"
tags: bitcoin
key: 16
modify_date: 2019-04-30 18:00:00 +08:00
---

# Overview
记录一下个人关于这本书的阅读，
- [精通比特币 第二版](http://book.8btc.com/books/6/masterbitcoin2cn/_book//)
- [Mastering Bitcoin 2nd Edition](https://github.com/bitcoinbook/bitcoinbook/tree/second_edition)

### [比特币单位](https://en.bitcoin.it/wiki/Units)
- 1聪比特币/satoshi/sat，一亿分之一比特币
- 1毫比特币/millibit/mBTC，一千分之一比特币
- 1比特币/BTC
- 网络最大数量，2100万BTC

![image](https://user-images.githubusercontent.com/8369671/80787236-98155680-8bb8-11ea-9992-20d47e886259.png)
> 比特币核心架构

### 区块结构
- block size
- block header
  - version
  - previous block hash
  - merkle root
  - timestamp
  - difficulty target
  - nonce
- transaction counter
- transcations

### 合约币（Counterparty）
- 合约币是在比特币之上建立的协议层。与“染色币”类似的“合约币协议”提供了创建和交易虚拟资产和代币的能力。此外，合约币提供了去中心化的资产交换。合约币还在实施基于Ethereum虚拟机（EVM）的智能合同

### 可路由的支付通道（闪电网络）
- 闪电网络是一种端到端连接的双向支付通道的可路由网络。这样的网络可以允许任何参与者穿过一个通道路由到另一个通道进行支付，而不需要信任任何中间人。闪电网络由Joseph Poon和Thadeus Dryja于2015年2月首次描述，其基础是许多其他人提出和阐述的支付通道概念
- “闪电网络”是指路由支付通道网络的具体设计，现已由至少五个不同的开源团队实施。这些的独立实施是由“闪电技术基础”（BOLT）论文中描述的一组互通性标准进行协作
- 闪电网络的原型实施已经由几个团队发布。现在，这些实现只能在testnet上运行，因为它们使用segwit，还没有在比特币区块主链（mainnet）上激活

![image](https://user-images.githubusercontent.com/8369671/80787240-9ba8dd80-8bb8-11ea-95f5-9538f6f1f2f3.png)
> Lightning Network

### 隔离见证
- 隔离见证（segwit）是一次比特币共识规则和网络协议的升级，其提议和实施将基于BIP-9 软分叉方案，目前（2017年中）尚待激活
- 隔离见证就是比特币的一种结构性调整，旨在将见证数据部分从一笔交易的scriptSig（解锁脚本）字段移出至一个伴随交易的单独的见证数据结构。客户端请求交易数据时可以选择要或不要该部分伴随的见证数据

### [比特币白皮书](http://book.8btc.com/books/6/masterbitcoin2cn/_book//appdx-bitcoinwhitepaper.html)
