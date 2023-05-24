// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/PPAPToken.sol";
import "../src/interfaces/univ2.sol";


contract PPAPBeforeLPTest is Test {
    PPAPToken public token;

    uint256 forkId;
    ERC20 WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router02 router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address treasury;
    address reserve;
    address sponsor;
    address owner;
    address alice;
    address[] path = new address[](2);

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        forkId = vm.createSelectFork(MAINNET_RPC_URL);
        owner = address(1000);
        treasury = address(0x6c5445D0C0B91eBDdDc38d8ec58dE6062E354d2C);
        reserve = address(0xBf5C5Bfb45Ca4e6D7BDCad65C5382D8b0F6495cd);
        sponsor = address(0xd1046b0cC930F140F7693710E5C8D2E24a23b9DF);
        alice = address(1100);

        vm.label(address(WETH), "WETH");
        vm.label(address(router), "UniswapV2 Router");
        vm.label(address(owner), "Owner");
        vm.label(address(alice), "Alice");


        vm.prank(owner);
        token = new PPAPToken();
        vm.label(address(token), "PPAPToken");

        // create liquidity pool
        deal(address(WETH), alice, 1000000e18);

        path[0] = address(WETH);
        path[1] = address(token);

        // alice's approves
        vm.startPrank(alice);
        WETH.approve(address(router), WETH.balanceOf(alice));
        vm.stopPrank();

    }

    function testBeforeLP() public {
        vm.startPrank(alice);
        vm.expectRevert();
        router.swapExactTokensForTokens(
            1000e18,
            0,
            path,
            alice,
            block.timestamp + 1000
        );
    }

    function testDeployment() public {
        assertEq(token.symbol(), "$PPAP");
        assertEq(token.name(), "PPAP Token");
        assertEq(token.decimals(), 18);
        assertEq(address(token.router()), address(0));
        assertEq(address(token.pair()), address(0));
    }
}

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
    address reserve;
    address sponsor;
    address exchanges;
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
        reserve = address(0xBf5C5Bfb45Ca4e6D7BDCad65C5382D8b0F6495cd);
        sponsor = address(0xd1046b0cC930F140F7693710E5C8D2E24a23b9DF);
        exchanges = address(0x8c0f99600D98cF581847A08b13dd3B7656263B7c);
        alice = address(100);
        bob = address(101);

        vm.label(address(WETH), "WETH");
        vm.label(address(factory), "UniswapV2 Factory");
        vm.label(address(router), "UniswapV2 Router");
        vm.label(address(treasury), "Treasury");
        vm.label(address(reserve), "Reserve");
        vm.label(address(sponsor), "Sponsor");
        vm.label(address(owner), "Owner");
        vm.label(address(alice), "Alice");
        vm.label(address(bob), "Bob");


        vm.prank(owner);
        token = new PPAPToken();
        vm.label(address(token), "PPAPToken");

        // create liquidity pool
        deal(address(WETH), treasury, 10000e18);
        deal(address(WETH), alice, 1000000e18);
        deal(address(WETH), bob, 1000000e18);

        // treasury's approves
        vm.startPrank(treasury);
        factory = IUniswapV2Factory(router.factory());
        token.approve(address(token), token.balanceOf(treasury));
        WETH.approve(address(token), WETH.balanceOf(treasury));
        token.createInitialLiquidityPool(router, address(WETH), WETH.balanceOf(treasury));
        pair = IUniswapV2Pair(factory.getPair(address(WETH), address(token)));
        vm.label(address(pair), "PPAP-WETH");

        path[0] = address(WETH);
        path[1] = address(token);
        reversePath[0] = address(token);
        reversePath[1] = address(WETH);
        vm.stopPrank();

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
        uint256 tokenBalance = token.balanceOf(alice);
        assertEq(wethBalance - amount, WETH.balanceOf(alice));
        timeTravel(1);

        // alice should have 3/4 PPAPs and treasury should have 1/4 PPAPs
        assertEq((token.balanceOf(alice) + token.feeCollected()) * buyTaxFee / 10000,
                 token.balanceOf(address(token)) - tokenTokenBalance);

        // alice may transfer without any fee to any addresses (including contracts)
        // during transfer swap should be triggered
        // after transfer expected:
        // - Alice has - 1 $PPAP
        // - Factory has + 1 $PPAP
        // - Treasury has + n WETH
        // - Token has - n $PPAP
        assertEq(WETH.balanceOf(treasury), 0);
        token.transfer(address(factory), 1e18);
        assertEq(token.balanceOf(alice), tokenBalance - 1e18);
        assertEq(token.balanceOf(address(factory)), 1e18);
        assertEq(token.balanceOf(address(token)), tokenTokenBalance);
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
        assertEq(tokenBalance * 10000 / (10000-buyTaxFee) / 1000, (tokenBalance + feeCollected) / 1000);
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

    function testWithdrawLP() public {
        uint256 pairLPBalance = pair.balanceOf(address(token));

        vm.startPrank(alice);
        vm.expectRevert("PPAP: not the treasury");
        token.withdrawLiquidity();
        vm.stopPrank();

        vm.startPrank(treasury);
        vm.expectRevert("PPAP: too early");
        token.withdrawLiquidity();
        timeTravel(365 days + 1 seconds);
        token.withdrawLiquidity();
        assertEq(pair.balanceOf(treasury), pairLPBalance);


        pair.approve(address(router), pairLPBalance);
        router.removeLiquidity(
            address(token),
            address(WETH),
            pairLPBalance,
            0,
            0,
            address(treasury),
            block.timestamp + 1000
        );
    }

    function testVestingUnlockForExchanges() public {
        vm.startPrank(exchanges);
        (uint256 period, uint256 amountPerPeriod, uint256 claimable, uint256 pending) = token.vestingClaimable(exchanges);
        uint256 balance1 = token.balanceOf(exchanges);
        assertEq(balance1, 0);

        token.vestingClaim();
        uint256 balance2 = token.balanceOf(exchanges);
        assertEq(balance2, 0);

        timeTravel(1 seconds);
        token.vestingClaim();
        uint256 balance3 = token.balanceOf(exchanges);
        assertEq(balance3, 0);

        timeTravel(30 days);
        token.vestingClaim();
        uint256 balance4 = token.balanceOf(exchanges);

        assertEq(balance4, pending);

        timeTravel(300 days + 1 seconds);
        token.vestingClaim();
        uint256 balance5 = token.balanceOf(exchanges);

        assertEq(balance5, pending);
    }

    function testVestingUnlock() public {
        vm.startPrank(sponsor);
        (uint256 period, uint256 amountPerPeriod, uint256 claimable, uint256 pending) = token.vestingClaimable(sponsor);
        uint256 balance1 = token.balanceOf(sponsor);
        assertEq(balance1, 0);

        token.vestingClaim();
        uint256 balance2 = token.balanceOf(sponsor);
        assertEq(balance2, 0);

        timeTravel(6 days + 1 seconds);
        token.vestingClaim();
        uint256 balance3 = token.balanceOf(sponsor);
        assertEq(balance3, 0);

        timeTravel(1 days + 1 seconds);
        token.vestingClaim();
        uint256 balance4 = token.balanceOf(sponsor);
        assertEq(balance4, amountPerPeriod);

        timeTravel(300 days + 1 seconds);
        token.vestingClaim();
        uint256 balance5 = token.balanceOf(sponsor);

        assertEq(balance5, pending);

        timeTravel(300 days + 1 seconds);
        token.vestingClaim();
        uint256 balance6 = token.balanceOf(sponsor);

        assertEq(balance6, pending);
    }
}
