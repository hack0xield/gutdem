import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";
import { deployConfig as cfg } from "../deploy.config";
import { deployConfig as testCfg } from "../deploy-test.config";

export async function main(
  isRoot: boolean,
  tests: boolean,
): Promise<[DeployedContracts]> {
  const LOG = !tests ? console.log.bind(console) : function () {};
  let totalGasUsed = 0n;
  const accounts = await ethers.getSigners();
  const account = await accounts[0].getAddress();

  LOG(`> Using account as owner: ${account}`);

  if (tests == true) {
    cfg = testCfg;
  }

  const dbnAddress = await demBaconDeploy();
  const safeAddress = await deploySafe();
  let kidosAddress,
    growerAddress,
    toddlerAddress,
    demRebelAddress,
    gameAddress,
    linkAddress;
  if (isRoot) {
    //await deployModeRoot();
  } else {
    await deployModeChild();
  }

  LOG(`> Total gas used: ${strDisplay(totalGasUsed)}`);

  const result = new DeployedContracts({
    demBacon: dbnAddress,
    demRebel: demRebelAddress,
    game: gameAddress,
    kidos: kidosAddress,
    growerDemNft: growerAddress,
    toddlerDemNft: toddlerAddress,
    safe: safeAddress,
    link: linkAddress,
  });
  return result;

  //   async function deployModeRoot() {
  //     const tunnel = tests ? "MockRootTunnel" : "RootTunnel";
  //     const [demRebelArgs, preSaleFacetArgs, bridgeArgs, tunnelArgs] =
  //       await deployFacets("DemRebel", "PreSaleFacet", "ChainBridge", tunnel);
  //
  //     demRebelAddress = await deployDiamond(
  //       "DemRebelDiamond",
  //       "contracts/DemRebel/InitDiamond.sol:InitDiamond",
  //       [demRebelArgs, preSaleFacetArgs, bridgeArgs, tunnelArgs],
  //       buildRebelArgs(),
  //     );
  //
  //     {
  //       const demRebelSale = await ethers.getContractAt(
  //         "PreSaleFacet",
  //         demRebelAddress,
  //         accounts[0],
  //       );
  //       const tx = await (await demRebelSale.setRewardManager(account)).wait();
  //       LOG(`>> demRebel setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
  //       totalGasUsed += tx.gasUsed;
  //     }
  //     {
  //       const tunnelFacet = await ethers.getContractAt(
  //         tunnel,
  //         demRebelAddress,
  //         accounts[0],
  //       );
  //       const tx = await (
  //         await tunnelFacet.initializeRoot(cfg.fxRoot, cfg.fxCheckpointManager)
  //       ).wait();
  //       LOG(`>> initializeRoot gas used: ${strDisplay(tx.gasUsed)}`);
  //       totalGasUsed += tx.gasUsed;
  //     };
  //   }

  async function deployModeChild() {
    const [
      demKidosArgs,
      kidosDropArgs,
      kidosStakeArgs,
      growerNftArgs,
      growerSaleArgs,
      toddlerNftArgs,
      toddlerSaleArgs,
      demRebelArgs,
      preSaleFacetArgs,
      cashOutArgs,
      gameManagerArgs,
      rebelFarmArgs,
      farmRaidArgs,
      VRFConsumerArgs,
    ] = await deployFacets(
      "DemKidos",
      "KidosDrop",
      "KidosStake",
      "DemNft",
      "SaleFacet",
      "DemNft",
      "SaleFacet",
      "DemRebel",
      "PreSaleFacet",
      "CashOut",
      "GameManager",
      "RebelFarm",
      tests ? "FarmRaidTest" : "FarmRaid",
      "VRFConsumer",
    );

    kidosAddress = await deployDiamond(
      "Kidos",
      "contracts/DemKidos/InitDiamond.sol:InitDiamond",
      [demKidosArgs, kidosDropArgs, kidosStakeArgs],
      [
        [
          cfg.toddlerNftName,
          cfg.toddlerNftSymbol,
          cfg.toddlerNftImage,
          account,
          cfg.kidosTicketsCount,
          cfg.kidosMaxMintNfts,
          cfg.kidosMintPrice,
        ],
      ],
    );
    growerAddress = await deployDiamond(
      "Grower DemNft",
      "contracts/DemNft/InitDiamond.sol:InitDiamond",
      [growerNftArgs, growerSaleArgs],
      [
        [
          cfg.growerNftName,
          cfg.growerNftSymbol,
          cfg.growerNftMax,
          cfg.growerNftImage,
          cfg.growerSaleActive,
          cfg.growerSaleBcnPrice,
          dbnAddress,
        ],
      ],
    );
    toddlerAddress = await deployDiamond(
      "Toddler DemNft",
      "contracts/DemNft/InitDiamond.sol:InitDiamond",
      [toddlerNftArgs, toddlerSaleArgs],
      [
        [
          cfg.toddlerNftName,
          cfg.toddlerNftSymbol,
          cfg.toddlerNftMax,
          cfg.toddlerNftImage,
          cfg.toddlerSaleActive,
          cfg.toddlerSaleBcnPrice,
          dbnAddress,
        ],
      ],
    );
    demRebelAddress = await deployDiamond(
      "DemRebelDiamond",
      "contracts/DemRebel/InitDiamond.sol:InitDiamond",
      [demRebelArgs, preSaleFacetArgs],
      buildRebelArgs(),
    );
    gameAddress = await deployDiamond(
      "GameDiamond",
      "contracts/Game/InitDiamond.sol:InitDiamond",
      [
        cashOutArgs,
        gameManagerArgs,
        rebelFarmArgs,
        farmRaidArgs,
        VRFConsumerArgs,
      ],
      buildGameArgs(
        dbnAddress,
        demRebelAddress,
        growerAddress,
        toddlerAddress,
        safeAddress,
      ),
    );

    {
      const demKidos = await ethers.getContractAt(
        "DemKidos",
        kidosAddress,
        accounts[0],
      );
      const tx = await (await demKidos.initMintSupply(cfg.toddlerNftMax)).wait();
      LOG(`>> demKidos initMintSupply gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;
    }
    {
      const demRebelSale = await ethers.getContractAt(
        "PreSaleFacet",
        demRebelAddress,
        accounts[0],
      );
      const tx = await (await demRebelSale.setRewardManager(account)).wait();
      LOG(`>> demRebel setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;
    }
    {
      const demNftSale = await ethers.getContractAt(
        "SaleFacet",
        growerAddress,
        accounts[0],
      );
      const tx = await (await demNftSale.setRewardManager(account)).wait();
      LOG(`>> grower setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;
    }
    {
      const demNftSale = await ethers.getContractAt(
        "SaleFacet",
        toddlerAddress,
        accounts[0],
      );
      const tx = await (await demNftSale.setRewardManager(account)).wait();
      LOG(`>> toddler setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;
    }

    {
      const gameFacet = await ethers.getContractAt(
        "GameManager",
        gameAddress,
        accounts[0],
      );
      {
        const tx = await (
          await gameFacet.connect(accounts[0]).addGameManagers([account])
        ).wait();
        LOG(`>> gameFacet addGameManagers gas used: ${strDisplay(tx.gasUsed)}`);
        totalGasUsed += tx.gasUsed;
      }
      if (!tests) {
        const tx = await (
          await gameFacet.connect(accounts[0]).configureBlastYield()
        ).wait();
        LOG(
          `>> gameFacet configureBlastYield gas used: ${strDisplay(
            tx.gasUsed,
          )}`,
        );
        totalGasUsed += tx.gasUsed;
      }
    }
    {
      const safeContract = await ethers.getContractAt(
        "Safe",
        safeAddress,
        accounts[0],
      );
      const tx = await (
        await safeContract.connect(accounts[0]).setGameContract(gameAddress)
      ).wait();
      LOG(`>> Safe setGameContract gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;
    }
    {
      let vrfCoordinator;
      let link;
      if (tests) {
        //Deploy VRF Mock stuff
        const linkToken = await (
          await ethers.getContractFactory("LinkTokenTest")
        ).deploy();
        await linkToken.waitForDeployment();
        const linkTokenReceipt = await linkToken.deploymentTransaction().wait();

        const vrfCoordinatorMock = await (
          await ethers.getContractFactory("VRFCoordinatorMock")
        ).deploy(linkTokenReceipt.contractAddress);
        await vrfCoordinatorMock.waitForDeployment();
        const vrfCoordinatorMockReceipt = await vrfCoordinatorMock
          .deploymentTransaction()
          .wait();

        vrfCoordinator = vrfCoordinatorMockReceipt.contractAddress;
        link = linkTokenReceipt.contractAddress;
      } else {
        vrfCoordinator = cfg.vrfCoordinator;
        link = cfg.linkTokenAddress;
      }

      const vrf = await ethers.getContractAt(
        "VRFConsumer",
        gameAddress,
        accounts[0],
      );
      let tx = await (
        await vrf.connect(accounts[0]).setVrfCoordinator(vrfCoordinator)
      ).wait();
      LOG(`>> setVrfCoordinator gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;

      tx = await (await vrf.connect(accounts[0]).setLinkAddress(link)).wait();
      LOG(`>> setLinkAddress gas used: ${strDisplay(tx.gasUsed)}`);
      totalGasUsed += tx.gasUsed;

      linkAddress = link;
    }
  }

  async function demBaconDeploy(): Promise<string> {
    const deployedDbn = await (
      await ethers.getContractFactory("DbnToken")
    ).deploy([account, cfg.dbnName, cfg.dbnSymbol]);
    await deployedDbn.waitForDeployment();
    const receipt = await deployedDbn.deploymentTransaction().wait();

    LOG(`>> demBacon address: ${receipt.contractAddress}`);
    LOG(`>> demBacon deploy gas used: ${strDisplay(receipt.gasUsed)}`);
    totalGasUsed += receipt.gasUsed;

    const tx = await (await deployedDbn.setRewardManager(account)).wait();
    LOG(`>> demBacon setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
    totalGasUsed += tx.gasUsed;

    return receipt.contractAddress;
  }

  async function deploySafe(): Promise<string> {
    const deployedSafe = await (
      await ethers.getContractFactory("Safe")
    ).deploy(dbnAddress);
    await deployedSafe.waitForDeployment();
    const receipt = await deployedSafe.deploymentTransaction().wait();

    LOG(`>> Safe address: ${receipt.contractAddress}`);
    LOG(`>> Safe deploy gas used: ${strDisplay(receipt.gasUsed)}`);
    totalGasUsed += receipt.gasUsed;

    return receipt.contractAddress;
  }

  async function deployFacets(...facets: any): Promise<FacetArgs[]> {
    LOG("");

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

      LOG(`>>> Facet ${facet} deployed: ${receipt.contractAddress}`);
      LOG(`${facet} deploy gas used: ${strDisplay(receipt.gasUsed)}`);
      LOG(`Tx hash: ${tx.hash}`);

      totalGasUsed += receipt.gasUsed;
    }

    LOG("");

    return instances;
  }

  async function deployDiamond(
    diamondName: string,
    initDiamond: string,
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
    ).deploy(account);
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

    LOG(`>> ${diamondName} diamond address: ${receipt.contractAddress}`);
    LOG(`>> ${diamondName} diamond deploy gas used: ${strDisplay(gasCost)}`);
    totalGasUsed += gasCost;

    return receipt.contractAddress;
  }

  function buildRebelArgs() {
    return [
      [
        cfg.name,
        cfg.symbol,
        cfg.cloneBoxURI,
        cfg.maxDemRebels,
        cfg.demRebelSalePrice,
        cfg.whitelistSalePrice,
        cfg.maxDemRebelsSalePerUser,
        cfg.isSaleActive,
      ],
    ];
  }
  function buildGameArgs(
    demBacon: string,
    demRebel: string,
    demGrower: string,
    demToddler: string,
    safe: string,
  ) {
    return [
      [
        dbnAddress,
        demRebel,
        demGrower,
        demToddler,
        safe,

        cfg.activationPrice,
        cfg.farmPeriod,
        cfg.farmMaxTier,
        cfg.toddlerMaxCount,
        cfg.basicLootShare,
        cfg.farmRaidDuration,

        cfg.poolShareFactor,

        cfg.vrfFee,
        cfg.vrfKeyHash,
      ],
    ];
  }
}

const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2,
};

function getSelectors(contract: Contract) {
  const fragments = contract.interface.fragments;
  return fragments.reduce((acc: string[], val: ethers.Fragment) => {
    if (ethers.Fragment.isFunction(val)) {
      acc.push(val.selector);
    }
    return acc;
  }, []);
}

class FacetArgs {
  public name: string = "";
  public address: string;
  public contract: Contract;

  constructor(name: string, address: string, contract: Contract) {
    this.name = name;
    this.contract = contract;
    this.address = address;
  }
}

export class DeployedContracts {
  public demBacon: string = "";
  public demRebel: string = "";
  public game: string = "";
  public kidos: string = "";
  public growerDemNft: string = "";
  public toddlerDemNft: string = "";
  public safe: string = "";
  public link: string = "";

  public constructor(init?: Partial<DeployedContracts>) {
    Object.assign(this, init);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main(cfg.isRootChain, false).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
