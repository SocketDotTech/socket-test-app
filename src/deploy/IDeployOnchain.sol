// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title IDeployOnchain
 * @dev Interface for interacting with deployed contracts through the gateway
 * Provides function signatures for validation testing
 */
interface IDeployOnchain {
    /**
     * @notice Gets the variable value from the deployed contract
     * @dev Used for validation testing
     */
    function variable() external;

    /**
     * @notice Gets the socket address from the deployed contract
     * @dev Used for validation testing of plug contracts
     */
    function socket__() external;
}
