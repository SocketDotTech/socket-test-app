// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/contracts/base/AppGatewayBase.sol";
import "./OnchainTrigger.sol";
import "./IOnchainTrigger.sol";

contract OnchainTriggerAppGateway is AppGatewayBase {
    bytes32 public onchainToEVMx = _createContractId("onchainToEVMx");
    uint256 public valueOnGateway;
    address deployerAddress;

    // Message types
    uint32 public constant INCREASE_ON_GATEWAY = 1;
    uint32 public constant PROPAGATE_TO_ANOTHER = 2;

    constructor(address addressResolver_, Fees memory fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[onchainToEVMx] = abi.encodePacked(type(OnchainTrigger).creationCode);
        _setOverrides(fees_);
    }

    function deployContracts(uint32 chainSlug_) external async {
        _deploy(onchainToEVMx, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32 chainSlug_) public override {
        setValidPlug(chainSlug_, onchainToEVMx, true);
    }

    function updateOnchain(uint32 targetChain) public async {
        address onchainToEVMxForwarderAddress = forwarderAddresses[onchainToEVMx][targetChain];
        IOnchainTrigger(onchainToEVMxForwarderAddress).updateFromGateway(valueOnGateway);
    }

    function callFromChain(uint32, address, bytes calldata payload_, bytes32)
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

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    /// @notice Sets the validity of an on-chain contract (plug) to authorize it to send information to a specific AppGateway
    /// @param chainSlug_ The unique identifier of the chain where the contract resides
    /// @param contractId The bytes32 identifier of the contract to be validated
    /// @param isValid Boolean flag indicating whether the contract is authorized (true) or not (false)
    /// @dev This function retrieves the onchain address using the contractId and chainSlug, then calls the watcher precompile to update the plug's validity status
    function setValidPlug(uint32 chainSlug_, bytes32 contractId, bool isValid) public {
        address onchainAddress = getOnChainAddress(contractId, chainSlug_);
        watcherPrecompile__().setIsValidPlug(chainSlug_, onchainAddress, isValid);
    }

    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
