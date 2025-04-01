// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title ICounter
 * @dev Interface for the Counter contract, defining its public functions
 * Used by the CounterAppGateway to interact with Counter instances
 */
interface ICounter {
    /**
     * @notice Returns the current counter value
     * @dev This function is view-only and does not modify state
     */
    function counter() external;

    /**
     * @notice Increases the counter value by 1
     * @dev Can only be called by authorized accounts via the SOCKET Protocol
     */
    function increment() external;

    /**
     * @notice This function is not part of the public interface and is intended solely for testing onchain reverts.
     * @dev Used internally to simulate and verify revert behavior during testing. Not meant for external use.
     */
    function unexistentFunction() external;
}
