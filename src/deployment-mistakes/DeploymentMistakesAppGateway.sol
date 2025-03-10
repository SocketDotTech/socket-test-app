// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./DeployOnchainMistakes.sol";

contract DeploymentMistakesAppGateway is AppGatewayBase {
    bytes32 public noPlugNoInititialize = _createContractId("noPlugNoInititialize");
    bytes32 public noPlugInitialize = _createContractId("noPlugInitialize");
    bytes32 public plugNoInitialize = _createContractId("plugNoInitialize");
    bytes32 public plugInitialize = _createContractId("plugInitialize");
    bytes32 public plugInitializeTwice = _createContractId("plugInitializeTwice");
    bytes32 public plugNoInitInitialize = _createContractId("plugNoInitInitialize");

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[noPlugNoInititialize] = abi.encodePacked(type(NoPlugNoInititialize).creationCode);
        creationCodeWithArgs[noPlugInitialize] = abi.encodePacked(type(NoPlugInitialize).creationCode);
        creationCodeWithArgs[plugNoInitialize] = abi.encodePacked(type(PlugNoInitialize).creationCode);
        creationCodeWithArgs[plugInitialize] = abi.encodePacked(type(PlugInitialize).creationCode);
        creationCodeWithArgs[plugInitializeTwice] = abi.encodePacked(type(PlugInitializeTwice).creationCode);
        creationCodeWithArgs[plugNoInitInitialize] = abi.encodePacked(type(PlugNoInitInitialize).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(noPlugNoInititialize, chainSlug_, IsPlug.NO);
        _deploy(
            noPlugInitialize, chainSlug_, IsPlug.NO, abi.encodeWithSelector(NoPlugInitialize.initialise.selector, 10)
        );
        _deploy(plugNoInitialize, chainSlug_, IsPlug.YES);
        _deploy(plugInitialize, chainSlug_, IsPlug.YES, abi.encodeWithSelector(PlugInitialize.initialise.selector, 10));
        _deploy(
            plugInitializeTwice,
            chainSlug_,
            IsPlug.YES,
            abi.encodeWithSelector(PlugInitializeTwice.initialise.selector, 10)
        );
        _deploy(plugNoInitInitialize, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32 chainSlug_) public override async {
        PlugInitializeTwice(forwarderAddresses[plugInitializeTwice][chainSlug_]).initialise(10);
        PlugNoInitInitialize(forwarderAddresses[plugNoInitInitialize][chainSlug_]).initialise(10);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
