import { assert, expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("DemRebel test", async () => {
  let demRebel: Contract;
  let preSaleFacet: Contract;

  let accounts: Signer[];
  let demRebelAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demRebelAddress = deployOutput.demRebel;

    accounts = await ethers.getSigners();

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
  });

  describe("Buy tokens test", async () => {
    const testCases = [
      {
        name: "User can buy one demRebel",
        count: 1,
        sender: 0,
      },
      {
        name: "User can buy 5 demRebels",
        count: 5,
        sender: 0,
      },
    ];

    for (const testCase of testCases) {
      it(testCase.name, async () => {
        await helpers.purchaseRebels(
          preSaleFacet,
          accounts[testCase.sender],
          testCase.count,
        );
      });
    }
  });

  it(`should not buy more than ${testCfg.maxDemRebelsSalePerUser} tokens`, async () => {
    {
      await helpers.purchaseRebels(
        preSaleFacet,
        accounts[2],
        testCfg.maxDemRebelsSalePerUser,
      );
    }

    const tx = preSaleFacet.connect(accounts[2]).purchaseDemRebels(1, {
      value: testCfg.demRebelSalePrice,
    });
    await expect(tx).to.be.revertedWith(
      "SaleFacet: Exceeded maximum DemRebels per user",
    );
  });

  it("should transfer rebels", async () => {
    const account1 = accounts[3];
    const account2 = accounts[1];
    const address1 = await account1.getAddress();
    const address2 = await account2.getAddress();

    await helpers.purchaseRebels(preSaleFacet, account1, 1);

    let tokenIds = await demRebel.connect(account1).tokenIdsOfOwner(address1);
    assert.isAtLeast(
      tokenIds.length,
      1,
      "error: must be at least one demRebel",
    );

    const fixedDemRebel = tokenIds[0];
    const tx = await demRebel
      .connect(account1)
      .transferFrom(address1, address2, fixedDemRebel);
    const status = (await tx.wait()).status;
    assert.equal(status, true, "demRebel should be transferred");

    tokenIds = await demRebel.connect(account2).tokenIdsOfOwner(address2);
    assert.isAtLeast(tokenIds.length, 1, "should be at least one demRebel");

    let f = false;
    for (const token of tokenIds) {
      if (token == fixedDemRebel) {
        f = true;
        break;
      }
    }
    assert.isTrue(f);
  });

  it("Should get token URI", async () => {
    {
      const tx = await demRebel.tokenURI(0);
      expect(tx).to.be.equal(
        "ipfs://QmUzSR5yDqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C",
      );
    }
    {
      const tx = await demRebel.setBaseURI1(
        "ipfs://QmXLYBZubaqHYVqiRA4HAXVddTyCdNWzKyQzhSJLpBcY2m/",
      );
      assert.equal((await tx.wait()).status, true, "BaseUri should be set");
    }
    {
      const tx = await demRebel.tokenURI(0);
      expect(tx).to.be.equal(
        "ipfs://QmXLYBZubaqHYVqiRA4HAXVddTyCdNWzKyQzhSJLpBcY2m/0",
      );
    }
  });

  describe("should not accept transactions with invalid value", async () => {
    it("should not allow to buy demRebel with low price", async () => {
      const tx = preSaleFacet.connect(accounts[10]).purchaseDemRebels(1, {
        value: testCfg.demRebelSalePrice - BigInt(1),
      });
      await expect(tx).to.be.revertedWith(
        "SaleFacet: Insufficient ethers value",
      );
    });
  });
});
