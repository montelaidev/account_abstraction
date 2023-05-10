import { ethers } from "hardhat";
import deployments from "../deployments.json";
import { MimoWallet__factory, EntryPoint__factory } from "../src/types";
import {
  fillAndSign,
  fillUserOpDefaults,
  getUserOpHash,
} from "../test/utils/UserOp";
import { hexConcat, hexZeroPad, hexlify, parseEther } from "ethers/lib/utils";
import axios from "axios";
import routerAbi from "../contracts/Router02.json";

async function main() {
  const [signer] = await ethers.getSigners();

  const mimoWallet = await MimoWallet__factory.connect(
    deployments.aaInstance,
    signer
  );

  const entryPoint = await EntryPoint__factory.connect(
    deployments.entryPoint,
    signer
  );

  const routerWrapper = new ethers.Contract(
    deployments.routerWrapper,
    routerAbi,
    signer
  );

  // prefund account with eth
  // await signer.sendTransaction({
  //   to: deployments.aaInstance,
  //   value: parseEther("0.1"),
  // });

  // create user op
  const userOp = await fillAndSign(
    fillUserOpDefaults({
      sender: deployments.aaInstance,
      callData: mimoWallet.interface.encodeFunctionData("execute", [
        deployments.routerWrapper,
        parseEther("0.05"),
        routerWrapper.interface.encodeFunctionData("swapExactETHForTokens", [
          1,
          [
            "0x9c3c9283d3e44854697cd22d3faa240cfb032889", // wmatic
            "0x08DAB81afBfb78bAD99731204D5a3f510F71588a", // usdc
          ], //path
          deployments.aaInstance, //to
          new Date().getTime() + 60000, // deadline
        ]),
      ]),
      paymasterAndData: hexConcat([
        deployments.actionTokenPaymaster,
        hexZeroPad(deployments.actionToken, 32),
        hexZeroPad(hexlify(1), 32),
      ]),
      nonce: (await mimoWallet.nonce()).toHexString(),
      callGasLimit: hexlify(200000),
      verificationGasLimit: hexlify(100000),
      maxFeePerGas: hexlify(3e9),
    }),
    signer,
    entryPoint
  );

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
