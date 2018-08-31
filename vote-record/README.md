## 投票信息合约模板 

投票信息合约实现了投票信息记录功能，投票信息保存在区块链中不可篡改，所有用户都可查看投票信息，保证了投票数据安全、真实，公正等特性。



### 合约功能

- 投票信息上链
- 查看投票信息



### 合约部署

部署VoteRecord合约，合约构造参数为开发者链克口袋账户地址。



### 使用方法

#### 投票信息上链

用户调用record方法将投票信息上链

接口定义：

```
  //投票信息上链
  function record(
      string name,                     //投票活动名称
      string rule,                     //投票规则
      bytes32[] candidate,             //候选人排名列表， 按得票数降序排列, 候选人数不超过300
      uint[] voteNum,                  //得票数列表
    )
    external
    returns(uint)
```

注：传入参数中，用户应保证候选人列表按照得票数降序排序，合约内不会做排序处理； 合约内使用合约方法调用发起方的链克口袋地址作为该投票信息记录者。



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



若投票人数过多，可分批多次调用recordVoter方法将投票人信息上链,  每次上链的投票人信息数量不超过100。

接口定义：

```
  //投票人信息上链
  function recordVoter(
    uint voteID,                //投票活动ID
    address[] voters,           //投票者账户地址列表
    bytes32[] candidates,       //所投候选人列表
    uint[] counts               //所投票数
    )
    external
    returns(bool)
```



#### 查看投票信息

用户调用getVoteInfo查看投票信息

接口定义：

```
  //查看投票信息
  function getVoteInfo(
    address recorder,           //信息记录者地址
  	uint voteID                 //投票活动ID
  	)
    external
    returns(
      string,                     //投票活动名称
      string,                     //投票规则
      bytes32[],                  //候选人列表
      uint[],                     //得票数列表
      uint,                       //投票者信息数量
    )
```



调用getVoterInfo批量查看投票人信息，每次查看投票人信息数量不超过100

接口定义：

```
  //查看投票人信息
  function getVoterInfo(
    address recorder,   //信息记录者地址
    uint voteID,        //投票活动ID
    uint startIndex,    //投票人信息起始位置, 
    					(startIndex+num)不大于getVoteInfo接口返回的投票者信息数量
    uint num            //查看投票人信息数量
    )
    external
    returns(
      address[],        //投票者账户地址列表
      bytes32[],        //所投候选人列表
      uint[]            //所投票数
    )
```

