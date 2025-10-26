# Coinbase Attestation Zero-Knowledge Verifier

This Noir circuit provides zero-knowledge verification of Coinbase KYC attestation transactions on Base network.

## Overview

The circuit verifies that a user has a valid Coinbase KYC attestation without revealing the raw transaction details or the user's public key.

### What it proves

1. **Transaction Integrity**: The raw transaction matches the claimed transaction hash
2. **Correct Destination**: The transaction was sent to the EAS (Ethereum Attestation Service) contract
3. **Valid Signature**: The transaction was signed by Coinbase Attester's private key
4. **Authorized Attester**: The public key derives to COINBASE_ATTESTER address
5. **Correct Recipient**: Attestation recipient matches the claimed user_address
6. **Not Expired**: Current time is before expiration time (if set)
7. **Not Revoked**: Attestation has not been revoked
8. **Privacy Preservation**: Raw transaction and attester's public key remain private

### Public Inputs (visible in proof)

- `user_address`: User's Ethereum address (20 bytes)
- `tx_hash`: Transaction hash to verify (32 bytes)

### Private Inputs (hidden in proof)

- `raw_transaction`: RLP-encoded raw transaction (300 bytes)
- `attester_pubkey_x`: Coinbase Attester's public key X coordinate (32 bytes)
- `attester_pubkey_y`: Coinbase Attester's public key Y coordinate (32 bytes)

### Extracted from Raw Transaction (verified internally)

- `recipient`: Attestation recipient address (extracted and verified against user_address)
- `revocation_time`: Revocation time (extracted and verified to be 0)

Note: Expiration check is performed on-chain by querying EAS and comparing with block.timestamp

## Circuit Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Public Inputs                              │
│  - user_address (20 bytes)                                      │
│  - tx_hash (32 bytes)                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Private Inputs                              │
│  - raw_transaction (300 bytes)                                  │
│  - user_pubkey_x (32 bytes)                                     │
│  - user_pubkey_y (32 bytes)                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: Verify Transaction Hash Integrity                      │
│   computed_hash = keccak256(raw_transaction)                   │
│   assert(computed_hash == tx_hash)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: Verify Transaction Destination                         │
│   to_address = extract_to_address(raw_transaction)             │
│   assert(to_address == EAS_CONTRACT)                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: Extract Transaction Signature                          │
│   signature = extract_signature(raw_transaction)               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Verify Transaction Signature                           │
│   valid = ecdsa_verify(pubkey, signature, tx_hash)             │
│   assert(valid)                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 5: Derive Address from Public Key                         │
│   pubkey_hash = keccak256(pubkey_x || pubkey_y)                │
│   derived_address = pubkey_hash[12:32]                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 6: Verify Coinbase Attester                               │
│   assert(derived_address == COINBASE_ATTESTER)                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 7: Verify Recipient Matches User Address                  │
│   recipient = extract_recipient_from_calldata(raw_tx)          │
│   assert(recipient == user_address)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 8: Verify Not Revoked                                     │
│   revocation_time = extract_revocation_time(raw_tx)            │
│   assert(revocation_time == 0)                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                        Proof Generated
```

## Usage

### Prerequisites

- Nargo (Noir compiler) installed
- A Coinbase KYC attestation transaction on Base network

### Step 1: Generate Test Data

```bash
# Set your environment variables
export USER_ADDRESS="0xYourAddress"
export ATTESTATION_TX_HASH="0xYourAttestationTxHash"

# Run the test script to generate circuit inputs
node test-raw-tx-verification.js
```

This will output the Prover.toml format data.

### Step 2: Update Prover.toml

Copy the generated data to `circuit/attestor/Prover.toml`:

```toml
# Public Inputs
user_address = [...]
tx_hash = [...]

# Private Inputs
raw_transaction = [...]
attester_pubkey_x = [...]
attester_pubkey_y = [...]
```

### Step 3: Compile the Circuit

```bash
cd circuit/attestor
nargo compile
```

### Step 4: Execute the Circuit

```bash
nargo execute
```

If successful, you'll see:
```
[attestor] Circuit witness successfully solved
[attestor] Witness saved to target/attestor.gz
```

## Implementation Notes

### RLP Decoding

The current implementation uses simplified RLP extraction for demonstration purposes. The `extract_to_address` and `extract_signature` functions assume fixed positions within the transaction.

For production use, implement proper RLP decoding using:
- [noir-trie-proofs](https://github.com/aragonzkresearch/noir-trie-proofs)

### Transaction Types

The circuit is designed for EIP-1559 transactions (Type 2), which is the standard on Base network.

Transaction format:
```
0x02 || rlp([
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gasLimit,
    to,
    value,
    data,
    accessList,
    signatureYParity,
    signatureR,
    signatureS
])
```

### Constants

- **EAS_CONTRACT**: `0x4200000000000000000000000000000000000021` (Base Mainnet)
- **COINBASE_ATTESTER**: `0x357458739F90461b99789350868CD7CF330Dd7EE`

## Security Considerations

### What the Verifier Sees

**Public** (visible to everyone):
- User's Ethereum address
- Transaction hash

**Private** (hidden in zero-knowledge proof):
- Raw transaction data
- User's public key coordinates
- Transaction signature

### Attack Vectors

1. **Invalid Raw Transaction**: Circuit verifies that keccak256(raw_tx) == tx_hash
2. **Wrong Public Key**: Circuit derives address from public key and verifies match
3. **Invalid Signature**: Circuit verifies ECDSA signature on the transaction
4. **Wrong Destination**: Circuit checks that transaction was sent to EAS contract

All attack vectors are prevented by the circuit's assertions.

## Future Improvements

1. **Proper RLP Decoding**: Implement full RLP decoder instead of fixed-position extraction
2. **Schema Verification**: Add verification of the attestation schema ID from calldata
3. **Timestamp Checks**: Verify attestation timestamp and expiration
4. **Batch Verification**: Support verifying multiple attestations in one proof
5. **Optimizations**: Reduce constraint count through algorithmic improvements

## References

- [Ethereum RLP Encoding](https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/)
- [EIP-1559 Transactions](https://eips.ethereum.org/EIPS/eip-1559)
- [Ethereum Attestation Service](https://docs.attest.sh/)
- [Noir Language](https://noir-lang.org/)
- [Coinbase Verifications](https://github.com/coinbase/verifications)
