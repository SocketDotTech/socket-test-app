// clients/setup.ts
import {
  createPublicClient,
  createWalletClient,
  http,
  type Hash,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arbitrumSepolia, optimismSepolia } from 'viem/chains';
import dotenv from 'dotenv';
import { ChainConfig } from './types.js';
import { CHAIN_IDS } from './constants.js';

// Load environment variables
dotenv.config();

// Environment validation
export function validateEnvironment(): void {
  const required = [
    'EVMX_RPC',
    'PRIVATE_KEY',
    'ADDRESS_RESOLVER',
    'FEES_MANAGER',
    'ARBITRUM_SEPOLIA_RPC',
    'OPTIMISM_SEPOLIA_RPC'
  ];

  for (const env of required) {
    if (!process.env[env]) {
      throw new Error(`${env} environment variable is required`);
    }
  }
}

// Setup all blockchain clients
export function setupClients(): {
  evmxChain: ChainConfig;
  arbChain: ChainConfig;
  opChain: ChainConfig;
} {
  validateEnvironment();

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as Hash);

  // EVMx Chain
  const evmxClient = createPublicClient({
    transport: http(process.env.EVMX_RPC)
  });

  const evmxWallet = createWalletClient({
    account,
    transport: http(process.env.EVMX_RPC)
  });

  // Arbitrum Sepolia Chain
  const arbClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http(process.env.ARBITRUM_SEPOLIA_RPC)
  });

  const arbWallet = createWalletClient({
    account,
    chain: arbitrumSepolia,
    transport: http(process.env.ARBITRUM_SEPOLIA_RPC)
  });

  // Optimism Sepolia Chain
  const opClient = createPublicClient({
    chain: optimismSepolia,
    transport: http(process.env.OPTIMISM_SEPOLIA_RPC)
  });

  const opWallet = createWalletClient({
    account,
    chain: optimismSepolia,
    transport: http(process.env.OPTIMISM_SEPOLIA_RPC)
  });

  return {
    evmxChain: {
      client: evmxClient,
      walletClient: evmxWallet,
      chainId: CHAIN_IDS.EVMX,
      explorerUrl: 'evmx.cloud.blockscout.com'
    },
    arbChain: {
      client: arbClient,
      walletClient: arbWallet,
      chainId: CHAIN_IDS.ARB_SEP,
      explorerUrl: 'arbitrum-sepolia.blockscout.com'
    },
    opChain: {
      client: opClient,
      walletClient: opWallet,
      chainId: CHAIN_IDS.OP_SEP,
      explorerUrl: 'optimism-sepolia.blockscout.com'
    }
  };
}
