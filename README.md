# Deployment Steps for EVMx Read Tests

Follow these steps to deploy and run the EVMx Read tests.

### 1. **Deploy the EVMx Read Tests Script**
Run the following command to deploy the EVMx Read tests script:
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
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

### 6. Withdraw funds
```bash
forge script script/read/RunEVMxRead.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```

# Deployment Steps for EVMx OnchainTrigger Tests

Follow these steps to deploy and run the EVMx OnchainTrigger tests.

### 1. **Deploy the EVMx OnchainTrigger Tests Script**
Run the following command to deploy the EVMx OnchainTrigger tests script:
```bash
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
```

### 1a. **Verify the EVMx Contract**
Verify the `OnchainTriggerAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/trigger-appgateway-onchain/OnchainTriggerAppGateway.sol:OnchainTriggerAppGateway
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
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Onchain Contract**
Verify the `OnchainTrigger` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/trigger-appgateway-onchain/OnchainTrigger.sol:OnchainTrigger
```

### 5. **Run EVMx OnchainTrigger Script**
Finally, run the EVMx OnchainTrigger script:
```bash
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --sig "onchainToEVMx()"
```

```bash
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --legacy --with-gas-price 0 --sig "eVMxToOnchain()"
```

```bash
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --sig "onchainToOnchain()"
```

### 6. Withdraw funds
```bash
forge script script/trigger-appgateway-onchain/RunEVMxOnchainTrigger.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```

# Deployment Steps for EVMx Write Tests

Follow these steps to deploy and run the EVMx Write tests.

### 1. **Deploy the EVMx Write Tests Script**
Run the following command to deploy the EVMx Write tests script:
```bash
forge script script/write/RunEVMxWrite.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
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
forge script script/write/RunEVMxWrite.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "runTriggers()"
```

### 6. Withdraw funds
```bash
forge script script/write/RunEVMxWrite.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```

# Deployment Steps for EVMx Deploy Tests

Follow these steps to deploy and run the EVMx Write tests.

### 1. **Deploy the EVMx Deploy Tests Script**
Run the following command to deploy the EVMx Deploy tests script:
```bash
forge script script/deploy/RunEVMxDeploy.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
```

### 1a. **Verify the Contract**
Verify the `DeployAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/deploy/DeploymentAppGateway.sol:DeploymentAppGateway
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
forge script script/deploy/RunEVMxDeploy.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Contract**
Verify the `DeployOnchain` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/deploy/DeployOnchain.sol:NoPlugNoInitialize
```

### 5. **Run EVMx Deploy Script**
Finally, run the EVMx Deploy script:
```bash
forge script script/deploy/RunEVMxDeploy.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "runTests()"
```

### 6. Withdraw funds
```bash
forge script script/deploy/RunEVMxDeploy.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```

# Deployment Steps for EVMx Schedule Tests

Follow these steps to deploy and run the EVMx Write tests.

### 1. **Deploy the EVMx Schedule Tests Script**
Run the following command to deploy the EVMx Schedule tests script:
```bash
forge script script/schedule/RunEVMxSchedule.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
```

### 1a. **Verify the Contract**
Verify the `ScheduleAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/schedule/ScheduleAppGateway.sol:ScheduleAppGateway
```

### 2. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 3. **Run EVMx Schedule Script**
Finally, run the EVMx Schedule script:
```bash
forge script script/schedule/RunEVMxSchedule.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "createTimers()"
```
# Deployment Steps for EVMx Forwarder
Follow these steps to deploy and run the EVMx Forwarder.

### 1. **Deploy the App Gateway**
Run the following command to deploy the `UploadAppGateway` contract:
```bash
forge script script/forwarder-on-evmx/RunEVMxForwarder.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
```

### 1a. **Verify the Contract**
Verify the `UploadAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/forwarder-on-evmx/UploadAppGateway.sol:UploadAppGateway
```

### 2. **Update the `APP_GATEWAY` in `.env`**
Make sure to update the `APP_GATEWAY` address in your `.env` file.

### 3. **Deploy Onchain Counter Contract**
Deploy the Counter contract on Arbitrum Sepolia:
```bash
forge script script/forwarder-on-evmx/RunEVMxForwarder.s.sol --broadcast --skip-simulation --sig "deployOnchainContract()"
```

### 3a. **Verify the Contract**
Verify the `Counter` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <COUNTER_ADDRESS> src/forwarder-on-evmx/Counter.sol:Counter
```

### 4. **Pay Fees in Arbitrum ETH**
Run the script to pay fees in Arbitrum ETH:
```bash
forge script lib/socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol --broadcast --skip-simulation
```

### 5. **Upload and Read**
Run the following command to upload the Counter contract to EVMx and read its value:
```bash
forge script script/forwarder-on-evmx/RunEVMxForwarder.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "uploadAndRead(address)" <COUNTER_ADDRESS>
```

### 6. **Withdraw App Fees**
To withdraw the accumulated fees:
```bash
forge script script/forwarder-on-evmx/RunEVMxForwarder.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```

# Deployment Steps for EVMx Revert
Follow these steps to deploy and run the EVMx Revert.

### 1. **Deploy the EVMx Revert Tests Script**
Run the following command to deploy the EVMx Revert tests script:
```bash
forge script script/revert/RunEVMxRevert.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployAppGateway()"
```

### 1a. **Verify the EVMx Contract**
Verify the `RevertAppGateway` contract on Blockscout:
```bash
forge verify-contract --rpc-url https://rpc-evmx-devnet.socket.tech/ --verifier blockscout --verifier-url https://evmx.cloud.blockscout.com/api <APP_GATEWAY_ADDRESS> src/revert/RevertAppGateway.sol:RevertAppGateway
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
forge script script/revert/RunEVMxRevert.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "deployOnchainContracts()"
```

### 4a. **Verify the Onchain Contract**
Verify the `Counter` contract on Arbitrum Sepolia Blockscout:
```bash
forge verify-contract --rpc-url https://rpc.ankr.com/arbitrum_sepolia --verifier-url https://arbitrum-sepolia.blockscout.com/api --verifier blockscout <ONCHAIN_ADDRESS> src/revert/Counter.sol:Counter
```

### 5. **Run EVMx Revert Script**
Finally, run the EVMx Revert script:
```bash
forge script script/revert/RunEVMxRevert.s.sol --broadcast --skip-simulation --with-gas-price 0 --legacy --sig "callReverts()"
```


### 6. Withdraw funds
```bash
forge script script/revert/RunEVMxRevert.s.sol --broadcast --sig "withdrawAppFees()" --legacy --with-gas-price 0
```
