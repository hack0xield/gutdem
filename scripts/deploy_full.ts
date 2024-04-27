import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";
import { deployConfig as cfg } from "../deploy.config";
import { deployConfig as testCfg } from "../deploy-test.config";
import * as deploy_common from "./deploy_common";
import * as deploy_kidos from "./deploy_kidos";

export async function main(
  isRoot: boolean,
  tests: boolean,
): Promise<[DeployedContracts]> {
  const gasReceipt = { totalGasUsed: 0n };
  const commonOutput = await deploy_common.main(isRoot, tests, gasReceipt);
  const kidosOutput = await deploy_kidos.main(tests, gasReceipt);

  const result = new DeployedContracts({
    demBacon: commonOutput.demBacon,
    demRebel: commonOutput.demRebel,
    game: commonOutput.game,
    kidos: kidosOutput.kidos,
    growerDemNft: commonOutput.growerDemNft,
    toddlerDemNft: commonOutput.toddlerDemNft,
    safe: commonOutput.safe,
    link: commonOutput.link,
  });
  return result;
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
