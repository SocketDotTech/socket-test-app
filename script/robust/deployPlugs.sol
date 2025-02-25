// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RobDeployer} from "../../src/apps/robust/RobDeployer.sol";

contract DeployOnchainContracts is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RobDeployer deployer = RobDeployer(vm.envAddress("APP_DEPLOYER"));
        deployer.deployContracts(11155420);
        deployer.deployContracts(421614);

        console.log("Contracts deployed:");
    }
}
