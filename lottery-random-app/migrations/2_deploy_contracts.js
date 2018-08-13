const LotteryData = artifacts.require("LotteryData")
const LotteryCore = artifacts.require("LotteryCore")

let lotteryData, lotteryCore

module.exports = function(deployer, nerworks, accounts) {
  let owner = accounts[0];
  deployer.deploy(LotteryData, owner).then(res => {
    lotteryData = res
    return deployer.deploy(LotteryCore, owner, lotteryData.address).then(lotteryCoreRes => {
      lotteryCore = lotteryCoreRes
      lotteryData.setLotteryCore(lotteryCore.address)
    })
  })
}
