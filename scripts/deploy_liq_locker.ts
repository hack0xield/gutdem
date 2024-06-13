import { ethers } from "hardhat";
import { strDisplay } from "./shared/utils";

const recipient = "0x8C07e7c7bfCCAC4d0B06938F5889e3621626FeFa";
const positionManager = "0x0f0c3de3cd5185454ede5ef184bc9c7f4133fb90";

export async function main(): Promise<[string]> {
  const LOG = console.log.bind(console);
  let totalGasUsed = 0n;
  const accounts = await ethers.getSigners();
  const account = await accounts[0].getAddress();

  LOG(`> LiquidityLocker deploy`);
  LOG(`> Recipient address: ${recipient}`);
  LOG(`> Using account as owner: ${account}`);

  const contract = await (
    await ethers.getContractFactory("LiquidityLocker")
  ).deploy(recipient, positionManager);
  await contract.waitForDeployment();
  const receipt = await contract.deploymentTransaction().wait();
  const liquidityLocker = receipt.contractAddress;

  LOG(`>> LiquidityLocker address: ${liquidityLocker}`);
  LOG(`>> LiquidityLocker deploy gas used: ${strDisplay(receipt.gasUsed)}`);
  totalGasUsed += receipt.gasUsed;

  LOG(`> LiquidityLocker Total gas used: ${strDisplay(totalGasUsed)}`);

  return liquidityLocker;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
