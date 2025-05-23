// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DepositFees} from "socket-protocol/script/helpers/PayFeesInArbitrumETH.s.sol";
import {FeesPlug} from "socket-protocol/contracts/evmx/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/utils/common/Constants.sol";
import {FeesManager} from "socket-protocol/contracts/evmx/payload-delivery/FeesManager.sol";

interface IAppGateway {
    function deployContracts(uint32 chainId) external;
    function withdrawFeeTokens(uint32 chainId, address token, uint256 amount, address recipient) external;
}

abstract contract SetupScript is Script {
    // ----- ENVIRONMENT VARIABLES -----
    string rpcEVMx = vm.envString("EVMX_RPC");
    string rpcArbSepolia = vm.envString("ARBITRUM_SEPOLIA_RPC");
    string rpcOPSepolia = vm.envString("OPTIMISM_SEPOLIA_RPC");
    address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
    address feesPlugArbSepolia = vm.envAddress("ARBITRUM_FEES_PLUG");
    address feesManagerAddress = vm.envAddress("FEES_MANAGER");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address appGatewayAddress = vm.envAddress("APP_GATEWAY");

    // ----- SCRIPT VARIABLES -----
    uint32 arbSepChainId = 421614;
    uint32 opSepChainId = 11155420;
    uint32[2] chainIds = [opSepChainId, arbSepChainId];

    uint256 fees = 30 ether;
    uint256 deployFees = 10 ether;
    FeesManager feesManager = FeesManager(payable(feesManagerAddress));
    FeesPlug feesPlug = FeesPlug(payable(feesPlugArbSepolia));

    function checkDepositedFees() internal returns (uint256 availableFees) {
        vm.createSelectFork(rpcEVMx);

        availableFees = feesManager.getAvailableCredits(appGatewayAddress);
        console.log("App Gateway:", appGatewayAddress);
        console.log("Available fees:", availableFees);
    }

    function _withdrawAppFees(uint32 chainId) internal {
        uint256 availableFees = checkDepositedFees();

        if (availableFees > 0) {
            // Switch to Arbitrum Sepolia to get gas price
            vm.createSelectFork(rpcArbSepolia);

            // Gas price from Arbitrum
            uint256 arbitrumGasPrice = block.basefee + 0.1 gwei; // With buffer
            uint256 gasLimit = 3_000_000; // Estimate
            uint256 estimatedGasCost = gasLimit * arbitrumGasPrice;

            console.log("Arbitrum gas price (wei):", arbitrumGasPrice);
            console.log("Gas limit:", gasLimit);
            console.log("Estimated gas cost:", estimatedGasCost);

            // Calculate amount to withdraw
            uint256 amountToWithdraw = availableFees > estimatedGasCost ? availableFees - estimatedGasCost : 0;

            if (amountToWithdraw > 0) {
                // Switch back to EVMX to perform withdrawal
                vm.createSelectFork(rpcEVMx);
                vm.startBroadcast(privateKey);
                address sender = vm.addr(privateKey);
                console.log("Withdrawing amount:", amountToWithdraw);
                IAppGateway(appGateway()).withdrawFeeTokens(chainId, ETH_ADDRESS, amountToWithdraw, sender);
                vm.stopBroadcast();

                // Switch back to Arbitrum Sepolia to check final balance
                vm.createSelectFork(rpcArbSepolia);
                console.log("Final sender balance:", sender.balance);
            } else {
                console.log("Available fees less than estimated gas cost");
            }
        }
    }

    function _deployOnchainContracts() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        for (uint256 i = 0; i < chainIds.length; i++) {
            IAppGateway(appGateway()).deployContracts(chainIds[i]);
        }

        vm.stopBroadcast();
        console.log("Contracts deployed");
    }

    // Deploy new AppGateway on EVMx
    function _deployAppGateway() internal virtual returns (address newAppGateway) {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        newAppGateway = deployAppGatewayContract();

        vm.stopBroadcast();

        console.log("New AppGateway deployed at:", newAppGateway);
        console.log("See AppGateway on EVMx: https://evmx.cloud.blockscout.com/address/%s", newAppGateway);
        console.log("Set APP_GATEWAY environment variable to:", newAppGateway);

        return newAppGateway;
    }

    // Abstract functions to be implemented by child contracts
    function appGateway() internal view virtual returns (address);

    // Function to be overridden by child contracts to deploy specific AppGateway implementation
    function deployAppGatewayContract() internal virtual returns (address);

    // Standard flow
    // Each implementation script will call these functions
    function _run(uint32 chainId) internal {
        uint256 availableFees = checkDepositedFees();

        if (availableFees > 0) {
            executeScriptSpecificLogic();
        } else {
            console.log("NO AVAILABLE FEES - Please deposit fees before running this script");
        }
    }

    // Abstract function to be implemented by child contracts
    function executeScriptSpecificLogic() internal virtual;
}
