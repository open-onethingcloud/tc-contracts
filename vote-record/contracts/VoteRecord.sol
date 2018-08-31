pragma solidity ^0.4.24;

import "./Ownable.sol";

contract VoteRecord is Ownable {

  //投票信息
  struct VoteInfo {
    string name;          //投票活动名称
    string rule;          //投票活动规则
    VoterInfo[] voters;   //投票人信息

    bytes32[] candidates; //候选人
    uint[]    voteNums;   //所得票数 

    mapping(bytes32 => bool) uniqueCandidates; 
  } 

  //投票人信息
  struct VoterInfo {
    address voter;         //投票人地址
    bytes32 candidate;     //所投候选人
    uint voteNum;          //所投票数
  }

  mapping(address => VoteInfo[]) vote_;

  constructor(address owner) Ownable(owner) public {}


  //投票信息上链
  function record(
      string name,                     //投票活动名称
      string rule,                     //投票规则
      bytes32[] candidates,            //候选人列表
      uint[] voteNums                  //得票数列表
    ) 
    external
    returns(uint)
  {
    require(bytes(name).length > 0, "vote name error");
    require(bytes(rule).length > 0, "vote rule error");
    require(candidates.length == voteNums.length && candidates.length > 0, "candidate info error");
    require(candidates.length <= 300, "candidate length error");

    VoteInfo[] storage infos = vote_[msg.sender];
    infos.length++;
    VoteInfo storage info = infos[infos.length-1];
    info.name = name;
    info.rule = rule;
    info.candidates = candidates;
    info.voteNums = voteNums; 
 
    //check candidates
    for(uint i = 0; i < candidates.length; i++) {
      require(!info.uniqueCandidates[candidates[i]], "candidates duplicated");
      info.uniqueCandidates[candidates[i]] = true;
    }

    return infos.length-1;
  }

  //查询最新的投票信息
  function getLastestVote()
    view external 
    returns(
      uint,  //投票活动ID
      string   //投票活动名称
    )
  { 
    VoteInfo[] storage infos = vote_[msg.sender];
    require(infos.length > 0, "null vote");
    return (
      infos.length-1,
      infos[infos.length-1].name
    );

  }

  //投票人信息上链, 每上链投票人信息数量不超过100
  function recordVoter(
    uint voteID,                //投票活动ID
    address[] voters,           //投票者账户地址列表
    bytes32[] candidates,       //所投候选人列表
    uint[] voteNums             //所投票数
    )
    external
    returns(bool)
  {
    require(voteID < vote_[msg.sender].length, "vote id error");
    require(voters.length == candidates.length && voters.length == voteNums.length);
    require(voters.length > 0 && voters.length <= 100, "voter num error");

    VoteInfo storage info = vote_[msg.sender][voteID];

    for(uint i = 0; i < voters.length; i++) {
      info.voters.push(VoterInfo({
        voter: voters[i],
        candidate: candidates[i],
        voteNum: voteNums[i]
      }));
    }
    return true;
  }

  //查看投票信息
  function getVoteInfo(
    address recorder,           //信息记录者地址
    uint voteID                 //投票活动ID
  )
    view external
    returns( 
      string,                     //投票活动名称
      string,                     //投票规则
      bytes32[],                  //候选人列表
      uint[],                     //得票数列表
      uint                        //投票者信息数量
    )
  {
    require(vote_[recorder].length > 0 || voteID < vote_[recorder].length, "vote not exist");
    VoteInfo storage info = vote_[recorder][voteID];
    return(
      info.name,
      info.rule,
      info.candidates,
      info.voteNums,
      info.voters.length
    );
  }

  //查看投票人信息
  function getVoterInfo(
    address recorder,   //信息记录者地址
    uint voteID,        //投票活动ID
    uint startIndex,    //投票人信息起始位置, (startIndex+num)不大于getVoteInfo接口返回的投票者信息数量
    uint num            //查看投票人信息数量
    )
    view external
    returns(
      address[],        //投票者账户地址列表
      bytes32[],        //所投候选人列表
      uint[]            //所投票数
    )
  { 
    require(num <= 100, "num error");
    require(vote_[recorder].length > 0 || voteID < vote_[recorder].length, "vote not exist");
    VoteInfo storage info = vote_[recorder][voteID];
    require(startIndex >= 0 && num > 0 && startIndex + num <= info.voters.length, "startIndex or num error");

    address[] memory voters = new address[](num);
    bytes32[] memory candidates = new bytes32[](num);
    uint[] memory voteNums = new uint[](num);

    for(uint i = 0; i < num; i++) {
      VoterInfo storage voterInfo = info.voters[startIndex+i];
      voters[i] = voterInfo.voter;
      candidates[i] = voterInfo.candidate;
      voteNums[i] = voterInfo.voteNum;
    }
    return(
      voters,
      candidates,
      voteNums
    );
  }
}


