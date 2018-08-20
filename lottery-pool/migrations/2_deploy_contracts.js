var LotteryControl = artifacts.require("LotteryControl");
var LotteryData = artifacts.require("LotteryData");

module.exports = function(deployer, nerworks, accounts) {
  let owner = accounts[0];
  deployer.deploy(LotteryData, owner).then(res => {
    lotteryData = res
    return deployer.deploy(LotteryControl, owner, lotteryData.address).then(lotteryControlRes => {
      LotteryControl = lotteryControlRes
      lotteryData.setLotteryControl(LotteryControl.address)
    })
  })
}
