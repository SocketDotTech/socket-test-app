// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {CounterAppGateway} from "../src/CounterAppGateway.sol";
import {CounterDeployer} from "../src/CounterDeployer.sol";
import {FeesData} from "lib/socket-poc/contracts/common/Structs.sol";
import {ETH_ADDRESS} from "lib/socket-poc/contracts/common/Constants.sol";

contract CounterDeploy is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");

        string memory rpc = vm.envString("SOCKET_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Ethereum Sepolia
        FeesData memory feesData = FeesData({
            feePoolChain: 11155111,
            feePoolToken: ETH_ADDRESS,
            maxFees: 0.01 ether
        });

        CounterDeployer deployer = new CounterDeployer(
            addressResolver,
            feesData
        );

        CounterAppGateway gateway = new CounterAppGateway(
            addressResolver,
            address(deployer),
            feesData
        );

        console.log("Contracts deployed:");
        console.log("CounterAppGateway:", address(gateway));
        console.log("Counter Deployer:", address(deployer));
    }
}
