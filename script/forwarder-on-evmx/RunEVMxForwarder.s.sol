// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {SetupScript} from "../SetupScript.sol";
import {UploadAppGateway} from "../../src/forwarder-on-evmx/UploadAppGateway.sol";
import {Counter} from "../../src/forwarder-on-evmx/Counter.sol";

contract RunEVMxUpload is SetupScript {
    Counter counter;
    UploadAppGateway uploadAppGateway;
    address onchainCounter;

    function appGateway() internal view override returns (address) {
        return address(uploadAppGateway);
    }

    function deployAppGatewayContract() internal override returns (address) {
        // Deploy UploadAppGateway
        UploadAppGateway newGateway = new UploadAppGateway(addressResolver, deployFees);
        return address(newGateway);
    }

    // Initialize contract references
    function init() internal {
        uploadAppGateway = UploadAppGateway(appGatewayAddress);
    }

    function executeScriptSpecificLogic() internal override {
        vm.createSelectFork(rpcEVMx);
        vm.startBroadcast(privateKey);

        uploadAppGateway.uploadToEVMx(onchainCounter, arbSepChainId);
        console.log("CounterForwarder:", uploadAppGateway.counterForwarder());
        uploadAppGateway.read();

        vm.stopBroadcast();
    }

    function run() external pure {
        console.log(
            "Please call one of these external functions: deployAppGateway(), deployOnchainContract(), updateConnectAndRead(address onchainCounter) or withdrawAppFees()"
        );
    }

    function deployAppGateway() external {
        _deployAppGateway();
    }

    function deployOnchainContract() external {
        vm.createSelectFork(rpcArbSepolia);
        vm.startBroadcast(privateKey);
        counter = new Counter();
        counter.increment();
        counter.increment();
        vm.stopBroadcast();
    }

    function read(address onchainCounter_) external {
        init();
        onchainCounter = onchainCounter_;
        _run(arbSepChainId);
    }

    function withdrawAppFees() external {
        init();
        _withdrawAppFees(arbSepChainId);
    }
}
