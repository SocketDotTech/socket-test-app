// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RobDep} from "../../src/robust/RobDep.sol";
import {RobAG} from "../../src/robust/RobAG.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";

contract CounterDeploy is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});

        RobAG gateway = RobAG(vm.envAddress("APP_GATEWAY"));
        gateway.triggerParallelWrite(0x3B67A1Db62895a915ce42CAB6d496D4D492715C3);

        console.log("Contracts deployed:");
    }
}
