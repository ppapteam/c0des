// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/tokens/WETH.sol";


contract FoundryTest is Test {
    uint256 forkId;
    WETH weth = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    address alice;
    address bob;

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        forkId = vm.createSelectFork(MAINNET_RPC_URL);
        alice = address(1001);
        bob = address(1002);

        vm.label(address(weth), "WETH");
        vm.label(address(alice), "Alice");
        vm.label(address(bob), "Bob");

        deal(address(weth), alice, 1 ether);

        // alice's approves
        vm.startPrank(alice);
        weth.approve(address(bob), weth.balanceOf(alice));
        vm.stopPrank();

    }

    function test() public {
        vm.startPrank(bob);
        weth.transferFrom(alice, bob, 1 ether);
    }
}
