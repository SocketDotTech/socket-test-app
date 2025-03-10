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

        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        IInbox(opSepInboxAddress).increaseOnGateway(5);
        require(inboxAppGateway.valueOnGateway() != 5, "Expected the same value");
        inboxAppGateway.updateOnchain(opSepChainId);
        require(IInbox(opSepInboxAddress).value() != 5, "Expected the same value");
        IInbox(opSepInboxAddress).propagateToAnother(arbSepChainId);
        require(IInbox(arbSepInboxAddress).value() != 5, "Expected the same value");

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
