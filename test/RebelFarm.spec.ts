import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy_full";

describe("RebelFarm and CashOut test", async () => {
  let demRebel: Contract;
  let preSaleFacet: Contract;
  let demBacon: Contract;
  let rebelFarm: Contract;
  let cashOut: Contract;
  let growerNft: Contract;
  let toddlerNft: Contract;
  let safeContract: Contract;

  let accounts: Signer[];
  let owner: Signer;

  let demBaconAddress: string;
  let demRebelAddress: string;
  let gameAddress: string;
  let growerAddress: string;
  let toddlerAddress: string;
  let safeAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demBaconAddress = deployOutput.demBacon;
    demRebelAddress = deployOutput.demRebel;
    gameAddress = deployOutput.game;
    growerAddress = deployOutput.growerDemNft;
    toddlerAddress = deployOutput.toddlerDemNft;
    safeAddress = deployOutput.safe;

    accounts = await ethers.getSigners();
    owner = accounts[0];

    demRebel = await ethers.getContractAt(
      "DemRebel",
      demRebelAddress,
      accounts[0],
    );
    preSaleFacet = await ethers.getContractAt(
      "PreSaleFacet",
      demRebelAddress,
      accounts[0],
    );
    demBacon = await ethers.getContractAt(
      "DbnToken",
      demBaconAddress,
      accounts[0],
    );
    rebelFarm = await ethers.getContractAt(
      "RebelFarm",
      gameAddress,
      accounts[0],
    );
    cashOut = await ethers.getContractAt("CashOut", gameAddress, accounts[0]);
    growerNft = await ethers.getContractAt(
      "DemNft",
      growerAddress,
      accounts[0],
    );
    toddlerNft = await ethers.getContractAt(
      "DemNft",
      toddlerAddress,
      accounts[0],
    );
    safeContract = await ethers.getContractAt("Safe", safeAddress, accounts[0]);
  });

  it("Farm params calc test", async () => {
    const tierValue = 5;

    let value = await rebelFarm.tierUpgradeCost(tierValue);
    let wei = ethers.parseEther("8600");
    expect(value).to.be.equal(wei);

    value = await rebelFarm.tierUpgradeCooldown(tierValue);
    expect(value).to.be.equal(118800);

    value = await rebelFarm.tierMaxGrowSpots(tierValue);
    expect(value).to.be.equal(7);

    value = await rebelFarm.tierGrowerFarmRate(tierValue);
    wei = ethers.parseEther("24");
    expect(value).to.be.equal(wei);

    value = await rebelFarm.tierHarvestCap(tierValue);
    wei = ethers.parseEther("1650");
    expect(value).to.be.equal(wei);

    //         value = await farmRaidFacet.tierBonusToAttack(tierValue);
    //         expect(value).to.be.equal(6);
    //
    //         value = await farmRaidFacet.tierBonusToDefense(tierValue);
    //         expect(value).to.be.equal(5);
    //
    //         value = await farmRaidFacet.tierBonusToLoot(tierValue);
    //         expect(value).to.be.equal(6);
    //
    //         value = await farmRaidFacet.tierBonusToProtection(tierValue);
    //         expect(value).to.be.equal(5);

    //         res1, res2 = await rebelFarm.getTokenDbnSwapPair(0);
    //         console.log(res1, res2);

    //         let res1;
    //         let res2;
    //         res1, res2 = await rebelFarm.getTokenDbnSwapPair(0);
    //         console.log(res1);
    //         console.log(res2);
  });

  it("Farm start test", async () => {
    const user = accounts[1];
    const userAddress = await user.getAddress();
    const tokenId = 1;

    await helpers.purchaseRebels(preSaleFacet, user, 2);

    {
      //Check for invalid starts
      const tx = rebelFarm
        .connect(user)
        .activateFarm(tokenId, [0], [0], { value: testCfg.activationPrice });
      await helpers.expectTxError(
        tx,
        "LibRebelFarm: sender is not grower owner",
      );
    }

    await helpers.buyGrowers(owner, user, 2, demBacon, growerNft);

    {
      const tx = rebelFarm
        .connect(user)
        .activateFarm(tokenId, [0], [0], { value: testCfg.activationPrice });
      await helpers.expectTxError(
        tx,
        "LibRebelFarm: sender is not toddler owner",
      );
    }

    await helpers.buyToddlers(owner, user, 2, demBacon, toddlerNft);

    {
      const tx = rebelFarm
        .connect(user)
        .activateFarm(tokenId, [0], [0, 1, 2], {
          value: testCfg.activationPrice,
        });
      await helpers.expectTxError(
        tx,
        "LibRebelFarm: sender is not toddler owner",
      );
    }

    {
      //Successful farm start
      const value = await rebelFarm.connect(user).isFarmActivated(tokenId);
      expect(value).to.be.equal(false);
    }
    {
      const tx = await rebelFarm
        .connect(user)
        .activateFarm(tokenId, [0, 1], [0], { value: testCfg.activationPrice });
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should Activate Farm");
    }
    {
      const tx = rebelFarm
        .connect(accounts[0])
        .activateFarm(tokenId, [0], [0], { value: testCfg.activationPrice });
      await helpers.expectTxError(tx, "LibAppStorage: Only DemRebel owner");
    }
    {
      const tx = rebelFarm
        .connect(user)
        .activateFarm(tokenId, [0], [0], { value: testCfg.activationPrice });
      await helpers.expectTxError(tx, "RebelFarm: Farm is already activated");
    }
    {
      const value = await rebelFarm.connect(user).isFarmActivated(tokenId);
      expect(value).to.be.equal(true);
    }
    {
      const value = await rebelFarm.connect(user).growerCount(tokenId);
      expect(value).to.be.equal(2);
    }
    {
      const value = await rebelFarm.connect(user).toddlerCount(tokenId);
      expect(value).to.be.equal(1);
    }

    {
      const balanceBefore = await ethers.provider.getBalance(user);
      await demRebel.connect(user).approve(gameAddress, tokenId);
      await rebelFarm.connect(user).stopAndBurn(tokenId);
      const balanceAfter = await ethers.provider.getBalance(user);

      expect(balanceAfter - balanceBefore).closeTo(
        testCfg.activationPrice,
        ethers.parseEther("0.001"),
      );
    }
  });

  it("Modify grower/toddler count, tier checks", async () => {
    const user = accounts[2];
    const userAddress = await user.getAddress();
    const tokenId = 2;

    await helpers.purchaseRebels(preSaleFacet, user, 1);

    {
      const tx = await rebelFarm
        .connect(user)
        .activateFarm(tokenId, [], [], { value: testCfg.activationPrice });
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should Activate Farm");
    }
    {
      //Farm without growers/toddlers
      const value = await rebelFarm.connect(user).getFarmTier(tokenId);
      expect(value).to.be.equal(1);
    }
    {
      const value = await rebelFarm.connect(user).isFarmActivated(tokenId);
      expect(value).to.be.equal(true);
    }
    {
      const value = await rebelFarm.connect(user).growerCount(tokenId);
      expect(value).to.be.equal(0);
    }
    {
      const value = await rebelFarm.connect(user).toddlerCount(tokenId);
      expect(value).to.be.equal(0);
    }

    await helpers.buyGrowers(owner, user, 4, demBacon, growerNft);
    await helpers.buyToddlers(owner, user, 5, demBacon, toddlerNft);

    {
      //Add growers/toddlers to farm
      const tx = await rebelFarm.connect(user).addGrowers(tokenId, [2, 3, 4]);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should add growers");
    }
    {
      const tx = await rebelFarm.connect(user).addToddlers(tokenId, [2, 3]);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should add toddlers");
    }
    {
      const tx = rebelFarm.connect(user).addGrowers(tokenId, [5]);
      await helpers.expectTxError(tx, "LibRebelFarm: Insufficient farm tier");
    }
    await helpers.increaseFarmTier(
      accounts[0],
      user,
      tokenId,
      2,
      safeContract,
      rebelFarm,
      gameAddress,
    );
    {
      //Check CD Fail Increase tier
      const tx = rebelFarm.connect(user).increaseTier(tokenId);
      await helpers.expectTxError(tx, "RebelFarm: Upgrade cooldown");
    }
    {
      const tx = rebelFarm.connect(user).addGrowers(tokenId, [6]);
      await helpers.expectTxError(
        tx,
        "LibRebelFarm: sender is not grower owner",
      );
    }
    {
      const tx = await rebelFarm.connect(user).addGrowers(tokenId, [5]);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should add growers");
    }

    {
      //Remove growers/toddlers from farm
      const tx = rebelFarm.connect(user).removeToddlers(tokenId, [0, 2, 3, 4]);
      await helpers.expectTxError(
        tx,
        "LibRebelFarm: Not enough toddlers in farm",
      );
    }
    {
      const tx = await rebelFarm.connect(user).removeGrowers(tokenId, [2]);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should remove growers");
    }
    {
      const tx = await rebelFarm.connect(user).removeToddlers(tokenId, [2, 3]);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should remove growers");
    }

    {
      //Final check count
      const value = await rebelFarm.connect(user).growerCount(tokenId);
      expect(value).to.be.equal(3);
    }
    {
      const value = await rebelFarm.connect(user).toddlerCount(tokenId);
      expect(value).to.be.equal(0);
    }
  });

  it("Farm rate and harvest", async () => {
    const user = accounts[3];
    const userAddress = await user.getAddress();
    const tokenId = 3;
    const growCount = 4;
    const todlCount = 2;

    await helpers.purchaseRebels(preSaleFacet, user, 1);
    await helpers.buyGrowers(accounts[0], user, growCount, demBacon, growerNft);
    await helpers.buyToddlers(
      accounts[0],
      user,
      todlCount,
      demBacon,
      toddlerNft,
    );

    {
      const tx = await rebelFarm
        .connect(user)
        .activateFarm(tokenId, [], [], { value: testCfg.activationPrice });
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should Activate Farm");
    }
    await helpers.increaseFarmTier(
      accounts[0],
      user,
      tokenId,
      2,
      safeContract,
      rebelFarm,
      gameAddress,
    );
    {
      //Add growers/toddlers to farm
      const growerIds = await growerNft
        .connect(user)
        .tokenIdsOfOwner(userAddress);
      const tx = await rebelFarm
        .connect(user)
        .addGrowers(tokenId, growerIds.toArray());
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should add growers");
    }
    {
      const toddlerIds = await toddlerNft
        .connect(user)
        .tokenIdsOfOwner(userAddress);
      const tx = await rebelFarm
        .connect(user)
        .addToddlers(tokenId, toddlerIds.toArray());
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should add toddlers");
    }

    await time.increase(60 * 60);

    //checks
    {
      const amountWei = await rebelFarm.connect(user).harvestAmount(tokenId);
      //console.log(amountWei);
      const amountStr = ethers.formatEther(amountWei);
      const amount = parseInt(amountStr, 10);
      expect(amount).to.be.equal(84);
    }
    {
      const tx = await rebelFarm.connect(user).harvestFarm(tokenId);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1);
    }
    {
      let safeContent = await safeContract
        .connect(user)
        .getSafeContent(tokenId);
      //console.log(safeContent);
      let amountStr = ethers.formatEther(safeContent);
      let amount = parseInt(amountStr, 10);
      expect(amount).to.be.equal(84);
    }
    {
      const amountWei = await rebelFarm.connect(user).harvestAmount(tokenId);
      const amountStr = ethers.formatEther(amountWei);
      const amount = parseInt(amountStr, 10);
      expect(amount).to.be.equal(0);
    }
  });

  it("Farm swap to Dbn test", async () => {
    let user = accounts[0];
    let userAddress = await user.getAddress();
    let farmId = 3;

    let tokensMass = 0n;
    for (let tokenId = 1; tokenId <= 3; tokenId++) {
      let amountWei = await rebelFarm.connect(user).harvestAmount(tokenId);
      let safeContent = await safeContract
        .connect(user)
        .getSafeContent(tokenId);

      tokensMass = tokensMass + amountWei;
      tokensMass = tokensMass + safeContent;
      console.log(amountWei);
      console.log(safeContent);
    }
    console.log(tokensMass);

    //Test init values
    await cashOut.startNewCashOutEpoch(tokensMass, ethers.parseEther("5"));
    {
      let value;
      value = await cashOut.getInitEpochPool();
      console.log(value);
      expect(value).to.be.equal(ethers.parseEther("995000"));
    }
    {
      let value;
      value = await cashOut.getPoolShareFactor();
      expect(value).to.be.equal(ethers.parseEther("1.5"));
    }

    //Test Swap Pair
    {
      let value = await cashOut.getTokenDbnSwapPair(farmId);
      expect(value.dbnAmount).to.be.equal(ethers.parseEther("16.8"));
      expect(value.tokenToSpend).to.be.equal(ethers.parseEther("84"));
    }

    //Cash out
    //Test Before
    let tokensAmount = ethers.parseEther("84");
    let dbnAmount = ethers.parseEther("16.8");
    {
      let safeContent = await safeContract.connect(user).getSafeContent(farmId);
      expect(safeContent).to.be.equal(tokensAmount);
    }
    {
      let dbnBalance = await demBacon.balanceOf(userAddress);
      expect(dbnBalance).to.be.equal(0);
    }
    //Test cash out
    {
      //Mint demBacon
      let ownerAccount = accounts[0];
      let tx = await demBacon
        .connect(ownerAccount)
        .mint(safeAddress, dbnAmount);
      let receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should mint demBacon");
    }
    {
      let farmOwner = accounts[3];
      await cashOut.connect(farmOwner).cashOut(farmId);
    }
    //Test After
    {
      let safeContent = await safeContract.connect(user).getSafeContent(farmId);
      expect(safeContent).to.be.equal(0);
    }
    {
      let farmOwnerAddress = accounts[3].getAddress();
      let dbnBalance = await demBacon.balanceOf(farmOwnerAddress);
      expect(dbnBalance).to.be.equal(dbnAmount);
    }
  });

  it("Dbn to Farm tokens swap test", async () => {
    let tokensAmount = ethers.parseEther("84");
    let dbnAmount = ethers.parseEther("16.8");
    let user = accounts[3];
    let userAddress = await user.getAddress();
    let farmId = 3;

    {
      let value = await cashOut.getFarmTokensAmountFromDbn(dbnAmount);
      expect(value).to.be.equal(tokensAmount);
    }

    //Test Before
    {
      let safeContent = await safeContract.connect(user).getSafeContent(farmId);
      expect(safeContent).to.be.equal(0);
    }
    {
      let dbnBalance = await demBacon.balanceOf(userAddress);
      expect(dbnBalance).to.be.equal(dbnAmount);
    }
    //Test Buy
    {
      //Approve demBacon
      let tx = await demBacon.connect(user).approve(cashOut.target, dbnAmount);
      let receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should approve demBacon");
    }
    {
      await cashOut.connect(user).buyFarmTokens(farmId, dbnAmount);
    }
    //Test After
    {
      let safeContent = await safeContract.connect(user).getSafeContent(farmId);
      expect(safeContent).to.be.equal(tokensAmount);
    }
    {
      let dbnBalance = await demBacon.balanceOf(userAddress);
      expect(dbnBalance).to.be.equal(0);
    }
  });
});
