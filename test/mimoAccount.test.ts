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

  describe("MimoWalletFactory", () => {
    it("should deploy to a deterministic address", async () => {
      const { factory, accountOwner } = await deployFixtures();

      const salt = 0;
      const address = await factory.getAddress(accountOwner.address, salt);

      console.log(
        `Deploying to ${address}, owner is ${accountOwner.address}, salt is ${salt}`
      );

      // contract should not have been deployed
      expect(
        await ethers.provider.getCode(address).then((code) => code.length)
      ).to.equal("0x".length);

      await factory.createAccount(accountOwner.address, salt, []);

      expect(
        await ethers.provider.getCode(address).then((code) => code.length)
      ).to.gt("0x".length);
    });

    it("should deploy to a different address based on a different salt", async () => {
      const { factory, accountOwner } = await deployFixtures();

      const salt1 = 0;
      const address1 = await factory.getAddress(accountOwner.address, salt1);

      const salt2 = 1;
      const address2 = await factory.getAddress(accountOwner.address, salt2);

      expect(address1).to.not.equal(address2);

      await factory.createAccount(accountOwner.address, salt1, []);
      await factory.createAccount(accountOwner.address, salt2, []);

      expect(
        await ethers.provider.getCode(address1).then((code) => code.length)
      ).to.gt("0x".length);
      expect(
        await ethers.provider.getCode(address2).then((code) => code.length)
      ).to.gt("0x".length);
    });
  });
});
