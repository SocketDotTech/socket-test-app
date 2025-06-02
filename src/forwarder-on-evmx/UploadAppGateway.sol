// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "socket-protocol/contracts/evmx/interfaces/IPromise.sol";
import "./ICounter.sol";

/**
 * @title UploadAppGateway
 * @dev Gateway contract for uploading and interacting with existing contracts across chains
 * Unlike other example application gateways, this contract connects to pre-existing contracts
 * Inherits from AppGatewayBase for SOCKET Protocol integration
 */
contract UploadAppGateway is AppGatewayBase {
    /**
     * @notice Address of the forwarder contract for the Counter
     * @dev Used to interact with the Counter contract across chains
     */
    address public counterForwarder;

    /**
     * @notice Event emitted when a value is read from an onchain contract
     * @param forwarder The address of the forwarder contract
     * @param value The value read from the onchain contract
     */
    event ReadOnchain(address forwarder, uint256 value);

    /**
     * @notice Constructs the UploadAppGateway contract
     * @dev Sets up fee overrides for the gateway
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) {
        _initializeAppGateway(addressResolver_);
        _setMaxFees(fees_);
    }

    /**
     * @notice Empty deployment function as this gateway uses existing contracts
     * @dev Required by AppGatewayBase but not used in this implementation
     * @param chainSlug_ The identifier of the target chain (unused)
     */
    function deployContracts(uint32 chainSlug_) external async {}

    /**
     * @notice Empty initialization function as no post-deployment setup is needed
     * @dev Required by AppGatewayBase but not used in this implementation
     * @param chainSlug_ The identifier of the chain (unused)
     */
    function initializeOnChain(uint32 chainSlug_) public override {}

    /**
     * @notice Uploads an existing onchain contract to EVMx
     * @dev Creates a forwarder contract that points to an existing onchain contract
     * @param onchainContract The address of the existing contract on the source chain
     * @param chainSlug_ The identifier of the chain where the contract exists
     */
    function uploadToEVMx(address onchainContract, uint32 chainSlug_) public {
        counterForwarder = asyncDeployer__().getOrDeployForwarderContract(onchainContract, chainSlug_);
    }

    /**
     * @notice Reads the counter value from the onchain contract
     * @dev Initiates an asynchronous read operation with parallel execution enabled
     * Sets up a promise to handle the read result via the handleRead function
     */
    function read() public async {
        _setOverrides(Read.ON, Parallel.ON);
        // TODO: Remove Parallel.ON after new contract deployment to devnet
        ICounter(counterForwarder).counter();
        IPromise(counterForwarder).then(this.handleRead.selector, abi.encode(counterForwarder));
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    /**
     * @notice Handles the result of a read operation from the onchain contract
     * @dev Callback function for promise resolution that emits a ReadOnchain event
     * Can only be called by the promises system
     * @param data The encoded forwarder address
     * @param returnData The encoded counter value read from the onchain contract
     */
    function handleRead(bytes memory data, bytes memory returnData) public onlyPromises {
        address instance = abi.decode(data, (address));
        uint256 value_ = abi.decode(returnData, (uint256));

        emit ReadOnchain(instance, value_);
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
