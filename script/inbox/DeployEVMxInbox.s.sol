// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";

import {InboxAppGateway} from "../../src/inbox/InboxAppGateway.sol";

contract DeployEVMxContracts is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});

        InboxAppGateway appGateway = new InboxAppGateway(addressResolver, fees);

        console.log("Contracts deployed:");
        console.log("AppGateway:", address(appGateway));
        console.log("See AppGateway on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(appGateway));
    }
}
