import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy_full";
import * as kidos_stake from "../scripts/deploy_kstake";
import * as kidos_stake_v2 from "../scripts/deploy_kstake2";

describe("KidosStake", async () => {
  let demKidos: Contract;
  let kidosStake: Contract;
  let kidosStakeV2: Contract;
  let otherNFT: Contract;
  let demBacon: Contract;

  let accounts: Signer[];

  let kidosAddress: string;
  let toddlerAddress: string;
  let demBaconAddress: string;
  let kidosStakeAddress: string;
  let kidosStakeV2Address: string;

  const CLAIM_REWARD = ethers.parseEther("40");
  const DEFAULT_STAKE_PERIOD = 24 * 60 * 60; //24 hours

  const DEPLOYER_ID = 0;
  const MANAGER_ID = 1;
  const PLAYER_ID1 = 2;
  const PLAYER_ID2 = 3;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    kidosAddress = deployOutput.kidos;
    toddlerAddress = deployOutput.toddlerDemNft;
    demBaconAddress = deployOutput.demBacon;

    kidosStakeAddress = await kidos_stake.main(true, kidosAddress);
    kidosStakeV2Address = await kidos_stake_v2.main(true, kidosAddress);

    accounts = await ethers.getSigners();

    demKidos = await ethers.getContractAt(
      "DemKidos",
      kidosAddress,
      accounts[0],
    );
    kidosStake = await ethers.getContractAt(
      "KidosStake",
      kidosStakeAddress,
      accounts[0],
    );
    kidosStakeV2 = await ethers.getContractAt(
      "KidosStakeOneOff",
      kidosStakeV2Address,
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

  let tokenId0;
  describe("KidosStake Test", function () {
    it("Supply user", async () => {
      const user = accounts[PLAYER_ID1];
      await demKidos
        .connect(accounts[MANAGER_ID])
        .transfer(user, ethers.parseEther("10000"));

      const owned = await demKidos.owned(user.address);
      expect(owned.length).to.be.equal(1);
      tokenId0 = owned[0];
    });

    it("Init Stake", async () => {
      await demKidos
        .connect(accounts[MANAGER_ID])
        .erc20Approve(kidosStakeAddress, ethers.MaxUint256);

      await kidosStake
        .connect(accounts[MANAGER_ID])
        .setRewardToken(kidosAddress);
      await kidosStake
        .connect(accounts[MANAGER_ID])
        .setRewardAmount(CLAIM_REWARD);
      await kidosStake
        .connect(accounts[MANAGER_ID])
        .setStakePeriod(DEFAULT_STAKE_PERIOD);
    });

    it("Stake", async () => {
      const user = accounts[PLAYER_ID1];

      expect((await kidosStake.stakedTokens(user.address)).length).to.equal(0);
      {
        const tx = demKidos.connect(user).safeTransferFrom(
          //["safeTransferFrom(address,address,uint256)"](
          user.address,
          kidosStakeAddress,
          tokenId0,
        );
        await expect(tx).to.be.revertedWith("KidosStake: Stake is disabled");
      }
      await kidosStake.connect(accounts[MANAGER_ID]).setStakeEnabled(true);
      await demKidos.connect(user).safeTransferFrom(
        //["safeTransferFrom(address,address,uint256)"](
        user.address,
        kidosStakeAddress,
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
      ).to.be.equal(kidosStakeAddress);

      await kidosStake.connect(accounts[PLAYER_ID1]).claimAndWithdraw(tokenId0);

      expect(
        await demKidos.connect(accounts[PLAYER_ID1]).ownerOf(tokenId0),
      ).to.be.equal(accounts[PLAYER_ID1].address);
    });

    it("Reject withdraw for no owner", async () => {
      await expect(
        kidosStake.connect(accounts[PLAYER_ID2]).claimAndWithdraw(tokenId0),
      ).to.be.revertedWith(
        "KidosStake: Only original owner can withdraw/claim",
      );
    });

    it("Reject if other NFT staked", async () => {
      const owner = accounts[DEPLOYER_ID];
      const user = accounts[PLAYER_ID1];
      await helpers.buyToddlers(owner, user, 1, demBacon, otherNFT);
      await expect(
        otherNFT.connect(accounts[PLAYER_ID1]).safeTransferFrom(
          //["safeTransferFrom(address,address,uint256)"](
          accounts[PLAYER_ID1].address,
          kidosStakeAddress,
          0,
        ),
      ).to.be.revertedWith("KidosStake: Expects DemKidos NFT");
    });

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
        kidosStakeAddress,
        tokenId0,
      );

      await checkBalance(initAmount);
      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);
      await checkBalance(initAmount);

      await time.increase(DEFAULT_STAKE_PERIOD + DEFAULT_STAKE_PERIOD / 2); //36 hours
      let amountToClaim = await kidosStake.rewardToClaim(tokenId0);
      expect(amountToClaim).to.be.equal(CLAIM_REWARD);
      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);
      await checkBalance(CLAIM_REWARD + initAmount);

      await time.increase(DEFAULT_STAKE_PERIOD / 2); //12 hours
      amountToClaim = await kidosStake.rewardToClaim(tokenId0);
      expect(amountToClaim).to.be.equal(CLAIM_REWARD);
      await kidosStake.connect(accounts[PLAYER_ID1]).claim(tokenId0);
      await checkBalance(CLAIM_REWARD * 2n + initAmount);
    });
  });

  describe("KidosStakeOneOff Test", function () {
    let mintable;
    let tokenId1;

    it("Supply user", async () => {
      const user = accounts[PLAYER_ID1];
      await demKidos
        .connect(accounts[MANAGER_ID])
        .transfer(user, ethers.parseEther("10000"));

      const owned = await demKidos.owned(user.address);
      expect(owned.length).to.be.equal(1);
      tokenId1 = owned[0];
    });

    it("Contract init", async () => {
      mintable = await (
        await ethers.getContractFactory("MintableTest")
      ).deploy(kidosStakeV2Address);
      await mintable.waitForDeployment();
      const receipt = await mintable.deploymentTransaction().wait();
      const mintableAddress = receipt.contractAddress;

      await kidosStakeV2
        .connect(accounts[MANAGER_ID])
        .setRewardToken(mintableAddress);
      await kidosStakeV2
        .connect(accounts[MANAGER_ID])
        .setStakePeriod(DEFAULT_STAKE_PERIOD);
    });

    it("Stake Test", async () => {
      const user = accounts[PLAYER_ID1];

      expect((await kidosStakeV2.stakedTokens(user.address)).length).to.equal(
        0,
      );
      {
        const tx = demKidos
          .connect(user)
          .safeTransferFrom(user.address, kidosStakeV2Address, tokenId1);
        await expect(tx).to.be.revertedWith("KidosStake: Stake is disabled");
      }
      await kidosStakeV2.connect(accounts[MANAGER_ID]).setStakeEnabled(true);
      await demKidos
        .connect(user)
        .safeTransferFrom(user.address, kidosStakeV2Address, tokenId1);
      expect((await kidosStakeV2.stakedTokens(user.address)).length).to.equal(
        1,
      );
    });

    it("Reward Check", async () => {
      const user = accounts[PLAYER_ID1];

      expect(await mintable.balanceOf(user.address)).to.be.equal(0);
      expect(await demKidos.connect(user).ownerOf(tokenId1)).to.be.equal(
        kidosStakeV2Address,
      );

      {
        const tx = kidosStakeV2.connect(user).claimAndWithdraw(tokenId1);
        await expect(tx).to.be.revertedWith("KidosStake: Not claimable yet");
      }
      {
        const tx = kidosStakeV2
          .connect(accounts[PLAYER_ID2])
          .claimAndWithdraw(tokenId1);
        await expect(tx).to.be.revertedWith(
          "KidosStake: Only original owner can withdraw/claim",
        );
      }
      await time.increase(DEFAULT_STAKE_PERIOD);
      await kidosStakeV2.connect(user).claimAndWithdraw(tokenId1);

      expect(await mintable.balanceOf(user.address)).to.be.equal(1);
      expect(
        await demKidos.connect(accounts[PLAYER_ID1]).ownerOf(tokenId1),
      ).to.be.equal(accounts[PLAYER_ID1].address);
    });
  });
});
