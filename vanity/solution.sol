// SPDX-License-Identifier: GNU AGPLv3

pragma solidity 0.7.6;
import "./Challenge.sol";

interface ISetup {
    function challenge() returns (address);
}

contract Solution {
    constructor(address _setup) public {
        Challenge challenge = ISetup(_setup).challenge();
        signature = "";

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
