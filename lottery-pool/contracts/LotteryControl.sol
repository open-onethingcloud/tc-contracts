pragma solidity ^0.4.24;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/ownership/rbac/RBAC.sol";

import "./LotteryData.sol";


contract LotteryControl is Ownable, RBAC {

  string constant admin_ = "admin";

  LotteryData private lotteryData_;


  /*
    接口名称：合约构造函数
    参数说明：owner：抽奖活动管理者账户地址，lotteryDataAddr：数据合约地址
  */
  constructor(address owner, address lotterDataAddr) public
  {
    require(owner != address(0));
    require(lotterDataAddr != address(0));
    owner = owner;
    lotteryData_ = LotteryData(lotterDataAddr);

    addRole(owner, admin_);
  }

  //判断是否普通账户地址
  modifier isHuman() {
    address addr = msg.sender;
    uint codeLength;
    assembly {codeLength := extcodesize(addr)}
    require(codeLength == 0, " sorry humans only");
    _;
  }

  // 添加管理员
  function addAdmin(address admin)
    onlyOwner external
  {
    addRole(admin, admin_);
  }

  // 移除管理员
  function removeAdmin(address admin)
    onlyOwner external
  {
    removeRole(admin, admin_);
  }

  // 更新数据合约地址
  function updateLotteryData(address lotterDataAddr)
    onlyOwner external
  {
    require(lotterDataAddr != address(0));
    lotteryData_ = LotteryData(lotterDataAddr);
  }

  /*
    接口名称：新建抽奖
    参数说明：lotteryName: 抽奖活动名称， mode：抽奖模式(0: 奖池金额固定模式， 1: 开奖时间固定模式  2：抽奖用户地址数量固定模式)
  */
  function newLottery(string lotteryName, uint mode)
    onlyRole(admin_) external 
  returns (uint)
  {
    uint lotteryID = lotteryData_.newLottery(lotteryName, mode);


    /*

    //设置抽奖参数配置， 开发者可根据需求自行配置
    this.setLotteryConfig(
      lotteryID,
      1534144871,   // 活动开始时间  2018/8/13 15:21:11
      1535144871,   // 活动结束时间 2018/8/25 5:7:51
      true,         // 是否限制每天抽奖时间
      8,            // 每天抽奖开始时间  8点
      22,           // 每天抽奖结束时间  22点
      10,           // 参与者抽奖次数限制
      2,            // 每次抽奖的金额 单位：链克
      8,            // 开奖条件    
      1             // 奖品平分成几份发放
    );

   */
    
    return lotteryID;
  }


  // 设置抽奖配置
  function setLotteryConfig (
    uint lotteryID,            //抽奖活动ID
    uint startTime,            //活动开始时间, Unix时间戳
    uint endTime,              //活动结束时间, Unix时间戳
    bool dayLimit,             //是否限制每天抽奖时间
    uint dayStartTime,         //每天抽奖开始时间 
    uint dayEndTime,           //每天抽奖结束时间 
    int timesPerItem,          //参与者抽奖次数限制 
    uint amountPerAction,      //每次抽奖的金额 单位：链克，  限制：单次抽奖金额设置最大10链克
    uint openCondition,        //开奖条件，  抽奖模式为 0:奖池模式，奖池金额达到指定数量开奖(单位：链克)  1:开奖时间模式，达到指定时间开奖(Unix时间戳)  2:地址模式，参与用户账户地址达到指定数量开奖
    uint copies                //奖品平分成几份发放，  限制：份数最大为100份
    )
    onlyRole(admin_) external 
  {
    lotteryData_.setLotteryConfig(lotteryID, startTime, endTime,
                                 dayLimit, dayStartTime, dayEndTime,
                                 timesPerItem, amountPerAction,
                                 openCondition, copies);
  }

  // 查看抽奖配置
  function queryLotteryConfig(uint lotteryID)
    onlyRole(admin_) view external 
    returns (
      uint,      //抽奖模式
      uint,      //活动开始时间
      uint,      //活动结束时间
      bool,      //是否限制每天抽奖时间
      uint,      //每天抽奖开始时间
      uint,      //每天抽奖结束时间
      int,       //参与者抽奖次数限制
      uint,      //每次抽奖需要的金额 单位：链克
      uint,      //开奖条件  抽奖模式 0:奖池模式，奖池金额达到指定数量(单位：链克)  1:开奖时间模式，指定时刻开奖(单位：秒)  2:地址模式，参与者账户地址达到指定数量
      uint       //奖品平分成几份发放
    )
  {
    return lotteryData_.queryLotteryConfig(lotteryID);
  }

  // 参与抽奖
  function joinLottery(uint lotteryID)
    isHuman payable external
  {
    lotteryData_.joinLottery.value(msg.value)(lotteryID, msg.sender, msg.value);
  }

  // 开奖(1. 不满足开奖条件则退款; 2. 满足条件则开奖、发奖)
  function openLottery(uint lotteryID)
    onlyRole(admin_) external
  {
    bool toOpen = lotteryData_.checkOpenLottery(lotteryID);
    require(toOpen, "open lottery requirement not met");
    lotteryData_.openLottery(lotteryID);
  }


  // 查询是否可以开奖   
  //retruns  true:可以开奖  false:不可开奖
  function checkOpenLottery(uint lotteryID)
    view onlyRole(admin_) external 
    returns(bool)
  {
    return lotteryData_.checkOpenLottery(lotteryID);
  }


  // 查询抽奖信息
  function queryLottery(uint lotteryID) view onlyRole(admin_) external 
    returns(
      string,      //抽奖活动名称
      uint,        //抽奖模式
      uint,        //抽奖活动状态  
      uint,        //目前奖池累积金额，单位：链克
      address[],   //抽奖用户账户地址
      uint[],      //抽奖用户抽奖次数    
      uint,        //抽奖人次数
      uint[]       //管理员提现记录  单位：wei    1 链克 = 1e18 wei
    )
  {
    return lotteryData_.queryLottery(lotteryID);
  } 
 
  // 查看抽奖结果
  function queryLotteryResult(uint lotteryID) view external 
    returns(
      uint,       //活动状态   3：已开奖  4：已退款
      address[],  //中奖用户地址
      uint[],     //中奖用户中奖金额，单位：wei   1 链克 = 1e18 wei   
      uint,       //已发奖人次数
      uint,       //已发奖金额计数，单位：wei     1 链克 = 1e18 wei
      uint,       //已退款金额计数, 单位：wei     1 链克 = 1e18 wei
      address[],  //已发奖用户地址
      address[]  //已退款用户地址   
    )
  {
    return lotteryData_.queryLotteryResult(lotteryID);
  }

  // 管理员提现(已开放或已退款状态才能提现成功)
  function withDraw(uint lotteryID) onlyRole(admin_) external {
    return lotteryData_.withDraw(lotteryID);
  }
}

