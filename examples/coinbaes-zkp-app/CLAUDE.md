# Coinbase Attestor Circuit - Implementation Requirements

## ⚠️ CRITICAL: NO SHORTCUTS ALLOWED

**절대 금지 사항:**
- ❌ JS에서 ecrecover 후 회로에서 검증하는 방식 절대 금지
- ❌ Pubkey를 외부 입력으로 받는 것 절대 금지
- ❌ "더 실용적인" 방법 제안 절대 금지
- ❌ "빠른" 방법 제안 절대 금지

**유일하게 허용되는 방식:**
- ✅ 회로 내에서 완전한 ecrecover 구현
- ✅ raw_transaction과 tx_signature만 입력으로 받기
- ✅ 모든 암호화 연산을 회로 내부에서 수행

## 🎯 Core Requirements

### Input Constraints
**MUST ONLY ACCEPT:**
- `user_address: pub [u8; 20]`
- `tx_hash: pub [u8; 32]`
- `tx_length: pub u32`
- `raw_transaction: [u8; 300]` (private)
- `tx_signature: [u8; 65]` (private) - r(32) + s(32) + v(1)

**MUST NOT ACCEPT:**
- ❌ `signer_pubkey_x` - MUST be recovered from signature
- ❌ `signer_pubkey_y` - MUST be recovered from signature
- ❌ `unsigned_tx_hash` - MUST be extracted from raw_transaction

### Implementation Requirements

1. **Extract from raw_transaction:**
   - Signature (r, s, v) from transaction
   - All transaction fields for unsigned hash calculation
   - Calldata containing user_address
   - Destination address (to Coinbase Attester)

2. **Implement ECRecover:**
   - Full public key recovery from signature
   - Algorithm: `pubkey = r^(-1) * (s*R - e*G)`
   - All elliptic curve operations must be implemented
   - No shortcuts - implement even if constraint count is high

3. **Verification Flow:**
   ```
   raw_transaction → parse → unsigned_hash
                           ↓
   tx_signature + unsigned_hash → ecrecover → pubkey
                                            ↓
                                    pubkey → address
                                            ↓
                                    verify == COINBASE_SIGNER
   ```

## 🚫 Forbidden Shortcuts

- Do NOT use external pubkey input
- Do NOT use pre-computed unsigned hash
- Do NOT avoid implementing ecrecover due to complexity
- Do NOT prioritize constraint count over correctness
- **❌ NEVER comment out or disable ecrecover verification just to make tests pass**
- **❌ NEVER create "temporary" solutions that bypass signature verification**
- **❌ The entire purpose of this project IS signature verification - removing it defeats the purpose**

## 🔒 ABSOLUTE RULES - NEVER BREAK THESE

### Rule #1: Browser-Only Execution
- **❌ NEVER suggest moving proof generation to a server**
- **❌ NEVER suggest external services or APIs for proving**
- **❌ NEVER create server/backend code without explicit user request**
- **✅ ALL proof generation MUST happen in the browser**
- **✅ ZKP must be deterministic and trustless**
- **Reason:** External servers break trustlessness. Users must be able to generate proofs independently.

### Rule #2: No Unauthorized Implementation
- **❌ NEVER implement solutions without explicit user permission**
- **❌ NEVER write code unless specifically asked**
- **✅ ALWAYS explain options first, then wait for user decision**
- **✅ When stuck, ask user for direction instead of assuming**

### Rule #3: When Facing Technical Limitations
- **❌ DON'T immediately propose workarounds that compromise principles**
- **✅ DO explain the technical constraint clearly**
- **✅ DO present multiple options with trade-offs**
- **✅ DO wait for user to choose the approach**

## ✅ Success Criteria

- Circuit compiles successfully
- All operations happen inside the circuit
- Privacy maintained (pubkey not revealed in proof)
- Coinbase signature verification is complete and correct

## 📝 Notes

- Cost/constraint count is acceptable - this is verification-focused
- Full cryptographic implementation required
- JS frontend will only provide raw_transaction and tx_signature

## 🐛 Known Issues Fixed

### Browser ACVM Type Error
**Issue:** "Bit size for rhs 128 does not match op bit size 8" error in browser
**Root cause:** In `bignum_lib/fns/constrained_ops.nr` line 190, the code was doing:
```noir
let bits_in_last_byte = num_bits as u8 % 8;
```
When MOD_BITS=256, `num_bits = 512`, which overflows u8 (max 255) before the modulo operation.

**Fix:** Do modulo before casting:
```noir
let bits_in_last_byte = (num_bits % 8) as u8;
```

This function (`derive_from_seed`) is never actually called (it has `assert(false)` guard), but Noir still compiles it and the ACVM in the browser validates all opcodes, triggering the type error.
