// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Console.sol";
import {CounterDeployer} from "../src/CounterDeployer.sol";
import {CounterAppGateway} from "../src/CounterAppGateway.sol";

contract IncrementCounters is Script {
    function run() external {
        string memory socketRPC = vm.envString("SOCKET_RPC");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(socketRPC);

        CounterDeployer deployer = CounterDeployer(
            vm.envAddress("COUNTER_DEPLOYER")
        );
        CounterAppGateway gateway = CounterAppGateway(
            vm.envAddress("COUNTER_APP_GATEWAY")
        );

        address counterForwarderArbitrumSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            421614
        );
        address counterForwarderOptimismSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            11155420
        );
        address counterForwarderBaseSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            84532
        );
        address counterForwarderSepolia = deployer.forwarderAddresses(
            deployer.counter(),
            11155111
        );

        address[] memory instances = new address[](4);
        instances[0] = counterForwarderArbitrumSepolia;
        instances[1] = counterForwarderOptimismSepolia;
        instances[2] = counterForwarderBaseSepolia;
        instances[3] = counterForwarderSepolia;

        vm.startBroadcast(deployerPrivateKey);
        gateway.incrementCounters(instances);
    }
}
