contract SetFees is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory arbitrumSepoliaRPC = vm.envString("ARBITRUM_SEPOLIA_RPC");

        vm.startBroadcast(deployerPrivateKey);
        vm.fork(arbitrumSepoliaRPC);

        address payloadDelivery = 0x9433644DEa540F91faC99EC6FAC9d7579f925624; // TODO: ADD correct PayloadDelivery on Socket Composer Testnet

        // Set fees on Arbitrum Sepolia
        FeesData memory feesData = FeesData({
            feePoolChain: 421614,
            feePoolToken: ETH_ADDRESS,
            maxFees: 0.01 ether
        });

        PayloadDelivery(payloadDelivery).deposit(ETH_ADDRESS, 0.01 ether, address(this));
        CounterDeployer(counterDeployer).setFees(feesData);
        CounterAppGateway(counterAppGateway).setFees(feesData);
    }
}
