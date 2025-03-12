// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {ScheduleAppGateway} from "../../src/schedule/ScheduleAppGateway.sol";

contract RunEVMxSchedule is SetupScript {
    ScheduleAppGateway scheduleAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(scheduleAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy ScheduleAppGateway
        ScheduleAppGateway newGateway = new ScheduleAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    // Initialize contract references
    function init() internal {
        scheduleAppGateway = ScheduleAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        scheduleAppGateway.triggerTimeouts();
    }

    function run() external pure {
        console.log("Please call one of these external functions: deployAppGateway() or runTimers()");
    }

    function deployAppGateway() external {
        _deployAppGateway();
    }

    function withdrawAppFees() external {
        init();
        _withdrawAppFees(arbSepChainId);
    }

    function runTimers() external {
        _run(arbSepChainId);
    }
}
