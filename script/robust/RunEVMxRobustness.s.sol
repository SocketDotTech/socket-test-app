// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RobDeployer} from "../../src/apps/robust/RobDeployer.sol";
import {RobAppGateway} from "../../src/apps/robust/RobAppGateway.sol";
import {DepositFees} from "socket-protocol/script/PayFeesInArbitrumETH.s.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {FeesPlug} from "socket-protocol/contracts/protocol/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";
import {FeesManager} from "socket-protocol/contracts/protocol/payload-delivery/app-gateway/FeesManager.sol";

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

    function checkDepositedFees(uint32 chainId, address appGateway) internal returns (uint256 availableFees) {
        vm.createSelectFork(rpcEVMx);

        (uint256 deposited, uint256 blocked) = feesManager.appGatewayFeeBalances(appGateway, chainId, ETH_ADDRESS);
        console.log("App Gateway:", appGateway);
        console.log("Deposited fees:", deposited);
        console.log("Blocked fees:", blocked);

        availableFees = feesManager.getAvailableFees(chainId, appGateway, ETH_ADDRESS);
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
                RobAppGateway appGateway = RobAppGateway(appGatewayAddress);
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
        RobDeployer deployer = RobDeployer(deployerAddress);
        deployer.deployContracts(opSepChainId);
        deployer.deployContracts(arbSepChainId);

        console.log("Contracts deployed:");
    }

    function run() external {
        uint256 availableFees = checkDepositedFees(arbSepChainId, appGatewayAddress);
        if (availableFees > 0) {
            deployOnchainContracts();
            withdrawAppFees(arbSepChainId);
        } else {
            console.log("NO AVAILABLE FEES");
        }
    }
}
