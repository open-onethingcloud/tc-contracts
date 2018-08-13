pragma solidity ^0.4.24;

import "./LotteryCore.sol";

contract LotteryCoreWithRules is LotteryCore {

    struct LotteryRule {     
        uint startTime;         // 抽奖活动起始时间戳
        uint endTime;           // 抽奖活动结束时间戳
        uint daysStartTime;     // 每天抽奖起始时间，0 为不限制
        uint daysEndTime;       // 每天抽奖结束时间，0 为不限制
        uint participateCnt;    // 抽奖活动总次数限制， 0 为不限制
        uint perAddressPartCnt; // 每个地址能参与的抽奖次数，0为不限制
    }

    mapping(uint => mapping(address => uint)) public participants; // 参与抽奖活动账户地址=>参与次数
    mapping(uint => uint) public participateCnts; // 抽奖参与总人次
    mapping(uint => LotteryRule) public lotteryRules; 

    constructor(address _owner, address _lotteryDataAddress) LotteryCore(_owner, _lotteryDataAddress) public {}

    /* 
     * 新建抽奖
     */
    function createLottery(
        string _lotteryName,
        uint _startTime,
        uint _endTime,
        uint _daysStartTime,
        uint _daysEndTime,
        uint _participateCnt,
        uint _perAddressPartCnt
    ) public onlyRole("admin") returns(uint) {
        uint _lotteryId = lotteryData.createLottery(_lotteryName);
        LotteryRule memory lotteryRule = LotteryRule(_startTime, _endTime, _daysStartTime, _daysEndTime, _participateCnt, _perAddressPartCnt);
        lotteryRules[_lotteryId] = lotteryRule;
    }

    /* 
     * 用户抽奖
     */
    function userDraw(uint _lotteryId) public {
        // 检查抽奖是否已结束
        uint status = lotteryData.getLotteryStatus(_lotteryId);
        if (status == 2) {
            revert("lottery is finshed");
        }

        // 检查抽奖是否在活动时间内
        LotteryRule storage lotteryRule = lotteryRules[_lotteryId];
        require(lotteryRule.startTime < now, "lottery is not start");
        if (lotteryRule.endTime < now) {
            lotteryData.closeLottery(_lotteryId, "lottery end time");
            require(lotteryRule.endTime > now, "lottery is finshed");
        }

        // 检查每日抽奖时间条件
        if (lotteryRule.daysStartTime != 0 && lotteryRule.daysEndTime != 0) {
            uint hourNow = now % 1 days / 1 hours + 8; // UTC(+8)时区
            require(hourNow > lotteryRule.daysStartTime && hourNow < lotteryRule.daysEndTime, "not in lottery time");
        }

        // 检查地址数量限制条件
        if (lotteryRule.participateCnt > 0) {
            if (participateCnts[_lotteryId] >= lotteryRule.participateCnt) {
                lotteryData.closeLottery(_lotteryId, "participateCnt exceed the limit");
                require(participateCnts[_lotteryId] <= lotteryRule.participateCnt, "participateCnt exceed the limit");
            }
        }

        // 检查每个地址参与次数限制
        if (lotteryRule.perAddressPartCnt > 0) {
            require(participants[_lotteryId][msg.sender] < lotteryRule.perAddressPartCnt, "perAddressPartCnt exceed the limit");
        }

        // 用户抽奖成功
        if (lotteryData.draw(_lotteryId, msg.sender)) {
            participateCnts[_lotteryId] ++;
            participants[_lotteryId][msg.sender] ++;
        }

    }

}
