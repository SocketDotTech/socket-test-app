// contracts/deployer.ts
import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs/promises';
import path from 'path';
import { parseAbi, type Address, type Hash, type Abi } from 'viem';
import { ChainConfig } from './types.js';
import { COLORS, CHAIN_IDS, AMOUNTS } from './constants.js';
import { getExplorerUrl, getExplorerAddressUrl } from './helpers.js';

// Build contracts using forge
export async function buildContracts(): Promise<void> {
  console.log(`${COLORS.CYAN}Building contracts${COLORS.NC}`);
  const execAsync = promisify(exec);

  try {
    await execAsync('forge build');
    console.log('Contracts built successfully');
  } catch (error) {
    console.error(`${COLORS.RED}Error:${COLORS.NC} forge build failed. Check your contract code.`);
    throw error;
  }
}

// Deploy contract function
export async function deployContract(
  contractName: string,
  constructorArgs: any[] = [],
  chainConfig: ChainConfig
): Promise<Address> {
  console.log(`${COLORS.CYAN}Deploying ${contractName} contract${COLORS.NC}`);

  try {
    // Read the compiled contract
    const artifactPath = path.join('out', `${contractName}.sol`, `${contractName}.json`);
    const artifact = JSON.parse(await fs.readFile(artifactPath, 'utf8'));

    const abi = artifact.abi;
    const bytecode = artifact.bytecode.object;

    // Deploy the contract
    const hash = await chainConfig.walletClient.deployContract({
      abi,
      bytecode,
      args: constructorArgs,
      account: chainConfig.walletClient.account!,
      chain: chainConfig.walletClient.chain,
      gasPrice: chainConfig.chainId === CHAIN_IDS.EVMX ? 0n : undefined
    });

    await new Promise(resolve => setTimeout(resolve, 2000));
    console.log(`${COLORS.GREEN}Tx Hash:${COLORS.NC} ${getExplorerUrl(hash, chainConfig)}`);

    // Get the deployed address
    const receipt = await chainConfig.client.getTransactionReceipt({ hash });

    if (!receipt.contractAddress) {
      throw new Error('Failed to get contract address from deployment');
    }

    const address = receipt.contractAddress;
    console.log(`${COLORS.GREEN}Contract deployed:${COLORS.NC} ${getExplorerAddressUrl(address, chainConfig)}`);

    return address;
  } catch (error) {
    console.error(`${COLORS.RED}Error:${COLORS.NC} Contract deployment failed.`);
    throw error;
  }
}

// Send transaction with consistent error handling
export async function sendTransaction(
  to: Address,
  functionName: string,
  args: any[] = [],
  chainConfig: ChainConfig,
  abi: Abi,
  value: bigint = 0n
): Promise<Hash> {
  console.log(`${COLORS.CYAN}Sending transaction to ${functionName} on ${to}${COLORS.NC}`);

  try {
    const hash = await chainConfig.walletClient.writeContract({
      address: to,
      abi,
      functionName,
      args,
      account: chainConfig.walletClient.account!,
      chain: chainConfig.walletClient.chain,
      gasPrice: chainConfig.chainId === CHAIN_IDS.EVMX ? 0n : undefined,
      value: value
    });

    await new Promise(resolve => setTimeout(resolve, 2000));
    console.log(`${COLORS.GREEN}Tx Hash:${COLORS.NC} ${getExplorerUrl(hash, chainConfig)}`);

    return hash;
  } catch (error) {
    console.error(`${COLORS.RED}Error:${COLORS.NC} Transaction failed.`);
    throw error;
  }
}

// Deploy AppGateway
export async function deployAppGateway(
  filename: string,
  evmxChain: ChainConfig,
  deployFees = AMOUNTS.DEPLOY_FEES
): Promise<Address> {
  return deployContract(
    filename,
    [process.env.ADDRESS_RESOLVER, deployFees / 2n],
    evmxChain
  );
}

// Deploy onchain contracts
export async function deployOnchain(
  chainId: number,
  appGateway: Address,
  evmxChain: ChainConfig
): Promise<void> {
  console.log(`${COLORS.CYAN}Deploying onchain contracts for chain id: ${chainId}${COLORS.NC}`);

  const abi = parseAbi([
    'function deployContracts(uint32 chainId) external'
  ]);

  await sendTransaction(
    appGateway,
    'deployContracts',
    [chainId],
    evmxChain,
    abi
  );
}
