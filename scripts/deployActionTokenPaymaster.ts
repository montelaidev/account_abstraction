import { ethers } from "hardhat";
import deployments from "../deployments.json";
import fs from "fs";
import { EntryPoint__factory } from "../src/types";
import { parseEther } from "ethers/lib/utils";

async function main() {
  const [signer] = await ethers.getSigners();
  const Paymaster = await ethers.getContractFactory(
    "ActionTokenPaymaster",
    signer
  );
  const paymaster = await Paymaster.deploy(
    deployments.entryPoint,
    signer.address,
    deployments.aaFactory
  );
  await paymaster.deployed();

  console.log(`Paymaster deployed to ${paymaster.address}`);

  console.log("Funding Paymaster");

  await paymaster.addStake(1, { value: ethers.utils.parseEther("0.1") });
  await paymaster.setActionToken([deployments.actionToken]);

  const entryPoint = await EntryPoint__factory.connect(
    deployments.entryPoint,
    signer
  );
  await entryPoint.depositTo(paymaster.address, {
    value: parseEther("0.5"),
  });

  fs.writeFileSync(
    "./deployments.json",
    JSON.stringify({
      ...deployments,
      actionTokenPaymaster: paymaster.address,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
