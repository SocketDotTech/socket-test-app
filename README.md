# Deployment Steps for EVMx Read Tests

Follow these steps to deploy and run the EVMx Read tests.

### 1. **Deploy the EVMx Read Tests Script**
Run the following command to deploy the EVMx Read tests script:
```bash
forge script script/read/DeployEVMxReadTests.s.sol --broadcast --legacy --with-gas-price 0
```

### 1a. **Verify the EVMx Contract**
Verify the `ReadAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/read/ReadAppGateway.sol:ReadAppGateway
```

### 2. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 3. **Pay Fees in Arbitrum ETH**
Run the script to pay fees in Arbitrum ETH:
```bash
forge script lib/socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
```

### 4. **Deploy Onchain Contracts**
Deploy the onchain contracts using the following script:
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Onchain Contract**
Verify the `ReadMultichain` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/read/ReadMultichain.sol:ReadMultichain
```

### 5. **Run EVMx Read Script**
Finally, run the EVMx Read script:
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy
```

# Deployment Steps for EVMx Inbox Tests

Follow these steps to deploy and run the EVMx Inbox tests.

### 1. **Deploy the EVMx Inbox Tests Script**
Run the following command to deploy the EVMx Inbox tests script:
```bash
forge script script/inbox/DeployEVMxInboxTests.s.sol --broadcast --legacy --with-gas-price 0
```

### 1a. **Verify the EVMx Contract**
Verify the `InboxAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/inbox/InboxAppGateway.sol:InboxAppGateway
```

### 2. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 3. **Pay Fees in Arbitrum ETH**
Run the script to pay fees in Arbitrum ETH:
```bash
forge script lib/socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
```

### 4. **Deploy Onchain Contracts**
Deploy the onchain contracts using the following script:
```bash
forge script script/inbox/RunEVMxInbox.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Onchain Contract**
Verify the `InboxMultichain` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/inbox/Inbox.sol:Inbox
```

### 5. **Run EVMx Inbox Script**
Finally, run the EVMx Inbox script:
```bash
forge script script/write/DeployEVMxWriteTests.s.sol --broadcast --sig "onchainToEVMx()"
```

```bash
forge script script/write/DeployEVMxWriteTests.s.sol --broadcast --legacy --with-gas-price 0 --sig "eVMxToOnchain()"
```

```bash
forge script script/write/DeployEVMxWriteTests.s.sol --broadcast --sig "onchainToOnchain()"
```

# Deployment Steps for EVMx Write Tests

Follow these steps to deploy and run the EVMx Write tests.

### 1. **Deploy the EVMx Write Tests Script**
Run the following command to deploy the EVMx Write tests script:
```bash
forge script script/write/DeployEVMxWriteTests.s.sol --broadcast --legacy --with-gas-price 0 --sig "onchainToEVMx()"
```

### 1a. **Verify the Contract**
Verify the `WriteAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/write/WriteAppGateway.sol:WriteAppGateway
```

### 2. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 3. **Pay Fees in Arbitrum ETH**
Run the script to pay fees in Arbitrum ETH:
```bash
forge script lib/socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
```

### 4. **Deploy Onchain Contracts**
Deploy the onchain contracts using the following script:
```bash
forge script script/write/RunEVMxWrite.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Contract**
Verify the `WriteMultichain` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/write/WriteMultichain.sol:WriteMultichain
```

### 5. **Run EVMx Write Script**
Finally, run the EVMx Write script:
```bash
forge script script/write/RunEVMxWrite.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy
```
