// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "./IOnchainTrigger.sol";
import "./OnchainTrigger.sol";

/**
 * @title OnchainTriggerAppGateway
 * @dev Gateway contract for the OnchainTrigger application that manages multi-chain value transfers
 * and updates through SOCKET Protocol.
 * Inherits from AppGatewayBase for SOCKET Protocol integration.
 */
contract OnchainTriggerAppGateway is AppGatewayBase {
    /**
     * @notice Identifier for the OnchainTrigger contract
     * @dev Used to track OnchainTrigger contract instances across chains
     */
    bytes32 public onchainToEVMx = _createContractId("onchainToEVMx");

    /**
     * @notice The current value stored in the gateway
     * @dev Can be increased by messages from OnchainTrigger contracts
     */
    uint256 public valueOnGateway;

    /**
     * @notice Address of the deployer
     * @dev Used for tracking deployment source
     */
    address deployerAddress;

    /**
     * @notice Message type identifier for increasing value on the gateway
     * @dev Used to differentiate message types in multi-chain communication
     */
    uint32 public constant INCREASE_ON_GATEWAY = 1;

    /**
     * @notice Message type identifier for propagating value to another chain
     * @dev Used to differentiate message types in multi-chain communication
     */
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    /**
     * @notice Constructs the OnchainTriggerAppGateway
     * @dev Sets up the creation code for the OnchainTrigger contract and configures fee overrides
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) {
        creationCodeWithArgs[onchainToEVMx] = abi.encodePacked(type(OnchainTrigger).creationCode);
        _setMaxFees(fees_);
    }

    /**
     * @notice Deploys OnchainTrigger contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async {
        _deploy(onchainToEVMx, chainSlug_, IsPlug.YES);
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev Sets up the validity of the deployed OnchainTrigger contract on the specified chain
     * @param chainSlug_ The identifier of the chain where the contract was deployed
     */
    function initializeOnChain(uint32 chainSlug_) public override {
        _setValidPlug(true, chainSlug_, onchainToEVMx);
    }

    /**
     * @notice Updates an OnchainTrigger contract on a target chain
     * @dev Sends the current valueOnGateway to the OnchainTrigger contract on the specified chain
     * @param targetChain The identifier of the destination chain
     */
    function updateOnchain(uint32 targetChain) public async {
        address onchainToEVMxForwarderAddress = forwarderAddresses[onchainToEVMx][targetChain];
        IOnchainTrigger(onchainToEVMxForwarderAddress).updateFromGateway(valueOnGateway);
    }

    /**
     * @notice Updates AppGateway value from OnchainTrigger contracts
     * @dev Updates AppGateway value from OnchainTrigger contracts
     * The onlyWatcherPrecompile modifier ensures the function can only be called by the watcher
     * @param value Value to update from the onchain contract on AppGateway
     */
    function callFromChain(uint256 value) external async onlyWatcher {
        valueOnGateway += value;
    }

    /**
     * @notice Updates OnchainTrigger contract value from another OnchainTrigger contract
     * @dev Updates OnchainTrigger contract value from another OnchainTrigger contract
     * The onlyWatcherPrecompile modifier ensures the function can only be called by the watcher
     * @param value Value to update on the other OnchainTrigger contract
     * @param targetChain Chain where the value should be updated
     */
    function propagateToChain(uint256 value, uint32 targetChain) external async onlyWatcher {
        address onchainToEVMxForwarderAddress = forwarderAddresses[onchainToEVMx][targetChain];
        IOnchainTrigger(onchainToEVMxForwarderAddress).updateFromGateway(value);
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
