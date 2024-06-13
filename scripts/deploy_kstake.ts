import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";
import { deployConfig as cfg } from "../deploy.config";
import { deployConfig as testCfg } from "../deploy-test.config";

const kidosAddress = "0x082E53a6519c5e0EC846D3Dc6eE499011601990A";

export async function main(tests: boolean, kidos: string): Promise<[string]> {
  const LOG = !tests ? console.log.bind(console) : function () {};
  let totalGasUsed = 0n;
  const accounts = await ethers.getSigners();
  const account = await accounts[0].getAddress();

  LOG(`> KidosStake deploy`);
  LOG(`> Kidos address: ${kidos}`);
  LOG(`> Using account as owner: ${account}`);

  if (tests == true) {
    cfg = testCfg;
  }

  const contract = await (
    await ethers.getContractFactory("KidosStake")
  ).deploy(kidos);
  await contract.waitForDeployment();
  const receipt = await contract.deploymentTransaction().wait();
  const stakeContract = receipt.contractAddress;

  LOG(`>> KidosStake address: ${stakeContract}`);
  LOG(`>> KidosStake deploy gas used: ${strDisplay(receipt.gasUsed)}`);
  totalGasUsed += receipt.gasUsed;

  const rewardManager = accounts[1];
  const rewardManagerAddr = tests ? await rewardManager.getAddress() : cfg.kidosRewardMgr;
  const tx = await (await contract.setRewardManager(rewardManagerAddr)).wait();
  LOG(`>> KidosStake setRewardManager gas used: ${strDisplay(tx.gasUsed)}`);
  totalGasUsed += tx.gasUsed;

  LOG(`> KidosStake Total gas used: ${strDisplay(totalGasUsed)}`);

  return stakeContract;
}

if (require.main === module) {
  main(false, kidosAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
