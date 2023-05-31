// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/PPAPTokenV2.sol";
import "../src/interfaces/univ2.sol";


contract PPAPTokenTest is Test {
    PPAPToken public token;

    uint256 forkId;
    uint256 startBlock;

    ERC20 WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    IUniswapV2Factory factory;
    IUniswapV2Router02 router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Pair pair;
    address treasury;
    address owner;
    address alice;
    address bob;
    address[] path = new address[](2);
    address[] reversePath = new address[](2);

    function timeTravel(uint256 secondsToMove, uint256 skipBlocks) public {
        vm.roll(block.number + skipBlocks);
        skip(secondsToMove);
    }

    function timeTravel(uint256 secondsToMove) public {
        timeTravel(secondsToMove, 1);
    }

    function stats(bool showAlice, bool showBob) public {
        if(showAlice) {
            console.log("PPAP Alice", token.balanceOf(alice));
            console.log("WETH Alice", WETH.balanceOf(alice));
        }

        if(showBob) {
            console.log("PPAP Bob", token.balanceOf(bob));
            console.log("WETH Bob", WETH.balanceOf(bob));
        }
        console.log("PPAP Treasury", token.balanceOf(treasury));
        console.log("WETH Treasury", WETH.balanceOf(treasury));

        console.log("PPAP PAIR", token.balanceOf(address(pair)));
        console.log("WETH PAIR", WETH.balanceOf(address(pair)));
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        console.log("1 PPAP : %e WETH", reserve0/reserve1);
    }

    function setUp() public {
        forkId = vm.createSelectFork(MAINNET_RPC_URL);

        startBlock = block.number;

        owner = address(0);
        treasury = address(0x6c5445D0C0B91eBDdDc38d8ec58dE6062E354d2C);
        alice = address(100);
        bob = address(101);

        vm.label(address(WETH), "WETH");
        vm.label(address(factory), "UniswapV2 Factory");
        vm.label(address(router), "UniswapV2 Router");
        vm.label(address(treasury), "Treasury");
        vm.label(address(owner), "Owner");
        vm.label(address(alice), "Alice");
        vm.label(address(bob), "Bob");


        vm.prank(owner);
        token = new PPAPToken();
        vm.label(address(token), "PPAPTokenV2");

        // create liquidity pool
        deal(address(WETH), treasury, 3e18);
        deal(address(WETH), alice, 1000000e18);
        deal(address(WETH), bob, 1000000e18);

        // treasury's approves
        vm.startPrank(treasury);
        factory = IUniswapV2Factory(router.factory());
        token.approve(address(router), token.balanceOf(treasury));
        WETH.approve(address(router), WETH.balanceOf(treasury));
        router.addLiquidity(
            address(WETH),
            address(token),
            3 ether,
            100_000_000_000 ether,
            3 ether,
            100_000_000_000 ether,
            treasury,
            block.timestamp + 10
        );
        pair = IUniswapV2Pair(factory.getPair(address(WETH), address(token)));
        vm.label(address(pair), "PPAP-WETH");

        path[0] = address(WETH);
        path[1] = address(token);
        reversePath[0] = address(token);
        reversePath[1] = address(WETH);
        vm.stopPrank();

        vm.prank(owner);
        token.setUni(address(router), address(pair));


        // alice's approves
        vm.startPrank(alice);
        WETH.approve(address(router), WETH.balanceOf(alice));
        vm.stopPrank();

        // bob's approves
        vm.startPrank(bob);
        WETH.approve(address(router), WETH.balanceOf(bob));
        vm.stopPrank();
    }

    function testDeployment() public {
        assertEq(address(token.pair()), address(pair));
    }

    function buyAndTransfer(uint256 atBlock, uint256 amount) public {
        timeTravel(atBlock * 5, atBlock);
        uint256 buyTaxFee = 0;
        if(atBlock <= 1) {
            buyTaxFee = token.initialBuyBPS();
        } else if (atBlock <= 86400 / 5) {
            buyTaxFee = token.earlyBuyBPS();
        } else {
            buyTaxFee = token.buyBPS();
        }
        uint256 tokenTokenBalance = token.balanceOf(address(token));
        vm.startPrank(alice);
        // alice buy N PPAP with 1000 WETH
        uint256 wethBalance = WETH.balanceOf(alice);
        router.swapExactTokensForTokens(
            amount, // 1000e18 + rand,
            0,
            path,
            alice,
            block.timestamp + 1000
        );
        uint256 aliceTokenBalance = token.balanceOf(alice);
        assertEq(wethBalance - amount, WETH.balanceOf(alice));
        timeTravel(1);

        // alice should have 3/4 PPAPs and treasury should have 1/4 PPAPs
        assertEq((token.balanceOf(alice) + token.feeCollected()) * buyTaxFee / 10000,
                 token.balanceOf(address(token))- tokenTokenBalance);

        // alice may transfer without any fee to any addresses (including contracts)
        // during transfer swap should be triggered
        // after transfer expected:
        // - Alice has - 1 $PPAP
        // - Factory has + 1 $PPAP
        // - Treasury has + n WETH
        // - Token has - n $PPAP
        assertEq(WETH.balanceOf(treasury), 0);
        uint256 feeCollected = token.feeCollected();
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        token.transfer(address(factory), 1e18);
        assertEq(token.balanceOf(alice), aliceTokenBalance - 1e18);
        assertEq(token.balanceOf(address(factory)), 1e18);
        uint256 feeMax = reserve0 * token.feeSwapBps() / 10000;
        if(feeMax < feeCollected) {
            assertEq(token.balanceOf(address(token)), feeCollected - feeMax);
            feeCollected = feeMax;
        } else {
            assertEq(token.balanceOf(address(token)), 0);
        }
        assert(WETH.balanceOf(treasury) > 0);
    }
    
    function buyAndSell(uint256 blocksBefore, uint256 blocksAfter) public {
        timeTravel(blocksBefore * 5, blocksBefore);
        vm.startPrank(alice);
        // alice buy N PPAP with 1000 WETH
        uint256 wethBalance = WETH.balanceOf(alice);
        router.swapExactTokensForTokens(
            1000e18,
            0,
            path,
            alice,
            block.timestamp + 1000
        );
        uint256 buyTaxFee = 0;
        uint256 sellTaxFee = 0;
        if(blocksBefore <= 1) {
            buyTaxFee = token.initialBuyBPS();
        } else if (blocksBefore <= 86400 / 5) {
            buyTaxFee = token.earlyBuyBPS();
        } else {
            buyTaxFee = token.buyBPS();
        }
        if((blocksBefore + blocksAfter) <= 1) {
            sellTaxFee = token.initialSellBPS();
        } else if ((blocksBefore + blocksAfter) <= 86400 / 5) {
            sellTaxFee = token.earlySellBPS();
        } else {
            sellTaxFee = token.sellBPS();
        }

        uint256 tokenBalance = token.balanceOf(alice);
        uint256 feeCollected = token.feeCollected();
        assertEq(tokenBalance * 10000 / (10000 - buyTaxFee) / 1000, (tokenBalance + feeCollected) / 1000);
        assertEq(wethBalance - 1000e18, WETH.balanceOf(alice));
        timeTravel(blocksAfter * 5, blocksAfter);
        token.approve(address(router), token.balanceOf(alice));
        // alice sell bought PPAP tokens
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            token.balanceOf(alice),
            80e18,
            reversePath,
            alice,
            block.timestamp + 1000
        );
        assertEq(tokenBalance * sellTaxFee / 10000, token.feeCollected() - feeCollected);
        assertEq(token.balanceOf(alice), 0);
    }

    function testBuyAndSell(uint256 blocksBefore, uint256 blocksAfter) public {
        vm.assume(blocksBefore >= 0 && blocksBefore <= 100000);
        vm.assume(blocksAfter <= 1000000);
        buyAndSell(blocksBefore, blocksAfter);
    }

    function testBuyInInitialAndSellInt24h(uint256 blocksBefore, uint256 blocksAfter) public {
        vm.assume(blocksBefore >= 0 && blocksBefore <= 1);
        vm.assume(blocksAfter <= 86400/5);
        buyAndSell(blocksBefore, blocksAfter);
    }

    function testBuyInInitialAndSellAfter24h(uint256 blocksBefore, uint256 blocksAfter) public {
        vm.assume(blocksBefore >= 0 && blocksBefore <= 1);
        vm.assume(blocksAfter < 1000);
        buyAndSell(blocksBefore, 86400/5 + blocksAfter);
    }

    function testBuyAndTransfer(uint256 atBlock, uint256 amount) public {
        vm.assume(atBlock >= 0 && atBlock <= 1000000);
        vm.assume(amount < 10000e18);
        buyAndTransfer(atBlock, amount + 1000e18);
    }

    function testBuyInInitialAndTransfer(uint256 atBlock, uint256 amount) public {
        vm.assume(atBlock >= 0 && atBlock <= 1);
        vm.assume(amount <= 10000e18);
        buyAndTransfer(atBlock, amount + 1000e18);
    }

    function testBuyIn24hAndTransfer(uint256 atBlock, uint256 amount) public {
        vm.assume(atBlock >= 1 && atBlock <= 86400/5);
        vm.assume(amount > 1000e18 && amount < 1000000e18);
        buyAndTransfer(atBlock, amount);
    }


    function testBurn() public {
        uint256 balance = token.balanceOf(treasury);
        vm.startPrank(treasury);
        token.burn(1000e18);
        assertEq(token.balanceOf(treasury), balance - 1000e18);
    }

}
