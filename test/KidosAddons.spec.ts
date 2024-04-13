import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe.only("DemKidos Drop and Mint Test", async () => {
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
  const MANAGER_ID = 1;
  const SIGNER_ID = 10;
  const PLAYER_ID1 = 2;
  const PLAYER_ID2 = 3;
  const PLAYER_ID3 = 4;

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
    const manager = accounts[MANAGER_ID];
    const address = await user.getAddress();
    const dropPrice = ethers.parseEther("0.003");

    {
      const tx = await kidosDrop.connect(manager).setDropPrice(dropPrice);
      expect((await tx.wait()).status).to.be.equal(1);
    }

    const ticketNumber = testCfg.kidosTicketsCount + 47;
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
      const tx = kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount);
      await expect(tx).to.be.revertedWith(
        "KidosDrop: SigVer is not set",
      );
    }
    {
      const tx = await kidosDrop.connect(manager).setSigVerifierAddress(signPublic);
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount);
      await expect(tx).to.be.revertedWith(
        "KidosDrop: Insufficient ethers value",
      );
    }
    {
      const tx = await kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount, {
          value: dropPrice,
        });
      expect((await tx.wait()).status).to.be.equal(1);
    }
    {
      const tx = kidosDrop
        .connect(user)
        .whitelistDrop(sig1, ticketNumber, amount, {
          value: dropPrice,
        });
      await expect(tx).to.be.revertedWith("KidosDrop: Already claimed");
    }
  });

  describe("Kidos Mint", function () {
    it("Should stop on checks", async () => {
      const user = accounts[PLAYER_ID3];
      const manager = accounts[MANAGER_ID];
      {
        const tx = kidosDrop.connect(user).mint(1);
        await expect(tx).to.be.revertedWith("KidosDrop: Mint is disabled");
      }
      await kidosDrop.connect(manager).setMintEnabled(true);
      {
        const tx = kidosDrop.connect(user).mint(5, {
          value: testCfg.kidosMintPrice * BigInt(4),
        });
        await expect(tx).to.be.revertedWith(
          "KidosDrop: Insufficient ethers value",
        );
      }
    });

    it("Should mint 1 nft", async () => {
      const user = accounts[PLAYER_ID3];
      await kidosDrop.connect(user).mint(1, {
        value: testCfg.kidosMintPrice * BigInt(1),
      });

      const owned = await demKidos.owned(user.address);
      expect(owned.length).to.be.equal(1);
    });

    it("Should mint 5 nft", async () => {
      const user = accounts[PLAYER_ID3];
      let amount = 5;
      await kidosDrop.connect(user).mint(amount, {
        value: testCfg.kidosMintPrice * BigInt(amount),
      });

      const owned = await demKidos.owned(user.address);
      expect(owned.length).to.be.equal(amount + 1);
    });

    it("Should not mint more than ${testCfg.kidosMaxMintNfts} nfts", async () => {
      const user = accounts[PLAYER_ID3];
      let amount = 5;
      {
        const tx = kidosDrop.connect(user).mint(amount, {
          value: testCfg.kidosMintPrice * BigInt(amount),
        });
        await expect(tx).to.be.revertedWith(
          "KidosDrop: Exceeded maximum nfts per user",
        );
      }
    });
  });
});
