import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("DemRebel PreSaleFacet Test", async () => {
  let preSaleFacet: Contract;

  let accounts: Signer[];

  let demRebelAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demRebelAddress = deployOutput.demRebel;

    accounts = await ethers.getSigners();

    preSaleFacet = await ethers.getContractAt(
      "PreSaleFacet",
      demRebelAddress,
      accounts[0],
    );
  });

  it("Check mint limits", async () => {
    const account = accounts[1];

    await preSaleFacet.setMaxDemRebelsSalePerUser(testCfg.maxDemRebels);

    for (let i = 0; i < 9; i++) {
      await helpers.purchaseRebels(preSaleFacet, account, 100);
    }
    {
      const count = 100 + 1;
      const tx = preSaleFacet.connect(account).purchaseDemRebels(count, {
        value: testCfg.demRebelSalePrice * BigInt(count),
      });
      await expect(tx).to.be.revertedWith(
        "SaleFacet: First part mint reached max cap",
      );
    }
    await helpers.purchaseRebels(preSaleFacet, account, 100);

    {
      const count = 1;
      const tx = preSaleFacet.connect(account).purchaseDemRebels(count, {
        value: testCfg.demRebelSalePrice * BigInt(count),
      });
      await expect(tx).to.be.revertedWith("SaleFacet: Sale is disabled");
    }
    {
      const tx = await preSaleFacet.connect(accounts[0]).setSaleIsActive(true);
      expect((await tx.wait()).status).to.be.equal(1);
    }
    for (let i = 0; i < 39; i++) {
      await helpers.purchaseRebels(preSaleFacet, account, 100);
    }
    {
      const count = 100 + 1;
      const tx = preSaleFacet.connect(account).purchaseDemRebels(count, {
        value: testCfg.demRebelSalePrice * BigInt(count),
      });
      await expect(tx).to.be.revertedWith(
        "SaleFacet: Second part mint reached max cap",
      );
    }
    await helpers.purchaseRebels(preSaleFacet, account, 100);
    {
      const isActive = await preSaleFacet.connect(account).isSaleActive();
      expect(isActive).to.be.equal(false);
    }
  });

  it("Whitelisted sale test", async () => {
    const signer = accounts[0];
    const signPublic = await signer.getAddress();
    const user = accounts[1];
    const address = await user.getAddress();

    {
      const tx = await preSaleFacet.setWhitelistActive(true);
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = await preSaleFacet.setPublicMintingAddress(signPublic);
      expect((await tx.wait()).status).to.be.equal(1);
    }

    const ticketNumber = testCfg.maxDemRebels - 1;
    const msg = ethers.solidityPackedKeccak256(
      ["address", "uint256"],
      [address, ticketNumber],
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
      const tx = await preSaleFacet
        .connect(user)
        .whitelistSale(sig1, ticketNumber, {
          value: testCfg.whitelistSalePrice,
        });
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = preSaleFacet.connect(user).whitelistSale(sig1, ticketNumber, {
        value: testCfg.whitelistSalePrice,
      });
      await expect(tx).to.be.revertedWith("SaleFacet: Already claimed");
    }
  });
});
