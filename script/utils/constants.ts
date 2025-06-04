// config/constants.ts
import { parseEther } from 'viem';

export const CHAIN_IDS = {
  EVMX: 43,
  // Testnets
  ARB_SEP: 421614,
  OP_SEP: 11155420,
  // Mainnets
  OP: 10,
  ARB: 42161,
  BASE: 8453,
} as const;

export const URLS = {
  EVMX_API_BASE: "https://api-evmx-devnet.socket.tech",
} as const;

export const AMOUNTS = {
  DEPLOY_FEES: parseEther('1'), // 1 ETH
  TEST_USDC: 1000000n, // 1 USDC for testing
  GAS_BUFFER: 100000000n, // 0.1 Gwei
  GAS_LIMIT: 50000000000n, // Gas limit estimate
} as const;

export const COLORS = {
  YELLOW: '\x1b[1;33m',
  GREEN: '\x1b[0;32m',
  CYAN: '\x1b[0;36m',
  RED: '\x1b[0;31m',
  NC: '\x1b[0m', // No Color
} as const;
