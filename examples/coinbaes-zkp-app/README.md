# Coinbase KYC Attestation Zero-Knowledge Verifier

A browser-based zero-knowledge proof application that verifies Coinbase KYC attestations without revealing the transaction signature or signer's public key.

## 🎯 What This Does

This application proves that:
1. A specific Ethereum address has received a valid Coinbase KYC attestation
2. The attestation transaction was signed by Coinbase's authorized wallet
3. **All verification happens in-circuit** - the signer's public key is recovered via ECRecover inside the ZK proof

## 🔒 Privacy Guarantees

- Transaction signature remains private
- Signer's public key is never revealed in the proof
- Only the verification result (valid/invalid) is public
- Uses constrained ECDSA verification for soundness

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Browser (Client)                         │
│                                                               │
│  1. Fetch Transaction → 2. Generate ZK Proof → 3. Verify     │
│     (Base Mainnet)         (7.17 seconds)        (2.39s)     │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    Noir Circuit (Wasm)
                              ↓
        ┌───────────────────────────────────────┐
        │  • Parse EIP-1559 Transaction         │
        │  • Extract unsigned transaction hash  │
        │  • Recover pubkey via ECRecover       │
        │  • Verify signer = Coinbase wallet    │
        └───────────────────────────────────────┘
```

## 📦 Project Structure

```
coinbaes-zkp-app/
├── circuit/attestor/          # Noir ZKP Circuit
│   ├── src/
│   │   ├── main.nr           # Main verification logic
│   │   ├── ecrecover.nr      # ECRecover implementation
│   │   ├── secp256k1.nr      # secp256k1 curve operations
│   │   ├── tx_parser.nr      # EIP-1559 transaction parser
│   │   └── bignum_lib/       # Big number arithmetic
│   ├── Prover.toml           # Example inputs
│   └── Nargo.toml            # Circuit configuration
├── src/                      # Frontend & Circuit Integration
│   ├── index.html            # UI
│   ├── index.js              # Main application logic
│   ├── circuitLoader.js      # Noir circuit loader
│   ├── proofUtils.js         # Proof generation utilities
│   └── styles.css            # Styling
├── lib/forge-std/            # Foundry standard library
└── foundry.toml              # Solidity compiler config
```

## 🚀 Quick Start

### Prerequisites

```bash
# Node.js 18+
node --version

# Noir v1.0.0-beta.9
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup -v 1.0.0-beta.9

# bb CLI v0.87.0
curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
bbup -v 0.87.0
```

### Installation

```bash
# Install dependencies
npm install

# Compile circuit
cd circuit/attestor
nargo compile
cd ../..

# Start development server
npm run dev
```

Visit `http://localhost:5173`

## 🧪 How to Use

1. **Connect Wallet**: Click "Connect Wallet" and switch to Base Mainnet
2. **Enter Attestation UID**: Get a Coinbase attestation UID from [EAS Scan](https://base.easscan.org)
3. **Generate Proof**: Click "Generate & Verify Proof" (takes ~7 seconds)
4. **View Result**: See proof verification result and details

### Example Attestation UID

```
0x16ab47674c8cd22dc72ef11cbce90ec4ec2c0eebf0ae77ae7ca92b6c5a5c1da0
```

## ⚡ Performance

- **Proof Generation**: 7.17 seconds (in browser)
- **Verification**: 2.39 seconds
- **Proof Size**: 147.77 KB
- **Circuit Stats**:
  - ACIR Opcodes: 3,838
  - Brillig Opcodes: 142,472

## 🔧 Development

### Compile Circuit

```bash
cd circuit/attestor
nargo compile
```

### Run Tests

```bash
cd circuit/attestor
nargo test
```

### Build for Production

```bash
npm run build
```

## 🎓 Technical Details

### Circuit Implementation

The circuit implements full ECRecover cryptography:

1. **Transaction Parsing**: Extracts fields from EIP-1559 transaction
2. **Unsigned Hash Creation**: Rebuilds the message that was signed
3. **Public Key Recovery**: Implements `pubkey = r^(-1) * (s*R - e*G)`
4. **Address Derivation**: Converts pubkey to Ethereum address via Keccak256
5. **Signer Verification**: Proves signer == Coinbase authorized wallet

### Optimization: Jacobian Coordinates

The circuit uses Jacobian projective coordinates for elliptic curve operations:
- Reduces modular inversions from ~1,152 to 3 (99.7% reduction)
- Trades memory-intensive divisions for CPU-intensive multiplications
- Enables browser WASM execution without capacity overflow

### Key Addresses

**Coinbase Attester Contract (Base Mainnet)**:
```
0x357458739F90461b99789350868CD7CF330Dd7EE
```

**Coinbase Authorized Signer**:
```
0x952f32128AF084422539C4Ff96df5C525322E564
```

## 🛠️ Troubleshooting

### Circuit Compilation Issues

```bash
cd circuit/attestor
nargo clean
nargo compile
```

### Browser Memory Issues

If proof generation fails:
- Close other browser tabs
- Use latest Chrome/Brave browser
- Clear browser cache

### Common Errors

**"Failed to fetch transaction"**
- Check if attestation UID exists on Base Mainnet
- Verify network connection

**"Proof generation failed"**
- Ensure circuit is compiled (`cd circuit/attestor && nargo compile`)
- Check browser console for detailed errors

## 📚 Resources

- [Noir Documentation](https://noir-lang.org/docs/)
- [bb.js Documentation](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg/ts)
- [Base Network](https://docs.base.org/)
- [EAS Documentation](https://docs.attest.sh/)

## 🔐 Security Notes

- This is a demonstration project
- Private keys are never exposed to the circuit
- Only public transaction data and signatures are used as inputs
- The circuit uses constrained ECDSA verification for soundness

## 📄 License

MIT License

## 🙏 Acknowledgments

Built with:
- [Noir](https://noir-lang.org/) - Zero-knowledge proof language
- [Barretenberg](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg) - Proving backend
- [Vite](https://vitejs.dev/) - Frontend build tool
- [Coinbase](https://www.coinbase.com/) - KYC attestation service
