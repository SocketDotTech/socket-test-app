// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./DeployOnchain.sol";

interface IDeployOnchain {
    function variable() external;
    function socket__() external;
}

contract DeploymentAppGateway is AppGatewayBase {
    bytes32 public noPlugNoInititialize = _createContractId("noPlugNoInititialize");
    bytes32 public noPlugInitialize = _createContractId("noPlugInitialize");
    bytes32 public plugNoInitialize = _createContractId("plugNoInitialize");
    bytes32 public plugInitialize = _createContractId("plugInitialize");
    bytes32 public plugInitializeTwice = _createContractId("plugInitializeTwice");
    bytes32 public plugNoInitInitialize = _createContractId("plugNoInitInitialize");

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[noPlugNoInititialize] = abi.encodePacked(type(NoPlugNoInititialize).creationCode);
        creationCodeWithArgs[noPlugInitialize] = abi.encodePacked(type(NoPlugInitialize).creationCode);
        creationCodeWithArgs[plugNoInitialize] = abi.encodePacked(type(PlugNoInitialize).creationCode);
        creationCodeWithArgs[plugInitialize] = abi.encodePacked(type(PlugInitialize).creationCode);
        creationCodeWithArgs[plugInitializeTwice] = abi.encodePacked(type(PlugInitializeTwice).creationCode);
        creationCodeWithArgs[plugNoInitInitialize] = abi.encodePacked(type(PlugNoInitInitialize).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(noPlugNoInititialize, chainSlug_, IsPlug.NO);
        _deploy(
            noPlugInitialize, chainSlug_, IsPlug.NO, abi.encodeWithSelector(NoPlugInitialize.initialise.selector, 10)
        );
        _deploy(plugNoInitialize, chainSlug_, IsPlug.YES);
        _deploy(plugInitialize, chainSlug_, IsPlug.YES, abi.encodeWithSelector(PlugInitialize.initialise.selector, 10));
        _deploy(
            plugInitializeTwice,
            chainSlug_,
            IsPlug.YES,
            abi.encodeWithSelector(PlugInitializeTwice.initialise.selector, 10)
        );
        _deploy(plugNoInitInitialize, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32 chainSlug_) public override async {
        PlugInitializeTwice(forwarderAddresses[plugInitializeTwice][chainSlug_]).initialise(10);
        PlugNoInitInitialize(forwarderAddresses[plugNoInitInitialize][chainSlug_]).initialise(10);
    }

    function contractValidation(uint32 chainSlug_) external async {
        address noPlugNoInititializeForwarder = forwarderAddresses[noPlugNoInititialize][chainSlug_];
        address noPlugInitializeForwarder = forwarderAddresses[noPlugInitialize][chainSlug_];
        address plugNoInitializeForwarder = forwarderAddresses[plugNoInitialize][chainSlug_];
        address plugInitializeForwarder = forwarderAddresses[plugInitialize][chainSlug_];
        address plugInitializeTwiceForwarder = forwarderAddresses[plugInitializeTwice][chainSlug_];
        address plugNoInitInitializeForwarder = forwarderAddresses[plugNoInitInitialize][chainSlug_];

        // NoPlugNoInititialize checks
        _setOverrides(Read.ON);
        IDeployOnchain(noPlugNoInititializeForwarder).variable();
        IPromise(noPlugNoInititializeForwarder).then(this.validateVariable.selector, abi.encode(0));

        // NoPlugInitialize checks
        IDeployOnchain(noPlugInitializeForwarder).variable();
        IPromise(noPlugInitializeForwarder).then(this.validateVariable.selector, abi.encode(10));

        // PlugNoInitialize checks
        IDeployOnchain(plugNoInitializeForwarder).variable();
        IPromise(plugNoInitializeForwarder).then(this.validateVariable.selector, abi.encode(0));
        IDeployOnchain(plugNoInitializeForwarder).socket__();
        IPromise(plugNoInitializeForwarder).then(this.validateSocket.selector, abi.encode(0));

        // PlugInitialize checks
        IDeployOnchain(plugInitializeForwarder).variable();
        IPromise(plugInitializeForwarder).then(this.validateVariable.selector, abi.encode(10));
        IDeployOnchain(plugInitializeForwarder).socket__();
        IPromise(plugInitializeForwarder).then(this.validateSocket.selector, abi.encode(0));

        // PlugInitializeTwice checks
        IDeployOnchain(plugInitializeTwiceForwarder).variable();
        IPromise(plugInitializeTwiceForwarder).then(this.validateVariable.selector, abi.encode(20));
        IDeployOnchain(plugInitializeTwiceForwarder).socket__();
        IPromise(plugInitializeTwiceForwarder).then(this.validateSocket.selector, abi.encode(0));

        // PlugNoInitInitialize checks
        _setOverrides(Read.ON);
        IDeployOnchain(plugNoInitInitializeForwarder).variable();
        IPromise(plugNoInitInitializeForwarder).then(this.validateVariable.selector, abi.encode(10));
        IDeployOnchain(plugNoInitInitializeForwarder).socket__();
        IPromise(plugNoInitInitializeForwarder).then(this.validateSocket.selector, abi.encode(0));
        _setOverrides(Read.OFF);
    }

    function validateVariable(bytes memory data, bytes memory returnData) external onlyPromises {
        uint256 onchainVariable = abi.decode(returnData, (uint256));
        uint256 expectedVariable = abi.decode(data, (uint256));
        require(onchainVariable == expectedVariable, "unexpected variable value");
    }

    function validateSocket(bytes memory data, bytes memory returnData) external onlyPromises {
        address onchainSocket = abi.decode(returnData, (address));
        address notSocket = abi.decode(data, (address));
        require(onchainSocket != notSocket, "Should return socket address");
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
