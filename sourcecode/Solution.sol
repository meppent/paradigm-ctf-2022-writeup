// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.8.16;

interface IChallenge {
    function solve(bytes memory code) external;
}

interface ISetup {
    function challenge() external view returns (IChallenge);
}

contract Solution {
    constructor(ISetup setup) {
        IChallenge challenge = setup.challenge();

        challenge.solve(hex"");
    }
}
