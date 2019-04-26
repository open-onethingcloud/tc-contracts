## 投票系统合约模板 

该合约实现了投票系统主要功能，共包含两个合约，VoteControl控制合约与VoteData数据合约，控制合约提供访问合约的入口，数据合约处理、保存相关数据。 

### 合约功能

- 新建投票活动
- 设置、查看投票规则
- 投票
- 查看投票信息
- 查看投票结果
- 查看投票人信息



### 合约部署

1. 部署VoteData合约， 合约构造参数为开发者口袋账户地址
2. 部署VoteControl合约，合约构造参数为开发者账户地址和VoteData合约地址
3. 调用VoteData合约setVoteControlAddr设置VoteControl合约地址



### 使用方法

开发者或用户通过调用VoteControl合约方法进行合约交互 



#### 新建投票

开发者调用newVote方法创建投票活动

接口定义：

```
function newVote(
  string name          //投票活动名称
  )
  onlyOwner external
  returns (uint)
```



调用getLastestVote方法查询刚才上链的投票活动ID，后续查看更新该投票活动时要求传入投票活动ID值

接口定义：

```
  //查询最新的投票信息
  function getLastestVote()
    view external
    returns(
      uint,    //投票活动ID
      string   //投票活动名称
    )
```



创建后再调用setVoteRule方法进行活动规则设置，开发者可根据需求传入参数进行规则配置

接口定义：

```
  // 设置投票活动规则
  function setVoteRule(
    uint voteID,            //投票活动ID
    uint startTime,         //投票开始时间 Unix时间戳
    uint endTime,           //投票结束时间 Unix时间戳
    bool dayTimeLimit,      //是否限制每天投票时间 true:限制 false:不限制
    uint dayStartTime,      //每天投票开始时间 以整点为单位
    uint dayEndTime,        //每天投票结束时间 以整点为单位
    uint dayVoteLimit,      //每天总投票数限制
    uint voteLimitPerUser,  //每个账户投票数限制
    address[] blacklist,    //投票黑名单
    bytes32[] candidates    //投票候选人,总候选人数不超过300
    )
```

注：合约中候选人名称类型为bytes32,  要求传入的名称长度不超过32个字节,否则合约内部会自动截断

调用setVoteRule方法后，活动自动生效。 



#### 投票

用户调用vote方法进行投票，若满足投票规则，接口返回true，投票成功。

接口定义：

```
  // 投票
  function vote(
    uint voteID,         //投票活动ID
    uint candidateIndex  //候选人Index， 候选人列表中从0开始计算
    )
    isHuman external
    returns(
      int,     //返回码， 0：成功  1：活动未开始 2：活动结束 
                          3：不在当天投票时间段内 4：当天投票总次数达到上限 
                          5:该用户投票次数达到上限 6：黑名单用户 7：所投候选人不存在
      string   //错误码信息
    )
```



#### 查看投票结果

在投票过程中或投票结束后，用户调用getVoteResult方法查看投票结果。

接口定义：

```
  // 查看投票结果
  function getVoteResult(uint voteID)
    view external
    returns(
      bytes32[],  //候选人得票排名列表， 按投票数降序排列
      uint[]      //候选人获得票数
    )
```

注：返回数据中，候选人列表已按照得票数降序排序， 若存在得票数相同的情况，先获得相应票数的候选人排在前面， 用户根据需求处理排名数据。



#### 查看投票信息

用户调用getVoteInfo查看投票信息

接口定义：

```
  // 查看投票信息
  function getVoteInfo(uint voteID)
    view public
    returns(
      string,  //投票活动名称
      uint,     //投票人数
      uint,     //总票数
      uint,     //投票活动状态
      uint      //投票者信息数量
    )

```



#### 查看投票人信息

用户调用getVoteInfo查看投票人信息，由于投票用户可能过多，需要分批查询投票用户信息，每次查询的数量不超过100。

接口定义：

```
  // 查看投票人信息
  function getVoter(
    uint voteID,     //投票活动ID
    uint startIndex, //投票者起始位置Index, 
                       (startIndex +num)不大于getVoteInfo接口返回的投票者信息数量
    uint num         //查看投票者信息数量
    )
    view external
    returns(
      address[],  //投票者账户地址
      bytes32[],  //候选人名称
      uint[]      //投票数
    )
```

注： 返回数据中，投票者对应的候选人、投票数通过数组下标对应
