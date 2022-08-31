# Vanity

For this challenge, the idea is simple: be able to sign a message from an address having more than 16 zeros, or to send a transaction with such an account.
It is not possible to do the latter, and it seems hard to do the former aswell.
Indeed, the library used to handle signature is an old OpenZeppelin release, the only difference between the most recent one being the possibility to submit both 65 bytes and 64 bytes signatures. While this possibility allows signature malleability attacks, it doesn't seem possible to leverage that to solve the challenge as the signatures are only used once.
So where is the bug?

Let's dive into `SignatureCheck.sol`.
```Solidity
(address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash, signature);
        if (error == ECDSA.RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)
        );
        return (success && result.length == 32 && abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
```

So as we said, the ECDSA library seems working well. But this contract allows non-EOA signature, by delegate-calling to their address, with a degree of liberty on the delegate-call calldata (signature is chosen by the user). If they return the 4 correct bytes then the signature is correct. Can we find a smart-contract deployed at an address with many zeros, returning data we can influence?

Yes we can! On Ethereum, there are precompiled contracts at addresses between `0x01` and `0x09`. We need to find the one able to return the data we want. While the contract `identity` at `0x04` seems to be an excellent candidate, it doesn't work. Indeed, the returned data must be of length 32 and `abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature)` is of length 4+32 = 36 at least even with an empty signature. So we can try with the contract `SHA2-256` at address 0x02. This contract returns exactly 32 bytes, the SHA2-256 of the input data.
As we want the return data to start with `isValidSignature.selector = 0x1626ba7e`, we need to find a signature such as `SHA256(0x1626ba7e + hash(CHALLENGE_MAGIC) + signature)` begins with `0x1626ba7e`.

To do this, we've written bruteforce algorithm in Rust, see [`./rust-vanity-finder`](rust-vanity-finder/). 
Our algorithm is able to find a solution in less than 30 minutes (`--release`!) on a classic computer.
A solution is `003f7f000000000000000000000000000000000000000000000000000051f1441a`.
We now just have to inject this code using Yul - cf `solution.sol`.

