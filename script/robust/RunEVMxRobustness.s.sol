// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {RobustnessDeployer} from "../../src/robustness/RobustnessDeployer.sol";
import {RobustnessAppGateway} from "../../src/robustness/RobustnessAppGateway.sol";

contract RunEVMxRobustness is SetupScript {
    RobustnessDeployer robustnessDeployer;
    RobustnessAppGateway robustnessAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(robustnessAppGateway);
    }

    function deployer() internal view override returns (address) {
        return address(robustnessDeployer);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = robustnessDeployer.forwarderAddresses(robustnessDeployer.multichain(), opSepChainId);
        arbSepForwarder = robustnessDeployer.forwarderAddresses(robustnessDeployer.multichain(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function runAllTriggers() internal {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        console.log("Running all trigger functions...");

        // 1. Trigger Sequential Write
        console.log("triggerSequentialWrite...");
        robustnessAppGateway.triggerSequentialWrite(opSepForwarder);

        // 2. Trigger Parallel Write
        console.log("triggerParallelWrite...");
        robustnessAppGateway.triggerParallelWrite(arbSepForwarder);

        // 3. Trigger Alternating Write between chains
        console.log("triggerAltWrite...");
        robustnessAppGateway.triggerAltWrite(opSepForwarder, arbSepForwarder);

        // 4. Trigger Parallel Read
        console.log("triggerParallelRead...");
        robustnessAppGateway.triggerParallelRead(opSepForwarder);

        // 5. Trigger Alternating Read between chains
        console.log("triggerAltRead...");
        robustnessAppGateway.triggerAltRead(opSepForwarder, arbSepForwarder);

        // 6. Trigger Read and Write
        console.log("triggerReadAndWrite...");
        robustnessAppGateway.triggerReadAndWrite(arbSepForwarder);

        // 7. Trigger Timeouts
        console.log("triggerTimeouts...");
        robustnessAppGateway.triggerTimeouts();

        vm.stopBroadcast();
        console.log("All triggers executed successfully");
    }

    function checkResults() internal {
        vm.createSelectFork(rpcEVMx);

        console.log("\n----- RESULTS -----");

        // Check values array
        console.log("Values array:");
        for (uint256 i = 0; i < 10; i++) {
            try robustnessAppGateway.values(i) returns (uint256 value) {
                console.log("values[%s]: %s", i, value);
            } catch {
                console.log("values[%s]: not set", i);
                break;
            }
        }

        // Check resolve times for timeouts
        console.log("\nTimeout resolve times:");
        for (uint256 i = 0; i < 10; i++) {
            uint256 resolveTime = robustnessAppGateway.resolveTimes(i);
            uint256 duration = robustnessAppGateway.timeoutDurations(i);
            if (resolveTime > 0) {
                console.log("Timeout %s (duration %s): resolved at timestamp %s", i, duration, resolveTime);
            } else {
                console.log("Timeout %s (duration %s): not yet resolved", i, duration);
            }
        }
    }

    function executeScriptSpecificLogic() internal override {
        // Initialize contract references
        robustnessDeployer = RobustnessDeployer(deployerAddress);
        robustnessAppGateway = RobustnessAppGateway(appGatewayAddress);

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
