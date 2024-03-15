
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  //Make sure to change the factory and weth contract respectively in below parameters
  const router = await hre.ethers.deployContract("NordekRouterV2", ["0xdf320C4265cb7a038FFd7dF1F745D4110f88c3d2","0x637e912D9dC788355FE827ef872C063951282f67"]);

  await router.waitForDeployment();
  console.log("Router contract deployed at",router.target)

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
