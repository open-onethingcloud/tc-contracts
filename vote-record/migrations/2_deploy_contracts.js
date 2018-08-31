var VoteRecord = artifacts.require("VoteRecord");

module.exports = function(deployer, nerworks, accounts) {
  let owner = accounts[0];
  deployer.deploy(VoteRecord, owner);
}
