# Advanced Coinbase KYC Attestation Circuit

Private, secure Coinbase KYC attestation verification with anti-replay protection and flexible signer management.

## Features

### 🔐 Privacy Enhancements
- **User address hidden**: Only `signal_hash` and `signer_list_merkle_root` are public
- **No transaction exposure**: All attestation details remain private
- **Public key privacy**: Recovered keys never appear in the proof

### 🛡️ Security Improvements
- **Anti-replay protection**: `signal_hash` prevents proof reuse
- **User ownership proof**: Users must sign the challenge with their wallet
- **Flexible signer management**: Merkle tree supports unlimited Coinbase signers

### ⚡ Performance Optimization
- **Hybrid verification**: JavaScript does heavy ECRecover, circuit does lightweight verify_signature
- **Estimated 3-5x faster** than full in-circuit ECRecover
- **Lower memory usage**: ~500MB vs ~2GB

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Advanced Circuit                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  PUBLIC INPUTS:                                              │
│  ├─ signal_hash (32 bytes)          ← Anti-replay challenge │
│  └─ signer_list_merkle_root (32 bytes) ← Authorized signers │
│                                                               │
│  PRIVATE INPUTS:                                             │
│  ├─ Part 1: User Ownership                                   │
│  │  ├─ user_address                                          │
│  │  ├─ user_signature (on signal_hash)                       │
│  │  ├─ user_pubkey_x                                         │
│  │  └─ user_pubkey_y                                         │
│  │                                                            │
│  ├─ Part 2: Attestation Transaction                          │
│  │  ├─ raw_transaction                                       │
│  │  ├─ tx_length                                             │
│  │  ├─ coinbase_attester_pubkey_x (from JS ecrecover)       │
│  │  └─ coinbase_attester_pubkey_y (from JS ecrecover)       │
│  │                                                            │
│  └─ Part 3: Merkle Proof                                     │
│     ├─ coinbase_signer_merkle_proof                          │
│     ├─ coinbase_signer_leaf_index                            │
│     └─ merkle_proof_depth                                    │
│                                                               │
│  VERIFICATION FLOW:                                          │
│  1. Verify user owns address (pubkey → address)              │
│  2. Verify user signed signal_hash                           │
│  3. Verify Coinbase signature (hybrid model)                 │
│  4. Verify signer is in Merkle tree                          │
│  5. Verify TX was sent to Attester contract                  │
│  6. Verify TX data matches user_address                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
circuit/advanced/
├── Nargo.toml              # Project configuration
├── Prover.toml             # Input template (needs JavaScript preprocessing)
├── README.md               # This file
└── src/
    ├── main.nr             # Main circuit logic (3-part verification)
    ├── tx_parser.nr        # EIP-1559 transaction parser (from attestor)
    └── merkle.nr           # Keccak256-based Merkle proof verification
```

## Comparison with Basic Circuit

| Feature | Basic (attestor) | Advanced |
|---------|-----------------|----------|
| **Privacy** | ❌ User address public | ✅ Fully private |
| **Anti-replay** | ❌ None | ✅ signal_hash |
| **Signer management** | Array (2 signers) | Merkle tree (unlimited) |
| **Performance** | ~70,000 constraints | ~15,000 constraints (est.) |
| **Proof time** | ~20-30 seconds | ~5-10 seconds (est.) |
| **Browser memory** | ~2GB | ~500MB (est.) |
| **ECRecover** | ✅ Full in-circuit | ⚡ Hybrid (JS + circuit) |

## How to Use

### Quick Start: Browser Frontend

The easiest way to test the advanced circuit is using the browser frontend:

```bash
cd frontend
npm install
npm run dev
```

Then open http://localhost:5174 in your browser.

The frontend provides a step-by-step interface:
1. Connect MetaMask wallet
2. Fetch Coinbase attestation transaction from Base
3. Generate proof inputs (JS preprocessing)
4. Generate ZK proof in browser
5. Verify proof

### Advanced: Manual JavaScript Preprocessing

For custom integrations, JavaScript must prepare the inputs:

```javascript
import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';

// 1. Generate anti-replay challenge
const signal_hash = ethers.randomBytes(32);

// 2. User signs the challenge
const userSig = await wallet.signMessage(signal_hash);
const user_signature = ethers.Signature.from(userSig);
const user_pubkey = ethers.SigningKey.recoverPublicKey(
    ethers.hashMessage(signal_hash),
    userSig
);

// 3. Fetch attestation transaction
const tx = await provider.getTransaction(txHash);
const unsigned_tx_hash = computeUnsignedTxHash(tx); // Custom function

// 4. Recover Coinbase signer public key
const coinbase_pubkey = ethers.SigningKey.recoverPublicKey(
    unsigned_tx_hash,
    tx.signature
);

// 5. Build Merkle tree of authorized signers
const signers = [
    '0x952f32128AF084422539C4Ff96df5C525322E564',
    '0x8844591D47F17bcA6F5dF8f6B64F4a739F1C0080',
    '0x88fe64ea2e121f49bb77abea6c0a45e93638c3c5',
    '0x44ace9abb148e8412ac4492e9a1ae6bd88226803'
];

const leaves = signers.map(addr =>
    ethers.keccak256(ethers.getAddress(addr))
);

const tree = new MerkleTree(leaves, ethers.keccak256, {
    sortPairs: true
});

const signer_list_merkle_root = tree.getRoot();
const coinbase_signer_address = ethers.computeAddress(coinbase_pubkey);
const leaf = ethers.keccak256(coinbase_signer_address);
const proof = tree.getProof(leaf);

// 6. Generate Prover.toml with all inputs
// (See Prover.toml template)
```

### Step 2: Generate Proof

```bash
cd circuit/advanced

# Compile circuit
nargo compile

# Generate proof
nargo prove

# Verify proof
nargo verify
```

### Step 3: On-Chain Verification

The verifier contract only needs to check:
1. `signal_hash` hasn't been used before (replay protection)
2. `signer_list_merkle_root` matches current authorized list
3. Proof is valid

```solidity
contract AdvancedVerifier {
    mapping(bytes32 => bool) public usedSignalHashes;
    bytes32 public currentSignerListRoot;

    function verify(
        bytes calldata proof,
        bytes32 signal_hash,
        bytes32 signer_list_merkle_root
    ) external {
        require(!usedSignalHashes[signal_hash], "Signal already used");
        require(signer_list_merkle_root == currentSignerListRoot, "Invalid signer list");

        // Verify ZK proof
        require(verifyProof(proof), "Invalid proof");

        usedSignalHashes[signal_hash] = true;
    }
}
```

## Security Considerations

### ✅ What This Circuit Guarantees

1. **User owns the address**: Proven via ECDSA signature on `signal_hash`
2. **Attestation is authentic**: Transaction was signed by authorized Coinbase signer
3. **Attestation is for this user**: Calldata contains user's address
4. **No replay attacks**: Each proof requires unique `signal_hash` signature

### ⚠️ Important Notes

1. **JavaScript trust**: The hybrid model requires trusting JavaScript ecrecover
   - Mitigation: Circuit verifies the recovered pubkey actually signed the TX
   - If JS lies about pubkey, verify_signature will fail

2. **Merkle root updates**: dApp must maintain current authorized signer list
   - Use on-chain governance or time-locks for updates
   - Clients should verify root against trusted source

3. **Signal hash generation**: Must be unpredictable and unique
   - Use cryptographically secure random source
   - Include timestamp/nonce if needed

## Development

### Build

```bash
nargo compile
```

### Test

```bash
# Run Noir tests
nargo test

# Check syntax
nargo check
```

### Clean

```bash
nargo clean
```

## Dependencies

- **keccak256**: `v0.1.1` - Ethereum-compatible keccak256 hashing
- **std::ecdsa_secp256k1**: Built-in ECDSA verification (Noir standard library)

## Future Improvements

1. **Batch verification**: Verify multiple attestations in one proof
2. **Recursive proofs**: Aggregate multiple Advanced proofs
3. **Cross-chain support**: Verify attestations from multiple chains
4. **Time-bound attestations**: Add expiration logic
5. **Selective disclosure**: Prove properties without revealing address

## License

Same as parent project

## References

- [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559) - Transaction format
- [Noir Language](https://noir-lang.org) - ZK DSL
- [Coinbase Attestation](https://docs.base.org) - Base attestation protocol
