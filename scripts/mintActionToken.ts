import { ethers } from "hardhat";
import fs from "fs";
import deployments from "../deployments.json";
import { SwapActionToken__factory } from "../src/types";

async function main() {
  const [signer] = await ethers.getSigners();
  // const swapActionToken = await SwapActionToken__factory(
  //   deployments.actionToken,
  //   signer
  // );
  const swapActionToken = (
    await ethers.getContractFactory("SwapActionToken", signer)
  ).attach(deployments.actionToken);

  await swapActionToken.mint(signer.address, 10);
  await swapActionToken.mint(deployments.aaInstance, 10);
  await swapActionToken.mint(
    "0x92Ae3d43d997a644744E67B095ED526c17Ba3f85",
    100000000000
  );

  console.log(`Minted ${signer.address} 10 action tokens`);

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
