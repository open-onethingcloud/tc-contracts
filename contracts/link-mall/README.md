#### 链克商城合约



链克商城合约示例实现了一个网上商城的部分功能，合约内定义了商品、订单的数据结构与读写方式， 这些数据保存在区块链中，具有不可篡改的去中心化存储特性。



##### 合约数据

目前合约仅支持商品、订单数据，开发者可根据具体业务需求在此基础上进一步扩展。

- 商品属性： 商品id，商品名称， 商品价格

- 订单属性：订单付款方地址， 订单内包含的商品id、商品价格，购买数量

  

##### 合约功能

- 设置商品（商品上架、下架）
- 查看商品
- 设置订单（用户购买商品支付订单时调用）
- 查看订单



##### 合约测试

开发者在发布合约前应充分测试保证合约逻辑正确性。

合约测试推荐使用[Remix - *Solidity* IDE](http://www.baidu.com/link?url=RKiuLEbki9QNMvJoNSBQr0ZfquUtM8-gnwH3Fz3VQsIBNOihOry1tBFwzyJ7M92u)， Remix使用教程详见[Remix documentation](https://remix.readthedocs.io/en/latest/#)。



##### 合约部署

该合约只使用了一个合约实例LinkMall，直接部署LinkMall合约即可，具体部署方式见 [迅雷链开放平台合约接入流程](https://open.onethingcloud.com/site/docopen.html#5)。

提交合约时要求填写初始化参数，需要对合约构造函数中的参数进行编码，链克商城合约构造函数为：

```
constructor(address owner) Ownable(owner) public {}
```

参数owner表示商户的链克口袋地址，作为商品出售时商户的链克口袋收款地址，参数编码可通过[web3.eth.abi.encodeParameter](http://web3js.readthedocs.io/en/1.0/web3-eth-abi.html#encodeparameter)接口实现。



##### 使用注意

一个完整的网上商城系统包含商品管理、订单管理、配送方式、用户中心等功能模块，开发者在使用该合约开发时应注意以下事项：

- 该合约支持的功能特性目前较为单一，开发者在使用时需额外设计未包含在合约内的功能模块
- 合约中分别以商品id、订单id来标识商品、订单，开发者在生成商品id、订单id时应保证id唯一性
- 合约内只存储商品，订单数据，其他数据需要保存在第三方本地服务，比如：商铺信息、用户信息、订单用户关联数据
