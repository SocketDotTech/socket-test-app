// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

/**
 * @title NoPlugNoInititialize
 * @dev A basic contract without plug functionality and no initialization function
 * For testing purposes, variable should be 0 and should revert on getting socket address
 */
contract NoPlugNoInititialize {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should remain 0 as there is no initialization mechanism
     */
    uint256 public variable;
}

/**
 * @title NoPlugInitialize
 * @dev A basic contract without plug functionality but with an initialization function
 * For testing purposes, variable should be 10 and should revert on getting socket address
 */
contract NoPlugInitialize {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should be 10 after initialization
     */
    uint256 public variable;

    /**
     * @notice Initializes the contract by setting the variable value
     * @dev Adds the provided value to the current variable value
     * @param variable_ The value to add to the variable
     */
    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

/**
 * @title PlugNoInitialize
 * @dev A contract with plug functionality but no initialization function
 * For testing purposes, variable should be 0 and should return socket address
 * Inherits from PlugBase for SOCKET Protocol integration
 */
contract PlugNoInitialize is PlugBase {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should remain 0 as there is no initialization function
     */
    uint256 public variable;
}

/**
 * @title PlugInitialize
 * @dev A contract with plug functionality and an initialization function
 * For testing purposes, variable should be 10 and should return socket address
 * Inherits from PlugBase for SOCKET Protocol integration
 */
contract PlugInitialize is PlugBase {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should be 10 after initialization
     */
    uint256 public variable;

    /**
     * @notice Initializes the contract by setting the variable value
     * @dev Adds the provided value to the current variable value
     * @param variable_ The value to add to the variable
     */
    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

/**
 * @title PlugInitializeTwice
 * @dev A contract with plug functionality where initialization is called twice
 * For testing purposes, variable should be 20 (init called twice) and should return socket address
 * Inherits from PlugBase for SOCKET Protocol integration
 */
contract PlugInitializeTwice is PlugBase {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should be 20 after initialization is called twice
     */
    uint256 public variable;

    /**
     * @notice Initializes the contract by setting the variable value
     * @dev Adds the provided value to the current variable value
     * @param variable_ The value to add to the variable
     */
    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

/**
 * @title PlugNoInitInitialize
 * @dev A contract with plug functionality where initialization is called after deployment
 * For testing purposes, variable should be 10 and should return socket address
 * Inherits from PlugBase for SOCKET Protocol integration
 */
contract PlugNoInitInitialize is PlugBase {
    /**
     * @notice The test variable used to verify initialization state
     * @dev Should be 10 after initialization
     */
    uint256 public variable;

    /**
     * @notice Initializes the contract by setting the variable value
     * @dev Adds the provided value to the current variable value
     * @param variable_ The value to add to the variable
     */
    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}
