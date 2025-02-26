// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";

import {DeploymentMistakesAppGateway} from "../../src/deployment-mistakes/DeploymentMistakesAppGateway.sol";
import {DeploymentMistakesDeployer} from "../../src/deployment-mistakes/DeploymentMistakesDeployer.sol";

contract DeployMistakes is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});

        DeploymentMistakesDeployer deployer =
            new DeploymentMistakesDeployer(addressResolver, auctionManager, FAST, fees);

        DeploymentMistakesAppGateway gateway =
            new DeploymentMistakesAppGateway(addressResolver, address(deployer), auctionManager, fees);

        console.log("Contracts deployed:");
        console.log("DeploymentMistakesDeployer:", address(deployer));
        console.log("DeploymentMistakesAppGateway:", address(gateway));

        console.log("DeploymentMistakesDeployer contract ids:");
        console.log("noPlugNoInititialize");
        console.logBytes32(deployer.noPlugNoInititialize());
        console.log("noPlugInitialize");
        console.logBytes32(deployer.noPlugInitialize());
        console.log("plugNoInitialize");
        console.logBytes32(deployer.plugNoInitialize());
        console.log("plugInitialize");
        console.logBytes32(deployer.plugInitialize());
        console.log("plugInitializeTwice");
        console.logBytes32(deployer.plugInitializeTwice());
        console.log("plugNoInitInitialize");
        console.logBytes32(deployer.plugNoInitInitialize());
    }
}
