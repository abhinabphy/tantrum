// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta,BalanceDeltaLibrary} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import{IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";



// library BalanceDeltaLibrary {
//     function amount0(BalanceDelta delta) internal pure returns (int128) {
//         return int128(int256(BalanceDelta.unwrap(delta) >> 128));
//     }

//     function amount1(BalanceDelta delta) internal pure returns (int128) {
//         return int128(int256(BalanceDelta.unwrap(delta)));
//     }
// }

/// @notice Example of swapping on Uniswap V4 using the PoolManager directly
/// @dev V4 uses a singleton PoolManager with unlock/unlockCallback pattern
contract UniswapV4Swap is IUnlockCallback {

    // Sqrt price limits for swaps
uint160 constant MIN_SQRT_PRICE = 4295128739;
uint160 constant MAX_SQRT_PRICE =
    1461446703485210103287273052203988822378723970342;
using CurrencyLibrary for Currency;
    IPoolManager public immutable poolManager;

    error NotPoolManager();
    error SwapFailed();

    using BalanceDeltaLibrary for BalanceDelta;
    
    // Custom struct for passing context through unlock()
    struct CallbackData {
        PoolKey key;
        uint128 amountIn;
        uint128 minAmountOut;
        bool zeroForOne;
        address sender;
    }

    constructor() {
        poolManager = IPoolManager(POOL_MANAGER);
    }



// Uniswap V4 PoolManager on Ethereum mainnet
address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @notice Swap exact input amount for output tokens
    /// @param key The pool key identifying the pool
    /// @param amountIn Amount of input tokens to swap
    /// @param minAmountOut Minimum acceptable output amount
    function swapExactInput(
        PoolKey calldata key,
        uint128 amountIn,
        uint128 minAmountOut
    ) external returns (uint256 amountOut) {
        // Encode swap parameters to pass through unlock callback
        bytes memory data = abi.encode(
            CallbackData({
                key: key,
                amountIn: amountIn,
                minAmountOut: minAmountOut,
                zeroForOne: false,
                sender: msg.sender
            })
        );

        // Initiate the swap - PoolManager will call unlockCallback
        bytes memory result = poolManager.unlock(data);
        amountOut = abi.decode(result, (uint256));
    }

    /// @notice Callback from PoolManager after unlock
    /// @dev This is where the actual swap logic executes
    function unlockCallback(bytes calldata data)
        external
        override
        returns (bytes memory)
    {
        if (msg.sender != address(poolManager)) revert NotPoolManager();

        CallbackData memory params = abi.decode(data, (CallbackData));

        // Execute the swap
        // zeroForOne: true = token0 -> token1, false = token1 -> token0
        // amountSpecified: negative = exact input, positive = exact output
        BalanceDelta delta = poolManager.swap(
            params.key,
            SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: -int256(uint256(params.amountIn)),
                sqrtPriceLimitX96: params.zeroForOne
                    ? MIN_SQRT_PRICE + 1
                    : MAX_SQRT_PRICE - 1
            }),
            bytes("")
        );

        // Calculate amounts from delta
        // delta.amount0() is negative (we owe the pool)
        // delta.amount1() is positive (pool owes us)
        uint256 amountOut = params.zeroForOne
            ? uint256(int256(delta.amount1()))
            : uint256(int256(delta.amount0()));

        if (amountOut < params.minAmountOut) revert SwapFailed();

        // Settle the input token (pay what we owe)
        Currency inputCurrency = params.zeroForOne
            ? params.key.currency0
            : params.key.currency1;

        poolManager.sync(inputCurrency);

        IERC20(Currency.unwrap(inputCurrency)).transferFrom(
            params.sender,
            address(poolManager),
            params.amountIn
        );
        poolManager.settle();

        // Take the output token (receive what we're owed)
        Currency outputCurrency = params.zeroForOne
            ? params.key.currency1
            : params.key.currency0;

        poolManager.take(outputCurrency, params.sender, amountOut);

        return abi.encode(amountOut);
    }

    
}








