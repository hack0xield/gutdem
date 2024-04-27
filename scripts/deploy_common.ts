import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";
import { DeployInfra as infra } from "./shared/deployInfra";
import { DeployedContracts } from "./deploy_full";
import { deployConfig as cfg } from "../deploy.config";
import { deployConfig as testCfg } from "../deploy-test.config";

export async function main(
  isRoot: boolean,
  tests: boolean,
  gas: { totalGasUsed: BigInt },
): Promise<[DeployedContracts]> {
  const LOG = !tests ? console.log.bind(console) : function () {};
  const accounts = await ethers.getSigners();
  const account = await accounts[0].getAddress();
  const rewardManager = accounts[1];

  infra.LOG = LOG;
  infra.gas = gas;

  LOG("");
  LOG(`> Common Deploy: account owner: ${account}`);

  if (tests == true) {
    cfg = testCfg;
  }
  const rewardManagerAddr = tests
    ? await rewardManager.getAddress()
    : cfg.kidosRewardMgr;

  const dbnAddress = await demBaconDeploy();
  const safeAddress = await deploySafe();
  let growerAddress,
    toddlerAddress,
    demRebelAddress,
    gameAddress,
    linkAddress;
  if (isRoot) {
    //await deployModeRoot();
  } else {
    await deployModeChild();
  }

  LOG(`> Total gas used: ${strDisplay(gas.totalGasUsed)}`);

  const result = new DeployedContracts({
    demBacon: dbnAddress,
    demRebel: demRebelAddress,
    game: gameAddress,
    growerDemNft: growerAddress,
    toddlerDemNft: toddlerAddress,
    safe: safeAddress,
    link: linkAddress,
  });
  return result;

  //   async function deployModeRoot() {
  //     const tunnel = tests ? "MockRootTunnel" : "RootTunnel";
  //     const [demRebelArgs, preSaleFacetArgs, bridgeArgs, tunnelArgs] =
  //       await infra.deployFacets("DemRebel", "PreSaleFacet", "ChainBridge", tunnel);
  //
  //     demRebelAddress = await infra.deployDiamond(
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
  //       gas.totalGasUsed += tx.gasUsed;
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
  //       gas.totalGasUsed += tx.gasUsed;
  //     };
  //   }

  async function deployModeChild() {
    const [
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
    ] = await infra.deployFacets(
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

    growerAddress = await infra.deployDiamond(
      "Grower DemNft",
      "contracts/DemNft/InitDiamond.sol:InitDiamond",
      account,
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
    toddlerAddress = await infra.deployDiamond(
      "Toddler DemNft",
      "contracts/DemNft/InitDiamond.sol:InitDiamond",
      account,
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
    demRebelAddress = await infra.deployDiamond(
      "DemRebelDiamond",
      "contracts/DemRebel/InitDiamond.sol:InitDiamond",
      account,
      [demRebelArgs, preSaleFacetArgs],
      buildRebelArgs(),
    );
    gameAddress = await infra.deployDiamond(
      "GameDiamond",
      "contracts/Game/InitDiamond.sol:InitDiamond",
      account,
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
      const demRebelSale = await ethers.getContractAt(
        "PreSaleFacet",
        demRebelAddress,
        accounts[0],
      );
      const tx = await (await demRebelSale.setRewardManager(account)).wait();
      LOG(`>> demRebel setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      gas.totalGasUsed += tx.gasUsed;
    }
    {
      const demNftSale = await ethers.getContractAt(
        "SaleFacet",
        growerAddress,
        accounts[0],
      );
      const tx = await (await demNftSale.setRewardManager(account)).wait();
      LOG(`>> grower setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      gas.totalGasUsed += tx.gasUsed;
    }
    {
      const demNftSale = await ethers.getContractAt(
        "SaleFacet",
        toddlerAddress,
        accounts[0],
      );
      const tx = await (await demNftSale.setRewardManager(account)).wait();
      LOG(`>> toddler setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
      gas.totalGasUsed += tx.gasUsed;
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
        gas.totalGasUsed += tx.gasUsed;
      }
      //TODO
      //       if (!tests) {
      //         const tx = await (
      //           await gameFacet.connect(accounts[0]).configureBlastYield()
      //         ).wait();
      //         LOG(
      //           `>> gameFacet configureBlastYield gas used: ${strDisplay(
      //             tx.gasUsed,
      //           )}`,
      //         );
      //         gas.totalGasUsed += tx.gasUsed;
      //       }
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
      gas.totalGasUsed += tx.gasUsed;
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
      gas.totalGasUsed += tx.gasUsed;

      tx = await (await vrf.connect(accounts[0]).setLinkAddress(link)).wait();
      LOG(`>> setLinkAddress gas used: ${strDisplay(tx.gasUsed)}`);
      gas.totalGasUsed += tx.gasUsed;

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
    gas.totalGasUsed += receipt.gasUsed;

    const tx = await (await deployedDbn.setRewardManager(account)).wait();
    LOG(`>> demBacon setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
    gas.totalGasUsed += tx.gasUsed;

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
    gas.totalGasUsed += receipt.gasUsed;

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

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  const gas = { totalGasUsed: 0n };
  main(cfg.isRootChain, false, gas).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
