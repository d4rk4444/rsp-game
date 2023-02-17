require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-chai-matchers");
require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.17",
    defaultNetwork: "bsc",
    networks: {
      hardhat: {
      },
      bscTestnet: {
        url: "https://bsc-testnet.public.blastapi.io",
        accounts: [process.env.PRIVATE_KEY],
      },
    },
    etherscan: {
      apiKey: '',
    },
    paths: {
        sources: "./contracts",
    },
};