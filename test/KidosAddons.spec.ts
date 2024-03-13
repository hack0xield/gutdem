import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe.only("DemKidos Drop and Stake Test", async () => {
  let demKidos: Contract;
  let kidosDrop: Contract;
  let kidosStake: Contract;
  let otherNFT: Contract;
  let demBacon: Contract;

  let accounts: Signer[];

  let kidosAddress: string;
  let toddlerAddress: string;
  let demBaconAddress: string;

  const CLAIM_REWARD = 40; // ether;
  const DEFAULT_STAKE_PERIOD = 24; // hours;

  const DEPLOYER_ID = 0;
  const MANAGER_ID = 0;
  const SIGNER_ID = 1;
  const PLAYER_ID1 = 2;
  const PLAYER_ID2 = 3;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    kidosAddress = deployOutput.kidos;
    toddlerAddress = deployOutput.toddlerDemNft;
    demBaconAddress = deployOutput.demBacon;

    accounts = await ethers.getSigners();

    demKidos = await ethers.getContractAt(
      "DemKidos",
      kidosAddress,
      accounts[0],
    );
    kidosDrop = await ethers.getContractAt(
      "KidosDrop",
      kidosAddress,
      accounts[0],
    );
    kidosStake = await ethers.getContractAt(
      "KidosStake",
      kidosAddress,
      accounts[0],
    );
    otherNFT = await ethers.getContractAt(
      "DemNft",
      toddlerAddress,
      accounts[0],
    );
    demBacon = await ethers.getContractAt(
      "DbnToken",
      demBaconAddress,
      accounts[0],
    );
  });

  it("Whitelisted sale test", async () => {
    const signer = accounts[SIGNER_ID];
    const signPublic = await signer.getAddress();
    const user = accounts[PLAYER_ID1];
    const address = await user.getAddress();

    {
      const tx = await kidosDrop.setSigVerifierAddress(signPublic);
      expect((await tx.wait()).status).to.be.equal(1);
    }

    const ticketNumber = testCfg.kidosTicketsCount + 119;
    const amount = ethers.parseEther("5000");
    const msg = ethers.solidityPackedKeccak256(
      ["address", "uint256", "uint256"],
      [address, ticketNumber, amount],
    );
    const sig1 = await signer.provider.send("eth_sign", [signPublic, msg]);
    //     const sig2 = await signer.provider.send("personal_sign",
    //       [msg, signPublic]
    //     );
    //     console.log(sig2);
    //
    //     const sig3 = await signer.signMessage(msg);
    //     console.log(sig3);

    {
      const tx = await kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount);
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount);
      await expect(tx).to.be.revertedWith("KidosDrop: Already claimed");
    }
  });

  let tokenId0;

  describe("Kidos Stake", function () {
    it("Owner should be changed", async () => {
      const user = accounts[PLAYER_ID1];
      await demKidos
        .connect(accounts[MANAGER_ID])
        .transfer(user, ethers.parseEther("5000"));

      const owned = await demKidos.owned(user.address);
      expect(owned.length).to.be.equal(1);
      tokenId0 = owned[0];
    });

    it("Stake", async () => {
      const user = accounts[PLAYER_ID1];

      expect((await kidosStake.stakedTokens(user.address)).length).to.equal(0);
      {
        const tx = demKidos.connect(user).safeTransferFrom(
          //["safeTransferFrom(address,address,uint256)"](
          user.address,
          kidosAddress,
          tokenId0,
        );
        await expect(tx).to.be.revertedWith("KidosStake: Stake is disabled");
      }
      await kidosStake.connect(accounts[MANAGER_ID]).setStakeEnabled(true);
      await demKidos.connect(user).safeTransferFrom(
        //["safeTransferFrom(address,address,uint256)"](
        user.address,
        kidosAddress,
        tokenId0,
      );
      expect((await kidosStake.stakedTokens(user.address)).length).to.equal(1);
    });

    it("Reject claim for no owner", async () => {
      await expect(
        kidosStake.connect(accounts[PLAYER_ID2]).claim(tokenId0),
      ).to.be.revertedWith("KidosStake: Only original owner can claim");
    });

    it("Withdraw", async () => {
      expect(
        await demKidos.connect(accounts[PLAYER_ID1]).ownerOf(tokenId0),
      ).to.be.equal(kidosAddress);

      await kidosStake.connect(accounts[PLAYER_ID1]).claimAndWithdraw(tokenId0);

      expect(
        await demKidos.connect(accounts[PLAYER_ID1]).ownerOf(tokenId0),
      ).to.be.equal(accounts[PLAYER_ID1].address);
    });

    it("Reject withdraw for no owner", async () => {
      await expect(
        kidosStake.connect(accounts[PLAYER_ID2]).claimAndWithdraw(tokenId0),
      ).to.be.revertedWith("KidosStake: Only original owner can claim");
    });
  });

  describe("Wrong NFT Stake", function () {
    it("Reject if other NFT staked", async () => {
      const owner = accounts[DEPLOYER_ID];
      const user = accounts[PLAYER_ID1];
      await helpers.buyToddlers(owner, user, 1, demBacon, otherNFT);
      await expect(
        otherNFT.connect(accounts[PLAYER_ID1]).safeTransferFrom(
          //["safeTransferFrom(address,address,uint256)"](
          accounts[PLAYER_ID1].address,
          kidosAddress,
          0,
        ),
      ).to.be.revertedWith("KidosStake: Expects DemKidos NFT");
    });
  });

  describe("Stake and Claim balances", function () {
    async function checkBalance(amount: BigNumber) {
      const balance = await demKidos.balanceOf(accounts[PLAYER_ID1].address);
      //console.log(balance);
      expect(balance).to.be.equal(amount);
    }

    it("Balance Checks", async () => {
      const initAmount = 0n; //ethers.parseEther("1");
      await demKidos.connect(accounts[PLAYER_ID1]).safeTransferFrom(
        //["safeTransferFrom(address,address,uint256)"](
        accounts[PLAYER_ID1].address,
        kidosAddress,
        tokenId0,
      );

      await checkBalance(initAmount);

      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);

      await checkBalance(initAmount);

      await time.increase(
        (DEFAULT_STAKE_PERIOD + DEFAULT_STAKE_PERIOD / 2) * 60 * 60,
      ); //36 hours
      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);

      await checkBalance(
        ethers.parseEther(CLAIM_REWARD.toString()) + initAmount,
      );

      await time.increase((DEFAULT_STAKE_PERIOD / 2) * 60 * 60); //12 hours
      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);

      await checkBalance(
        ethers.parseEther((CLAIM_REWARD * 2).toString()) + initAmount,
      );
    });
  });
});
