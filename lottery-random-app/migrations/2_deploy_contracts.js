const LotteryData = artifacts.require("./LotteryData.sol")
const LotteryCore = artifacts.require("./LotteryCore.sol")

let lotteryData, lotteryCore

module.exports = function(deployer, nerworks, accounts) {
  console.info(accounts)
  let owner = accounts[0];
  deployer.deploy(LotteryData, owner).then(res => {
    lotteryData = res
    deployer.deploy(LotteryCore, owner, lotteryData.address).then(lotteryCoreRes => {
      lotteryCore = lotteryCoreRes
      lotteryData.setLotteryCore(lotteryCore.address)
      lotteryCore.addAdmin(owner)
    })
  })
}
