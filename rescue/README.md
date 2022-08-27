# Rescue

Let's dive into Rescue, one of the most solved challenge.
The context of this one is pretty straightforward, an EOA sent by mistake 10 wEth to `MasterChefHelper.sol` and we need to get them back.
`MasterChefHelper.sol` is a wrapper of UniswapV2, adding a unique external function: `swapTokenForPoolToken`.

This function purpose is to swap a quantity X of tokens A into the equivalent of X/2 of tokens B and X/2 of tokens C, and then to add liquidity to the B/C pool on Uniswap.
But something is odd:
```Solidity
function _addLiquidity(address token0, address token1, uint256 minAmountOut) internal {
    (,, uint256 amountOut) = router.addLiquidity(
        token0, 
        token1, 
        ERC20Like(token0).balanceOf(address(this)), 
        ERC20Like(token1).balanceOf(address(this)), 
        0, 
        0, 
        msg.sender, 
        block.timestamp
    );
    require(amountOut >= minAmountOut);
}
```
The function send the whole balance of the contract to add liquidity. 
Knowing that we have 5000 eth initially, the idea then becomes clear: we need to find a token A existing in a pool with wEth. We buy a great quantity of token A (>> 10 eth) and send it to the `MasterChefHelper.sol` contract. After that, we can buy a small quantity of a token B, and call `swapTokenForPoolToken` with this token as `tokenIn` and the id of the pool wEth/A as `poolId`.
We do not really care about `minAmountOut` so we can set it to be 0 (we won't get sandwiched on a private blockchain heh). 

The contract will swap the small amount of token B and add liquidity with the 10 wEth it has, and the great amount of token A we sent him. Knowing that the amount of token A is worth more than 10 eth, the action od adding liquidity will take all 10 eth of the contract and we are done! 
See `solution.sol` for an actual implementation.
