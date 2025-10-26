# Browser Testing Guide

## 🚀 Quick Start

### 옵션 1: 자동 실행 스크립트 사용 (추천)

```bash
./start-browser-test.sh
```

이 스크립트는 자동으로:
- Node.js 설치 확인
- 회로 컴파일 (필요한 경우)
- npm 의존성 설치 (필요한 경우)
- 개발 서버 시작

### 옵션 2: 수동 실행

1. **의존성 설치**
```bash
npm install
```

2. **회로 컴파일** (이미 완료되어 있음)
```bash
nargo compile
```
이 명령어는 `target/attestor.json` (회로 아티팩트)를 생성합니다.

3. **개발 서버 시작**
```bash
npm run dev
```
Vite 개발 서버가 http://localhost:3000 (또는 3001)에서 시작됩니다.

## 📝 How to Use

### Option 1: Use Sample Data (Quick Test)

1. Click **"Load Sample Data"** button
2. Click **"Generate Proof"** button
3. Wait for proof generation (may take 10-30 seconds)
4. Click **"Verify Proof"** button
5. Check the verification result

### Option 2: Use Real Coinbase Transaction Data

1. **Get Real Transaction Data:**
   - Obtain a real Coinbase KYC attestation transaction
   - Extract the raw transaction bytes
   - Extract the transaction signature (r, s, v)

2. **Fill in the inputs:**
   - **User Address**: The Ethereum address of the user (20 bytes)
   - **Transaction Hash**: The keccak256 hash of the signed transaction (32 bytes)
   - **Transaction Length**: Actual length of the transaction in bytes
   - **Raw Transaction**: Array of 300 bytes (padded with zeros if shorter)
   - **Transaction Signature**: Array of 65 bytes (r: 32 bytes, s: 32 bytes, v: 1 byte)

3. **Generate and Verify:**
   - Click "Generate Proof"
   - Wait for completion
   - Click "Verify Proof"

## 📊 What Happens Behind the Scenes

### Proof Generation
1. **Input Parsing**: Converts hex strings to byte arrays
2. **Circuit Execution**:
   - Parses raw transaction
   - Verifies transaction hash
   - Extracts signature components (r, s, v)
   - **Performs complete ECRecover** inside the circuit
   - Recovers public key from signature
   - Converts public key to Ethereum address
   - Verifies the signer is Coinbase
3. **Proof Creation**: Generates a zero-knowledge proof using Barretenberg backend

### Proof Verification
1. **Proof Validation**: Verifies the proof cryptographically
2. **Public Input Check**: Ensures public inputs match
3. **Result**: Returns whether the proof is valid

## 🎯 Expected Behavior

### With Valid Inputs:
- ✅ Proof generation succeeds
- ✅ Proof verification passes
- ✅ User can see proof size and generation time

### With Invalid Inputs:
- ❌ Proof generation may fail with constraint errors
- ❌ Verification will fail if proof doesn't match inputs

## 🔧 Circuit Details

**Implementation:**
- **Complete ECRecover**: Full public key recovery from ECDSA signature
- **No Shortcuts**: Only accepts `raw_transaction` and `tx_signature` as inputs
- **Privacy Preserving**: Public key is not revealed in the proof

**Circuit Size:**
- Expression Width: Bounded { width: 4 }
- ACIR Opcodes: 6,326
- Brillig Opcodes: 133,596
- Circuit Artifact Size: ~1.2 MB

**Performance:**
- Proof Generation: ~10-30 seconds (depending on hardware)
- Proof Verification: ~1-3 seconds
- Proof Size: ~5-10 KB

## 🐛 Troubleshooting

### "Failed to initialize" Error
- Make sure `target/attestor.json` exists
- Run `nargo compile` first

### "Proof generation failed" Error
- Check that all inputs are properly formatted
- Verify input lengths (20, 32, 300, 65 bytes)
- Check browser console for detailed error messages

### Slow Performance
- First proof generation is always slower (WASM initialization)
- Subsequent proofs will be faster
- Consider using a more powerful machine for better performance

## 📦 Build for Production

```bash
npm run build
```

This creates an optimized build in the `dist/` directory that can be deployed to any static hosting service.

## 🔗 Resources

- [Noir Documentation](https://noir-lang.org/)
- [Barretenberg Backend](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg)
- [CLAUDE.md](./CLAUDE.md) - Implementation requirements and constraints
