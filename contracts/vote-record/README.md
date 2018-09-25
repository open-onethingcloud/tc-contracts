## 投票信息合约模板 

投票信息合约实现了投票信息记录功能，投票信息保存在区块链中不可篡改，所有用户都可查看投票信息，保证了投票数据安全、真实，公正等特性。



### 合约功能

- 投票信息上链
- 查看投票详细信息
- 查看投票信息列表



### 合约部署

部署VoteRecord合约，合约构造参数为开发者链克口袋账户地址。



### 使用方法

#### 投票信息上链

用户调用record方法将投票信息上链

接口定义：

```
  //投票信息上链
  function record(
      bytes32 name,                    //投票活动名称
      string rule,                     //投票规则
      bytes32[] candidates,            //候选人列表
      uint[] voteNums                  //得票数列表
    )
    onlyOwner external
    returns(uint)
```

注：传入参数中，用户应保证候选人列表按照得票数降序排序，合约内不会做排序处理; 合约中投票活动名称、候选人名称、投票人类型为bytes32, 要求传入的名称长度不超过32个字节,否则合约内部会自动截断



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



若投票人数过多，可分批多次调用recordVoter方法将投票人信息上链，每次上链的投票人信息数量不超过100。

接口定义：

```
  //投票人信息上链, 每上链投票人信息数量不超过100
  function recordVoter(
    uint voteID,                //投票活动ID
    bytes32[] voters,           //投票人列表
    bytes32[] candidates,       //所投候选人列表
    uint[] voteNums             //所投票数
    )
    onlyOwner external
    returns(bool)
```
注：投票人类型为bytes32， 开发者可用电话号码、用户ID、用户名等来标识投票人，并自行保证投票人标识唯一性



#### 查看投票信息

调用getVoteNum方法查看合约内投票信息数量

接口定义:

```
 //查看投票信息数量
 function getVoteNum()
    view external
    returns (uint)
```



调用getVoteList方法查看投票信息列表

接口定义：

```
  //查询投票信息列表
  function getVoteList(
    uint startIndex,  //查询投票信息起始位置  (startIndex+num)不大于getVoteNum接口返回的投票信 息数量
    uint num          //查询投票信息数量, 单次查询数量不超过500
  )
    view external
    returns(
      uint[],     //投票活动ID列表
      bytes32[]   //投票活动名称列表
    )
```



用户调用getVoteInfo查看投票信息

接口定义：

```
  //查看投票详细信息
  function getVoteInfo(
    uint voteID                 //投票活动ID
  )
    view external
    returns(
      bytes32,                    //投票活动名称
      string,                     //投票规则
      bytes32[],                  //候选人列表
      uint[],                     //得票数列表
      uint                        //投票者信息数量
    )
```



调用getVoterInfo批量查看投票人信息，每次查看投票人信息数量不超过100

接口定义：

```
   //查看投票人信息
  function getVoterInfo(
    uint voteID,        //投票活动ID
    uint startIndex,    //投票人信息起始位置, (startIndex+num)不大于getVoteInfo接口返回的投票者信息数量
    uint num            //查看投票人信息数量
    )
    view external
    returns(
      bytes32[],        //投票人列表
      bytes32[],        //所投候选人列表
      uint[]            //所投票数
    )
```

