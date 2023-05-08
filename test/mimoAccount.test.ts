const { expect } = require("chai");
import { ethers } from "hardhat";
import { Wallet } from "ethers";
import {
  MimoWallet__factory,
  MimoWalletFactory,
  EntryPoint,
  SwapActionToken,
  MimoWallet,
  ActionTokenPaymaster,
} from "../src/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  signUserOp,
  fillUserOpDefaults,
  getUserOpHash,
  fillAndSign,
} from "./utils/UserOp";
import {
  defaultAbiCoder,
  hexConcat,
  hexZeroPad,
  hexlify,
  parseEther,
} from "ethers/lib/utils";

describe("AA Tests", function () {
  async function deployFixtures({
    mockEntrypointEOA,
  }: {
    mockEntrypointEOA?: string;
  } = {}): Promise<{
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
    accountOwnerWallet: Wallet;
    tokenPaymaster: ActionTokenPaymaster;
  }> {
    const [accountOwner, deployer, paymaster, account2, guardian1, guardian2] =
      await ethers.getSigners();

    const EntryPoint = await ethers.getContractFactory("EntryPoint", deployer);
    const entryPoint = await EntryPoint.deploy();
    await entryPoint.deployed();

    const MimoWalletFactory = await ethers.getContractFactory(
      "MimoWalletFactory",
      deployer
    );
    const mimoWalletFactory = await MimoWalletFactory.deploy(
      mockEntrypointEOA ?? entryPoint.address
    );
    await mimoWalletFactory.deployed();

    const SwapActionToken = await ethers.getContractFactory(
      "SwapActionToken",
      deployer
    );
    const swapActionToken = await SwapActionToken.deploy();
    await swapActionToken.deployed();

    console.log(`Swap Action Token deployed to ${swapActionToken.address}`);

    const mimoAccountAddress = await mimoWalletFactory.getAddress(
      accountOwner.address,
      1337
    );
    await mimoWalletFactory.createAccount(accountOwner.address, 1337, []);

    const mimoAccountWallet = MimoWallet__factory.connect(
      mimoAccountAddress,
      accountOwner
    );

    console.log(`AA Wallet Deployed to ${mimoAccountWallet.address}`);

    // mock oracle to always return 0
    const ActionTokenOracle = await ethers.getContractFactory(
      "ActionPriceOracle",
      deployer
    );

    const actionTokenOracle = await ActionTokenOracle.deploy();
    await actionTokenOracle.deployed();

    const TokenPaymasterFactory = await ethers.getContractFactory(
      "ActionTokenPaymaster",
      deployer
    );
    const tokenPaymaster = await TokenPaymasterFactory.deploy(
      entryPoint.address,
      deployer.address,
      mimoWalletFactory.address
    );
    await tokenPaymaster.deployed();
    console.log(`Paymaster deployed to ${tokenPaymaster.address}`);

    await tokenPaymaster.addStake(1, { value: parseEther("2") });
    await entryPoint.depositTo(tokenPaymaster.address, {
      value: parseEther("100"),
    });

    await tokenPaymaster.setActionToken([swapActionToken.address]);
    await swapActionToken.mint(accountOwner.address, 1000);

    await mimoAccountWallet.execute(
      swapActionToken.address,
      0,
      swapActionToken.interface.encodeFunctionData("approve", [
        tokenPaymaster.address,
        1000,
      ])
    );

    const accountOwnerWallet = ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk"
    );

    console.log(
      "compare owner to wallet",
      accountOwner.address,
      accountOwnerWallet.address
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
      accountOwnerWallet,
      tokenPaymaster,
    };
  }

  describe("Entrypoint", () => {
    it("should be able to deploy new account with initcode", async () => {});

    it("should be able to verify a signature", async () => {});

    it("should be able to execute handleOps", async () => {});
  });

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

  describe.only("MimoAccountWallet", () => {
    it("admin can call execute or executeBatch", async () => {
      const { mimoAccountWallet, accountOwner, guardian1 } =
        await deployFixtures();

      // sending eth to the account
      const tx = {
        to: mimoAccountWallet.address,
        value: 1000,
      };
      await accountOwner.sendTransaction(tx);

      const balanceBefore = await ethers.provider.getBalance(
        mimoAccountWallet.address
      );
      await mimoAccountWallet.execute(
        guardian1.address,
        500,
        ethers.constants.HashZero
      );

      const balanceAfter = await ethers.provider.getBalance(
        mimoAccountWallet.address
      );
      expect(balanceBefore.sub(balanceAfter).eq(ethers.BigNumber.from(500))).to
        .be.true;

      await mimoAccountWallet.executeBatch(
        [guardian1.address, guardian1.address],
        ["250", "250"],
        [ethers.constants.HashZero, ethers.constants.HashZero]
      );

      const balanceAfterBatch = await ethers.provider.getBalance(
        mimoAccountWallet.address
      );
      expect(balanceAfterBatch.eq(ethers.BigNumber.from(0))).to.be.true;
    });
    it("unauthorized cannot call execute or executeBatch", async () => {
      const { account2, mimoAccountWallet } = await deployFixtures();

      await expect(
        mimoAccountWallet
          .connect(account2)
          .execute(account2.address, 1000, ethers.constants.HashZero)
      ).to.be.revertedWith("MimoAccountWallet: not Owner or EntryPoint");
    });

    it("should be able to withdraw any erc20 token", async () => {
      const { accountOwner, swapActionToken, mimoAccountWallet } =
        await deployFixtures();

      await swapActionToken.mint(mimoAccountWallet.address, 1000);

      const balanceBefore = await swapActionToken.balanceOf(
        accountOwner.address
      );

      await mimoAccountWallet.execute(
        swapActionToken.address,
        0,
        swapActionToken.interface.encodeFunctionData("transfer", [
          accountOwner.address,
          1000,
        ])
      );

      const balanceAfter = await swapActionToken.balanceOf(
        accountOwner.address
      );
      expect(balanceAfter).to.equal(balanceBefore.add(1000));
      expect(await swapActionToken.balanceOf(mimoAccountWallet.address)).to.eq(
        0
      );
    });
    it("should be able to withdraw ether", async () => {
      const { accountOwner, account2, mimoAccountWallet } =
        await deployFixtures();

      await accountOwner.sendTransaction({
        to: mimoAccountWallet.address,
        value: 1000,
      });

      const balanceBefore = await ethers.provider.getBalance(account2.address);

      await mimoAccountWallet.execute(
        account2.address,
        1000,
        ethers.constants.HashZero
      );

      const balanceAfter = await ethers.provider.getBalance(account2.address);
      expect(balanceAfter.sub(balanceBefore)).to.equal(1000);
    });

    describe.only("validateSignatures", () => {
      const actualGasPrice = 1e9;
      it("should be able to validate an admin signature", async () => {
        // gets unused signer
        const entrypointEOA = (await ethers.getSigners())[10];
        const {
          mimoAccountWallet,
          accountOwner,
          accountOwnerWallet,
          entryPoint,
        } = await deployFixtures({ mockEntrypointEOA: entrypointEOA.address });

        const callGasLimit = 200000;
        const verificationGasLimit = 100000;
        const maxFeePerGas = 3e9;
        const chainId = await ethers.provider
          .getNetwork()
          .then((net) => net.chainId);
        console.log("chainid", chainId);

        const userOp = await signUserOp(
          fillUserOpDefaults({
            sender: mimoAccountWallet.address,
            callGasLimit,
            verificationGasLimit,
            maxFeePerGas,
          }),
          accountOwnerWallet,
          entrypointEOA.address,
          chainId
        );

        console.log("userop", userOp);
        console.log("account owner", accountOwnerWallet.address);
        console.log("account owner", accountOwner.address);
        console.log("entryPointEOA", entrypointEOA.address);

        const userOpHash = getUserOpHash(
          userOp,
          entrypointEOA.address,
          chainId
        );
        const expectedPay =
          actualGasPrice * (callGasLimit + verificationGasLimit);

        const result = await mimoAccountWallet
          .connect(entrypointEOA)
          .callStatic.validateUserOp(userOp, userOpHash, expectedPay, {
            gasPrice: actualGasPrice,
          });
        console.log(result);

        expect(result.eq(0)).to.be.true;
      });
    });
  });

  describe("Action Token accountOwnerWalletPaymaster", () => {
    describe("validatePaymasterUserOp", () => {
      it("validate paymaster successfully", async () => {
        const {
          entryPoint,
          tokenPaymaster,
          mimoAccountWallet,
          accountOwnerWallet,
          swapActionToken,
        } = await deployFixtures();
        const userOp = await fillAndSign(
          {
            sender: mimoAccountWallet.address,
            paymasterAndData: hexConcat([
              tokenPaymaster.address,
              hexZeroPad(swapActionToken.address, 32),
              hexZeroPad(hexlify(1), 32),
            ]),
          },
          accountOwnerWallet,
          entryPoint
        );
        console.log(userOp);
        console.log(
          await entryPoint.callStatic
            .simulateValidation(userOp)
            .catch(simulationResultCatch)
        );
      });
    });
  });
});

/**
 * process exception of ValidationResult
 * usage: entryPoint.simulationResult(..).catch(simulationResultCatch)
 */
export function simulationResultCatch(e: any): any {
  if (e.errorName !== "ValidationResult") {
    throw e;
  }
  return e.errorArgs;
}
