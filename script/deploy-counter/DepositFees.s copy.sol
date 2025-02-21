// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";
import {FeesPlug} from "socket-protocol/contracts/protocol/payload-delivery/FeesPlug.sol";

contract DepositFees is Script {
    function run() external {
        uint256 feesAmount = 0.001 ether;
        address appGateway = vm.envAddress("APP_GATEWAY");
        FeesPlug feesPlug = FeesPlug(
            payable(vm.envAddress("ARBITRUM_FEES_PLUG"))
        );

        string memory rpc = vm.envString("ARBITRUM_SEPOLIA_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        feesPlug.deposit{value: feesAmount}(
            ETH_ADDRESS,
            appGateway,
            feesAmount
        );

        console.log("Fees deposited:", feesAmount);
    }
}
