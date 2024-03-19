// const { version } = require("hardhat");
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const etherscanApiKey = "F1Q54SD2AAPJBA4G35INQ8BN8268WG3BQB";
module.exports = {
  solidity: "0.8.20",
  solidity: {
    compilers: [{ version: "0.8.20" }, { version: "0.8.9" },{version:"0.5.16"},{version:"0.6.2"},{version:"0.6.6"},{version:"0.8.24"},{version:"0.4.18"}],
  },
  networks: {
    nordek:{
    url:"https://mainnet-rpc.nordekscan.com/",
    accounts:["0c5efd4ed532b1c91ce3791976eca2cf417af03190da285603f26c57d7effa1d"]},
    nordektestnet:{
      url: "https://testnet-explorer.nordekscan.com/",
      accounts: [
        "0c5efd4ed532b1c91ce3791976eca2cf417af03190da285603f26c57d7effa1d",
      ],
    },
    
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 99999,
    },}
    ,
    etherscan: {
      apiKey: {
        nordek: "api"
      },
      customChains: [
        {
          network: "nordek-testnet",
          chainId: 58875,
          urls: {
            apiURL: "https://testnet-explorer.nordekscan.com/",
            browserURL: "https://testnet-rpc.nordekscan.com/"
          }
        },{
          network: "nordek",
          chainId: 81041,
          urls: {
            apiURL: "https://mainnet-rpc.nordekscan.com/",
            browserURL: "https://testnet-rpc.nordekscan.com/"
          }
        }
      ]
    }
};
