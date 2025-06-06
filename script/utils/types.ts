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
  chain1Forwarder?: Address;
  chain1Onchain?: Address;
  chain2Forwarder?: Address;
  chain2Onchain?: Address;
  deployForwarders?: Address[];
  deployOnchain?: Address[];
}

export interface TestFlags {
  write: boolean;
  read: boolean;
  trigger: boolean;
  upload: boolean;
  scheduler: boolean;
  insufficient: boolean;
  revert: boolean;
  deployment: boolean;
  all: boolean;
}
