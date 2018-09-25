pragma solidity ^0.4.24;

import "./VoteData.sol";
import "../Ownable.sol";

contract VoteControl is Ownable {
  VoteData private voteData_;


  /*
    接口名称：合约构造函数
    参数说明：owner：抽奖活动管理者账户地址，lotteryDataAddr：数据合约地址
  */
  constructor(address owner, address voteDataAddr) Ownable(owner) public
  {
    require(owner != address(0));
    require(voteDataAddr != address(0));
    voteData_ = VoteData(voteDataAddr);
  }

  //判断是否普通账户地址
  modifier isHuman() {
    address addr = msg.sender;
    uint codeLength;
    assembly {codeLength := extcodesize(addr)}
    require(codeLength == 0, " sorry humans only");
    _;
  } 
 
  // 更新数据合约地址
  function updateVoteData(address voteDataAddr)
    onlyOwner external
  {
    require(voteDataAddr != address(0));
    voteData_ = VoteData(voteDataAddr);
  }

  /*
    接口名称：新建投票活动
    参数说明：name：投票活动名称
  */
  function newVote(string name)
    onlyOwner external 
    returns (uint)
  {
    return voteData_.newVote(name);    
  } 
 
  //查看最新的投票活动信息
  function getLastVote()
    view onlyOwner external
    returns(
      uint,    //投票活动ID
      string   //投票活动名称
    )
  {
    return voteData_.getLastestVote();  
  }
 
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
    bytes32[] candidates    //投票候选人
    )
    onlyOwner external
  {
    voteData_.setVoteRule(
      voteID,
      startTime,
      endTime,
      dayTimeLimit,
      dayStartTime,
      dayEndTime,
      dayVoteLimit,
      voteLimitPerUser,
      blacklist,
      candidates
    );
  }  
 
  // 查询投票活动规则
  function getVoteRule(uint voteID)
    view external
    returns( 
      uint,         //投票开始时间 Unix时间戳
      uint,         //投票结束时间 Unix时间戳
      bool,         //是否限制每天投票时间 true:限制 false:不限制
      uint,         //每天投票开始时间 以整点为单位
      uint,         //每天投票结束时间 以整点为单位
      uint,         //每天总投票数限制
      uint,         //每个账户投票数限制
      address[],    //投票黑名单
      bytes32[]     //投票候选人
    )
  {
     return voteData_.getVoteRule(voteID);
  }
 
  // 查看投票者信息
  function getVoter(
    uint voteID,     //投票活动ID
    uint startIndex, //投票者起始位置Index,  (startIndex +num)小于等于getVoteInfo接口返回的投票者信息数量
    uint num         //查看投票者信息数量
    )
    view external
    returns(
      address[],  //投票者账户地址
      bytes32[],  //候选人名称
      uint[]      //投票数
    )
  {
    return voteData_.getVoter(voteID, startIndex, num);
  } 
 
  // 查看投票结果
  function getVoteResult(uint voteID) 
    view external
    returns(
      bytes32[],  //候选人列表， 按投票数降序排列
      uint[]      //候选人获得票数
    )
  {
    return voteData_.getVoteResult(voteID);    
  } 
 
  // 查看投票信息
  function getVoteInfo(uint voteID) 
    view public
    returns(
      string,   //投票活动名称
      uint,     //投票人数
      uint,     //总票数
      uint,     //投票活动状态
      uint      //投票者信息数量
    )  
  {
    return voteData_.getVoteInfo(voteID);    
  }

  // 投票
  function vote(
    uint voteID,         //投票活动ID
    uint candidateIndex  //候选人Index， 候选人列表中从0开始计算 
    )
    isHuman external
    returns(
      int,     //返回码， 0：成功  1：活动未开始 2：活动结束 3：不在当天投票时间段内 4：当天投票总次数达到上限 5:该用户投票次数达到上限 6：黑名单用户 7：所投候选人不存在
      string   //错误码信息
    )
  {
    return voteData_.voteUp(voteID, msg.sender, candidateIndex);
  } 
}
