import { ethers } from "hardhat";
import fs from "fs";
import deployments from "../deployments.json";

async function main() {
  const [signer] = await ethers.getSigners();
  const SwapActionToken = await ethers.getContractFactory(
    "SwapActionToken",
    signer
  );
  const swapActionToken = await SwapActionToken.deploy();
  await swapActionToken.deployed();
  console.log(`ActionToken deployed to ${swapActionToken.address}`);

  await swapActionToken.mint(signer.address, 10);
  fs.writeFileSync(
    "./deployments.json",
    JSON.stringify({
      ...deployments,
      actionToken: swapActionToken.address,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
