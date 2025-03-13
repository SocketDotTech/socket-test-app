// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {OnchainTriggerAppGateway} from "../../src/onchain-to-evmx/OnchainTriggerAppGateway.sol";
import {IOnchainTrigger} from "../../src/onchain-to-evmx/IOnchainTrigger.sol";

contract RunEVMxOnchainTrigger is SetupScript {
    OnchainTriggerAppGateway onchainToEVMxAppGateway;
    address opSepForwarder;
    address arbSepForwarder;
    address opSepOnchainTriggerAddress;
    address arbSepOnchainTriggerAddress;
    uint8 step;

    function appGateway() internal view override returns (address) {
        return address(onchainToEVMxAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy OnchainTriggerAppGateway
        OnchainTriggerAppGateway newGateway = new OnchainTriggerAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder =
            onchainToEVMxAppGateway.forwarderAddresses(onchainToEVMxAppGateway.onchainToEVMx(), opSepChainId);
        arbSepForwarder =
            onchainToEVMxAppGateway.forwarderAddresses(onchainToEVMxAppGateway.onchainToEVMx(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function onchainToEVMxTransactions() internal {
        // TODO: Emit event on each update to easily track and update
        if (step == 1) {
            vm.createSelectFork(rpcArbSepolia);
            vm.startBroadcast(privateKey);

            IOnchainTrigger(arbSepOnchainTriggerAddress).increaseOnGateway(5);

            vm.stopBroadcast();
            console.log("Increase on AppGateway executed successfully");
        } else if (step == 2) {
            // TODO: Emit event on each update to easily track and update
            vm.createSelectFork(rpcEVMx);
            vm.startBroadcast(privateKey);

            onchainToEVMxAppGateway.updateOnchain(opSepChainId);

            vm.stopBroadcast();
            console.log("Update on Optimism Sepolia from AppGateway executed successfully");
        } else if (step == 3) {
            // TODO: Emit event on each update to easily track and update
            vm.createSelectFork(rpcOPSepolia);
            vm.startBroadcast(privateKey);

            IOnchainTrigger(opSepOnchainTriggerAddress).propagateToAnother(arbSepChainId);

            vm.stopBroadcast();
            console.log("Update on Arbitrum Sepolia from AppGateway executed successfully");
        }
    }

    // Initialize contract references
    function init() internal {
        onchainToEVMxAppGateway = OnchainTriggerAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        opSepOnchainTriggerAddress =
            onchainToEVMxAppGateway.getOnChainAddress(onchainToEVMxAppGateway.onchainToEVMx(), opSepChainId);
        arbSepOnchainTriggerAddress =
            onchainToEVMxAppGateway.getOnChainAddress(onchainToEVMxAppGateway.onchainToEVMx(), arbSepChainId);
        onchainToEVMxTransactions();
    }

    function run() external pure {
        console.log(
            "Please call one of these external functions: deployAppGateway(), deployOnchainContracts(), onchainToEVMx(), eVMxToOnchain(), or onchainToOnchain()"
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

    function onchainToEVMx() external {
        step = 1;
        _run(arbSepChainId);
    }

    function eVMxToOnchain() external {
        step = 2;
        _run(arbSepChainId);
    }

    function onchainToOnchain() external {
        step = 3;
        _run(arbSepChainId);
    }
}
