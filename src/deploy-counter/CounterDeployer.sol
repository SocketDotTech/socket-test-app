// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Counters.sol";
import "socket-protocol/contracts/base/AppDeployerBase.sol";

contract CounterDeployer is AppDeployerBase {
    bytes32 public noPlugNoInitCounter =
        _createContractId("noPlugNoInitCounter");
    bytes32 public noPlugInitCounter = _createContractId("noPlugInitCounter");
    bytes32 public plugNoInitCounter = _createContractId("plugNoInitCounter");
    bytes32 public plugInitCounter = _createContractId("plugInitCounter");
    bytes32 public plugInitInitCounter =
        _createContractId("plugInitInitCounter");
    bytes32 public plugNoInitInitCounter =
        _createContractId("plugNoInitInitCounter");

    constructor(
        address addressResolver_,
        address auctionManager_,
        bytes32 sbType_,
        Fees memory fees_
    ) AppDeployerBase(addressResolver_, auctionManager_, sbType_) {
        creationCodeWithArgs[noPlugNoInitCounter] = abi.encodePacked(
            type(NoPlugNoInitCounter).creationCode
        );
        creationCodeWithArgs[noPlugInitCounter] = abi.encodePacked(
            type(NoPlugInitCounter).creationCode
        );
        creationCodeWithArgs[plugNoInitCounter] = abi.encodePacked(
            type(PlugNoInitCounter).creationCode
        );
        creationCodeWithArgs[plugInitCounter] = abi.encodePacked(
            type(PlugInitCounter).creationCode
        );
        creationCodeWithArgs[plugInitInitCounter] = abi.encodePacked(
            type(PlugInitInitCounter).creationCode
        );
        creationCodeWithArgs[plugNoInitInitCounter] = abi.encodePacked(
            type(PlugNoInitInitCounter).creationCode
        );
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(noPlugNoInitCounter, chainSlug_, IsPlug.NO);
        _deploy(
            noPlugInitCounter,
            chainSlug_,
            IsPlug.NO,
            abi.encodeWithSelector(NoPlugInitCounter.initialise.selector, 10)
        );
        _deploy(plugNoInitCounter, chainSlug_, IsPlug.YES);
        _deploy(
            plugInitCounter,
            chainSlug_,
            IsPlug.YES,
            abi.encodeWithSelector(PlugInitCounter.initialise.selector, 10)
        );
        _deploy(
            plugInitInitCounter,
            chainSlug_,
            IsPlug.YES,
            abi.encodeWithSelector(PlugInitInitCounter.initialise.selector, 10)
        );
        _deploy(plugNoInitInitCounter, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32 chainSlug_) public override async {
        PlugInitInitCounter(forwarderAddresses[plugInitInitCounter][chainSlug_])
            .initialise(10);
        PlugNoInitInitCounter(
            forwarderAddresses[plugNoInitInitCounter][chainSlug_]
        ).initialise(10);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }
}
