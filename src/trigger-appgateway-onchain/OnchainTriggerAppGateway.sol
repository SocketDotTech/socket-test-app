// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./OnchainTrigger.sol";
import "./IOnchainTrigger.sol";

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
    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[onchainToEVMx] = abi.encodePacked(type(OnchainTrigger).creationCode);
        _setOverrides(fees_);
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
    function initialize(uint32 chainSlug_) public override {
        address onchainAddress = getOnChainAddress(onchainToEVMx, chainSlug_);
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, onchainAddress, true);
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
     * @notice Handles incoming messages from OnchainTrigger contracts
     * @dev Processes different message types from OnchainTrigger contracts
     * The onlyWatcherPrecompile modifier ensures the function can only be called by the watcher
     *        chainSlug_ The identifier of the source chain (unused)
     *        sourceAddress The address of the sender contract (unused)
     * @param payload_ The encoded message data containing the message type and payload
     *        msgId The transaction identifier (unused)
     */
    function callFromChain(uint32, address, bytes32, bytes calldata payload_)
        external
        override
        async
        onlyWatcherPrecompile
    {
        (uint32 msgType, bytes memory payload) = abi.decode(payload_, (uint32, bytes));
        if (msgType == INCREASE_ON_GATEWAY) {
            uint256 valueOnchain = abi.decode(payload, (uint256));
            valueOnGateway += valueOnchain;
        } else if (msgType == PROPAGATE_TO_ANOTHER) {
            (uint256 valueOnchain, uint32 targetChain) = abi.decode(payload, (uint256, uint32));
            address onchainToEVMxForwarderAddress = forwarderAddresses[onchainToEVMx][targetChain];
            IOnchainTrigger(onchainToEVMxForwarderAddress).updateFromGateway(valueOnchain);
        } else {
            revert("OnchainTriggerGateway: invalid message type");
        }
    }

    /**
     * @notice Updates the fee configuration
     * @dev Allows modification of fee settings for onchain operations
     * @param fees_ New fee configuration
     */
    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    /**
     * @notice Withdraws fee tokens from the SOCKET Protocol
     * @dev Allows withdrawal of accumulated fees to a specified receiver
     * @param chainSlug_ The chain from which to withdraw fees
     * @param token_ The token address to withdraw
     * @param amount_ The amount to withdraw
     * @param receiver_ The address that will receive the withdrawn fees
     */
    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
