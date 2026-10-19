const hre = require("hardhat");
async function main() {
  const Hub = await hre.ethers.getContractFactory("EcoCarbonCreditHub");
  const hub = await Hub.deploy();
  await hub.deployed();
  console.log("Carbon Credit Hub deployed to:", hub.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
