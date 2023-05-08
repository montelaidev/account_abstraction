import { ethers } from "hardhat";
import deployments from "../deployments.json";

async function main() {
  const [signer] = await ethers.getSigners();
  await signer.sendTransaction({
    to: deployments.aaInstance,
    value: ethers.utils.parseEther("0.1"),
  });

  console.log(`Transferring 0.1 to ${deployments.aaInstance}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
