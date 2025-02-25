// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RobAppGateway} from "../../src/apps/robust/RobAppGateway.sol";

contract ParallelWrite is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RobAppGateway gateway = RobAppGateway(vm.envAddress("APP_GATEWAY"));
        gateway.triggerParallelWrite(0x3B67A1Db62895a915ce42CAB6d496D4D492715C3);
    }
}
