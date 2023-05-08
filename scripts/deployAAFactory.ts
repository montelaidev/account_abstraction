import { ethers } from "hardhat";
import deployments from "../deployments.json";
import fs from "fs";

async function main() {
  const MimoWalletFactory = await ethers.getContractFactory(
    "MimoWalletFactory"
  );
  const mimoWalletFactory = await MimoWalletFactory.deploy(
    deployments.entryPoint
  );
  await mimoWalletFactory.deployed();

  console.log(`MimoWalletFactory deployed to ${mimoWalletFactory.address}`);
  fs.writeFileSync(
    "./deployments.json",
    JSON.stringify({
      ...deployments,
      aaFactory: mimoWalletFactory.address,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
