var VoteControl = artifacts.require("VoteControl");
var VoteData = artifacts.require("VoteData");

module.exports = function(deployer, nerworks, accounts) {
  let owner = accounts[0];
  deployer.deploy(VoteData, owner).then(res => {
    voteData = res
    return deployer.deploy(VoteControl, owner, voteData.address).then(voteControlRes => {
      voteControl = voteControlRes
      voteData.setVoteControl(voteControl.address)
    })
  })
}
