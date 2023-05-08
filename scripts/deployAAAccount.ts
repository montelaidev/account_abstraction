import { ethers } from "hardhat";
import deployments from "../deployments.json";
import fs from "fs";
import { MimoWalletFactory__factory } from "../src/types";

async function main() {
  const salt = new Date().getTime();

  const [signer] = await ethers.getSigners();
  const MimoWalletFactory = await MimoWalletFactory__factory.connect(
    deployments.aaFactory,
    signer
  );

  const mimoAccountAddress = await MimoWalletFactory.getAddress(
    signer.address,
    salt
  );

  const mimoWallet = await MimoWalletFactory.createAccount(
    signer.address,
    salt,
    []
  );

  await mimoWallet.wait();

  console.log(`MimoWallet deployed to ${mimoAccountAddress}`);
  fs.writeFileSync(
    "../deployments.json",
    JSON.stringify({
      ...deployments,
      aaInstance: mimoAccountAddress,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
