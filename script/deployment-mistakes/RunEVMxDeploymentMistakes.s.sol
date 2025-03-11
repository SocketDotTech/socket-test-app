// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {DeploymentMistakesAppGateway} from "../../src/deployment-mistakes/DeploymentMistakesAppGateway.sol";
import {
    NoPlugNoInititialize,
    NoPlugInitialize,
    PlugNoInitialize,
    PlugInitialize,
    PlugInitializeTwice,
    PlugNoInitInitialize
} from "../../src/deployment-mistakes/DeployOnchainMistakes.sol";

contract RunEVMxDeploymentMistakes is SetupScript {
    DeploymentMistakesAppGateway mistakesAppGateway;
    address noPlugNoInititializeForwarder;
    address noPlugInitializeForwarder;
    address plugNoInitializeForwarder;
    address plugInitializeForwarder;
    address plugInitializeTwiceForwarder;
    address plugNoInitInitializeForwarder;

    function appGateway() internal view override returns (address) {
        return address(mistakesAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy DeploymentMistakesAppGateway
        DeploymentMistakesAppGateway newGateway = new DeploymentMistakesAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);

        noPlugNoInititializeForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.noPlugNoInititialize(), arbSepChainId);
        console.log("No Plug No Init Forwarder:", noPlugNoInititializeForwarder);

        noPlugInitializeForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.noPlugInitialize(), arbSepChainId);
        console.log("No Plug Init Forwarder:", noPlugInitializeForwarder);

        plugNoInitializeForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.plugNoInitialize(), arbSepChainId);
        console.log("Plug No Init Forwarder:", plugNoInitializeForwarder);

        plugInitializeForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.plugInitialize(), arbSepChainId);
        console.log("Plug Init Forwarder:", plugInitializeForwarder);

        plugInitializeTwiceForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.plugInitializeTwice(), arbSepChainId);
        console.log("Plug Init Init Forwarder:", plugInitializeTwiceForwarder);

        plugNoInitInitializeForwarder =
            mistakesAppGateway.forwarderAddresses(mistakesAppGateway.plugNoInitInitialize(), arbSepChainId);
        console.log("Plug No Init Init Forwarder:", plugNoInitInitializeForwarder);
    }

    function validateMistakes() internal {
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
        mistakesAppGateway = DeploymentMistakesAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        validateMistakes();
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
    }
}
