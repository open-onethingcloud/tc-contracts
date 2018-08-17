## 抽奖合约奖池模型

该合约实现了抽奖活动奖池模型主要功能，共包含两个合约，LotteryControl控制合约与LotteryData数据合约，控制合约提供开发者访问合约的入口，数据合约处理、保存相关数据。



### 合约功能

- 添加、移除抽奖合约管理员账户地址
- 新建抽奖
- 设置抽奖合约参数配置
- 查看抽奖合约参数配置
- 开启抽奖
- 参与抽奖
- 查询抽奖信息
- 查询抽奖结果



### 合约部署

1. 部署LotteryData合约

2. 部署LotteryControl合约

3. 调用LotteryData合约 setLotteryControl方法，设置LotteryControl合约地址

   

### 使用方法

开发者或用户通过调用LotteryControl合约方法进行合约交互



#### 创建抽奖

开发者调用newLottery方法创建抽奖活动，该方法返回活动ID，开发者需保存活动ID，后续调用合约方法要求传入该活动ID；

创建后再调用setLotteryConfig进行活动规则设置，开发者可根据需求传入参数进行规则配置，配置参数说明如下。

```
  // 设置抽奖配置
  function setLotteryConfig (
    uint lotteryID,            //抽奖活动ID
    uint startTime,            //活动开始时间, Unix时间戳
    uint endTime,              //活动结束时间, Unix时间戳
    bool dayLimit,             //是否限制每天抽奖时间
    uint dayStartTime,         //每天抽奖开始时间
    uint dayEndTime,           //每天抽奖结束时间
    int timesPerItem,          //参与者抽奖次数限制
    uint amountPerAction,      //每次抽奖的金额 单位：链克
    uint openCondition,        //开奖条件，  抽奖模式为 0:奖池模式，奖池金额达到指定数量开奖(单位：链克)  1:开奖时间模式，达到指定时间开奖(Unix时间戳)  2:地址模式，参与用户账户地址达到指定数量开奖
    uint copies                //奖品平分成几份发放
    )
```

调用setLotteryConfig后，抽奖活动自动生效。



#### 参与抽奖

用户调用joinLottery方法参与抽奖，若满足抽奖规则，则成功参与，用户可在抽奖开启后查看抽奖结果；



#### 开启抽奖

**奖池金额、参与用户数量固定模式**

抽奖活动满足开奖条件时，合约内部会触发OpenLottery事件，开发者可通过监听该事件判断可以已开启抽奖，然后调用调用openLottery开启抽奖。若抽奖活动结束，仍未监听事件发生，开发者直接调用openLottery开启抽奖。



**开奖时间固定模式**

开发者在开奖时间到达后调用openLottery开启抽奖。



#### 查询抽奖

开启抽奖后抽奖活动最终有以下两种状态，开发者或用户可通过调用queryLotteryResult方法查看结果

- 满足开奖条件，合约内部自动执行抽奖，给中奖用户发送奖品，活动状态为已开奖
- 不满足开奖条件，合约内部自动退还参与抽奖用户相应的链克，活动状态为已退款



#### 抽奖机制

奖池内全部链克平分成N份(开发者可修改合约参数配置)， 依次将每份奖励随机分配给抽奖参与用户，一个用户可能获得多份奖励。