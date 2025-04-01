// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {RevertAppGateway} from "../../src/revert/RevertAppGateway.sol";

contract RunEVMxRevert is SetupScript {
    RevertAppGateway revertAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(revertAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy RevertAppGateway
        RevertAppGateway newGateway = new RevertAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = revertAppGateway.forwarderAddresses(revertAppGateway.counter(), opSepChainId);
        arbSepForwarder = revertAppGateway.forwarderAddresses(revertAppGateway.counter(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    // Initialize contract references
    function init() internal {
        revertAppGateway = RevertAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        // TODO: Add calls
    }

    function run() external pure {
        console.log("Please call one of these external functions: deployAppGateway() and deployOnchainContracts()");
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
}
