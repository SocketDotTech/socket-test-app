// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {
    NoPlugNoInititialize,
    NoPlugInitialize,
    PlugNoInitialize,
    PlugInitialize,
    PlugInitializeTwice,
    PlugNoInitInitialize
} from "../../src/deployment-mistakes/DeployOnchainMistakes.sol";
import {DeploymentMistakesDeployer} from "../../src/deployment-mistakes/DeploymentMistakesDeployer.sol";

contract CheckDeployOnchainMistakes is Script {
    function run() external {
        NoPlugNoInititialize noPlugNoInit = NoPlugNoInititialize(0x1C42CABB4c2FB13fd79905738B34CC1330c9E13e);
        NoPlugInitialize noPlugInit = NoPlugInitialize(0xD3B6b2Da89b3378707bE1b23401C83fB72786A71);
        PlugNoInitialize plugNoInit = PlugNoInitialize(0x201aC62D12811f2C2A22DD78aEc77EA1403fAdfE);
        PlugInitialize plugInit = PlugInitialize(0x7ce0E3182Bbe47580278598E139251677Db8D14a);
        PlugInitializeTwice plugInitInit = PlugInitializeTwice(0xA66352F0eEA89Bb5686132A6477B85c53C542512);
        PlugNoInitInitialize plugNoInitInit = PlugNoInitInitialize(0xF0c397CA708ae2D9d76305926BE564591a3D5C12);

        string memory rpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(rpc);

        vm.startBroadcast();

        // NoPlugNoInititialize checks
        require(noPlugNoInit.variable() == 0, "variable should be 0");
        (bool success,) = address(noPlugNoInit).call(abi.encodeWithSignature("socket__()"));
        require(!success, "Should revert on socket__()");
        console.log("NoPlugNoInititialize checks passed");

        // NoPlugInitialize checks
        require(noPlugInit.variable() == 10, "variable should be 10");
        (success,) = address(noPlugInit).call(abi.encodeWithSignature("socket__()"));
        require(!success, "Should revert on socket__()");
        console.log("NoPlugInitialize checks passed");

        // PlugNoInitialize checks
        require(plugNoInit.variable() == 0, "variable should be 0");
        require(address(plugNoInit.socket__()) != address(0), "Should return socket address");
        console.log("PlugNoInitialize checks passed");

        // PlugInitialize checks
        require(plugInit.variable() == 10, "variable should be 10");
        require(address(plugInit.socket__()) != address(0), "Should return socket address");
        console.log("PlugInitialize checks passed");

        // PlugNoInitInitialize checks
        require(plugNoInitInit.variable() == 10, "variable should be 10");
        require(address(plugNoInitInit.socket__()) != address(0), "Should return socket address");
        console.log("PlugNoInitInitialize checks passed");

        // PlugInitializeTwice checks
        require(address(plugInitInit.socket__()) != address(0), "Should return socket address");
        require(plugInitInit.variable() == 20, "variable should be 20");
        console.log("PlugInitializeTwice checks passed");
    }
}
