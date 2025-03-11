// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {DeploymentAppGateway} from "../../src/deploy/DeploymentAppGateway.sol";
import {
    NoPlugNoInititialize,
    NoPlugInitialize,
    PlugNoInitialize,
    PlugInitialize,
    PlugInitializeTwice,
    PlugNoInitInitialize
} from "../../src/deploy/DeployOnchain.sol";

contract RunEVMxDeployment is SetupScript {
    DeploymentAppGateway deploymentAppGateway;
    address noPlugNoInititializeForwarder;
    address noPlugInitializeForwarder;
    address plugNoInitializeForwarder;
    address plugInitializeForwarder;
    address plugInitializeTwiceForwarder;
    address plugNoInitInitializeForwarder;

    function appGateway() internal view override returns (address) {
        return address(deploymentAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy DeploymentAppGateway
        DeploymentAppGateway newGateway = new DeploymentAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);

        noPlugNoInititializeForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.noPlugNoInititialize(), arbSepChainId);
        console.log("No Plug No Init Forwarder:", noPlugNoInititializeForwarder);

        noPlugInitializeForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.noPlugInitialize(), arbSepChainId);
        console.log("No Plug Init Forwarder:", noPlugInitializeForwarder);

        plugNoInitializeForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.plugNoInitialize(), arbSepChainId);
        console.log("Plug No Init Forwarder:", plugNoInitializeForwarder);

        plugInitializeForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.plugInitialize(), arbSepChainId);
        console.log("Plug Init Forwarder:", plugInitializeForwarder);

        plugInitializeTwiceForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.plugInitializeTwice(), arbSepChainId);
        console.log("Plug Init Init Forwarder:", plugInitializeTwiceForwarder);

        plugNoInitInitializeForwarder =
            deploymentAppGateway.forwarderAddresses(deploymentAppGateway.plugNoInitInitialize(), arbSepChainId);
        console.log("Plug No Init Init Forwarder:", plugNoInitInitializeForwarder);
    }

    function validate() internal {
        NoPlugNoInititialize noPlugNoInititialize = NoPlugNoInititialize(noPlugNoInititializeForwarder);
        NoPlugInitialize noPlugInitialize = NoPlugInitialize(noPlugInitializeForwarder);
        PlugNoInitialize plugNoInitialize = PlugNoInitialize(plugNoInitializeForwarder);
        PlugInitialize plugInitialize = PlugInitialize(plugInitializeForwarder);
        PlugInitializeTwice plugInitializeTwice = PlugInitializeTwice(plugInitializeTwiceForwarder);
        PlugNoInitInitialize plugNoInitInitialize = PlugNoInitInitialize(plugNoInitInitializeForwarder);

        vm.createSelectFork(rpcArbSepolia);
        vm.startBroadcast(privateKey);

        // NoPlugNoInititialize checks
        require(noPlugNoInititialize.variable() == 0, "variable should be 0");
        (bool success,) = noPlugNoInititializeForwarder.call(abi.encodeWithSignature("socket__()"));
        require(!success, "Should revert on socket__()");
        console.log("NoPlugNoInititialize checks passed");

        // NoPlugInitialize checks
        require(noPlugInitialize.variable() == 10, "variable should be 10");
        (success,) = noPlugInitializeForwarder.call(abi.encodeWithSignature("socket__()"));
        require(!success, "Should revert on socket__()");
        console.log("NoPlugInitialize checks passed");

        // PlugNoInitialize checks
        require(plugNoInitialize.variable() == 0, "variable should be 0");
        require(address(plugNoInitialize.socket__()) != address(0), "Should return socket address");
        console.log("PlugNoInitialize checks passed");

        // PlugInitialize checks
        require(plugInitialize.variable() == 10, "variable should be 10");
        require(address(plugInitialize.socket__()) != address(0), "Should return socket address");
        console.log("PlugInitialize checks passed");

        // PlugInitializeTwice checks
        require(address(plugInitializeTwice.socket__()) != address(0), "Should return socket address");
        require(plugInitializeTwice.variable() == 20, "variable should be 20");
        console.log("PlugInitializeTwice checks passed");

        // PlugNoInitInitialize checks
        require(plugNoInitInitialize.variable() == 10, "variable should be 10");
        require(address(plugNoInitInitialize.socket__()) != address(0), "Should return socket address");
        console.log("PlugNoInitInitialize checks passed");

        vm.stopBroadcast();
    }

    // Initialize contract references
    function init() internal {
        deploymentAppGateway = DeploymentAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        validate();
    }

    function run() external pure {
        console.log(
            "Please call one of these external functions: deployAppGateway(), deployOnchainContracts(), or runTests()"
        );
    }

    function deployAppGateway() external {
        _deployAppGateway();
    }

    function withdrawAppFees() external {
        init();
        _withdrawAppFees(arbSepChainId);
    }

    function deployOnchainContracts() external {
        init();
        _deployOnchainContracts();
    }

    function runTests() external {
        _run(arbSepChainId);
        _run(opSepChainId);
    }
}
