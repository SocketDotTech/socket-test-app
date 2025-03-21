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

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy ReadAppGateway
        ReadAppGateway newGateway = new ReadAppGateway(addressResolver, deployFees);
        return address(newGateway);
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
        checkResults();

        // 2. Trigger Alternating Read between chains
        console.log("triggerAltRead...");
        readAppGateway.triggerAltRead(opSepForwarder, arbSepForwarder);
        checkResults();
        vm.stopBroadcast();
        console.log("All triggers executed successfully");
    }

    function checkResults() internal view {
        console.log("\n----- RESULTS -----");
        // TODO: monitor events as Foundry reads are not reliable

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

    // Initialize contract references
    function init() internal {
        readAppGateway = ReadAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        runAllTriggers();
    }

    function run() external pure {
        console.log(
            "Please call one of these external functions: deployAppGateway(), deployOnchainContracts(), or runTriggers()"
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

    function runTriggers() external {
        _run(arbSepChainId);
    }
}
