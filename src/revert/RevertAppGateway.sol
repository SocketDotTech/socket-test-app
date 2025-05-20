// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/evmx/base/AppGatewayBase.sol";
import "socket-protocol/contracts/evmx/interfaces/IPromise.sol";
import "./ICounter.sol";
import "./Counter.sol";

contract RevertAppGateway is AppGatewayBase {
    /**
     * @notice Identifier for the Counter contract
     * @dev Used to track Counter contract instances across chains
     */
    bytes32 public counter = _createContractId("counter");

    /**
     * @notice Event to emit on callbacks
     * @param chainSlug The value read from the onchain contract
     * @param value The value read from the onchain contract
     */
    event CallbackEvent(uint32 chainSlug, uint256 value);

    /**
     * @notice Constructs the RevertAppGateway
     * @dev Sets up the creation code for the Counter contract and configures fee overrides
     * @param addressResolver_ Address of the SOCKET Protocol's AddressResolver contract
     * @param fees_ Fee configuration for multi-chain operations
     */
    constructor(address addressResolver_, uint256 fees_) AppGatewayBase(addressResolver_) {
        creationCodeWithArgs[counter] = abi.encodePacked(type(Counter).creationCode);
        _setOverrides(fees_);
    }

    /**
     * @notice Deploys Counter contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async(bytes("")) {
        _deploy(counter, chainSlug_, IsPlug.YES);
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev Sets up the validity of the deployed OnchainTrigger contract on the specified chain
     * @param chainSlug_ The identifier of the chain where the contract was deployed
     */
    function initialize(uint32 chainSlug_) public override async(bytes("")) {
        address instance = forwarderAddresses[counter][chainSlug_];
        ICounter(instance).increment();
    }

    /**
     * @notice Tests onchain revert behavior by calling unexistentFunction on a specific chain instance
     * @dev This is a testing function that triggers a revert by calling unexistentFunction on an ICounter instance
     *      associated with the given chainSlug. Uses the forwarderAddresses mapping to locate the instance.
     *         unexistentFunction exists on the interface but not on the onchain contract. This will cause an onchain revert.
     * @param chainSlug A uint32 identifier for the target chain to test the revert on
     */
    function testOnChainRevert(uint32 chainSlug) public async(bytes("")) {
        address instance = forwarderAddresses[counter][chainSlug];
        ICounter(instance).unexistentFunction();
    }

    /**
     * @notice Tests callback revert behavior by setting up a promise that triggers a revert in its callback
     * @dev This testing function exercises the revert handling of a callback mechanism. It first enables
     *      read and parallel overrides, calls counter, then sets up a promise with a callback to
     *      notCorrectInputArgs that will revert due to wrong input parameters
     * @param chainSlug A uint32 identifier for the target chain to test the callback revert on
     */
    function testCallbackRevertWrongInputArgs(uint32 chainSlug) public async(bytes("")) {
        _setOverrides(Read.ON, Parallel.ON);
        address instance = forwarderAddresses[counter][chainSlug];
        ICounter(instance).counter();
        // wrong function input parameters for a callback
        IPromise(instance).then(this.notCorrectInputArgs.selector, abi.encode(chainSlug));
        _setOverrides(Read.OFF, Parallel.OFF);
    }

    /**
     * @notice A function with incorrect input arguments, used for testing or demonstration
     * @dev This function intentionally uses wrong parameters. The correct arguments should be:
     *      (bytes memory data, bytes memory returnData) instead of the current uint32.
     *      Restricted to onlyPromises modifier, likely limiting access to promise-related calls.
     * @param someWrongParam An incorrect uint32 parameter, should be replaced with proper args
     */
    function notCorrectInputArgs(uint32 someWrongParam) public onlyPromises {
        emit CallbackEvent(someWrongParam, 0);
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
