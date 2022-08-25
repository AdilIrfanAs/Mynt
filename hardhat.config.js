require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const ROPSTEN_PRIVATE_KEY = "45ef7ad1b638dceb77dd33aa81cbdc7ce2961bfb685d9fd5750a0c962ba2380a";
const mnemonic =  "duck toss shadow loop tenant ability concert language cart answer pull harbor";

// "stadium chief figure relax fox food smile survey since spin solution comfort";


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html


task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000
      }
    }
  },
  networks: {
    ropsten: {
      url: `https://ropsten.infura.io/v3/33d4c2fbdc21481084faea019f41ca17`,
      accounts: [`${ROPSTEN_PRIVATE_KEY}`]
    },
    bsctestnet: {
      url: " https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      gasPrice: "auto",
      accounts: {mnemonic: mnemonic}
    },
  },
  etherscan: {
    // apiKey: "G6I4KD2IVT8FDUCRZ1RIEB84H2DNUMTM9N"
    apiKey: "T74SH4VYYEPBQ1F3N2N673FKBGEPZGEJ2H"
  }
};
