// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RobustnessDeployer} from "../../src/apps/robust/RobustnessDeployer.sol";
import {RobustnessAppGateway} from "../../src/apps/robust/RobustnessAppGateway.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";

contract DeployEVMxContracts is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});

        RobustnessDeployer deployer = new RobustnessDeployer(addressResolver, auctionManager, FAST, fees);

        RobustnessAppGateway gateway =
            new RobustnessAppGateway(addressResolver, address(deployer), auctionManager, fees);

        console.log("Contracts deployed:");
        console.log("Deployer:", address(deployer));
        console.log("AppGateway:", address(gateway));
    }
}
