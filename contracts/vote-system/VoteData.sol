pragma solidity ^0.4.24;

import "../Ownable.sol";

contract VoteData is Ownable {

  //投票规则
  struct VoteRule {
    uint startTime;         //投票开始时间  Uinx时间戳
    uint endTime;           //投票结束时间  Unix时间戳
    bool dayTimeLimit;      //是否限制每天投票时间  false：不限制 true：限制
    uint dayStartTime;      //每天投票开始时间 单位：小时
    uint dayEndTime;        //每天投票结束时间 单位：小时
    uint dayVoteLimit;      //每天总投票次数限制
    uint voteLimitPerUser;  //每个用户投票次数限制
    address[] blacklist;    //投票参与用户黑名单
    bytes32[] candidates;   //候选人信息

    mapping(bytes32 => bool) uniqueCandidates; 
  }

  //投票状态
  enum VoteStatus {
    Initial,   //投票初始化
    Started,   //投票开始
    Ended      //投票结束
  }

  //投票信息
  struct VoteInfo {
    string name;                                 //投票活动名称
    address[] voterArray;                        //投票者地址
    mapping(address => Voter) voters;            //投票者信息
    SimpleVoter[] simpleVoters;                  //投票人简要信息
    mapping(address => uint) simpleVotersIndex;  //投票简要信息索引  
    uint[] dayArray;                             //日期信息
    mapping(uint => uint) dayVote;               //每天投票总数
    uint dayStart;                               //投票开始时间的日期  UTC天数
    uint totalCount;                             //总票数
  }

  //投票人简要信息
  struct SimpleVoter {
    address addr;          //投票人地址
    uint candidateIndex;   //候选人索引
    uint count;            //投票数
  }

  //投票者信息
  struct Voter {
    uint[] vote;                        //得票者
    mapping(uint => uint) voteCount;    //得票数
    uint totalCount;                    //总投票数
  }

  //投票结果
  struct VoteResult {
    mapping(uint => uint) votes;   //候选人得票数
    uint[] rank;                   //候选人排名
  }

  struct Vote {
    VoteRule rule;        //投票规则
    VoteInfo info;        //投票信息
    VoteResult result;    //投票结果
    VoteStatus status;    //投票状态
  }

  address public voteControlAddr_;
  Vote[] private votes_;

  /*
    接口名称：合约构造函数
    参数说明：owner：抽奖活动管理者账户地址
  */
  constructor(address owner) Ownable(owner) public {}
    
  modifier onlyControl() {
    require(voteControlAddr_ == msg.sender, "onlyControl error");
    _;
  } 

  // 更新数据合约地址
  function setVoteControlAddr(address voteControlAddr)
    onlyOwner external
  {
    require(voteControlAddr != address(0));
    voteControlAddr_ = voteControlAddr;
  }


  /*
    接口名称：新建投票活动
    参数说明：name：投票活动名称
  */
  function newVote(string name) 
    onlyControl public
    returns(uint)
  {
    require(bytes(name).length > 0, "vote name error");
    votes_.length++;
    Vote storage vote = votes_[votes_.length-1];
    vote.info.name = name;
    vote.status = VoteStatus.Initial;
    return votes_.length-1;
  }

  //查看最新的投票活动信息
  function getLastestVote()
    view onlyControl public
    returns(
      uint,
      string
    )
  {
    require(votes_.length > 0, "null vote");
    VoteInfo storage info = votes_[votes_.length-1].info;
    return (
      votes_.length-1,
      info.name
    );
  }

  // 设置投票活动规则
  function setVoteRule(
    uint voteID,
    uint startTime,
    uint endTime,
    bool dayTimeLimit,
    uint dayStartTime,
    uint dayEndTime,
    uint dayVoteLimit,
    uint voteLimitPerUser,
    address[] blacklist,
    bytes32[] candidates
    )
    onlyControl public 
  {
    require(voteID < votes_.length, "vote id error");
    Vote storage vote = votes_[voteID];
    require(vote.status == VoteStatus.Initial, "vote status error");
    require(startTime < endTime, "vote time error");
    if (dayTimeLimit) {
      require(dayStartTime < dayEndTime, "vote day time error");
    }
    require(dayVoteLimit > 0, "day vote limit error");
    require(voteLimitPerUser > 0, "vote limit per user error");
    require(candidates.length > 0 && candidates.length <= 300, "candidates num error");

    VoteRule storage rule = vote.rule;
    rule.startTime = startTime;
    rule.endTime = endTime;
    rule.dayTimeLimit = dayTimeLimit;
    rule.dayStartTime = dayStartTime;
    rule.dayEndTime = dayEndTime;
    rule.dayVoteLimit = dayVoteLimit;
    rule.voteLimitPerUser = voteLimitPerUser;
    rule.blacklist = blacklist;

    //check candidates
    for(uint i = 0; i < candidates.length; i++) {
      require(!rule.uniqueCandidates[candidates[i]], "candidates duplicated");
      rule.uniqueCandidates[candidates[i]] = true;
    }

    rule.candidates = candidates;

    //init rank info
    for(i = 0; i < candidates.length; i++) {
      vote.result.rank.push(i);
    }

    vote.info.dayStart = _getTheDay(startTime, vote);

    vote.status = VoteStatus.Started;
  }

  // 查询投票活动规则
  function getVoteRule(uint voteID)
    onlyControl view public
    returns( 
      uint,
      uint,
      bool,
      uint,
      uint,
      uint,
      uint,
      address[],
      bytes32[]
    )
  {
    require(voteID < votes_.length, "vote id error");
    VoteRule storage rule = votes_[voteID].rule;
    return (
      rule.startTime,
      rule.endTime,
      rule.dayTimeLimit,
      rule.dayStartTime,
      rule.dayEndTime,
      rule.dayVoteLimit,
      rule.voteLimitPerUser,
      rule.blacklist,
      rule.candidates
    );    
  }

  // 投票
  function voteUp(uint voteID, address msgSender, uint candidateIndex) 
    onlyControl public
    returns (int, string)
  {
    require(voteID < votes_.length, "vote id error");
    Vote storage vote = votes_[voteID];
    
    (int errCode, string memory errMsg) = _checkVote(vote, msgSender, candidateIndex);
    if (errCode > 0) {
      return (errCode, errMsg);
    }
    _vote(vote, msgSender, candidateIndex);
    return (0, "");
  }

  // 检查是否满足投票条件
  function _checkVote(Vote storage vote, address msgSender, uint candidateIndex)
    internal
    returns(int, string)
  {
    VoteInfo storage info = vote.info;
    VoteRule storage rule = vote.rule;

    uint timeNow = now;
    if (vote.status == VoteStatus.Initial || timeNow < rule.startTime) {
      return (1, "vote not started");
    }
   
    if (vote.status == VoteStatus.Ended || timeNow > rule.endTime) {
      if (vote.status != VoteStatus.Ended && timeNow > rule.endTime) {
        vote.status = VoteStatus.Ended;
      }
      return(2, "vote ended");
    }

    if (rule.dayTimeLimit) {
      uint timeHour = (((timeNow / 3600) % 24) + 8) % 24;
      if (timeHour < rule.dayStartTime || timeHour >= rule.dayEndTime) {
        return(3, "vote day time limit");
      }
    }
  
    uint day = _getTheDay(now, vote);
    if (info.dayVote[day] >= rule.dayVoteLimit) {
      return(4, "vote limited per day");
    }

    Voter storage voter = info.voters[msgSender];
    if (voter.totalCount >= rule.voteLimitPerUser) {
      return(5, "user vote limited per day");
    }

    for(uint i = 0; i < rule.blacklist.length; i++) {
      if (msgSender == rule.blacklist[i]) {
        return(6, "blacklist error");
      }
    }

    if (candidateIndex >= rule.candidates.length) {
      return(7, "invalid candidate");
    }
    return (0, ""); 
  }

  function _getTheDay(uint timestamp, Vote storage vote)
    view internal 
    returns(uint) 
  {
    return ((timestamp + 8 hours)/ 1 days) - vote.info.dayStart;
  }  

  // 投票处理
  function _vote(Vote storage vote, address msgSender, uint candidateIndex)
   internal 
  {
    VoteInfo storage info = vote.info;
    VoteResult storage result = vote.result;

    Voter storage voter = info.voters[msgSender];

    if (voter.totalCount == 0) {
      info.voterArray.push(msgSender);
    }

    //vote for the candidate first time
    if (voter.voteCount[candidateIndex] == 0) {
      voter.vote.push(candidateIndex);
      info.simpleVoters.push(SimpleVoter({
        addr: msgSender,
        candidateIndex: candidateIndex,
        count: 0
      }));
      info.simpleVotersIndex[msgSender] = info.simpleVoters.length - 1;
    }

    info.simpleVoters[info.simpleVotersIndex[msgSender]].count++;
    voter.voteCount[candidateIndex]++;
    voter.totalCount++;
    info.totalCount++;

    uint day = _getTheDay(now, vote);
    if (info.dayVote[day] == 0) {
      info.dayArray.push(day);
    }
    info.dayVote[day]++;

    result.votes[candidateIndex]++;

    uint[] storage rank = result.rank;

    //vote rank
    int startIndex = -1;
    for (uint i = 0; i < rank.length; i++) {
      if (candidateIndex == rank[i]) {
        startIndex = int(i);
        break;
      }
    }
    assert(startIndex != -1);

    for (i = uint(startIndex); i > 0; i--) {
      if (result.votes[rank[i]] > result.votes[rank[i-1]]) {
        //swap element
        uint tmp = rank[i];
        rank[i] = rank[i-1];
        rank[i-1] = tmp; 
      } 
    }
  }



  // 查看投票信息
  function getVoteInfo(uint voteID) 
    onlyControl view public
    returns(
      string,   //投票活动名称
      uint,     //投票人数
      uint,     //总票数
      uint,     //投票活动状态
      uint      //投票人简要信息数量
    )  
  { 
    require(voteID < votes_.length, "vote id error");
    Vote storage vote = votes_[voteID];
    VoteInfo storage info = vote.info;

    uint status = uint(vote.status);
    if (now > vote.rule.endTime) {
      status = uint(VoteStatus.Ended);
    }

    return(
      info.name,
      info.voterArray.length,
      info.totalCount,
      status,
      info.simpleVoters.length
    );
  }

  // 查看投票结果
  function getVoteResult(uint voteID) 
    onlyControl view public
    returns(
      bytes32[],
      uint[]
    )
  { 
    require(voteID < votes_.length, "vote id error");
    Vote storage vote = votes_[voteID];

    uint[] storage rank = vote.result.rank;
    bytes32[] memory candidatesRank = new bytes32[](rank.length);
    uint[] memory counts = new uint[](rank.length);

    for (uint i = 0; i < rank.length; i++) {
      candidatesRank[i] = vote.rule.candidates[rank[i]];
      counts[i] = vote.result.votes[rank[i]];
    }
    return (candidatesRank, counts);
  }

  // 查看投票者信息
  function getVoter(uint voteID, uint startIndex, uint num)
    onlyControl view public
    returns(
      address[],  //投票者
      bytes32[],  //候选人
      uint[]      //投票数
    )
  { 
    require(voteID < votes_.length, "vote id error");
    require(num <= 100, "num error");
    Vote storage vote = votes_[voteID];
    SimpleVoter[] storage voters = vote.info.simpleVoters;

    require(startIndex >= 0 &&
            startIndex < voters.length &&
            num > 0 &&
            startIndex + num <= voters.length, "startIndex or num error");

    address[] memory addrs = new address[](num);
    bytes32[] memory candidates = new bytes32[](num);
    uint[] memory counts = new uint[](num);

    for(uint i = 0; i < num; i++) {
      SimpleVoter storage voter = voters[startIndex+i];
      addrs[i] = voter.addr;
      candidates[i] = vote.rule.candidates[voter.candidateIndex];
      counts[i] = voter.count;
    }
    return (addrs, candidates, counts);
  }
}
