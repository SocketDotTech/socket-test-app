// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/PlugBase.sol";

// for tests, counter should be 0, should revert on getting socket address
contract NoPlugNoInitCounter {
    uint256 public counter;

    function increase() external {
        counter++;
    }
}

// for tests, counter should be 10, should revert on getting socket address
contract NoPlugInitCounter {
    uint256 public counter;

    function increase() external {
        counter++;
    }

    function initialise(uint256 counter_) external {
        counter = counter_;
    }
}

// for tests, counter should be 0, should return socket address
contract PlugNoInitCounter is PlugBase {
    uint256 public counter;

    function increase() external onlySocket {
        counter++;
    }
}

// for tests, counter should be 10, should return socket address
contract PlugInitCounter is PlugBase {
    uint256 public counter;

    function increase() external {
        counter++;
    }

    function initialise(uint256 counter_) external {
        counter = counter_;
    }
}

// for tests, counter should be 20 (init called twice), should return socket address
contract PlugInitInitCounter is PlugBase {
    uint256 public counter;

    function increase() external {
        counter++;
    }

    function initialise(uint256 counter_) external {
        counter = counter_;
    }
}

// for tests, counter should be 10 (init data not passed), should return socket address
contract PlugNoInitInitCounter is PlugBase {
    uint256 public counter;

    function increase() external {
        counter++;
    }

    function initialise(uint256 counter_) external {
        counter = counter_;
    }
}
