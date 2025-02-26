// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DepositFees} from "socket-protocol/script/PayFeesInArbitrumETH.s.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {FeesPlug} from "socket-protocol/contracts/protocol/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";
import {FeesManager} from "socket-protocol/contracts/protocol/payload-delivery/app-gateway/FeesManager.sol";

import {RobustnessDeployer} from "../../src/robustness/RobustnessDeployer.sol";
import {RobustnessAppGateway} from "../../src/robustness/RobustnessAppGateway.sol";

contract RunEVMxRobustness is Script {
    // ----- ENVIRONMENT VARIABLES -----
    string rpcEVMx = vm.envString("EVMX_RPC");
    string rpcArbSepolia = vm.envString("ARBITRUM_SEPOLIA_RPC");
    address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
    address auctionManager = vm.envAddress("AUCTION_MANAGER");
    address feesPlugArbSepolia = vm.envAddress("ARBITRUM_FEES_PLUG");
    address feesManagerAddress = vm.envAddress("FEES_MANAGER");
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployerAddress = vm.envAddress("DEPLOYER");
    address appGatewayAddress = vm.envAddress("APP_GATEWAY");

    // ----- SCRIPT VARIABLES -----
    uint32 arbSepChainId = 411614;
    uint32 opSepChainId = 11155420;

    Fees fees = Fees({feePoolChain: arbSepChainId, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});
    FeesManager feesManager = FeesManager(payable(feesManagerAddress));
    FeesPlug feesPlug = FeesPlug(payable(feesPlugArbSepolia));

    RobustnessDeployer deployer = RobustnessDeployer(deployerAddress);
    RobustnessAppGateway appGateway = RobustnessAppGateway(appGatewayAddress);
    address opSepForwarder;
    address arbSepForwarder;

    function checkDepositedFees(uint32 chainId) internal returns (uint256 availableFees) {
        vm.createSelectFork(rpcEVMx);

        (uint256 deposited, uint256 blocked) =
            feesManager.appGatewayFeeBalances(appGatewayAddress, chainId, ETH_ADDRESS);
        console.log("App Gateway:", appGatewayAddress);
        console.log("Deposited fees:", deposited);
        console.log("Blocked fees:", blocked);

        availableFees = feesManager.getAvailableFees(chainId, appGatewayAddress, ETH_ADDRESS);
        console.log("Available fees:", availableFees);
    }

    function withdrawAppFees(uint32 chainId) internal {
        // EVMX Check available fees
        vm.createSelectFork(rpcEVMx);

        uint256 availableFees = feesManager.getAvailableFees(chainId, appGatewayAddress, ETH_ADDRESS);
        console.log("Available fees:", availableFees);

        if (availableFees > 0) {
            // Switch to Arbitrum Sepolia to get gas price
            vm.createSelectFork(rpcArbSepolia);

            // Gas price from Arbitrum
            uint256 arbitrumGasPrice = block.basefee + 0.1 gwei; // With buffer
            uint256 gasLimit = 5_000_000; // Estimate
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
                appGateway.withdrawFeeTokens(chainId, ETH_ADDRESS, amountToWithdraw, sender);
                vm.stopBroadcast();

                // Switch back to Arbitrum Sepolia to check final balance
                vm.createSelectFork(rpcArbSepolia);
                console.log("Final sender balance:", sender.balance);
            } else {
                console.log("Available fees less than estimated gas cost");
            }
        }
    }

    function deployOnchainContracts() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);
        deployer.deployContracts(opSepChainId);
        deployer.deployContracts(arbSepChainId);
        vm.stopBroadcast();

        console.log("Contracts deployed");
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = deployer.forwarderAddresses(deployer.multichain(), opSepChainId);
        arbSepForwarder = deployer.forwarderAddresses(deployer.multichain(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function runAllTriggers() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        console.log("Running all trigger functions...");

        // 1. Trigger Sequential Write
        console.log("triggerSequentialWrite...");
        appGateway.triggerSequentialWrite(opSepForwarder);

        // 2. Trigger Parallel Write
        console.log("triggerParallelWrite...");
        appGateway.triggerParallelWrite(arbSepForwarder);

        // 3. Trigger Alternating Write between chains
        console.log("triggerAltWrite...");
        appGateway.triggerAltWrite(opSepForwarder, arbSepForwarder);

        // 4. Trigger Parallel Read
        console.log("triggerParallelRead...");
        appGateway.triggerParallelRead(opSepForwarder);

        // 5. Trigger Alternating Read between chains
        console.log("triggerAltRead...");
        appGateway.triggerAltRead(opSepForwarder, arbSepForwarder);

        // 6. Trigger Read and Write
        console.log("triggerReadAndWrite...");
        appGateway.triggerReadAndWrite(arbSepForwarder);

        // 7. Trigger Timeouts
        console.log("triggerTimeouts...");
        appGateway.triggerTimeouts();

        vm.stopBroadcast();
        console.log("All triggers executed successfully");
    }

    function checkResults() internal {
        vm.createSelectFork(rpcEVMx);

        console.log("\n----- RESULTS -----");

        // Check values array
        console.log("Values array:");
        for (uint256 i = 0; i < 10; i++) {
            try appGateway.values(i) returns (uint256 value) {
                console.log("values[%s]: %s", i, value);
            } catch {
                console.log("values[%s]: not set", i);
                break;
            }
        }

        // Check resolve times for timeouts
        console.log("\nTimeout resolve times:");
        for (uint256 i = 0; i < 10; i++) {
            uint256 resolveTime = appGateway.resolveTimes(i);
            uint256 duration = appGateway.timeoutDurations(i);
            if (resolveTime > 0) {
                console.log("Timeout %s (duration %s): resolved at timestamp %s", i, duration, resolveTime);
            } else {
                console.log("Timeout %s (duration %s): not yet resolved", i, duration);
            }
        }
    }

    function run() external {
        uint256 availableFees = checkDepositedFees(arbSepChainId);

        if (availableFees > 0) {
            // Set up onchain deployments
            deployOnchainContracts();
            getForwarderAddresses();

            runAllTriggers();
            checkResults(); // TODO: Check if we need to wait before checking the results

            withdrawAppFees(arbSepChainId);
        } else {
            console.log("NO AVAILABLE FEES - Please deposit fees before running this script");
        }
    }
}
