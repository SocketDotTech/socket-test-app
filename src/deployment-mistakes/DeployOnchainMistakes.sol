// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

// for tests, variable should be 0
// should revert on getting socket address
contract NoPlugNoInititialize {
    uint256 public variable;
}

// for tests, variable should be 10
// should revert on getting socket address
contract NoPlugInitialize {
    uint256 public variable;

    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

// for tests, variable should be 0
// should return socket address
contract PlugNoInitialize is PlugBase {
    uint256 public variable;
}

// for tests, variable should be 10
// should return socket address
contract PlugInitialize is PlugBase {
    uint256 public variable;

    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

// for tests, counter should be 20 (init called twice: initialize on _deploy and then on initialize from AppGateway)
// should return socket address
contract PlugInitializeTwice is PlugBase {
    uint256 public variable;

    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}

// for tests, variable should be 10 (init data not passed)
// should return socket address
contract PlugNoInitInitialize is PlugBase {
    uint256 public variable;

    function initialise(uint256 variable_) external {
        variable += variable_;
    }
}
