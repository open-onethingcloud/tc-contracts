pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "./Ownable.sol";


contract LotteryData is Ownable {
  using SafeMath for uint;

  //抽奖模式
  enum LotteryMode {
    Sum,     //奖池金额固定模式
    Time,    //开奖时间固定模式
    Address  //抽奖用户地址数量固定模式
  }
  
  //抽奖状态
  enum LotteryStatus {
    Initial,  //抽奖初始化
    Started,  //抽奖已开始
    ToOpen,   //已达成抽奖条件，待开奖
    Opened,   //已开奖
    Refund    //已退款 (不满足开奖条件，奖池退款)
  }

  //抽奖配置
  struct LotteryConfig {
    uint startTime;         //抽奖开始时间
    uint endTime;           //抽奖结束时间
    bool dayLimit;          //是否限制每天抽奖时间 
    uint dayStartTime;      //每天抽奖开始时间 单位：小时
    uint dayEndTime;        //每天抽奖结束时间 单位：小时
    int timesPerItem;       //每个链克地址抽奖次数限制  -1表示不限制次数
    uint amountPerAction;   //单次抽奖金额 单位：链克
    uint openCondition;     //开奖条件 抽奖模式为Sum:奖池金额达到指定数量(单位：链克)  Time:指定时刻开奖(单位：秒)  Address:参与账户地址达到指定数量
    uint copies;            //总奖池被分成几份
   
    uint totalAward;        //奖池条件达成时的总金额  单位：Wei
    uint awardPerCopy;      //每份奖金金额  单位：Wei
    uint seed;              //随机数种子
  }

  //抽奖者信息
  struct JoinerInfo {
    mapping(address => uint) joinerAction;  //抽奖次数记录   (account address => join count)
    address[] uniqueJoiners;                //去重的抽奖者地址列表

    mapping(uint => address) indexJoiner;   //抽奖者索引地址记录 (index => account address)
    address[] indexs;                       //抽奖者索引记录
  }

  //抽奖结果
  struct LotteryResult {
    address[] winnerAddrs;                     //中奖者地址
    mapping(address => WinnerResult)  winners; //中奖者信息
    uint    drawCount;                         //奖品发放人数
    uint    totalDrawAmount;                   //总的奖品发放金额 单位：Wei

    uint    totalRefundAmount;                 //总的退款金额 单位：Wei
    address[]    drawedUsers;                  //已发奖用户地址
    address[]    refundUsers;                  //已退款用户地址
    mapping(address => bool) refunded;         //中奖用户是否退款
    uint[] ownerDrawRecord;                    //管理者提现记录
  }

  //中奖者信息
  struct WinnerResult {
    uint    award;          //中奖金额 单位：Wei
    bool    drawed;         //奖金是否发放
    bool    exist;          //是否中奖
  }

  //抽奖信息
  struct Lottery {
    string name;          //抽奖名称
    LotteryMode mode;     //抽奖模式
    LotteryStatus status; //抽奖状态
    LotteryConfig config; //抽奖配置
    JoinerInfo joiner;    //抽奖者信息
    LotteryResult result; //中奖结果
  } 
 
  address public lotteryControl_;

  Lottery[] private lotteries_;

  event NewLotteryControl(address lotterControl);
  event JoinLottery(uint lotteryID);
  event OpenLottery(uint lotteryID);

  constructor(address owner)  Ownable(owner) public {}

  // 控制合约修饰
  modifier onlyControl() {
    require(msg.sender == lotteryControl_, "only for control contract");
    _;
  }

  // 设置抽奖控制合约地址  
  function setLotteryControl(address lotteryControl)
  onlyOwner public {
    lotteryControl_ = lotteryControl;
    emit NewLotteryControl(lotteryControl);
  }

  // 创建合约 
  function newLottery(string name, uint mode)
    onlyControl public
    returns(uint)
  {
    lotteries_.length++;
    Lottery storage lottery = lotteries_[lotteries_.length - 1];
    lottery.name = name;
    lottery.status = LotteryStatus.Initial;
    lottery.mode = LotteryMode(mode);
    return lotteries_.length - 1;
  }

  // 抽奖退款 
  function _refundLottery(Lottery storage lottery)  internal {
    JoinerInfo storage joiner = lottery.joiner;
    LotteryResult storage result = lottery.result;

    for(uint i = 0; i < joiner.uniqueJoiners.length; i++) {
      address joinerAddr = joiner.uniqueJoiners[i];
      if (result.refunded[joinerAddr]) {
        continue;
      }

      uint action = joiner.joinerAction[joinerAddr];
      if (action == 0) {
        continue;
      }
      uint amount = action.mul(lottery.config.amountPerAction).mul(1e18);
      
      result.refunded[joinerAddr] = true;

      if (!joinerAddr.send(amount)) {
        result.refunded[joinerAddr] = false;
        continue;
      }
      result.refundUsers.push(joinerAddr);
      result.totalRefundAmount = result.totalRefundAmount.add(amount);
    }

    lottery.status = LotteryStatus.Refund;
  }

  //查看抽奖数据
  function queryLottery(uint lotteryID) view onlyControl public
    returns(
      string,
      uint,
      uint,          
      uint,                  
      address[],
      uint[],          
      uint,                        
      uint[]      
    )
  {
    require(lotteryID < lotteries_.length);

    Lottery storage lottery = lotteries_[lotteryID];
    LotteryConfig storage config = lottery.config;
    JoinerInfo storage joiner = lottery.joiner;

    //uint awardPerCopy = config.awardPerCopy.div(1e18); // uint: ether
    uint[] memory joinAction = new uint[](joiner.uniqueJoiners.length);
    for (uint i = 0; i < joiner.uniqueJoiners.length; i++) {
      joinAction[i] = joiner.joinerAction[joiner.uniqueJoiners[i]];
    }
    
    return(
      lottery.name, 
      uint(lottery.mode), 
      uint(lottery.status),
      config.totalAward.div(1e18), 
      //awardPerCopy,
      joiner.uniqueJoiners, 
      joinAction,
      joiner.indexs.length,
      lottery.result.ownerDrawRecord
    );
  }


  // 查看抽奖结果
  function queryLotteryResult(uint lotteryID)
    view onlyControl public 
    returns (
      uint,
      address[],
      uint[],           
      uint, 
      uint,                  
      uint, 
      address[],                  
      address[]
    )
  {
    require(lotteryID < lotteries_.length);

    Lottery storage lottery = lotteries_[lotteryID];
    LotteryResult storage result = lottery.result; 
 
    uint[] memory winnerAwards = new uint[](result.winnerAddrs.length);
    for (uint i = 0; i < result.winnerAddrs.length; i++) {
      //winnerAwards[i] = result.winners[result.winnerAddrs[i]].award.div(1e18);
      winnerAwards[i] = result.winners[result.winnerAddrs[i]].award;
    }
    
    //uint totalDrawAmount = result.totalDrawAmount.div(1e18);
    //uint totalRefundAmount = result.totalRefundAmount.div(1e18);

    return(
      uint(lottery.status),
      result.winnerAddrs,
      winnerAwards,
      result.drawCount, 
      result.totalDrawAmount,
      result.totalRefundAmount, 
      result.drawedUsers,
      result.refundUsers
    );
  }


  //参与抽奖
  function joinLottery(uint lotteryID, address msgSender, uint msgValue)
    onlyControl payable public
  {
    require(lotteryID < lotteries_.length, "lotteryID error");
    Lottery storage lottery = lotteries_[lotteryID];

    //检查抽奖条件
    bool checkRet = false;
    string memory errMsg = "";
    (checkRet, errMsg) = _checkJoinLottery(lottery, msgSender, msgValue);
    require(checkRet, errMsg);

    //更新抽奖数据
    JoinerInfo storage joiner = lottery.joiner;
    uint index = joiner.indexs.push(msgSender) - 1;
    joiner.indexJoiner[index] = msgSender;
    if (joiner.joinerAction[msgSender] == 0) {
      joiner.uniqueJoiners.push(msgSender);
    }
    joiner.joinerAction[msgSender]++;
    lottery.config.totalAward += msgValue;


    //更新抽奖状态
    _updateJoinLottery(lotteryID, lottery);

    emit JoinLottery(lotteryID);

  }

  // 更新活动状态
  function _updateJoinLottery(uint lotteryID, Lottery storage lottery) internal {

    LotteryConfig storage config = lottery.config;
    bool toOpen = false;

    if (lottery.mode == LotteryMode.Sum) {
      if (config.totalAward >= config.openCondition.mul(1e18)) {
        toOpen = true;
      }
    } else if (lottery.mode == LotteryMode.Time) {
      if (now >= config.openCondition) {
        toOpen = true;
      }
    } else if (lottery.mode == LotteryMode.Address) {
      if (lottery.joiner.uniqueJoiners.length >= config.openCondition) {
        toOpen = true;
      }
    }

    if (toOpen) {
      lottery.status = LotteryStatus.ToOpen;
      //openLottery(lotteryID);
      emit OpenLottery(lotteryID);  
    }
  }


  function checkOpenLottery(uint lotteryID) 
    view onlyControl public
    returns(bool)
  {
    require(lotteryID < lotteries_.length, "lotteryID error");
    Lottery storage lottery = lotteries_[lotteryID];
    require(lottery.status != LotteryStatus.Initial, "openLottery status error"); 
 
    LotteryConfig storage config = lottery.config;

    bool refund = false;
    bool toOpen = false;
    if (lottery.status == LotteryStatus.Started) {
      if (lottery.mode == LotteryMode.Sum || lottery.mode == LotteryMode.Address) {
        if (now >= config.endTime) {
          refund = true;
        }
      } else if (lottery.mode == LotteryMode.Time) {
        if (now >= config.openCondition) {
          toOpen = true;
        }
      }
    } else if (lottery.status == LotteryStatus.ToOpen) {
      return true;
    } else {
      //可重复执行OpenLottery
      return true;
    }
 
    if (refund || toOpen) {
      return true;
    }
    return false;
  }


  // 开奖
  // 若活动未满足条件则进行退款操作  开发者收到OpenLottery事件后调用该接口
  // 返回true， 则成功处理开奖或退款
  function openLottery(uint lotteryID) 
    onlyControl public
    returns(bool)
  {
    require(lotteryID < lotteries_.length, "lotteryID error");
    Lottery storage lottery = lotteries_[lotteryID];
    require(lottery.status != LotteryStatus.Initial, "openLottery status error");

    LotteryConfig storage config = lottery.config;

    if (lottery.status == LotteryStatus.Opened) {
      if (lottery.result.drawCount >= lottery.result.winnerAddrs.length) {
        //所有中奖已发放
        return true;
      } else {
        _drawLottery(lottery);
        return true;
      }
    } 
 
    if (lottery.status == LotteryStatus.Refund) {
      return true; //todo 处理部分退款失败
    }

    //若活动结束，未达成活动条件，则奖池金额退款
    bool refund = false;
    if (lottery.status == LotteryStatus.Started) {
      if (lottery.mode == LotteryMode.Sum || lottery.mode == LotteryMode.Address) {
        if (now >= config.endTime) {
          refund = true;
        }
      } else if (lottery.mode == LotteryMode.Time) {
        if (now >= config.openCondition) {
          lottery.status = LotteryStatus.ToOpen;
        }
      }
    }

    //活动条件未达成，退款处理
    if (refund) {
      _refundLottery(lottery);
      return true;
    }

    //活动条件达成，开奖处理
    if (lottery.status == LotteryStatus.ToOpen) {
      _openLottery(lottery);
      return true;
    }
    return false;
  }


  //发放奖品
  function _drawLottery(Lottery storage lottery)  internal {
    require(lottery.status == LotteryStatus.Opened, "_drawLottery status error");
    
    LotteryResult storage result = lottery.result;

    for(uint i = 0; i < result.winnerAddrs.length; i++) {
      address winnerAddr = result.winnerAddrs[i];
      WinnerResult storage winner = result.winners[winnerAddr];
      if (!winner.exist || winner.drawed) {
        continue;
      }

      winner.drawed = true;
      require(result.totalDrawAmount <= lottery.config.totalAward, "_drawLottery totalDrawAmount error");
      
      if (!winnerAddr.send(winner.award)) {
        winner.drawed = false;
        continue;
      } 
      result.drawedUsers.push(winnerAddr);
      result.drawCount++;
      result.totalDrawAmount = result.totalDrawAmount.add(winner.award);
    }
  }


  function _openLottery(Lottery storage lottery) internal {
    require(lottery.status == LotteryStatus.ToOpen, "_openLottery status error");

    LotteryConfig storage config = lottery.config;
    LotteryResult storage result = lottery.result;

    config.awardPerCopy = config.totalAward.div(config.copies);


    for(uint i = 0; i < config.copies; i++) {
      uint randNum = _getRandomNum(lottery);
      uint index = randNum % lottery.joiner.indexs.length;
      address winnerAddr = lottery.joiner.indexJoiner[index];
      if (!result.winners[winnerAddr].exist) {
        result.winnerAddrs.push(winnerAddr);
        result.winners[winnerAddr].exist = true;
      }
      result.winners[winnerAddr].award  += config.awardPerCopy;
    }

    lottery.status = LotteryStatus.Opened;
    _drawLottery(lottery);
  } 


 
  //产生随机数
  function _getRandomNum(Lottery storage lottery) internal returns(uint) {
    uint timeNow = now;
    uint seedTmp = uint(blockhash(block.number-1));
    uint randNum = uint(keccak256(abi.encodePacked(timeNow.add(lottery.config.seed).add(seedTmp))));
    lottery.config.seed++;
    return randNum;
  }

  // 检查抽奖参与条件
  function _checkJoinLottery(Lottery storage lottery, address msgSender, uint msgValue)
  internal view
  returns(bool, string)
  {

    //检查抽奖活动状态
    if (lottery.status != LotteryStatus.Started) {
      return (false, "status error");
    }

    //检查抽奖活动时间
    LotteryConfig storage config = lottery.config;
    uint timeNow = now;
    if (timeNow < config.startTime || timeNow > config.endTime) {
      return (false, "join time limit");
    }

    //检查抽奖活动每天有效时间
    uint timeHour = (((now / 3600) % 24) + 8) % 24;
    if (config.dayLimit) {
      if (timeHour < config.dayStartTime || timeHour > config.dayEndTime) {
        return (false, "join day time limit");
      }
    }

    //检查参与者抽奖次数限制
    if (config.timesPerItem != -1 && lottery.joiner.joinerAction[msgSender] >= uint(config.timesPerItem)) {
      return (false, "join timesPerItem limit");
    }

    //检查参与者交易金额
    //uint amountWeiPerAction = config.amountPerAction.mul(1e18);
    if (config.amountPerAction != msgValue.div(1e18 wei)) {
      return (false, "join value error");
    }
    return (true, "");
  }


  function getWithDrawAmount(uint lotteryID)
    view onlyControl public
    returns(uint) 
  {
    require(lotteryID < lotteries_.length);
    Lottery storage lottery = lotteries_[lotteryID];
    return lottery.config.totalAward;
  }

  function setLotteryConfig(
    uint lotteryID,
    uint startTime, uint endTime,
    bool dayLimit, uint dayStartTime, uint dayEndTime,
    int timesPerItem, uint amountPerAction,
    uint openCondition, uint copies
  )
    onlyControl public
  {
    require(lotteryID < lotteries_.length, "lotteryID error");
    require(startTime < endTime, "startTime or endTime error");

    Lottery storage lottery = lotteries_[lotteryID];
    require (lottery.status == LotteryStatus.Initial, "lottery status error");

    if (dayLimit) {
      require(dayStartTime < dayEndTime, "dayStartTime or dayEndTime error" );
    }
    require(amountPerAction <= 10, "amountPerAction error");  //单次抽奖金额设置最大10链克
    require(copies > 0 && copies <= 100, "copies error"); // 奖池全部链克平分份数最大为100份


    //开奖时间固定模式下， 开奖时间设置要求大于抽奖结束时间
    if (lottery.mode == LotteryMode.Time) {
      require(openCondition >= endTime, "openCondition error in Time Mode");
    }
    
    lottery.status = LotteryStatus.Started;

    lottery.config = LotteryConfig({
      startTime: startTime,
      endTime: endTime,
      dayLimit: dayLimit,
      dayStartTime: dayStartTime,
      dayEndTime: dayEndTime,
      timesPerItem: timesPerItem,
      amountPerAction: amountPerAction,
      openCondition: openCondition,
      copies: copies,
      totalAward: 0,
      awardPerCopy: 0,
      seed: 0
    });
  }

  function queryLotteryConfig(uint lotteryID)
    onlyControl
    view public
    returns(
      uint,
      uint,
      uint,
      bool, 
      uint, 
      uint,
      int, 
      uint,
      uint, 
      uint
  ) 
  {
    require(lotteryID < lotteries_.length);
    Lottery storage lottery = lotteries_[lotteryID];

    LotteryConfig storage config = lottery.config;
    return(
      uint(lottery.mode),
      config.startTime, 
      config.endTime,
      config.dayLimit, 
      config.dayStartTime, 
      config.dayEndTime,
      config.timesPerItem, 
      config.amountPerAction,
      config.openCondition, 
      config.copies
    );
  }

  function withDraw(uint lotteryID) onlyControl public {
    require(lotteryID < lotteries_.length);
    Lottery storage lottery = lotteries_[lotteryID];

    require(lottery.status == LotteryStatus.Opened || lottery.status == LotteryStatus.Refund);
    uint amount = address(this).balance;
    require (amount > 0, "null balance");
    _owner.transfer(address(this).balance);
    lottery.result.ownerDrawRecord.push(amount);
  }
} 

