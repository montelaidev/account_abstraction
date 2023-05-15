import { ethers } from "hardhat";
import deployments from "../deployments.json";
import { ActionTokenPaymaster__factory } from "../src/types";
import { parseEther } from "ethers/lib/utils";

async function main() {
  const [signer] = await ethers.getSigners();

  const paymaster = ActionTokenPaymaster__factory.connect(
    deployments.actionTokenPaymaster,
    signer
  );
  await paymaster.deposit(parseEther("5"));

  console.log(`Transferring 5 to ${deployments.actionTokenPaymaster}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
