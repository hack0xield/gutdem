const { ethers } = require("hardhat");

import {assert, expect} from "chai";
import { Contract, Signer, ContractFactory } from 'ethers';

const FacetCutAction = {
    Add: 0,
    Replace: 1,
    Remove: 2
}

function getSelectors(contract: Contract) {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.reduce((acc: string[], val: string) => {
        if (val !== 'init(bytes)') {
            acc.push(contract.interface.getSighash(val));
        }
        return acc;
    }, []);
}



export class FacetArgs {
    public name: string = "";
    public contract: Contract;
    public address: string;

    constructor(name: string, address: string, contract: Contract) {
        this.name = name;
        this.contract = contract;
        this.address = address;
    }
}

export async function deployDiamond(
    diamondName: string,
    initDiamond: string,
    facets: FacetArgs[],
    owner: any,
    args: any[],
    txArgs: any,
    ): Promise<[string, number]> {
    let gasCost = ethers.BigNumber.from("0");
    let diamondFactory = await ethers.getContractFactory("Diamond");

    const diamondCut = [];
    for (let facetArg of facets) {
        diamondCut.push([
            facetArg.address,
            FacetCutAction.Add,
            getSelectors(facetArg.contract)
        ]);
    }

    let initDiamondFactory = await ethers.getContractFactory(initDiamond);
    let deployedInitDiamond = await initDiamondFactory.deploy();
    await deployedInitDiamond.deployed();
    let result = await deployedInitDiamond.deployTransaction.wait();
    let deployedInitDiamondAddress = result.contractAddress;
    expect(result.status).to.be.equal(1);
    gasCost = gasCost.add(result.gasUsed);

    const functionCall = deployedInitDiamond.interface.encodeFunctionData("init", args);

    const deployedDiamond = await diamondFactory.deploy(owner);
    await deployedDiamond.deployed();
    let tx = deployedDiamond.deployTransaction;
    let receipt = await tx.wait();
    expect(receipt.status).to.be.equal(1);
    gasCost = gasCost.add(receipt.gasUsed);

    const diamondCutFacet = await ethers.getContractAt(
        'DiamondCutFacet',
        receipt.contractAddress
    );

    tx = await diamondCutFacet.diamondCut(diamondCut, deployedInitDiamondAddress, functionCall);
    result = await tx.wait();
    expect(result.status).to.be.equal(1);
    gasCost = gasCost.add(result.gasUsed);

    return [receipt.contractAddress, gasCost];
}