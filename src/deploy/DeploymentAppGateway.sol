// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "./DeployOnchain.sol";
import "./IDeployOnchain.sol";

/**
 * @title DeploymentAppGateway
 * @dev Gateway contract for deploying and testing various contract deployment scenarios
 * Tests different combinations of plug/non-plug contracts with and without initialization
 * Inherits from AppGatewayBase for SOCKET Protocol integration
 */
contract DeploymentAppGateway is AppGatewayBase {
    /**
     * @notice Contract ID for a non-plug contract without initialization
     */
    bytes32 public noPlugNoInititialize = _createContractId("noPlugNoInititialize");

    /**
     * @notice Contract ID for a non-plug contract with initialization
     */
    bytes32 public noPlugInitialize = _createContractId("noPlugInitialize");

    /**
     * @notice Contract ID for a plug contract without initialization
     */
    bytes32 public plugNoInitialize = _createContractId("plugNoInitialize");

    /**
     * @notice Contract ID for a plug contract with initialization
     */
    bytes32 public plugInitialize = _createContractId("plugInitialize");

    /**
     * @notice Contract ID for a plug contract with initialization called twice
     */
    bytes32 public plugInitializeTwice = _createContractId("plugInitializeTwice");

    /**
     * @notice Contract ID for a plug contract with initialization called separately
     */
    bytes32 public plugNoInitInitialize = _createContractId("plugNoInitInitialize");

    /**
     * @notice Constructs the DeploymentAppGateway contract
     * @dev Sets up the creation code for all test contracts and configures fee overrides
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[noPlugNoInititialize] = abi.encodePacked(type(NoPlugNoInititialize).creationCode);
        creationCodeWithArgs[noPlugInitialize] = abi.encodePacked(type(NoPlugInitialize).creationCode);
        creationCodeWithArgs[plugNoInitialize] = abi.encodePacked(type(PlugNoInitialize).creationCode);
        creationCodeWithArgs[plugInitialize] = abi.encodePacked(type(PlugInitialize).creationCode);
        creationCodeWithArgs[plugInitializeTwice] = abi.encodePacked(type(PlugInitializeTwice).creationCode);
        creationCodeWithArgs[plugNoInitInitialize] = abi.encodePacked(type(PlugNoInitInitialize).creationCode);
        _setMaxFees(fees_);
    }

    /**
     * @notice Deploys all test contracts to a specified chain
     * @dev Triggers asynchronous multi-chain deployments with different initialization scenarios
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async(bytes("")) {
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

    /**
     * @notice Initializes contracts that require post-deployment initialization
     * @dev Calls initialize functions on specific contracts after deployment
     * @param chainSlug_ The identifier of the chain where contracts were deployed
     */
    function initializeOnChain(uint32 chainSlug_) public override async(bytes("")) {
        PlugInitializeTwice(forwarderAddresses[plugInitializeTwice][chainSlug_]).initialise(10);
        PlugNoInitInitialize(forwarderAddresses[plugNoInitInitialize][chainSlug_]).initialise(10);
    }

    /**
     * @notice Validates the state of all deployed contracts
     * @dev Performs checks on each contract type to ensure proper initialization and functionality
     * @param chainSlug_ The identifier of the chain where contracts were deployed
     */
    function contractValidation(uint32 chainSlug_) external async(bytes("")) {
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

    /**
     * @notice Validates the variable value of a deployed contract
     * @dev Callback function for promise resolution that checks if the variable matches expected value
     * @param data The encoded expected variable value
     * @param returnData The encoded actual variable value returned from the contract
     */
    function validateVariable(bytes memory data, bytes memory returnData) external onlyPromises {
        uint256 onchainVariable = abi.decode(returnData, (uint256));
        uint256 expectedVariable = abi.decode(data, (uint256));
        require(onchainVariable == expectedVariable, "unexpected variable value");
    }

    /**
     * @notice Validates the socket address of a deployed contract
     * @dev Callback function for promise resolution that checks if the contract has a valid socket address
     * @param data The encoded address (expected to be 0)
     * @param returnData The encoded socket address returned from the contract
     */
    function validateSocket(bytes memory data, bytes memory returnData) external onlyPromises {
        address onchainSocket = abi.decode(returnData, (address));
        address notSocket = abi.decode(data, (address));
        require(onchainSocket != notSocket, "Should return socket address");
    }

    /**
     * @notice Withdraws fee tokens from the SOCKET Protocol
     * @dev Allows withdrawal of accumulated fees to a specified receiver
     * @param chainSlug_ The chain from which to withdraw fees
     * @param token_ The token address to withdraw
     * @param amount_ The amount to withdraw
     * @param receiver_ The address that will receive the withdrawn fees
     */
    function withdrawCredits(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawCredits(chainSlug_, token_, amount_, maxFees, receiver_);
    }
}
