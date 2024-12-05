// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {CounterAppGateway} from "../src/CounterAppGateway.sol";
import {CounterDeployer} from "../src/CounterDeployer.sol";
import {Counter} from "../src/Counter.sol";
import {FeesData} from "lib/socket-poc/contracts/common/Structs.sol";
import {ETH_ADDRESS} from "lib/socket-poc/contracts/common/Constants.sol";

contract CounterDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        // Setting fee payment on Arbitrum Sepolia
        // FeesData memory feesData = FeesData({
        //     feePoolChain: 421614,
        //     feePoolToken: ETH_ADDRESS,
        //     maxFees: 0.01 ether
        // });

        CounterDeployer deployer = new CounterDeployer(
            addressResolver
        );

        CounterAppGateway gateway = new CounterAppGateway(
            addressResolver,
            address(deployer)
        );

        console.log("Contracts deployed:");
        console.log("CounterAppGateway:", address(gateway));
        console.log("Counter Deployer:", address(deployer));

        console.log("Deploying contracts on Arbitrum Sepolia...");
        deployer.deployContracts(421614);
        console.log("Deploying contracts on Optimism Sepolia...");
        deployer.deployContracts(11155420);
    }
}
