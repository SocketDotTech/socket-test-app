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

    function appGateway() internal view override returns (address) {
        return address(inboxAppGateway);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = inboxAppGateway.forwarderAddresses(inboxAppGateway.inbox(), opSepChainId);
        arbSepForwarder = inboxAppGateway.forwarderAddresses(inboxAppGateway.inbox(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function inboxTransactions() internal {
        address opSepInboxAddress = inboxAppGateway.getOnChainAddress(inboxAppGateway.inbox(), opSepChainId);
        address arbSepInboxAddress = inboxAppGateway.getOnChainAddress(inboxAppGateway.inbox(), arbSepChainId);

        vm.createSelectFork(rpcArbSepolia);
        vm.startBroadcast(privateKey);

        IInbox(arbSepInboxAddress).increaseOnGateway(5);

        vm.stopBroadcast();
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        // TODO: Wait for event? or wait until read is 5 not sure how to handle this on foundry script
        console.log(inboxAppGateway.valueOnGateway());
        inboxAppGateway.updateOnchain(opSepChainId);

        vm.stopBroadcast();
        vm.createSelectFork(rpcOPSepolia);
        vm.startBroadcast(privateKey);

        // TODO: Wait for event? or wait until read is 5 not sure how to handle this on foundry script
        console.log(IInbox(opSepInboxAddress).value());
        IInbox(opSepInboxAddress).propagateToAnother(arbSepChainId);
        // TODO: Wait for event? or wait until read is 5 not sure how to handle this on foundry script
        console.log(IInbox(arbSepInboxAddress).value());

        vm.stopBroadcast();
        console.log("All inbox transactions executed successfully");
    }

    // Initialize contract references
    function init() internal {
        inboxAppGateway = InboxAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        init();
        getForwarderAddresses();
        inboxTransactions();
    }

    function run() external {
        _run(arbSepChainId);
    }

    function deployOnchainContracts() external {
        init();
        _deployOnchainContracts();
    }
}
