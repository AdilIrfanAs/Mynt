const hre = require("hardhat");

async function main() {

  const MyToken = await hre.ethers.getContractFactory("MYNTIST");
  const myToken = await MyToken.deploy();
  await myToken.deployed();
  console.log("MYNTIST deployed to:", myToken.address);

  // const AdoptionAmplifer = await hre.ethers.getContractFactory("AdoptionAmplifer");
  // const adoptionAmplifer = await AdoptionAmplifer.deploy();
  // await adoptionAmplifer.deployed();
  // console.log("MyAdoptionAmplifier deployed to:", adoptionAmplifer.address);

  // npx hardhat run --network bsctestnet scripts/script.js
  // npx hardhat  verify --network bsctestnet addressofcontract
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
