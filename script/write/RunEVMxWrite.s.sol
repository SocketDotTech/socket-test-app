// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {WriteAppGateway} from "../../src/write/WriteAppGateway.sol";

contract RunEVMxWrite is SetupScript {
    WriteAppGateway writeAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(writeAppGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = writeAppGateway.forwarderAddresses(writeAppGateway.multichain(), opSepChainId);
        arbSepForwarder = writeAppGateway.forwarderAddresses(writeAppGateway.multichain(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function runAllTriggers() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);
        console.log("Running all trigger functions...");

        // 1. Trigger Sequential Write
        console.log("triggerSequentialWrite...");
        writeAppGateway.triggerSequentialWrite(opSepForwarder);

        // 2. Trigger Parallel Write
        console.log("triggerParallelWrite...");
        writeAppGateway.triggerParallelWrite(arbSepForwarder);

        // 3. Trigger Alternating Write between chains
        console.log("triggerAltWrite...");
        writeAppGateway.triggerAltWrite(opSepForwarder, arbSepForwarder);

        vm.stopBroadcast();
        console.log("All triggers executed successfully");
    }

    function checkResults() internal {
        vm.createSelectFork(rpcEVMx);
        console.log("\n----- RESULTS -----");
        // TODO: Add check for Counter value
    }

    // Initialize contract references
    function init() internal {
        writeAppGateway = WriteAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        runAllTriggers();
        checkResults();
    }

    function run() external {
        _run(arbSepChainId);
    }

    function deployOnchainContracts() external {
        init();
        _deployOnchainContracts();
    }
}
