var LinkMall = artifacts.require("LinkMall");

// put your own wallet address here
var owner_address = "0x627306090abab3a6e1400e9345bc60c78a8bef57";

module.exports = function(deployer) {
  deployer.deploy(LinkMall, owner_address);
};

