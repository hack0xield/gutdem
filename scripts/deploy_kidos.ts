import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";
import { DeployInfra as infra } from "./shared/deployInfra";
import { DeployedContracts } from "./deploy_full";
import { deployConfig as cfg } from "../deploy.config";
import { deployConfig as testCfg } from "../deploy-test.config";

export async function main(
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
  LOG(`> Kidos Deploy: account owner: ${account}`);

  if (tests == true) {
    cfg = testCfg;
  }
  const rewardManagerAddr = tests
    ? await rewardManager.getAddress()
    : cfg.kidosRewardMgr;

  let kidosAddress;
  await deployKidos();

  LOG(`> Total gas used: ${strDisplay(gas.totalGasUsed)}`);

  const result = new DeployedContracts({
    kidos: kidosAddress,
  });
  return result;

  async function deployKidos() {
    const [demKidosArgs, kidosDropArgs] = await infra.deployFacets(
      "DemKidos",
      "KidosDrop",
    );

    kidosAddress = await infra.deployDiamond(
      "Kidos",
      "contracts/DemKidos/InitDiamond.sol:InitDiamond",
      account,
      [demKidosArgs, kidosDropArgs],
      [
        [
          cfg.kidosNftName,
          cfg.kidosNftSymbol,
          cfg.kidosNftImage,
          rewardManagerAddr,
          cfg.kidosTicketsCount,
          cfg.kidosMaxMintNfts,
          cfg.kidosMintPrice,
          cfg.kidosDropPrice,
        ],
      ],
    );
    {
      const demKidos = await ethers.getContractAt(
        "DemKidos",
        kidosAddress,
        accounts[0],
      );
      {
        const tx = await (
          await demKidos.initMintSupply(cfg.kidosNftMax)
        ).wait();
        LOG(`>> demKidos initMintSupply gas used: ${strDisplay(tx.gasUsed)}`);
        gas.totalGasUsed += tx.gasUsed;
      }
      if (tests) {
        //Set approve with RewardManager when not test deploy!
        const tx = await (
          await demKidos
            .connect(accounts[1])
            .erc20Approve(kidosAddress, ethers.MaxUint256)
        ).wait();
        LOG(`>> demKidos erc20Approve gas used: ${strDisplay(tx.gasUsed)}`);
        gas.totalGasUsed += tx.gasUsed;
      }
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  const gas = { totalGasUsed: 0n };
  main(false, gas).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
