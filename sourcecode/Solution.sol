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

        challenge.solve(
            hex"60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f60025814601e57808060005260205260405260606000f3dead0dead0dead5b7f"
        );
    }
}
