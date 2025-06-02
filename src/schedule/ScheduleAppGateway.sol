// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";

/**
 * @title ScheduleAppGateway
 * @dev Gateway contract that demonstrates the scheduling capabilities of the SOCKET Protocol.
 * This contract allows for the creation of timed executions with various delay intervals.
 * Inherits from AppGatewayBase for SOCKET Protocol integration.
 */
contract ScheduleAppGateway is AppGatewayBase {
    /**
     * @notice Array of timeout durations in seconds
     * @dev These values define the delay periods in seconds for scheduled executions
     */
    uint256[] public timeoutsInSeconds = [1, 20, 60, 120, 600, 1200, 5000];

    /**
     * @notice Emitted when a scheduled timeout is resolved
     * @param index The index of the timeout in the timeoutsInSeconds array
     * @param creationTimestamp The timestamp when the timeout was created
     * @param executionTimestamp The timestamp when the timeout was executed
     */
    event TimeoutResolved(uint256 index, uint256 creationTimestamp, uint256 executionTimestamp);

    /**
     * @notice Constructs the ScheduleAppGateway
     * @dev Sets up fee overrides for the contract
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for onchain operations
     */
    constructor(address addressResolver_, uint256 fees_) AppGatewayBase(addressResolver_) {
        _setMaxFees(fees_);
    }

    /**
     * @notice Deploys contracts to a specified chain
     * @dev This function is a placeholder for the ScheduleAppGateway since no contracts need deployment
     *      The chainSlug parameter is required by the interface but not used.
     */
    function deployContracts(uint32) external async(bytes("")) {
        return;
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev No initialization needed for this application, so implementation is empty.
     *      The chainSlug parameter is required by the interface but not used.
     */
    function initializeOnChain(uint32) public pure override {
        return;
    }

    /**
     * @notice Triggers multiple timeouts with different delay periods
     * @dev Sets up scheduled calls to resolveTimeout with various delay periods defined in timeoutsInSeconds
     */
    function triggerTimeouts() public {
        for (uint256 i = 0; i < timeoutsInSeconds.length; i++) {
            bytes memory payload = abi.encodeWithSelector(this.resolveTimeout.selector, i, block.timestamp);
            watcherPrecompile__().setTimeout(timeoutsInSeconds[i], payload);
        }
    }

    /**
     * @notice Callback function executed when a timeout is reached
     * @dev Emits a TimeoutResolved event with timing information
     * @param index_ The index of the timeout in the timeoutsInSeconds array
     * @param creationTimestamp_ The timestamp when the timeout was created
     */
    function resolveTimeout(uint256 index_, uint256 creationTimestamp_) public {
        emit TimeoutResolved(index_, creationTimestamp_, block.timestamp);
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
