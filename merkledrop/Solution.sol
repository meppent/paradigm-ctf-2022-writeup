// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IMerkleDistributor {
    function claim(
        uint256 index,
        address account,
        uint96 amount,
        bytes32[] memory merkleProof
    ) external;
}

interface ISetup {
    function merkleDistributor() external returns (IMerkleDistributor);
}

contract Solution {

    constructor(ISetup setup) {
        IMerkleDistributor merkleDistributor = setup.merkleDistributor();

        bytes32[] memory proof1 = new bytes32[](5);
        proof1[0] = 0x8920c10a5317ecff2d0de2150d5d18f01cb53a377f4c29a9656785a22a680d1d;
        proof1[1] = 0xc999b0a9763c737361256ccc81801b6f759e725e115e4a10aa07e63d27033fde;
        proof1[2] = 0x842f0da95edb7b8dca299f71c33d4e4ecbb37c2301220f6e17eef76c5f386813;
        proof1[3] = 0x0e3089bffdef8d325761bd4711d7c59b18553f14d84116aecb9098bba3c0a20c;
        proof1[4] = 0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5;

        bytes32[] memory proof2 = new bytes32[](6);
        proof2[0] = 0xe10102068cab128ad732ed1a8f53922f78f0acdca6aa82a072e02a77d343be00;
        proof2[1] = 0xd779d1890bba630ee282997e511c09575fae6af79d88ae89a7a850a3eb2876b3;
        proof2[2] = 0x46b46a28fab615ab202ace89e215576e28ed0ee55f5f6b5e36d7ce9b0d1feda2;
        proof2[3] = 0xabde46c0e277501c050793f072f0759904f6b2b8e94023efb7fc9112f366374a;
        proof2[4] = 0x0e3089bffdef8d325761bd4711d7c59b18553f14d84116aecb9098bba3c0a20c;
        proof2[5] = 0x5271d2d8f9a3cc8d6fd02bfb11720e1c518a3bb08e7110d6bf7558764a8da1c5;

        merkleDistributor.claim(
            0xd43194becc149ad7bf6db88a0ae8a6622e369b3367ba2cc97ba1ea28c407c442,
            address(0xd48451c19959e2D9bD4E620fBE88aA5F6F7eA72A),
            0x00000f40f0c122ae08d2207b,
            proof1
        );

        merkleDistributor.claim(
            8,
            address(0x249934e4C5b838F920883a9f3ceC255C0aB3f827),
            0xa0d154c64a300ddf85,
            proof2
        );
    }
}