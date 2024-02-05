import { ethers } from "hardhat";
import { assert, expect } from "chai";
import { Contract, Signer } from "ethers";
import { deployConfig as testCfg } from "../../deploy-test.config";

import * as utils from "../../scripts/deploy";

const helpers = {
  purchaseRebels: async (
    saleFacet: Contract,
    account: Signer,
    count: number,
  ) => {
    const tx = await saleFacet.connect(account).purchaseDemRebels(count, {
      value: testCfg.demRebelSalePrice * BigInt(count),
    });
    const receipt = await tx.wait();
    expect(receipt.status).to.be.equal(1, "Should buy DemRebels");
  },

  mintDemBacon: async (
    owner: Signer,
    account: Signer,
    dbnFacet: Contract,
    amount: bigint,
  ) => {
    const accountAddress = await account.getAddress();
    {
      const tx = await dbnFacet.connect(owner).mint(accountAddress, amount);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should mint demBacon");
    }
  },

  buyGrowers: async (
    owner: Signer,
    account: Signer,
    grwsCount: bigint,
    demBacon: Contract,
    growerNftFacet: Contract,
  ) => {
    const accountAddress = await account.getAddress();
    const totalPrice = testCfg.growerSaleBcnPrice * BigInt(grwsCount);

    await helpers.mintDemBacon(owner, account, demBacon, totalPrice);
    const balanceBefore = await growerNftFacet.balanceOf(accountAddress);
    {
      //Use ERC1363 to obtain growers
      const tx = await demBacon
        .connect(account)
        .transferAndCall(growerNftFacet.target, totalPrice);
      await tx.wait();
    }
    const balanceAfter = await growerNftFacet.balanceOf(accountAddress);
    expect(balanceAfter - balanceBefore).to.be.equal(
      grwsCount,
      "Buy obtain failed",
    );
  },

  increaseFarmTier: async (
    ownerAccount: Signer,
    account: Signer,
    farmId: number,
    tierLevel: number,
    safeContract: Contract,
    rebelFarm: Contract,
    gameAddress: string,
  ) => {
    const tierDbnPrice = await rebelFarm.tierUpgradeCost(tierLevel);
    const ownerAddress = await ownerAccount.getAddress();

    {
      //Update safe entry
      await (
        await safeContract.connect(ownerAccount).setGameContract(ownerAddress)
      ).wait();
      let tx = await safeContract
        .connect(ownerAccount)
        .increaseSafeEntry(farmId, tierDbnPrice);
      let receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1);
      await (
        await safeContract.connect(ownerAccount).setGameContract(gameAddress)
      ).wait();
    }
    {
      //Increase tier
      const tx = await rebelFarm.connect(account).increaseTier(farmId);
      const receipt = await tx.wait();
      expect(receipt.status).to.be.equal(1, "Should increase tier");
    }
  },

  buyToddlers: async (
    owner: Signer,
    account: Signer,
    todCount: bigint,
    demBacon: Contract,
    toddlerNftFacet: Contract,
  ) => {
    const accountAddress = await account.getAddress();
    const totalPrice = testCfg.toddlerSaleBcnPrice * BigInt(todCount);

    await helpers.mintDemBacon(owner, account, demBacon, totalPrice);
    const balanceBefore = await toddlerNftFacet.balanceOf(accountAddress);
    {
      //Use ERC1363 to obtain growers
      const tx = await demBacon
        .connect(account)
        .transferAndCall(toddlerNftFacet.target, totalPrice);
      await tx.wait();
    }
    const balanceAfter = await toddlerNftFacet.balanceOf(accountAddress);
    expect(balanceAfter - balanceBefore).to.be.equal(
      todCount,
      "Buy obtain failed",
    );
  },

//   deployL1: async (demRebelAddressChild: Contract) => {
//     const accounts = await ethers.getSigners();
//     const deployRootOutput = await utils.main(true, true);
//     const demRebelAddressRoot = deployRootOutput.demRebel;
//
//     const rootTunnel = await ethers.getContractAt(
//       "RootTunnel",
//       demRebelAddressRoot,
//       accounts[0],
//     );
//     const bridgeRoot = await ethers.getContractAt(
//       "ChainBridge",
//       demRebelAddressRoot,
//       accounts[0],
//     );
//
//     const childTunnel = await ethers.getContractAt(
//       "ChildTunnel",
//       demRebelAddressChild,
//       accounts[0],
//     );
//     const bridgeChild = await ethers.getContractAt(
//       "ChainBridge",
//       demRebelAddressChild,
//       accounts[0],
//     );
//
//     {
//       const tx = await rootTunnel.setFxChildTunnel(childTunnel.target);
//       expect((await tx.wait()).status).to.equal(1);
//     }
//     {
//       const tx = await childTunnel.setFxRootTunnel(rootTunnel.target);
//       expect((await tx.wait()).status).to.equal(1);
//     }
//     {
//       const tx = await bridgeRoot.setReflection(
//         demRebelAddressRoot,
//         demRebelAddressChild,
//       );
//       expect((await tx.wait()).status).to.equal(1);
//     }
//     {
//       const tx = await bridgeChild.setReflection(
//         demRebelAddressRoot,
//         demRebelAddressChild,
//       );
//       expect((await tx.wait()).status).to.equal(1);
//     }
//
//     let MockFxAddress;
//     {
//       const factory = await ethers.getContractFactory("MockFxRoot");
//       const facetInstance = await factory.deploy();
//       await facetInstance.waitForDeployment();
//       const receipt = await facetInstance.deploymentTransaction().wait();
//
//       expect(receipt.status).to.be.eq(1, "MockFxRoot deploy error");
//       MockFxAddress = receipt.contractAddress;
//     }
//     {
//       const tx = await rootTunnel.initializeRoot(
//         MockFxAddress,
//         testCfg.fxCheckpointManager,
//       );
//       const receipt = await tx.wait();
//       expect(receipt.status).to.be.eq(1, "rootTunnel init fail");
//     }
//     {
//       const tx = await childTunnel.initializeChild(MockFxAddress);
//       const receipt = await tx.wait();
//       expect(receipt.status).to.be.eq(1, "childTunnel init fail");
//     }
//
//     return demRebelAddressRoot;
//   },
//
//   bridgeL1toL2: async (
//     demRebelAddressRoot: Contract,
//     demRebelAddressChild: Contract,
//     account: Signer,
//     count: number,
//   ) => {
//     const accounts = await ethers.getSigners();
//     const manager = accounts[9];
//     const manAddress = await manager.getAddress();
//     const accountAddress = await account.getAddress();
//     const demRebelRoot = await ethers.getContractAt(
//       "DemRebel",
//       demRebelAddressRoot,
//       accounts[0],
//     );
//     const saleFacetRoot = await ethers.getContractAt(
//       "PreSaleFacet",
//       demRebelAddressRoot,
//       accounts[0],
//     );
//     const bridgeRoot = await ethers.getContractAt(
//       "ChainBridge",
//       demRebelAddressRoot,
//       accounts[0],
//     );
//     const demRebelChild = await ethers.getContractAt(
//       "DemRebel",
//       demRebelAddressChild,
//       accounts[0],
//     );
//
//     await helpers.purchaseRebels(saleFacetRoot, manager, count);
//     const tokenIds = await demRebelRoot
//       .connect(manager)
//       .tokenIdsOfOwner(manAddress);
//     {
//       const tx = await bridgeRoot
//         .connect(manager)
//         .transition(tokenIds.toArray());
//       expect((await tx.wait()).status).to.equal(1, "transition should be made");
//     }
//     {
//       await demRebelChild
//         .connect(manager)
//         .safeBatchTransferFrom(
//           manAddress,
//           accountAddress,
//           tokenIds.toArray(),
//           ethers.encodeBytes32String(""),
//         );
//     }
//   },

  errorMessage: (e: any) => {
    let message = "";
    if (typeof e === "string") {
      message = e.toUpperCase();
    } else if (e instanceof Error) {
      message = e.message;
    }
    return message;
  },

  expectTxError: async (tx: string, errorMsg: string) => {
    try {
      await tx;
      expect(true, "promise should fail").eq(false);
    } catch (e) {
      const message = helpers.errorMessage(e);
      //console.log(message);
      expect(message).includes(errorMsg);
    }
  },
};

export { helpers };
