import { ethers } from "hardhat";
import deployments from "../deployments.json";
import fs from "fs";

async function main() {
  const RouterWrapper = await ethers.getContractFactory("RouterWrapper");
  const routerWrapper = await RouterWrapper.deploy(
    "0x8954AfA98594b838bda56FE4C12a09D7739D179b", // mumbai router address for quickswap
    deployments.actionToken,
    [10, 20, 50],
    [1, 5, 10]
  );
  await routerWrapper.deployed();

  console.log(`RouterWrapper deployed to ${routerWrapper.address}`);
  fs.writeFileSync(
    "./deployments.json",
    JSON.stringify({
      ...deployments,
      routerWrapper: routerWrapper.address,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
