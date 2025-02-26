// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {InboxDeployer} from "../../src/inbox/InboxDeployer.sol";
import {InboxAppGateway, IInbox} from "../../src/inbox/InboxAppGateway.sol";

contract RunEVMxInbox is SetupScript {
    InboxDeployer inboxDeployer;
    InboxAppGateway inboxAppGateway;
    address opSepForwarder;
    address arbSepForwarder;

    function appGateway() internal view override returns (address) {
        return address(inboxAppGateway);
    }

    function deployer() internal view override returns (address) {
        return address(inboxDeployer);
    }

    function getForwarderAddresses() internal {
        vm.createSelectFork(rpcEVMx);
        opSepForwarder = inboxDeployer.forwarderAddresses(inboxDeployer.inbox(), opSepChainId);
        arbSepForwarder = inboxDeployer.forwarderAddresses(inboxDeployer.inbox(), arbSepChainId);

        console.log("Optimism Sepolia Forwarder:", opSepForwarder);
        console.log("Arbitrum Sepolia Forwarder:", arbSepForwarder);
    }

    function inboxTransactions() internal {
        address opSepInboxAddress = inboxDeployer.getOnChainAddress(inboxDeployer.inbox(), opSepChainId);
        address arbSepInboxAddress = inboxDeployer.getOnChainAddress(inboxDeployer.inbox(), arbSepChainId);

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

    function executeScriptSpecificLogic() internal override {
        // Initialize contract references
        inboxDeployer = InboxDeployer(deployerAddress);
        inboxAppGateway = InboxAppGateway(appGatewayAddress);

        // Deploy to both test chains
        uint32[] memory chainIds = new uint32[](2);
        chainIds[0] = opSepChainId;
        chainIds[1] = arbSepChainId;
        deployOnchainContracts(chainIds);

        getForwarderAddresses();
        inboxTransactions();
    }

    function run() external {
        _run(arbSepChainId);
    }
}
