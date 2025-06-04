import {
  createPublicClient,
  createWalletClient,
  http,
  type Hash,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arbitrumSepolia, optimismSepolia, optimism, arbitrum, base } from 'viem/chains';
import dotenv from 'dotenv';
import { ChainConfig } from './types.js';
import { CHAIN_IDS } from './constants.js';

// Load environment variables
dotenv.config();

// Environment validation - only check required chains
export function validateEnvironment(): void {
  const required = [
    'PRIVATE_KEY',
    // EVMx
    'EVMX_RPC',
    'ADDRESS_RESOLVER',
    'FEES_MANAGER',
    // Testnets (always required)
    'ARBITRUM_SEPOLIA_RPC',
    'OPTIMISM_SEPOLIA_RPC',
  ];

  for (const env of required) {
    if (!process.env[env]) {
      throw new Error(`${env} environment variable is required`);
    }
  }
}

// Helper function to create chain config
function createChainConfig(
  chainInfo: any,
  rpcUrl: string,
  account: any,
  chainId: number,
  explorerUrl: string
): ChainConfig {
  const client = createPublicClient({
    chain: chainInfo,
    transport: http(rpcUrl)
  });

  const walletClient = createWalletClient({
    account,
    chain: chainInfo,
    transport: http(rpcUrl)
  });

  return {
    client,
    walletClient,
    chainId,
    explorerUrl
  };
}

// Check if mainnet environment variables are available
export function getAvailableMainnets(): {
  hasArbitrum: boolean;
  hasOptimism: boolean;
  hasBase: boolean;
} {
  return {
    hasArbitrum: !!process.env.ARBITRUM_RPC,
    hasOptimism: !!process.env.OPTIMISM_RPC,
    hasBase: !!process.env.BASE_RPC,
  };
}

// Setup all blockchain clients with optional mainnets
export function setupClients(): {
  evmxChain: ChainConfig;
  arbChain: ChainConfig;
  opChain: ChainConfig;
  arbMainnetChain?: ChainConfig;
  opMainnetChain?: ChainConfig;
  baseMainnetChain?: ChainConfig;
} {
  validateEnvironment();

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as Hash);
  const availableMainnets = getAvailableMainnets();

  // EVMx Chain (always required)
  const evmxClient = createPublicClient({
    transport: http(process.env.EVMX_RPC)
  });
  const evmxWallet = createWalletClient({
    account,
    transport: http(process.env.EVMX_RPC)
  });

  // Testnet chains (always required)
  const arbChain = createChainConfig(
    arbitrumSepolia,
    process.env.ARBITRUM_SEPOLIA_RPC!,
    account,
    CHAIN_IDS.ARB_SEP,
    'arbitrum-sepolia.blockscout.com'
  );

  const opChain = createChainConfig(
    optimismSepolia,
    process.env.OPTIMISM_SEPOLIA_RPC!,
    account,
    CHAIN_IDS.OP_SEP,
    'optimism-sepolia.blockscout.com'
  );

  const result: {
    evmxChain: ChainConfig;
    arbChain: ChainConfig;
    opChain: ChainConfig;
    arbMainnetChain?: ChainConfig;
    opMainnetChain?: ChainConfig;
    baseMainnetChain?: ChainConfig;
  } = {
    evmxChain: {
      client: evmxClient,
      walletClient: evmxWallet,
      chainId: CHAIN_IDS.EVMX,
      explorerUrl: 'evmx.cloud.blockscout.com'
    },
    arbChain,
    opChain,
  };

  // Optional mainnet chains
  if (availableMainnets.hasArbitrum) {
    result.arbMainnetChain = createChainConfig(
      arbitrum,
      process.env.ARBITRUM_RPC!,
      account,
      CHAIN_IDS.ARB,
      'arbitrum.blockscout.com'
    );
  }

  if (availableMainnets.hasOptimism) {
    result.opMainnetChain = createChainConfig(
      optimism,
      process.env.OPTIMISM_RPC!,
      account,
      CHAIN_IDS.OP, // Fixed: was using OP_SEP instead of OP
      'optimism.blockscout.com'
    );
  }

  if (availableMainnets.hasBase) {
    result.baseMainnetChain = createChainConfig(
      base,
      process.env.BASE_RPC!,
      account,
      CHAIN_IDS.BASE,
      'base.blockscout.com'
    );
  }

  return result;
}

// Helper function to get only available chains
export function getAvailableChains() {
  const clients = setupClients();
  const availableMainnets = getAvailableMainnets();

  console.log('Available chains:');
  console.log('- EVMx: ✓');
  console.log('- Arbitrum Sepolia: ✓');
  console.log('- Optimism Sepolia: ✓');
  if (availableMainnets.hasArbitrum) {
    console.log(`- Arbitrum Mainnet: ✓`);
  }
  if (availableMainnets.hasOptimism) {
    console.log(`- Optimism Mainnet: ✓`);
  }
  if (availableMainnets.hasBase) {
    console.log(`- Base Mainnet: ✓`);
  }

  return clients;
}
