import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import { helpers } from "./shared/helpers";
import { deployConfig as testCfg } from "../deploy-test.config";

import * as utils from "../scripts/deploy";

describe("DemKidos Test", async () => {
  let kidosFacet: Contract;

  let accounts: Signer[];
  let owner: Signer;
  let ownerAddress: string;
  let demKidosAddress: string;

  before(async () => {
    const deployOutput = await utils.main(false, true);
    demKidosAddress = deployOutput.kidos;

    accounts = await ethers.getSigners();
    owner = accounts[0];
    ownerAddress = await accounts[0].getAddress();

    kidosFacet = await ethers.getContractAt(
      "DemKidos",
      demKidosAddress,
      accounts[0],
    );
  });
});
