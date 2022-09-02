# Merkledrop 

This challenge implements a contract in which the users can claim a quantity of a token that has been allocated to them. To do so, a [Merkle tree](https://en.wikipedia.org/wiki/Merkle_tree) is used. A Merkle tree allows storing a lot of information in a single variable with a known size: the Merkle root.

In the contact `MerkleDistributor`, one can claim a number of tokens for an address by calling the function `claim` with the corresponding proof, a `bytes32[]` variable called `merkleProof`. All the 64 allowed claims with the corresponding proofs are given in a [`tree.json`](data/tree.json) file. Each allowed claim has an index that prevents people claiming two times their tokens. 

A total of $75.10^{21}$ tokens is given to the contract, and in the standard case, all of this amount should be distributed to the 64 users. The objective of the challenge is to create an unwanted claim: all the tokens from the distributor should be gone, but at least one of the 64 users must not have claimed their tokens.

A well-known attack on Merkle trees is the "second preimage attack", and it is what we will use here. The idea is that not only the leaves have a valid proof, but also all the inner nodes of the Merkle tree. These inner nodes create unwanted valid data. The first step of the Python script [`solution-finder.py`](solution-finder.py) finds all of these data.

Now we want to know if we can exploit one of these data (it is not guaranteed in general). So let's see how the user input are verified. 

```solidity
bytes32 node = keccak256(abi.encodePacked(index, account, amount));
require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');
``` 

We see that a node in the Merkle tree is the keccak256 of the `index` (an `uint256`), the `account` (an `address`) and the `amount` (an  `uint96`), encoded with `abi.encodePacked`. This encoding method removes the excess zeros to fit the actual size of the content. An `uint256` will be encoded on 32 bytes, an `address` on 20 bytes, and an `uint96` on 12 bytes. That gives a data encoded on 64 bytes, exactly the size of the unwanted valid data (because it is the concatenation of two 32 bytes hashes). 

Now, we want to know if an unwanted data that can be the encoded representation of an index, an address and an amount. The index and the address are not a problem, because there is no requirement on them (only that the index has not been already claimed). But the amount can be a problem, because we can't claim more than the amount on the contract, otherwise it will revert. The second step of the [Python script](solution-finder.py) finds if one of these unwanted data could be the encoded representation of an index, an address and an amount with an amount lesser than $75.10^{21}$.

Only one inner node satisfies this property (that is already quite lucky). It allows us to claim exactly 72033437049132565012603 tokens. But the challenge requires to leave no token on the contract. So, we need to find a way to claim the remaining 2966562950867437084549 tokens. If we are lucky, we can claim exactly this amount with some of the real users. By chance, the user at the index 8 can claim exactly  the remaining amount, and the third step of the [Python script](solution-finder.py) finds them.

The final step builds the proof of the inner node, and then prints all the arguments to send. We can now deploy the contract [`Solution.sol`](Solution.sol) that solves the challenge at the deployment.
