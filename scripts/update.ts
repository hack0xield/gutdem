const { ethers } = require("hardhat");

import { Contract, Signer } from 'ethers';
import { strDisplay } from "./shared/utils";
import { FacetArgs } from './shared/deployDiamond';

/*
1. Fill facets list. Fill add/remove selectors, all facet selectors will be updated.
2. New facets will be deployed by 'function deployFacet'.
*/

const facets = [
//     {
//       facetName: "PreSaleFacet",
//       addSelectors: [
//         //"function testPreSale() external view returns (uint256)",
//         //"function functionName(uint256 _tokenId) public view returns (address)",
//       ],
//       removeSelectors: [
//           //"function testPreSale() external view returns (uint256)",
//       ],
//     }
    {
      facetName: "KidosDrop",
      addSelectors: [
        //"function getGrowerHirePrice() external view returns (uint256)",
        //"function setGrowerHirePrice(uint256 _price) external"
        //"function testPreSale() external view returns (uint256)",
        //"function functionName(uint256 _tokenId) public view returns (address)",
        //"function isScoutDone(uint256 _rebelId) external view returns (bool)"
        //"function getRebelFarmInfo(uint256 _rebelId) external view returns (RebelFarmInfo)"
        "function initWlBitmap(uint256 ticketsCount) external"
      ],
      removeSelectors: [
          //"function testPreSale() external view returns (uint256)",
      ],
    }
];

const diamondAddress = "0x082E53a6519c5e0EC846D3Dc6eE499011601990A";

const FacetCutAction = {
    Add: 0,
    Replace: 1,
    Remove: 2
}

let totalGasUsed = 0n;

async function deployFacet(facet: string): Promise<FacetArgs> {
    const factory = await ethers.getContractFactory(facet);
    const facetInstance = await factory.deploy();
    await facetInstance.waitForDeployment();

    const tx = facetInstance.deploymentTransaction();
    const receipt = await tx.wait();

    console.log(`Tx hash: ${tx.hash}, ${receipt.contractAddress}`);
    console.log(`>>> Facet ${facet} deployed: ${receipt.contractAddress}`);
    console.log(`${facet} deploy gas used: ${strDisplay(receipt.gasUsed)}`);

    totalGasUsed += receipt.gasUsed;

    return new FacetArgs(facet, receipt.contractAddress, facetInstance);
}

// function getSelectors(contract: Contract) {
//     const signatures = Object.keys(contract.interface.functions);
//     return signatures.reduce((acc: string[], val: string) => {
//         if (val !== 'init(bytes)') {
//             acc.push(contract.interface.getSighash(val));
//         }
//         return acc;
//     }, []);
// }

function getSelectors(contract: Contract) {
  const fragments = contract.interface.fragments;
  return fragments.reduce((acc: string[], val: ethers.Fragment) => {
    if (ethers.Fragment.isFunction(val)) {
      acc.push(val.selector);
    }
    return acc;
  }, []);
}

function getSelector(func: string) {
    //const abiInterface = new ethers.Interface([func]);
    //return abiInterface.getSighash(ethers.Fragment.from(func));

    return ethers.Fragment.from(func).selector;
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
    console.log("> Update started");

    let accounts = await ethers.getSigners();
    let account = await accounts[0].getAddress();

    const cut = [];
    for (let facet of facets) {
        let deployArgs = await deployFacet(facet.facetName);
        let facetAddress = deployArgs.address;
        let deployedFacet = deployArgs.contract;

        const newSelectors = getSighashes(facet.addSelectors);
        let existingFuncs = getSelectors(deployedFacet);
        for (const selector of newSelectors) {
            if (!existingFuncs.includes(selector)) {
                const index = newSelectors.findIndex((val) => val == selector);

                throw Error(
                    `Selector ${selector} (${facet.addSelectors[index]}) not found`
                );
            }
        }

        let existingSelectors = getSelectors(deployedFacet);
        existingSelectors = existingSelectors.filter(
            (selector) => !newSelectors.includes(selector)
        );

        if (newSelectors.length > 0) {
            cut.push({
                facetAddress: facetAddress,
                action: FacetCutAction.Add,
                functionSelectors: newSelectors,
            });
        }

        //Always replace the existing selectors to prevent duplications
        if (existingSelectors.length > 0) {
           cut.push({
               facetAddress: facetAddress,
               action: FacetCutAction.Replace,
               functionSelectors: existingSelectors,
           });
        }

        const removeSelectors = getSighashes(facet.removeSelectors);
        if (removeSelectors.length > 0) {
           cut.push({
               facetAddress: "0x0000000000000000000000000000000000000000",
               action: FacetCutAction.Remove,
               functionSelectors: removeSelectors,
           });
        }
    }

    console.log(`> cut: ${JSON.stringify(cut)}`);
    const diamondCut = (await ethers.getContractAt(
        "IDiamondCut",
        diamondAddress,
        accounts[0]
    ));

     const tx = await diamondCut.diamondCut(
         cut,
         ethers.ZeroAddress,
         "0x"
     );
     const receipt = await tx.wait();
     console.log(`diamondCut gas used: ${strDisplay(receipt.gasUsed)}`);
     totalGasUsed += receipt.gasUsed;

     console.log(`> Total gas used: ${strDisplay(totalGasUsed)}`);

     let diamondLoupe = await ethers.getContractAt(
         "IDiamondLoupe",
         diamondAddress,
         accounts[0],
     );
     let value = await diamondLoupe.connect(accounts[0]).facets();
     console.log(`> diamondLoupe: ${JSON.stringify(value)}`);

//      let preSaleFacet = await ethers.getContractAt(
//          "PreSaleFacet",
//          diamondAddress,
//          accounts[0],
//      );
//      let tokenIdsCount = await preSaleFacet.connect(accounts[0]).testPreSale();
//      console.log(`> tokenIdsCount: ${tokenIdsCount}`);
//
//      let demRebelFacet = await ethers.getContractAt(
//          "DemRebelFacet",
//          diamondAddress,
//          accounts[0],
//      );
//      let totalSupply = await demRebelFacet.connect(accounts[0]).totalSupply();
//      console.log(`> totalSupply: ${totalSupply}`);
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