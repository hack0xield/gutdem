import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("FarmRaidFacet test", async () => {
  let preSaleFacet: Contract;
  let demBacon: Contract;
  let rebelFarm: Contract;
  let farmRaid: Contract;
  let growerNft: Contract;
  let toddlerNft: Contract;
  let safeContract: Contract;
  let link: Contract;

  let accounts: Signer[];
  let owner: Signer;

  let demBaconAddress: string;
  let demRebelAddress: string;
  let gameAddress: string;
  let growerAddress: string;
  let toddlerAddress: string;
  let safeAddress: string;
  let linkAddress: string;

  async function makeScout(
    farmRaid: Contract,
    account: Signer,
    tokenId: number,
  ) {
    const receipt = await (
      await farmRaid.connect(account).scoutTest(tokenId)
    ).wait();
    let request, random;
    for (const event of receipt.logs) {
      if (event.eventName == "ScoutedTest") {
        //console.log(`==== Event ${event.eventName} with args \n ${event.args}`);
        request = event.args[0];
        random = event.args[1];
      }
    }
    await farmRaid.connect(account).scoutCallbackTest(request, random);
    {
      const farmId = await farmRaid.connect(account).getScoutedFarm(tokenId);
      console.log("===== Scouted farm: ", farmId);
    }
  }

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demBaconAddress = deployOutput.demBacon;
    demRebelAddress = deployOutput.demRebel;
    gameAddress = deployOutput.game;
    growerAddress = deployOutput.growerDemNft;
    toddlerAddress = deployOutput.toddlerDemNft;
    safeAddress = deployOutput.safe;
    linkAddress = deployOutput.link;

    accounts = await ethers.getSigners();
    owner = accounts[0];

    preSaleFacet = await ethers.getContractAt("PreSaleFacet", demRebelAddress, owner);
    rebelFarm = await ethers.getContractAt("RebelFarm", gameAddress, owner);
    farmRaid = await ethers.getContractAt("FarmRaidTest", gameAddress, owner);
    demBacon = await ethers.getContractAt("DbnToken", demBaconAddress, owner);
    growerNft = await ethers.getContractAt("DemNft", growerAddress, owner);
    toddlerNft = await ethers.getContractAt("DemNft", toddlerAddress, owner);
    safeContract = await ethers.getContractAt("Safe", safeAddress, owner);
    link = await ethers.getContractAt("MockLinkToken", linkAddress, owner);
  });

  it("Scout test", async () => {
    const user = accounts[1];
    const userAddress = await user.getAddress();
    const tokenId = 0;

    await link.connect(owner).transfer(userAddress, ethers.parseEther("0.1"));

    //Buy Rebels and start Farms
    await helpers.purchaseRebels(preSaleFacet, user, 4);
    for (let id = 0; id < 3; id++) {
      //Only for 3 rebels
      await rebelFarm
        .connect(user)
        .activateFarm(id, [], [], { value: testCfg.activationPrice });
    }

    //Buy Toddler for Raid
    await helpers.buyToddlers(owner, user, 1, demBacon, toddlerNft);
    await rebelFarm.connect(user).addToddlers(tokenId, [0]);

    //Check Scout, should scout different and success eventually
    for (let i = 0; i < 10; i++) {
      await makeScout(farmRaid, user, tokenId);
    }
  });

  it("Raid test and harvest amount", async () => {
    const user = accounts[1];
    const userAddress = await user.getAddress();
    const tokenId = 0;

    //Add growers/toddlers for farm
    await helpers.buyGrowers(owner, user, 6, demBacon, growerNft);
    await helpers.buyToddlers(owner, user, 3, demBacon, toddlerNft);
    await rebelFarm.connect(user).addGrowers(1, [0, 1, 2]);
    await rebelFarm.connect(user).addGrowers(2, [3, 4, 5]);
    await rebelFarm.connect(user).addToddlers(1, [1, 2]);
    await rebelFarm.connect(user).addToddlers(2, [3]);

    //Set farm period
    await rebelFarm.connect(accounts[0]).setRebelFarmPeriod(4);
    await farmRaid.connect(accounts[0]).setFarmRaidDuration(1);

    //Make Raid till success raid
    let raidResult = false;
    let attempt = 0;
    while (raidResult == false) {
      console.log("=== Raid Testing attempt - ", attempt);
      attempt += 1;

      await time.increase(1); //Wait for Raid finish
      const isOngoing = await farmRaid.connect(user).isFarmRaidOngoing(tokenId);
      if (isOngoing == true) {
        {
          console.log("==== Return toddlers");
          const tx = await farmRaid.connect(user).returnToddlers(tokenId);
          const receipt = await tx.wait();
          expect(receipt.status).to.be.equal(1);
        }
      }

      await makeScout(farmRaid, user, tokenId);
      //Balance before
      {
        const balanceWei = await demBacon.connect(user).balanceOf(userAddress);
        const balanceStr = ethers.formatEther(balanceWei);
        const balance = parseInt(balanceStr, 10);
        console.log("==== Balance before: ", balanceWei, balance);
      }
      //Raid attempt
      {
        const farmId = await farmRaid.connect(user).getScoutedFarm(tokenId);
        {
          const amountWei = await rebelFarm.connect(user).harvestAmount(farmId);
          const amountStr = ethers.formatEther(amountWei);
          const amount = parseInt(amountStr, 10);
          console.log("==== To harvest amount: ", amountWei, amount);
        }
        {
          //lets harvest before robbing to fill safe..
          const tx = await rebelFarm.connect(user).harvestFarm(farmId);
          const receipt = await tx.wait();
          expect(receipt.status).to.be.equal(1);
        }
        {
          const amountWei = await safeContract
            .connect(user)
            .getSafeContent(farmId);
          const amountStr = ethers.formatEther(amountWei);
          const amount = parseInt(amountStr, 10);
          console.log("==== Safe content now: ", amountWei, amount);
        }

        let tx = await farmRaid.connect(user).raidTest(tokenId, 1);
        let receipt = await tx.wait();
        let request, random;
        for (const event of receipt.logs) {
          if (event.eventName == "FarmRaidedTest") {
            console.log(
              `==== Event ${event.eventName} with args \n ${event.args}`,
            );
            request = event.args[0];
            random = event.args[1];
          }
        }

        tx = await farmRaid.connect(user).raidCallbackTest(request, random);
        receipt = await tx.wait();
        expect(receipt.status).to.be.equal(1);
        //console.log(receipt.logs);
        //console.log(farmRaid.connect(user).filters.FarmRaided());
        //console.log(receipt.events.filter((x) => {return x.event == "FarmRaided"}));
        //console.log(receipt);
        //console.log(receipt.events[0].args);
        //console.log(receipt.events);
        //console.log(farmRaid.connect(user).filters.FarmRaided().args);
        for (const event of receipt.logs) {
          if (event.eventName == "FarmRaided") {
            console.log(
              `==== Event ${event.eventName} with args \n ${event.args}`,
            );
            raidResult = event.args[2];
          }
        }
      }
      //Check safe after Raid
      {
        const amountWei = await safeContract
          .connect(user)
          .getSafeContent(tokenId);
        const amountStr = ethers.formatEther(amountWei);
        const amount = parseInt(amountStr, 10);
        ``;
        console.log("==== Balance after: ", amountWei, amount);

        if (raidResult == false) {
          expect(amount).to.be.equal(0);
        } else {
          expect(amount).to.not.equal(0);
        }
      }
    }
  });

  it("Raid getters test and return toddlers", async () => {
    const user = accounts[1];
    const userAddress = await user.getAddress();
    const tokenId = 0;

    await farmRaid.connect(accounts[0]).setFarmRaidDuration(113000);
    {
      const tx = farmRaid.connect(user).raid(tokenId, 1);
      await helpers.expectTxError(
        tx,
        "LibFarmRaid: Scouting should be performed first",
      );
    }
    {
      const tx = farmRaid.connect(user).scout(tokenId);
      await helpers.expectTxError(
        tx,
        "LibFarmRaid: Previous raid is not finished yet",
      );
    }

    {
      const count = await farmRaid.connect(user).getActiveToddlers(tokenId);
      expect(count).to.be.equal(0);
    }
    {
      const value = await farmRaid.connect(user).isFarmRaidOngoing(tokenId);
      expect(value).to.be.equal(true);
    }
    {
      const value = await farmRaid.connect(user).isFarmRaidFinished(tokenId);
      expect(value).to.be.equal(false);
    }

    await farmRaid.connect(accounts[0]).setFarmRaidDuration(1);
    {
      const value = await farmRaid.connect(user).isFarmRaidOngoing(tokenId);
      expect(value).to.be.equal(true);
    }
    {
      const value = await farmRaid.connect(user).isFarmRaidFinished(tokenId);
      expect(value).to.be.equal(true);
    }

    await farmRaid.connect(user).returnToddlers(tokenId);
    {
      const count = await farmRaid.connect(user).getActiveToddlers(tokenId);
      expect(count).to.be.equal(1);
    }
    {
      const value = await farmRaid.connect(user).isFarmRaidOngoing(tokenId);
      expect(value).to.be.equal(false);
    }
    {
      const tx = farmRaid.connect(user).isFarmRaidFinished(tokenId);
      await helpers.expectTxError(tx, "LibFarmRaid: The raid is not started");
    }

    {
      await makeScout(farmRaid, user, tokenId);
      {
        let tx = await farmRaid.connect(user).raidTest(tokenId, 1);
        let receipt = await tx.wait();
        let request, random;
        for (const event of receipt.logs) {
          if (event.eventName == "FarmRaidedTest") {
            console.log(
              `==== Event ${event.eventName} with args ${event.args}`,
            );
            request = event.args[0];
            random = event.args[1];
          }
        }

        tx = await farmRaid.connect(user).raidCallbackTest(request, random);
        receipt = await tx.wait();
        expect(receipt.status).to.be.equal(1);
      }
    }
  });

  it("Scout tier test (console)", async () => {
    const user = accounts[1];
    const userAddress = await user.getAddress();

    //Activate additional farm
    const newTokenId = 3;
    rebelFarm
      .connect(user)
      .activateFarm(newTokenId, [], [], { value: testCfg.activationPrice });

    //Make different tiers
    const tokenId = 1;
    {
      const token = tokenId;
      for (let i = 0; i < 1; i++) {
        const toTier = 2 + i;
        const cd = await rebelFarm.tierUpgradeCooldown(toTier);
        await time.increase(cd);
        await helpers.increaseFarmTier(
          owner,
          user,
          token,
          toTier,
          safeContract,
          rebelFarm,
          gameAddress,
        );
      }
      const farmTier = await rebelFarm.connect(user).getFarmTier(token);
      console.log("=== Tier for farm: ", token, farmTier);
    }
    {
      const token = tokenId + 1;
      for (let i = 0; i < 2; i++) {
        const toTier = 2 + i;
        const cd = await rebelFarm.tierUpgradeCooldown(toTier);
        await time.increase(cd);
        await helpers.increaseFarmTier(
          owner,
          user,
          token,
          toTier,
          safeContract,
          rebelFarm,
          gameAddress,
        );
      }
      const farmTier = await rebelFarm.connect(user).getFarmTier(token);
      console.log("=== Tier for farm: ", token, farmTier);
    }
    {
      const token = tokenId + 2;
      for (let i = 0; i < 4; i++) {
        const toTier = 2 + i;
        const cd = await rebelFarm.tierUpgradeCooldown(toTier);
        await time.increase(cd);
        await helpers.increaseFarmTier(
          owner,
          user,
          token,
          toTier,
          safeContract,
          rebelFarm,
          gameAddress,
        );
      }
      const farmTier = await rebelFarm.connect(user).getFarmTier(token);
      console.log("=== Tier for farm: ", token, farmTier);
    }

    //Make sure we will scout only 'upper' farms.
    for (let i = 0; i < 10; i++) {
      //             {
      //                 let random = await farmRaid.connect(user).testRandomNumber();
      //                 console.log("random: ", random[0], random[1], random[2]);
      //             }
      await makeScout(farmRaid, user, tokenId);
      //console.log("==== ", await farmRaid.connect(user).getRebelFarmInfo(tokenId));
    }
  });
});
