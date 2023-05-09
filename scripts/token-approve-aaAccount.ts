import { ethers } from "hardhat";
import fs from "fs";
import deployments from "../deployments.json";
import { MimoWallet__factory, SwapActionToken__factory } from "../src/types";

async function main() {
  const [signer] = await ethers.getSigners();
  // const swapActionToken = await SwapActionToken__factory(
  //   deployments.actionToken,
  //   signer
  // );
  const swapActionToken = (
    await ethers.getContractFactory("SwapActionToken", signer)
  ).attach(deployments.actionToken);

  const mimoWallet = await MimoWallet__factory.connect(
    deployments.aaInstance,
    signer
  );

  await mimoWallet.execute(
    swapActionToken.address,
    0,
    swapActionToken.interface.encodeFunctionData("approve", [
      deployments.actionTokenPaymaster,
      ethers.constants.MaxUint256,
    ])
  );

  console.log(
    `Approved ${deployments.aaInstance} to use max Action Token ${deployments.actionToken}`
  );

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
