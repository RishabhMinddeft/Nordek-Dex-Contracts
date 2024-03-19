// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = hre.ethers.parseEther("0.001");

  // const lock = await hre.ethers.deployContract("Lock", [unlockTime], {
  //   value: lockedAmount,
  // });

  // await lock.waitForDeployment();

  const weth = await hre.ethers.deployContract("WNRK9");

  await weth.waitForDeployment();
  console.log("weth contract deployed at",weth.target)

  //set 
  const factory = await hre.ethers.deployContract("NordekV2Factory", ["0x8D5F686e8d3F91678a8E2F3B327eFD8533567146","0x8D5F686e8d3F91678a8E2F3B327eFD8533567146"]);

  await factory.waitForDeployment();
  console.log("Factory contract deployed at",factory.target)

  // const router = await hre.ethers.deployContract("SwapRouterV2", [factory.target,"0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",weth.target]);

  // await router.waitForDeployment();
  // console.log("Router contract deployed at",router.target)
  // console.log(
  //   `Lock with ${ethers.formatEther(
  //     lockedAmount
  //   )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  // );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
