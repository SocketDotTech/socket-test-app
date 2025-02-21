// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NoPlugNoInitCounter, NoPlugInitCounter, PlugNoInitCounter, PlugInitCounter, PlugInitInitCounter, PlugNoInitInitCounter} from "../../src/deploy-counter/Counters.sol";
import {CounterDeployer} from "../../src/deploy-counter/CounterDeployer.sol";

contract CheckCounters is Script {
    function run() external {
        NoPlugNoInitCounter noPlugNoInit = NoPlugNoInitCounter(
            0x1C42CABB4c2FB13fd79905738B34CC1330c9E13e
        );
        NoPlugInitCounter noPlugInit = NoPlugInitCounter(
            0xD3B6b2Da89b3378707bE1b23401C83fB72786A71
        );
        PlugNoInitCounter plugNoInit = PlugNoInitCounter(
            0x201aC62D12811f2C2A22DD78aEc77EA1403fAdfE
        );
        PlugInitCounter plugInit = PlugInitCounter(
            0x7ce0E3182Bbe47580278598E139251677Db8D14a
        );
        PlugInitInitCounter plugInitInit = PlugInitInitCounter(
            0xA66352F0eEA89Bb5686132A6477B85c53C542512
        );
        PlugNoInitInitCounter plugNoInitInit = PlugNoInitInitCounter(
            0xF0c397CA708ae2D9d76305926BE564591a3D5C12
        );

        string memory rpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(rpc);

        vm.startBroadcast();

        // NoPlugNoInitCounter checks
        require(noPlugNoInit.counter() == 0, "Counter should be 0");
        (bool success, ) = address(noPlugNoInit).call(
            abi.encodeWithSignature("socket__()")
        );
        require(!success, "Should revert on socket__()");
        console.log("NoPlugNoInitCounter checks passed");

        // NoPlugInitCounter checks
        require(noPlugInit.counter() == 10, "Counter should be 10");
        (success, ) = address(noPlugInit).call(
            abi.encodeWithSignature("socket__()")
        );
        require(!success, "Should revert on socket__()");
        console.log("NoPlugInitCounter checks passed");

        // PlugNoInitCounter checks
        require(plugNoInit.counter() == 0, "Counter should be 0");
        require(
            address(plugNoInit.socket__()) != address(0),
            "Should return socket address"
        );
        console.log("PlugNoInitCounter checks passed");

        // PlugInitCounter checks
        require(plugInit.counter() == 10, "Counter should be 10");
        require(
            address(plugInit.socket__()) != address(0),
            "Should return socket address"
        );
        console.log("PlugInitCounter checks passed");

        // PlugNoInitInitCounter checks
        require(plugNoInitInit.counter() == 10, "Counter should be 10");
        require(
            address(plugNoInitInit.socket__()) != address(0),
            "Should return socket address"
        );
        console.log("PlugNoInitInitCounter checks passed");

        // PlugInitInitCounter checks
        require(
            address(plugInitInit.socket__()) != address(0),
            "Should return socket address"
        );
        require(plugInitInit.counter() == 20, "Counter should be 20");
        console.log("PlugInitInitCounter checks passed");
    }
}
