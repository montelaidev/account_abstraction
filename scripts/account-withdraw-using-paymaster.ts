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
import { hexConcat, hexZeroPad, hexlify, parseEther } from "ethers/lib/utils";
const sdk = require("api")("@stackup/v0.6#9j72valhd1dd90");
import axios from "axios";

async function main() {
  const [signer] = await ethers.getSigners();
  const chainId = await signer.provider
    ?.getNetwork()
    .then((net) => net.chainId)!;

  const mimoWallet = await MimoWallet__factory.connect(
    deployments.aaInstance,
    signer
  );

  const entryPoint = await EntryPoint__factory.connect(
    deployments.entryPoint,
    signer
  );

  // create user op
  const userOp = await fillAndSign(
    fillUserOpDefaults({
      sender: deployments.aaInstance,
      callData: mimoWallet.interface.encodeFunctionData("execute", [
        signer.address,
        parseEther("0.0123"),
        ethers.constants.HashZero,
      ]),
      paymasterAndData: hexConcat([
        deployments.actionTokenPaymaster,
        hexZeroPad(deployments.actionToken, 32),
        hexZeroPad(hexlify(1), 32),
      ]),
      nonce: (await mimoWallet.nonce()).toHexString(),
      callGasLimit: hexlify(200000),
      verificationGasLimit: hexlify(100000),
    }),
    signer,
    entryPoint
  );

  const userOpHash = getUserOpHash(userOp, deployments.entryPoint, chainId);

  const actualGasPrice = 1e9;
  const callGasLimit = 200000;
  const verificationGasLimit = 100000;
  const maxFeePerGas = 3e9;
  const expectedPay = actualGasPrice * (callGasLimit + verificationGasLimit);

  console.log(userOp);

  const res = await axios.post(
    process.env.BUNDLER_URL!,
    {
      jsonrpc: "2.0",
      id: 1,
      method: "eth_sendUserOperation",
      params: [userOp, deployments.entryPoint],
    },
    {
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
    }
  );
  console.log(res.data);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
