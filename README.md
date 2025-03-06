# Deployment Steps for EVMx Read Tests

Follow these steps to deploy and run the EVMx Read tests.

### 1. **Deploy the EVMx Read Tests Script**
Run the following command to deploy the EVMx Read tests script:
```bash
forge script script/read/DeployEVMxReadTests.sol --broadcast --legacy --with-gas-price 0
```

### 2. **Verify the Contract**
Verify the `ReadAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/read/ReadAppGateway.sol:ReadAppGateway
```

### 3. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 4. **Pay Fees in Arbitrum ETH**
Run the script to pay fees in Arbitrum ETH:
```bash
forge script lib/socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
```

### 5. **Deploy Onchain Contracts**
Deploy the onchain contracts using the following script:
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 6. **Run EVMx Read Script**
Finally, run the EVMx Read script:
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy
```
