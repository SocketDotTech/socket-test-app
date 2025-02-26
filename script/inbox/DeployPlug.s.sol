// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/contracts/protocol/payload-delivery/FeesPlug.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";

import {InboxDeployer} from "../src/inbox/InboxDeployer.sol";

contract DeployPlug is Script {
    function run() external {
        console.log("Creating fork of Arbitrum Sepolia...");
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        console.log("Fork created successfully");

        console.log("Getting private key from env...");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        console.log("Broadcasting transactions from private key");

        console.log("Getting deployer contract address...");
        InboxDeployer deployer = InboxDeployer(vm.envAddress("APP_DEPLOYER"));
        console.log("Deployer contract:", address(deployer));

        console.log("Deploying contracts to Optimism Sepolia (11155420)...");
        deployer.deployContracts(11155420);
        console.log("Deployment to Optimism Sepolia complete");

        console.log("Deploying contracts to Arbitrum Sepolia (421614)...");
        deployer.deployContracts(421614);
        console.log("Deployment to Arbitrum Sepolia complete");

        address sender = vm.addr(privateKey);
        console.log("Sender address:", sender);
        uint256 balance = sender.balance;
        console.log("Sender balance in wei:", balance);
        console.log("Sender balance in ETH:", balance / 1e18);
    }
}
