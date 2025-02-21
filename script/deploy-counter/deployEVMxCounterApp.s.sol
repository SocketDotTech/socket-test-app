// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/contracts/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS, FAST} from "socket-protocol/contracts/protocol/utils/common/Constants.sol";
import {FeesPlug} from "socket-protocol/contracts/protocol/payload-delivery/FeesPlug.sol";

import {CounterAppGateway} from "../../src/deploy-counter/CounterAppGateway.sol";
import {CounterDeployer} from "../../src/deploy-counter/CounterDeployer.sol";

contract CounterDeploy is Script {
    function run() external {
        uint256 feesAmount = 0.001 ether;
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address auctionManager = vm.envAddress("AUCTION_MANAGER");
        FeesPlug feesPlug = FeesPlug(
            payable(vm.envAddress("ARBITRUM_FEES_PLUG"))
        );

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Setting fee payment on Arbitrum Sepolia
        Fees memory fees = Fees({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            amount: feesAmount
        });

        CounterDeployer deployer = new CounterDeployer(
            addressResolver,
            auctionManager,
            FAST,
            fees
        );

        CounterAppGateway gateway = new CounterAppGateway(
            addressResolver,
            address(deployer),
            auctionManager,
            fees
        );

        console.log("Contracts deployed:");
        console.log("CounterDeployer:", address(deployer));
        console.log("CounterAppGateway:", address(gateway));

        console.log("CounterDeployer contract ids:");
        console.log("noPlugNoInitCounter");
        console.logBytes32(deployer.noPlugNoInitCounter());
        console.log("noPlugInitCounter");
        console.logBytes32(deployer.noPlugInitCounter());
        console.log("plugNoInitCounter");
        console.logBytes32(deployer.plugNoInitCounter());
        console.log("plugInitCounter");
        console.logBytes32(deployer.plugInitCounter());
        console.log("plugInitInitCounter");
        console.logBytes32(deployer.plugInitInitCounter());
        console.log("plugNoInitInitCounter");
        console.logBytes32(deployer.plugNoInitInitCounter());
    }
}
