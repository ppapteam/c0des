// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/PPAPToken.sol";

contract Uniswap is Script {
    IUniswapV2Factory factory;
    IUniswapV2Router02 router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ERC20 WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address treasury = address(0x6c5445D0C0B91eBDdDc38d8ec58dE6062E354d2C);
    IUniswapV2Pair pair;
    function run() external {
        uint256 treasuryPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(treasuryPrivateKey);

        PPAPToken token = PPAPToken(0xa26A0190a0E9D37CE5c0abf7EcD1cD70f5d6c564);
        
        factory = IUniswapV2Factory(router.factory());
        token.approve(address(token), token.balanceOf(treasury));
        WETH.approve(address(token), WETH.balanceOf(treasury));
        token.createInitialLiquidityPool(router, address(WETH), WETH.balanceOf(treasury));
        pair = IUniswapV2Pair(factory.getPair(address(WETH), address(token)));
        console.log("Pair: ", address(pair));

        vm.stopBroadcast();
    }
}
