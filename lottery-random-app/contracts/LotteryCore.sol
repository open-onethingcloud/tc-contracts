pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/ownership/rbac/RBAC.sol";
import "./LotteryData.sol";
import "./Ownable.sol";

contract LotteryCore is Ownable, RBAC {

    LotteryData private lotteryData;

    /* 
     * 构造函数
     * params: owner, 数据合约地址
     */
    constructor(address _owner, address _lotteryDataAddress) Ownable(_owner) public {
        require(_owner != address(0x0));
        require(_lotteryDataAddress != address(0x0));
        lotteryData = LotteryData(_lotteryDataAddress);
        addRole(_owner, "admin");
    }

    /* 
     * 添加管理员
     */
    function addAdmin(address _admin) onlyOwner public {
        addRole(_admin, "admin");
    }

    /* 
     * 移除管理员
     */
    function removeAdmin(address _admin) onlyOwner public {
        removeRole(_admin, "admin");
    }

    /* 
     * 升级数据合约地址
     */
    function updateLotteryData(address _lotteryDataAddress) onlyOwner public {
        require(_lotteryDataAddress != address(0x0));
        lotteryData = LotteryData(_lotteryDataAddress);
    }

    /* 
     * 新建抽奖
     */
    function createLottery(string _lotteryName) onlyRole("admin") public returns(uint) {
        return lotteryData.createLottery(_lotteryName);
    }

    /* 
     * 新增抽奖奖品
     */
    function addLotteryPrize(uint _lotteryId, string _prizeName, uint _amount, uint _probability) onlyRole("admin") public {
        lotteryData.addLotteryPrize(_lotteryId, _prizeName, _amount, _probability);
    }

    /* 
     * 启动抽奖
     */
    function startLottery(uint _lotteryId) onlyRole("admin") public {
        lotteryData.startLottery(_lotteryId);
    } 

    /* 
     * 关闭抽奖
     */
    function closeLottery(uint _lotteryId) onlyRole("admin") public {
        lotteryData.closeLottery(_lotteryId);
    }

    /* 
     * 用户抽奖
     */
    function userDraw(uint _lotteryId) public {
        lotteryData.draw(_lotteryId, msg.sender);
    }

}
