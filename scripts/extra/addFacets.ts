const { ethers } = require("hardhat");

import { Contract, Signer } from 'ethers';
import { strDisplay } from "./shared/utils";
import { FacetArgs } from './shared/deployDiamond';

const facets = [
    {
      facetName: "TestFacet"
    }
];

const diamondAddress = "0xeCAFb24CDaf76A58B7463CA56EAB4b5026325465";

const FacetCutAction = {
    Add: 0,
    Replace: 1,
    Remove: 2
}

let totalGasUsed = ethers.BigNumber.from("0");

async function deployFacet(facet: string): Promise<FacetArgs> {
    const factory = await ethers.getContractFactory(facet);
    const facetInstance = await factory.deploy();
    await facetInstance.deployed();

    const tx = facetInstance.deployTransaction;
    const receipt = await tx.wait();

    console.log(`Tx hash: ${tx.hash}, ${receipt.contractAddress}`);
    console.log(`>>> Facet ${facet} deployed: ${receipt.contractAddress}`);
    console.log(`${facet} deploy gas used: ${strDisplay(receipt.gasUsed)}`);

    totalGasUsed = totalGasUsed.add(receipt.gasUsed);

    return new FacetArgs(facet, receipt.contractAddress, facetInstance);
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

function getSelector(func: string) {
    const abiInterface = new ethers.utils.Interface([func]);
    return abiInterface.getSighash(ethers.utils.Fragment.from(func));
}

function getSighashes(selectors: string[]): string[] {
    if (selectors.length === 0) return [];
    const sighashes: string[] = [];
    selectors.forEach((selector) => {
        if (selector !== "") sighashes.push(getSelector(selector));
    });
    return sighashes;
}

export async function main() {
    console.log("> Add Facet started");

    let accounts = await ethers.getSigners();
    let account = await accounts[0].getAddress();

    const cut = [];
    for (let facet of facets) {
        let deployArgs = await deployFacet(facet.facetName);
        let facetAddress = deployArgs.address;
        let deployedFacet = deployArgs.contract;

        let selectors = getSelectors(deployedFacet);

        cut.push({
            facetAddress: facetAddress,
            action: FacetCutAction.Add,
            functionSelectors: selectors,
        });
    }

    console.log(`> cut: ${JSON.stringify(cut)}`);
    const diamondCut = (await ethers.getContractAt(
        "IDiamondCut",
        diamondAddress,
        accounts[0]
    ));

    const tx = await diamondCut.diamondCut(
        cut,
        ethers.constants.AddressZero,
        "0x"
    );
    const receipt = await tx.wait();
    console.log(`diamondCut gas used: ${strDisplay(receipt.gasUsed)}`);
    totalGasUsed = totalGasUsed.add(receipt.gasUsed);

    console.log(`> Total gas used: ${strDisplay(totalGasUsed)}`);

    let diamondLoupe = await ethers.getContractAt(
        "IDiamondLoupe",
        diamondAddress,
        accounts[0],
    );
    let value = await diamondLoupe.connect(accounts[0]).facets();
    console.log(`> diamondLoupe: ${JSON.stringify(value)}`);
}

if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

exports.deployProject = main;