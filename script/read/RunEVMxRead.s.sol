// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {ReadAppGateway} from "../../src/read/ReadAppGateway.sol";

contract RunEVMxRead is SetupScript {
    ReadAppGateway readAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(readAppGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = readAppGateway.forwarderAddresses(readAppGateway.multichain(), opSepChainId);
        arbSepForwarder = readAppGateway.forwarderAddresses(readAppGateway.multichain(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function runAllTriggers() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        console.log("Running all trigger functions...");

        // 1. Trigger Parallel Read
        console.log("triggerParallelRead...");
        readAppGateway.triggerParallelRead(opSepForwarder);

        // 2. Trigger Alternating Read between chains
        console.log("triggerAltRead...");
        readAppGateway.triggerAltRead(opSepForwarder, arbSepForwarder);

        vm.stopBroadcast();
        console.log("All triggers executed successfully");
    }

    function checkResults() internal {
        vm.createSelectFork(rpcEVMx);

        console.log("\n----- RESULTS -----");

        // Check values array
        console.log("Values array:");
        for (uint256 i = 0; i < 10; i++) {
            try readAppGateway.values(i) returns (uint256 value) {
                console.log("values[%s]: %s", i, value);
            } catch {
                console.log("values[%s]: not set", i);
                break;
            }
        }
    }

    function executeScriptSpecificLogic() internal override {
        // Initialize contract references
        readAppGateway = ReadAppGateway(appGatewayAddress);

        // Deploy to both test chains
        uint32[] memory chainIds = new uint32[](2);
        chainIds[0] = opSepChainId;
        chainIds[1] = arbSepChainId;
        deployOnchainContracts(chainIds);

        getForwarderAddresses();
        runAllTriggers();
        checkResults();
    }

    function run() external {
        _run(arbSepChainId);
    }
}
