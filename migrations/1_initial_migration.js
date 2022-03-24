const YannToken = artifacts.require("YannToken");
const YannTokenSale = artifacts.require("YannTokenSale");

module.exports = function (deployer) {
  // deployer.deploy(YannToken).then(() => {
  //   deployer.deploy(YannTokenSale, YannToken.address);
  // });
  // If this code doesn't work, to deploy the contract token sale
  // we have to copy the contract tokenn address and paste here
  deployer.deploy(YannTokenSale, "0x9352d22695319d677706008BE5A1aE26005eFb01");
};