import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("DemKidos Drop and Stake Test", async () => {
  let kidosDrop: Contract;

  let accounts: Signer[];

  let kidosAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    kidosAddress = deployOutput.kidos;

    accounts = await ethers.getSigners();

    kidosDrop = await ethers.getContractAt(
      "KidosDrop",
      kidosAddress,
      accounts[0],
    );
  });

  it("Whitelisted sale test", async () => {
    const signer = accounts[1];
    const signPublic = await signer.getAddress();
    const user = accounts[2];
    const address = await user.getAddress();

    {
      const tx = await kidosDrop.setSigVerifierAddress(signPublic);
      expect((await tx.wait()).status).to.be.equal(1);
    }

    const ticketNumber = testCfg.kidosTicketsCount + 47;
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
      const tx = await kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber);
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = kidosDrop.connect(user).whitelistDrop(sig1, ticketNumber);
      await expect(tx).to.be.revertedWith("KidosDrop: Already claimed");
    }
  });
});
