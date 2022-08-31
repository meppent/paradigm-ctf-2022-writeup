// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.7.6;

interface IChallenge {
    function solve(address signer, bytes memory signature) external;
}

interface ISetup {
    function challenge() external view returns (IChallenge);
}

contract Solution {
    constructor(ISetup setup) {
        IChallenge challenge = ISetup(setup).challenge();
        bytes memory signature = "";

        assembly {
            mstore(signature, 0x00)
            mstore(
                add(signature, 0x20),
                0x3f7f000000000000000000000000000000000000000000000000000051f1441a
            )
        }

        challenge.solve(address(2), signature);
    }
}
