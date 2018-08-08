pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Ownable.sol";

contract LotteryData is Ownable {
    using SafeMath for uint;

    address public lotteryCore;

    enum LotteryStatus { Default, Going, Finshed }

    struct Prize {
        string name;            // 奖品名称
        uint amount;            // 奖品数量
        uint remainAmount;      // 剩余数量
        uint probability;       // 概率倒数 （如 1%， 则为 100）
        address[] winners;      // 中奖用户列表
        mapping(address => bytes32) winRecords; // 中奖纪录
        uint[] winProbArray;    // 随机数中奖区间
    }

    struct Lottery {
        string name;            // 抽奖名称
        LotteryStatus status;   // 抽奖状态
        uint totalPrizeAmount;  // 总奖品数量
        uint totalDrawCnt;      // 总抽奖次数 
        uint LCM;               // 奖品列表概率倒数的最小公倍数
        Prize[] prizes;         // 奖品列表
    }

    Lottery[] public lotteries;

    event NewLotteryCore(address _lotteryCore);
    event UserDrawInfo(bytes32 hash, uint converHash, uint randomRes);
    event CloseLottery(uint _lotteryId, string reason);

    constructor(address _owner) Ownable(_owner) public {}

    /* 
     * 逻辑合约修饰
     */
    modifier onlyCore() {
        require(msg.sender == lotteryCore, "Only Core contract modifier");
        _;
    }

    /* 
     * 设置抽奖逻辑合约地址
     */
    function setLotteryCore(address _lotteryCore) public onlyOwner {
        lotteryCore = _lotteryCore;
        emit NewLotteryCore(_lotteryCore);
    }

    /* 
     * 创建抽奖
     */
    function createLottery(string _name) external onlyCore returns(uint) {
        lotteries.length ++;
        Lottery storage lottery = lotteries[lotteries.length - 1];
        lottery.name = _name;
        lottery.status = LotteryStatus.Default;
        return lotteries.length-1;
    }

    /* 
     * 新增抽奖奖品
     */
    function addLotteryPrize(uint lotteryId, string _name, uint _amount, uint _probability) external onlyCore {
        Lottery storage lottery = lotteries[lotteryId];
        require(lottery.status == LotteryStatus.Default, "lottery status not Default");
        Prize memory prize;
        prize.name = _name;
        prize.amount = _amount;
        prize.remainAmount = _amount;
        prize.probability = _probability;
        lottery.prizes.push(prize);
        lottery.totalPrizeAmount += _amount;
    }

    /* 
     * 获取lotteries数组长度
     */
    function getLotteriesLength() public view returns(uint) {
        return lotteries.length;
    }

    /* 
     * 获取抽奖的奖品数组长度
     */
    function getLotteryPrizesLength(uint _lotteryId) public view returns(uint) {
        return lotteries[_lotteryId].prizes.length;
    }

    /* 
     * 启动抽奖
     */
    function startLottery(uint lotteryId) external onlyCore {
        Lottery storage lottery = lotteries[lotteryId];
        require(lottery.status == LotteryStatus.Default, "lottery status not Defalut");
        require(lottery.prizes.length > 0, "lottery prizes is null");
        lottery.LCM = getLestCommonMulArray(lotteryId);
        uint winProbBegin = 0;
        for (uint i = 0; i < lottery.prizes.length; i++) {
            Prize storage prize = lottery.prizes[i];
            for (uint j = 0; j < lottery.LCM.div(prize.probability); j++) {
                prize.winProbArray.push(winProbBegin);
                winProbBegin ++;
            }
        }

        lottery.status = LotteryStatus.Going;
    }

    /* 
     * 关闭抽奖
     */
    function closeLottery(uint lotteryId, string reason) public onlyCore {
        Lottery storage lottery = lotteries[lotteryId];
        lottery.status = LotteryStatus.Finshed;
        emit CloseLottery(lotteryId, reason);
    }

    /* 
     * 用户抽奖
     */
    function draw(uint lotteryId, address sender) external onlyCore returns(bool) {
        Lottery storage lottery = lotteries[lotteryId];
        require(lottery.status == LotteryStatus.Going, "lottery status is not Going");
        lottery.totalDrawCnt ++;
        uint random = getRandomNum(lottery.totalDrawCnt);
        
        uint drawRes = random % lottery.LCM;
        emit UserDrawInfo(blockhash(block.number - 1), random, drawRes);
        for (uint i = 0; i < lottery.prizes.length; i++) {
            Prize storage prize = lottery.prizes[i];
            if (prize.remainAmount > 0) {
                for (uint j = 0; j < prize.winProbArray.length; j++) {
                    if (drawRes == prize.winProbArray[j]) {
                        prize.winners.push(sender);
                        prize.winRecords[sender] = blockhash(block.number - 1);
                        prize.remainAmount --;
                        lottery.totalPrizeAmount --;

                        if (lottery.totalPrizeAmount == 0) {
                            closeLottery(lotteryId, "run out of prizes");
                        }
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /* 
     * 获取随机值
     * 过程：uint(keccak256(拼接字符串 (上一块的blockhash + msg.sender + 全局自增index)))
     */
    function getRandomNum(uint lotteryCnt) internal view returns(uint) {
        bytes32 blockhashBytes = blockhash(block.number - 1);
        bytes32 lotteryBytes = bytes32(lotteryCnt);
        uint joinLength = blockhashBytes.length + 20 + lotteryBytes.length;
        bytes memory hashJoin = new bytes(joinLength);
        uint k = 0;
        for (uint i = 0; i < blockhashBytes.length; i++) {
            hashJoin[k++] = blockhashBytes[i];
        }
        // bytes 拼接 msg.sender 地址
        for (i = 0; i < 20; i++) {
            hashJoin[k++] = byte(uint8(uint(msg.sender) / (2 ** (8 * (19 - i))))); 
        }
        for (i = 0; i < lotteryBytes.length; i++) {
            hashJoin[k++] = lotteryBytes[i];
        }
        return uint(keccak256(hashJoin));
    }
    
    /* 
     * 获取抽奖信息
     */
    function getLotteryInfo(uint _lotteryId) public view returns(string, uint, uint, uint, uint) {
        Lottery storage lottery = lotteries[_lotteryId];
        return (
            lottery.name,
            uint(lottery.status),
            lottery.totalPrizeAmount,
            lottery.LCM,
            lottery.prizes.length
        );
    }

    /* 
     * 获取抽奖奖品信息
     */
    function getLotteryPrizeInfo(uint _lotteryId, uint prizeIndex) public view returns(string, uint, uint, uint, address[], uint[]) {
        Lottery storage lottery = lotteries[_lotteryId];
        Prize storage prize = lottery.prizes[prizeIndex];

        return (
            prize.name,
            prize.amount,
            prize.remainAmount,
            prize.probability,
            prize.winners,
            prize.winProbArray
        );
    }

    /* 
     * 获取抽奖状态
     */
    function getLotteryStatus(uint _lotteryId) public view returns(uint) {
        Lottery storage lottery = lotteries[_lotteryId];
        return uint(lottery.status);
    }

    /* 
     * 求奖品概率倒数的最小公倍数
     */
    function getLestCommonMulArray(uint lotteryId) internal view returns(uint) {
        Lottery storage lottery = lotteries[lotteryId];
        uint prizesLength = lottery.prizes.length;
        uint[] memory probArray = new uint[](prizesLength);
        for (uint i = 0; i < prizesLength; i++) {
            probArray[i] = lottery.prizes[i].probability;
        }
        uint tempLCM = probArray[0];
        for (uint j = 0; j < probArray.length - 1; j ++) {
            tempLCM = getLestCommonMul(tempLCM, probArray[j+1]);
        }
        return tempLCM;
    }

    function getLestCommonMul(uint a, uint b) internal pure returns(uint) {
        uint min = a > b ? b : a;
        uint max = a > b ? a : b;

        for (uint i = 1; i <= max; i++) {
            uint temp = min.mul(i);
            if (temp % max == 0) {
                return temp;
            }
        }
    }

}
