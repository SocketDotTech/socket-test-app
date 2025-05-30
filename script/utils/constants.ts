// config/constants.ts
import { parseEther } from 'viem';

export const CHAIN_IDS = {
  EVMX: 43,
  ARB_SEP: 421614,
  OP_SEP: 11155420,
} as const;

export const URLS = {
  EVMX_API_BASE: "https://api-evmx-devnet.socket.tech",
} as const;

export const AMOUNTS = {
  DEPLOY_FEES: parseEther('10'), // 10 ETH
  TEST_USDC: BigInt('100000000'), // 100 TEST USDC
  GAS_BUFFER: BigInt('100000000'), // 0.1 Gwei
  GAS_LIMIT: BigInt('50000000000'), // Gas limit estimate
} as const;

export const COLORS = {
  YELLOW: '\x1b[1;33m',
  GREEN: '\x1b[0;32m',
  CYAN: '\x1b[0;36m',
  RED: '\x1b[0;31m',
  NC: '\x1b[0m', // No Color
} as const;

