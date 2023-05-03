const { expect } = require("chai");
import { ethers } from "hardhat";
import {
  MimoWallet__factory,
  MimoWalletFactory,
  EntryPoint,
  SwapActionToken,
  MimoWallet,
} from "../src/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Token contract", function () {
  async function deployFixtures(): Promise<{
    factory: MimoWalletFactory;
    entryPoint: EntryPoint;
    deployer: SignerWithAddress;
    paymaster: SignerWithAddress;
    accountOwner: SignerWithAddress;
    guardian1: SignerWithAddress;
    guardian2: SignerWithAddress;
    account2: SignerWithAddress;
    swapActionToken: SwapActionToken;
    mimoAccountAddress: string;
    mimoAccountWallet: MimoWallet;
  }> {
    const [deployer, accountOwner, paymaster, account2, guardian1, guardian2] =
      await ethers.getSigners();

    const EntryPoint = await ethers.getContractFactory("EntryPoint", deployer);
    const entryPoint = await EntryPoint.deploy();
    await entryPoint.deployed();

    const MimoWalletFactory = await ethers.getContractFactory(
      "MimoWalletFactory",
      deployer
    );
    const mimoWalletFactory = await MimoWalletFactory.deploy(
      entryPoint.address
    );
    await mimoWalletFactory.deployed();

    const SwapActionToken = await ethers.getContractFactory(
      "SwapActionToken",
      deployer
    );
    const swapActionToken = await SwapActionToken.deploy();
    await swapActionToken.deployed();

    const mimoAccountAddress = await mimoWalletFactory.getAddress(
      accountOwner.address,
      1337
    );
    await mimoWalletFactory.createAccount(accountOwner.address, 1337, []);

    const mimoAccountWallet = MimoWallet__factory.connect(
      mimoAccountAddress,
      accountOwner
    );

    return {
      factory: mimoWalletFactory,
      entryPoint,
      deployer,
      paymaster,
      accountOwner,
      guardian1,
      guardian2,
      account2,
      mimoAccountWallet,
      swapActionToken,
      mimoAccountAddress,
    };
  }

});
