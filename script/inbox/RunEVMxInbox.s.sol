// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {InboxAppGateway} from "../../src/inbox/InboxAppGateway.sol";
import {IInbox} from "../../src/inbox/IInbox.sol";

contract RunEVMxInbox is SetupScript {
    InboxAppGateway inboxAppGateway;
    address opSepForwarder;
    address arbSepForwarder;
    address opSepInboxAddress;
    address arbSepInboxAddress;
    uint8 step;

    function appGateway() internal view override returns (address) {
        return address(inboxAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy InboxAppGateway
        InboxAppGateway newGateway = new InboxAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = inboxAppGateway.forwarderAddresses(inboxAppGateway.inbox(), opSepChainId);
        arbSepForwarder = inboxAppGateway.forwarderAddresses(inboxAppGateway.inbox(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function inboxTransactions() internal {
        // TODO: Emit event on each update to easily track and update
        if (step == 1) {
            vm.createSelectFork(rpcArbSepolia);
            vm.startBroadcast(privateKey);

            IInbox(arbSepInboxAddress).increaseOnGateway(5);

            vm.stopBroadcast();
        } else if (step == 2) {
            // TODO: Emit event on each update to easily track and update
            vm.createSelectFork(rpcEVMx);
            vm.startBroadcast(privateKey);

            inboxAppGateway.updateOnchain(opSepChainId);

            vm.stopBroadcast();
        } else if (step == 3) {
            // TODO: Emit event on each update to easily track and update
            vm.createSelectFork(rpcOPSepolia);
            vm.startBroadcast(privateKey);

            IInbox(opSepInboxAddress).propagateToAnother(arbSepChainId);

            vm.stopBroadcast();
        }
        console.log("All inbox transactions executed successfully");
    }

    // Initialize contract references
    function init() internal {
        inboxAppGateway = InboxAppGateway(appGatewayAddress);
        opSepInboxAddress = inboxAppGateway.getOnChainAddress(inboxAppGateway.inbox(), opSepChainId);
        arbSepInboxAddress = inboxAppGateway.getOnChainAddress(inboxAppGateway.inbox(), arbSepChainId);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        inboxTransactions();
    }

    function run() external pure {
        console.log(
            "Please call one of these external functions: deployAppGateway(), deployOnchainContracts(), onchainToEVMx(), eVMxToOnchain(), or onchainToOnchain()"
        );
    }

    function deployAppGateway() external {
        address newGateway = _deployAppGateway();
        console.log("AppGateway deployed. Set APP_GATEWAY environment variable to:", newGateway);
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
