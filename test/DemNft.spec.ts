import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("DemNft Test", async () => {
  let demBacon: Contract;
  let demNft: Contract;
  let saleFacet: Contract;

  let accounts: Signer[];
  let owner: Signer;
  let ownerAddress: string;
  let demBaconAddress: string;
  let demNftAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demBaconAddress = deployOutput.demBacon;
    demNftAddress = deployOutput.growerDemNft;

    accounts = await ethers.getSigners();
    owner = accounts[0];
    ownerAddress = await accounts[0].getAddress();

    demBacon = await ethers.getContractAt(
      "DbnToken",
      demBaconAddress,
      accounts[0],
    );

    demNft = await ethers.getContractAt("DemNft", demNftAddress, accounts[0]);

    saleFacet = await ethers.getContractAt(
      "SaleFacet",
      demNftAddress,
      accounts[0],
    );
  });

  it("Should set Reward manager", async () => {
    {
      const user1 = accounts[1];
      await expect(demBacon.connect(user1).setRewardManager(ownerAddress)).to.be
        .revertedWithCustomError;
    }
    {
      const receipt = await (
        await demBacon.setRewardManager(ownerAddress)
      ).wait();
      expect(receipt.status).to.equal(1);
    }
    {
      const user1 = accounts[1];
      await expect(
        saleFacet.connect(user1).setRewardManager(ownerAddress),
      ).to.be.revertedWith("LibAppStorage: Only owner");
    }
    {
      const receipt = await (
        await saleFacet.setRewardManager(ownerAddress)
      ).wait();
      expect(receipt.status).to.equal(1);
    }
  });

  it("Should set tokenURI", async () => {
    const testIpfsPath =
      "ipfs://QmXLYBZubaqHYVqiRA4HAXVddTyCdNWzKyQzhSJLpBcY2m/";
    const tokenId = 1;

    {
      //tokenUri before
      const tokenURI = await demNft.tokenURI(tokenId);
      expect(tokenURI).to.be.equal(testCfg.growerNftImage);
    }
    {
      //tokenUri set
      const receipt = await (await demNft.setBaseURI(testIpfsPath)).wait();
      expect(receipt.status).to.equal(1);
    }
    {
      //tokenUri after
      const tx = await demNft.tokenURI(tokenId);
      expect(tx).to.be.equal(testIpfsPath + tokenId, "tokenURI invalid");
    }
  });

  it("Check buy and total supply", async () => {
    const user1 = accounts[1];
    const user2 = accounts[2];

    await helpers.buyGrowers(owner, user1, 1, demBacon, demNft);
    await helpers.buyGrowers(owner, user2, 4, demBacon, demNft);
    await helpers.buyGrowers(owner, user1, 2, demBacon, demNft);

    const totalSupply = await demNft.totalSupply();
    expect(totalSupply).to.be.equal(7);
    const balance1 = await demNft.balanceOf(await user1.getAddress());
    expect(balance1).to.be.equal(3);
    const balance2 = await demNft.balanceOf(await user2.getAddress());
    expect(balance2).to.be.equal(4);
  });

  it("Check supply limit", async () => {
    const user1 = accounts[1];

    await expect(
      helpers.buyGrowers(owner, user1, 5000, demBacon, demNft),
    ).to.be.revertedWith("LibDemNft: Exceed max nft supply");
  });

  it("Check on pay low price", async () => {
    const user2 = accounts[2];

    await helpers.mintDemBacon(
      owner,
      user2,
      demBacon,
      BigInt(testCfg.growerSaleBcnPrice),
    );
    await expect(
      demBacon
        .connect(user2)
        .transferAndCall(
          demNftAddress,
          BigInt(testCfg.growerSaleBcnPrice) / 2n,
        ),
    ).to.be.revertedWith("SaleFacet: Too low amount");
  });

  it("Check dbn withdraw", async () => {
    const rewardManager = owner;
    const rewardManagerAddress = await rewardManager.getAddress();

    const user2 = accounts[2];
    await expect(saleFacet.connect(user2).withdrawDbn()).to.be.revertedWith(
      "LibAppStorage: Only reward manager",
    );

    const balanceBefore = await demBacon.balanceOf(rewardManagerAddress);
    await saleFacet.connect(rewardManager).withdrawDbn();
    const balanceAfter = await demBacon.balanceOf(rewardManagerAddress);

    expect(balanceAfter - balanceBefore).equal(ethers.parseEther("700"));
  });

  it("Check index methods", async () => {
    const user1 = accounts[1];
    const user2 = accounts[2];
    const userAddress1 = await user1.getAddress();
    const userAddress2 = await user2.getAddress();

    expect(await demNft.tokenByIndex(6)).to.be.equal(6);
    await expect(demNft.tokenByIndex(7)).to.be.revertedWith(
      "DemNft: Nft owner can't be address(0)",
    );

    expect(await demNft.tokenOfOwnerByIndex(userAddress1, 0)).to.be.equal(0);
    expect(await demNft.tokenOfOwnerByIndex(userAddress1, 1)).to.be.equal(5);
    expect(await demNft.tokenOfOwnerByIndex(userAddress1, 2)).to.be.equal(6);

    expect(await demNft.tokenOfOwnerByIndex(userAddress2, 0)).to.be.equal(1);
    expect(await demNft.tokenOfOwnerByIndex(userAddress2, 1)).to.be.equal(2);
    expect(await demNft.tokenOfOwnerByIndex(userAddress2, 2)).to.be.equal(3);
    expect(await demNft.tokenOfOwnerByIndex(userAddress2, 3)).to.be.equal(4);

    expect((await demNft.tokenIdsOfOwner(userAddress1)).length).to.be.equal(3);
    expect((await demNft.tokenIdsOfOwner(userAddress2)).length).to.be.equal(4);

    expect(await demNft.ownerOf(0)).to.be.equal(userAddress1);
    expect(await demNft.ownerOf(6)).to.be.equal(userAddress1);
    expect(await demNft.ownerOf(1)).to.be.equal(userAddress2);
    expect(await demNft.ownerOf(4)).to.be.equal(userAddress2);
  });

  it("Check transferFrom", async () => {
    const user1 = accounts[1];
    const user2 = accounts[2];
    const userAddress1 = await user1.getAddress();
    const userAddress2 = await user2.getAddress();

    await expect(
      demNft.connect(user1).transferFrom(userAddress2, userAddress1, 5),
    ).to.be.revertedWith("DemNft: _from is not owner, transfer failed");

    {
      await demNft.connect(user1).transferFrom(userAddress1, userAddress2, 5);

      expect((await demNft.tokenIdsOfOwner(userAddress1)).length).to.equal(2);
      expect((await demNft.tokenIdsOfOwner(userAddress2)).length).to.equal(5);

      expect(await demNft.tokenOfOwnerByIndex(userAddress1, 0)).to.be.equal(0);
      expect(await demNft.tokenOfOwnerByIndex(userAddress1, 1)).to.be.equal(6);

      expect(await demNft.tokenOfOwnerByIndex(userAddress2, 4)).to.be.equal(5);
    }
    {
      await demNft
        .connect(user2)
        .safeBatchTransferFrom(
          userAddress2,
          userAddress1,
          [1, 2, 3, 4, 5],
          ethers.encodeBytes32String(""),
        );

      expect((await demNft.tokenIdsOfOwner(userAddress1)).length).to.equal(7);
      expect((await demNft.tokenIdsOfOwner(userAddress2)).length).to.equal(0);
      expect(await demNft.tokenOfOwnerByIndex(userAddress1, 0)).to.equal(0);
      await expect(
        demNft.tokenOfOwnerByIndex(userAddress2, 0),
      ).to.be.revertedWith("DemNft: index beyond owner balance");
    }
  });

  it("Check safeTransferFrom", async () => {
    const user1 = accounts[1];
    const userAddress1 = await user1.getAddress();

    const testContract = await (
      await ethers.getContractFactory("ERC721TokenReceiver")
    ).deploy();
    await testContract.waitForDeployment();
    await testContract.deploymentTransaction().wait();

    await demNft
      .connect(user1)
      .safeTransferFrom(userAddress1, testContract.target, 0);
    await demNft
      .connect(user1)
      .safeBatchTransferFrom(
        userAddress1,
        testContract.target,
        [1, 2, 3],
        ethers.encodeBytes32String(""),
      );

    expect((await demNft.tokenIdsOfOwner(userAddress1)).length).to.equal(3);
    expect((await demNft.tokenIdsOfOwner(testContract.target)).length).to.equal(
      4,
    );
  });
});
