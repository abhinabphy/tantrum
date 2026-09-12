//sample swap for generic testing purpose

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {UniswapV4Swap} from "utils/swaputils.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

contract Swaptest is Test {
    using PoolIdLibrary for PoolKey;
    // Uniswap V4 PoolManager on Ethereum mainnet
    address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    UniswapV4Swap public swapper;

    function setUp() public {
        uint256 mainnetfork = vm.createFork("https://ethereum-rpc.publicnode.com");
        vm.selectFork(mainnetfork);
        address alice = makeAddr("alice");
        vm.deal(alice, 20 ether);
        bytes memory sig = abi.encodeWithSignature("deposit()");
        swapper = new UniswapV4Swap();

        (bool success, bytes memory _data) = WETH.call{value: 10 ether}(abi.encodeWithSignature("deposit()"));

        require(success, "not deposited");
        console.logUint(IERC20(WETH).balanceOf(alice));
        IERC20(WETH).approve(address(swapper), type(uint256).max);
    }

    function testswap() public {
        // USDC (0xA0b8...) < WETH (0xC02a...) -> token0 = USDC, token1 = WETH
        Currency currency0 = USDC < WETH ? Currency.wrap(USDC) : Currency.wrap(WETH);
        Currency currency1 = USDC < WETH ? Currency.wrap(WETH) : Currency.wrap(USDC);

        PoolKey memory p = PoolKey({
            currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: IHooks(address(0))
        });
        bytes32 pooladdress = keccak256(abi.encode(p));
        console.logBytes32(pooladdress);
        uint128 wethin = 1 ether;
        //usdc mount
        uint256 usdcout = swapper.swapExactInput(p, wethin, 0);

        console.log((usdcout / 1e6) / (wethin / 1e18));
    }
}
