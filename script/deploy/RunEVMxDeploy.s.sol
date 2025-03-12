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

    function appGateway() internal view override returns (address) {
        return address(deploymentAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy DeploymentAppGateway
        DeploymentAppGateway newGateway = new DeploymentAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal pure {
        return;
    }

    function validate() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        deploymentAppGateway.contractValidation(arbSepChainId);

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
    }
}
