import { ethers } from "hardhat";
import deployments from "../deployments.json";
import fs from "fs";
import { MimoWallet__factory, EntryPoint__factory } from "../src/types";
import {
  fillAndSign,
  fillUserOpDefaults,
  getUserOpHash,
} from "../test/utils/UserOp";
import { wrapProvider } from "@account-abstraction/sdk";
import { Contract } from "ethers";

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(
    process.env.POLYGON_MUMBAI_PROVIDER
  );
  const [signer] = await ethers.getSigners();
  const config = {
    chainId: await signer.provider?.getNetwork().then((net) => net.chainId),
    entryPointAddress: deployments.entryPoint,
    bundlerUrl: `https://api.stackup.sh/v1/node/${process.env.STACKUP_API_KEY}`,
  };

  // console.log(config);
  // console.log(signer);
  const aaProvider = await wrapProvider(provider, config, signer);
  // console.log(aaProvider);
  const mimoWallet = await MimoWallet__factory.connect(
    deployments.aaInstance,
    aaProvider
  );

  const wallet = new Contract(
    deployments.aaInstance,
    mimoWallet.interface,
    signer
  );

  const res = await wallet.execute(
    signer.address,
    ethers.utils.parseEther("0.05"),
    ethers.constants.HashZero
  );

  console.log(res);

  // const entryPoint = await EntryPoint__factory.connect(
  //   deployments.entryPoint,
  //   signer
  // );

  // // create user op
  // const userOp = await fillAndSign(
  //   {
  //     sender: deployments.aaInstance,
  //     nonce: 0,
  //     callData: mimoWallet.interface.encodeFunctionData("execute", [
  //       signer.address,
  //       0.01,
  //       ethers.constants.HashZero,
  //     ]),
  //   },
  //   signer,
  //   entryPoint
  // );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
