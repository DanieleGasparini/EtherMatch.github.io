var Election = artifacts.require("./Ethership.sol");

module.exports = function(deployer) {
  deployer.deploy(Election);
};