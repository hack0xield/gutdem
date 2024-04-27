import { ethers } from "hardhat";
//import { assert, expect } from "chai";
//import { Contract, Signer, ContractFactory } from "ethers";
import { strDisplay } from "./utils";

export class FacetArgs {
  public name: string = "";
  public address: string;
  public contract: Contract;

  constructor(name: string, address: string, contract: Contract) {
    this.name = name;
    this.contract = contract;
    this.address = address;
  }
}

export const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2,
};

export function getSelectors(contract: Contract) {
  const fragments = contract.interface.fragments;
  return fragments.reduce((acc: string[], val: ethers.Fragment) => {
    if (ethers.Fragment.isFunction(val)) {
      acc.push(val.selector);
    }
    return acc;
  }, []);
}

export class DeployInfra {
  static gas: { totalGasUsed: BigInt };
  static LOG = function () {};

  static async deployFacets(...facets: any): Promise<FacetArgs[]> {
    this.LOG("");

    const instances: FacetArgs[] = [];
    for (let facet of facets) {
      let constructorArgs = [];

      if (Array.isArray(facet)) {
        [facet, constructorArgs] = facet;
      }

      const factory = await ethers.getContractFactory(facet);
      const facetInstance = await factory.deploy(...constructorArgs);
      await facetInstance.waitForDeployment();
      const tx = facetInstance.deploymentTransaction();
      const receipt = await tx.wait();

      instances.push(
        new FacetArgs(facet, receipt.contractAddress, facetInstance),
      );

      this.LOG(`>>> Facet ${facet} deployed: ${receipt.contractAddress}`);
      this.LOG(`${facet} deploy gas used: ${strDisplay(receipt.gasUsed)}`);
      this.LOG(`Tx hash: ${tx.hash}`);

      this.gas.totalGasUsed += receipt.gasUsed;
    }

    this.LOG("");

    return instances;
  }

  static async deployDiamond(
    diamondName: string,
    initDiamond: string,
    owner: any,
    facets: FacetArgs[],
    args: any[],
  ): Promise<string> {
    let gasCost = 0n;

    const diamondCut = [];
    for (const facetArg of facets) {
      diamondCut.push([
        facetArg.address,
        FacetCutAction.Add,
        getSelectors(facetArg.contract),
      ]);
    }

    const deployedInitDiamond = await (
      await ethers.getContractFactory(initDiamond)
    ).deploy();
    await deployedInitDiamond.waitForDeployment();
    let receipt = await deployedInitDiamond.deploymentTransaction().wait();
    const deployedInitDiamondAddress = receipt.contractAddress;
    gasCost += receipt.gasUsed;

    const deployedDiamond = await (
      await ethers.getContractFactory("Diamond")
    ).deploy(owner);
    await deployedDiamond.waitForDeployment();
    receipt = await deployedDiamond.deploymentTransaction().wait();
    gasCost += receipt.gasUsed;

    const diamondCutFacet = await ethers.getContractAt(
      "DiamondCutFacet",
      receipt.contractAddress,
    );
    const functionCall = deployedInitDiamond.interface.encodeFunctionData(
      "init",
      args,
    );
    const cutTx = await (
      await diamondCutFacet.diamondCut(
        diamondCut,
        deployedInitDiamondAddress,
        functionCall,
      )
    ).wait();
    gasCost += cutTx.gasUsed;

    this.LOG(`>> ${diamondName} diamond address: ${receipt.contractAddress}`);
    this.LOG(
      `>> ${diamondName} diamond deploy gas used: ${strDisplay(gasCost)}`,
    );
    this.gas.totalGasUsed += gasCost;

    return receipt.contractAddress;
  }
}
