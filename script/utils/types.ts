// config/types.ts
import type { Address, WalletClient } from 'viem';

export interface ChainConfig {
  client: any; // PublicClient doesn't work for OP Sepolia due to different tx types
  walletClient: WalletClient;
  chainId: number;
  explorerUrl: string;
}

export interface ContractAddresses {
  appGateway: Address;
  arbForwarder?: Address;
  arbOnchain?: Address;
  opForwarder?: Address;
  opOnchain?: Address;
}

export interface TestFlags {
  write: boolean;
  read: boolean;
  trigger: boolean;
  upload: boolean;
  scheduler: boolean;
  insufficient: boolean;
  revert: boolean;
  all: boolean;
}
