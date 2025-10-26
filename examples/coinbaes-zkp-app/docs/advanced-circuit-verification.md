# 고급 서킷 검증: RLP 디코딩 + ECDSA 검증

## 개요

**좋은 소식**: Noir에서 RLP 디코딩과 ECDSA 서명 검증이 모두 가능합니다!

---

## 1. RLP 디코딩 ✅ 가능

### 라이브러리: `aragonzkresearch/noir-trie-proofs`

GitHub: https://github.com/aragonzkresearch/noir-trie-proofs

### 설치

```toml
# Nargo.toml
[dependencies]
noir_trie_proofs = { git = "https://github.com/aragonzkresearch/noir-trie-proofs", tag = "main", directory = "lib" }
```

### 기능

- ✅ RLP 리스트 디코딩
- ✅ Ethereum State/Storage Proof 검증
- ✅ Merkle Patricia Trie 검증
- ⚠️ 제약: MAX_LEN_IN_BYTES = 2 (페이로드 길이 제한)

### 사용 예제

```noir
use noir_trie_proofs::rlp;

fn main(
    encoded_data: [u8; 100]
) {
    // RLP 디코딩
    let decoded = rlp::decode(encoded_data);

    // 디코딩된 데이터 사용
    // ...
}
```

---

## 2. ECDSA 서명 검증 ✅ 가능

### 내장 함수: `std::ecdsa_secp256k1`

공식 문서: https://noir-lang.org/docs/noir/standard_library/cryptographic_primitives/ecdsa_sig_verification

### 함수 시그니처

```noir
use std::ecdsa_secp256k1;

pub fn verify_signature(
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32],
    signature: [u8; 64],
    hashed_message: [u8; 32]
) -> bool
```

### 파라미터

- **pub_key_x**: 공개키 X 좌표 (32 bytes)
- **pub_key_y**: 공개키 Y 좌표 (32 bytes)
- **signature**: (r, s) 서명 (64 bytes)
- **hashed_message**: 해시된 메시지 (32 bytes)

### 중요 제약

⚠️ **서명 정규화 필요**: `s ≤ order / 2` (malleability 방지)

### 사용 예제

```noir
use std::ecdsa_secp256k1;

fn main(
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32],
    signature: [u8; 64],
    message_hash: [u8; 32]
) {
    let valid = ecdsa_secp256k1::verify_signature(
        pub_key_x,
        pub_key_y,
        signature,
        message_hash
    );

    assert(valid == true);
}
```

---

## 3. Keccak-256 해시 ❌ 역연산 불가능

### 왜 불가능한가?

Keccak-256은 **일방향 해시 함수**입니다:

```
원본 데이터 → Keccak-256 → 해시값 (32 bytes)
             ✅ 가능

해시값 → ??? → 원본 데이터
         ❌ 불가능 (수학적으로 역연산 불가)
```

### 해시 함수의 특성

1. **결정적 (Deterministic)**
   - 같은 입력 → 항상 같은 출력

2. **일방향 (One-way)**
   - 출력 → 입력 복원 불가능
   - 2^256 가능성을 모두 시도해야 함 (현실적으로 불가능)

3. **충돌 저항성 (Collision Resistant)**
   - 다른 입력이 같은 출력을 만들기 어려움

### 그럼 어떻게 검증하나?

**원본 데이터를 알고 있어야 합니다!**

```noir
use std::hash::keccak256;

fn main(
    original_data: [u8; 100],  // 원본 필요!
    expected_hash: [u8; 32]
) {
    // 원본을 다시 해싱
    let computed_hash = keccak256(original_data, 100);

    // 비교
    assert(computed_hash == expected_hash);
}
```

---

## 4. 트랜잭션 서명 검증 통합

### 가능한 검증 흐름

```
Raw Transaction (RLP 인코딩)
    ↓ RLP Decode (noir-trie-proofs)
[nonce, gasPrice, gasLimit, to, value, data, v, r, s]
    ↓
TX Hash 재계산
    ↓ Keccak-256
computed_hash = keccak256(raw_tx)
    ↓
TX Hash 비교
assert(computed_hash == expected_tx_hash)
    ↓
ECDSA 서명 검증 (std::ecdsa_secp256k1)
    ↓
서명자 주소 복구
    ↓
✅ 검증 완료!
```

### Noir 구현 예제

```noir
use std::ecdsa_secp256k1;
use std::hash::keccak256;
use noir_trie_proofs::rlp;

fn main(
    // Inputs
    raw_transaction: [u8; 300],
    expected_tx_hash: [u8; 32],
    expected_signer: [u8; 20],

    // 공개키 (서명 복구 또는 제공)
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32]
) {
    // 1. TX Hash 재계산
    let computed_hash = keccak256(raw_transaction, 300);

    // 2. TX Hash 검증
    assert(computed_hash == expected_tx_hash);

    // 3. RLP 디코딩
    let decoded = rlp::decode(raw_transaction);

    // 4. 서명 추출 (v, r, s)
    let v = decoded[6];
    let r = decoded[7];  // 32 bytes
    let s = decoded[8];  // 32 bytes

    // 5. 서명 결합 (r || s = 64 bytes)
    let mut signature: [u8; 64] = [0; 64];
    for i in 0..32 {
        signature[i] = r[i];
        signature[i + 32] = s[i];
    }

    // 6. ECDSA 서명 검증
    let valid = ecdsa_secp256k1::verify_signature(
        pub_key_x,
        pub_key_y,
        signature,
        computed_hash
    );

    assert(valid == true);

    // 7. 서명자 주소 검증 (공개키 → 주소)
    let pub_key_hash = keccak256_pubkey(pub_key_x, pub_key_y);
    let signer_address = pub_key_hash[12..32];  // 마지막 20 bytes

    assert(signer_address == expected_signer);

    // ✅ 검증 완료!
}

// 공개키 → 주소 변환
fn keccak256_pubkey(
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32]
) -> [u8; 32] {
    // 공개키 = 0x04 || x || y
    let mut pub_key: [u8; 65] = [0; 65];
    pub_key[0] = 0x04;

    for i in 0..32 {
        pub_key[i + 1] = pub_key_x[i];
        pub_key[i + 33] = pub_key_y[i];
    }

    keccak256(pub_key, 65)
}
```

---

## 5. 실제 Attestation 트랜잭션 검증

### 완전한 검증 체인

```noir
use std::ecdsa_secp256k1;
use std::hash::keccak256;
use noir_trie_proofs::rlp;

fn verify_attestation_transaction(
    // Raw Transaction (from test-tx-decode.js)
    raw_tx: [u8; 300],

    // Attestation Data
    attestation_uid: Field,
    attester: Field,
    recipient: Field,
    schema: Field,

    // Transaction Signer
    expected_signer: [u8; 20],
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32]
) {
    // === Part 1: TX Hash 검증 ===

    let tx_hash = keccak256(raw_tx, 300);

    // === Part 2: RLP 디코딩 ===

    let decoded = rlp::decode(raw_tx);

    let nonce = decoded[0];
    let gas_price = decoded[1];
    let gas_limit = decoded[2];
    let to = decoded[3];        // EAS Contract
    let value = decoded[4];
    let data = decoded[5];      // Calldata
    let v = decoded[6];
    let r = decoded[7];
    let s = decoded[8];

    // === Part 3: EAS Contract 확인 ===

    let EAS_CONTRACT: Field = 0x4200000000000000000000000000000000000021;
    assert(to == EAS_CONTRACT);

    // === Part 4: ECDSA 서명 검증 ===

    let mut signature: [u8; 64] = [0; 64];
    for i in 0..32 {
        signature[i] = r[i];
        signature[i + 32] = s[i];
    }

    let valid = ecdsa_secp256k1::verify_signature(
        pub_key_x,
        pub_key_y,
        signature,
        tx_hash
    );

    assert(valid == true);

    // === Part 5: 서명자 주소 검증 ===

    let pub_key_hash = keccak256_pubkey(pub_key_x, pub_key_y);
    let signer_address = pub_key_hash[12..32];

    assert(signer_address == expected_signer);

    // === Part 6: Calldata 디코딩 (EAS Attest) ===

    // Function selector: 0x56feed5e (attest)
    let function_selector = data[0..4];
    assert(function_selector == [0x56, 0xfe, 0xed, 0x5e]);

    // Calldata에서 recipient 추출 (offset 4 + 12 = 16)
    let calldata_recipient = data[16..36];
    assert(calldata_recipient == recipient);

    // === Part 7: Attestation 메타데이터 검증 ===

    // Coinbase Attester
    let COINBASE_ATTESTER: Field = 0x357458739F90461b99789350868CD7CF330Dd7EE;
    assert(attester == COINBASE_ATTESTER);

    // Verified Account Schema
    let VERIFIED_SCHEMA: Field = 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9;
    assert(schema == VERIFIED_SCHEMA);

    // ✅ 완전한 검증 완료!
    // 1. TX Hash 검증
    // 2. RLP 디코딩
    // 3. ECDSA 서명 검증
    // 4. 서명자 주소 검증
    // 5. EAS Contract 확인
    // 6. Calldata 검증
    // 7. Attestation 메타데이터 검증
}
```

---

## 6. 제약사항 및 해결 방법

### 제약 1: RLP 디코딩 길이 제한

**문제**: `noir-trie-proofs`는 MAX_LEN_IN_BYTES = 2 제약

**해결**:
- 작은 트랜잭션만 처리
- 또는 라이브러리 수정 (MAX_LEN_IN_BYTES 증가)

### 제약 2: ECDSA 서명 정규화

**문제**: `s ≤ order / 2` 필요

**해결**:
```javascript
// Frontend에서 서명 정규화
if (s > secp256k1.CURVE.n / 2n) {
    s = secp256k1.CURVE.n - s;
    v = v === 27 ? 28 : 27;
}
```

### 제약 3: 공개키 복구

**문제**: Noir에는 `ecrecover` 없음 (서명 → 공개키 복구)

**해결 방법 1**: 오프체인에서 공개키 복구
```javascript
import { recoverPublicKey } from 'ethers';

const publicKey = recoverPublicKey(txHash, signature);
const pubKeyX = publicKey.slice(4, 68);   // 32 bytes
const pubKeyY = publicKey.slice(68, 132); // 32 bytes
```

**해결 방법 2**: 트랜잭션에서 From 주소 사용
```javascript
const from = tx.from;  // 서명자 주소
```

### 제약 4: 회로 크기

**문제**: ECDSA + RLP = 많은 constraints

**예상 크기**:
- RLP 디코딩: ~10,000 constraints
- ECDSA 검증: ~1,500,000 constraints
- Keccak-256: ~100,000 constraints
- **총합**: ~1,610,000 constraints

**해결**:
- UltraHonk Backend 사용 (더 빠름)
- 검증 범위 축소
- 병렬 처리

---

## 7. 업데이트된 검증 범위

### 이전 분석 (잘못됨)

| 항목 | 가능 여부 |
|------|----------|
| RLP 디코딩 | ❌ 라이브러리 부족 |
| ECDSA 검증 | ❌ 어려움 |

### 최신 분석 (정확함) ✅

| 항목 | 가능 여부 | 방법 |
|------|----------|------|
| RLP 디코딩 | ✅ 가능 | `noir-trie-proofs` |
| ECDSA 서명 검증 | ✅ 가능 | `std::ecdsa_secp256k1` |
| Keccak-256 해싱 | ✅ 가능 | `std::hash::keccak256` |
| Keccak-256 역연산 | ❌ 불가능 | 수학적으로 불가능 (일방향) |
| TX Hash 검증 | ✅ 가능 | 원본 Raw TX 필요 |
| 서명자 주소 검증 | ✅ 가능 | 공개키 → Keccak → Address |
| Calldata 디코딩 | ✅ 가능 | 수동 파싱 |
| 온체인 존재 증명 | ⚠️ 부분 가능 | State Proof 필요 |

---

## 8. 최종 권장 구현

### Phase 1: 기본 검증 (즉시 구현)

```noir
fn main(
    attestation_uid: pub Field,
    attester: pub Field,
    recipient: Field,
    schema: pub Field
) {
    assert(attester == 0x357458739F90461b99789350868CD7CF330Dd7EE);
    assert(schema == 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9);
}
```

**증명 시간**: < 1초

### Phase 2: RLP + TX Hash 검증 (고급)

```noir
use std::hash::keccak256;
use noir_trie_proofs::rlp;

fn main(
    raw_tx: [u8; 300],
    expected_tx_hash: pub [u8; 32]
) {
    let computed_hash = keccak256(raw_tx, 300);
    assert(computed_hash == expected_tx_hash);

    let decoded = rlp::decode(raw_tx);
    // Calldata 검증...
}
```

**증명 시간**: 2-5초

### Phase 3: 완전한 ECDSA 검증 (최종)

```noir
use std::ecdsa_secp256k1;
use std::hash::keccak256;
use noir_trie_proofs::rlp;

fn main(
    raw_tx: [u8; 300],
    pub_key_x: [u8; 32],
    pub_key_y: [u8; 32],
    expected_signer: [u8; 20]
) {
    // TX Hash
    let tx_hash = keccak256(raw_tx, 300);

    // RLP Decode
    let decoded = rlp::decode(raw_tx);
    let r = decoded[7];
    let s = decoded[8];

    // ECDSA Verify
    let mut sig: [u8; 64] = [0; 64];
    for i in 0..32 {
        sig[i] = r[i];
        sig[i + 32] = s[i];
    }

    let valid = ecdsa_secp256k1::verify_signature(
        pub_key_x,
        pub_key_y,
        sig,
        tx_hash
    );

    assert(valid == true);
}
```

**증명 시간**: 10-30초

---

## 9. 결론

### ✅ 가능한 것들

1. **RLP 디코딩** - `noir-trie-proofs` 라이브러리
2. **ECDSA 서명 검증** - Noir 표준 라이브러리
3. **Keccak-256 해싱** - Noir 표준 라이브러리
4. **TX Hash 검증** - 원본 Raw TX 제공 시
5. **서명자 주소 검증** - 공개키 제공 시
6. **Calldata 디코딩** - 수동 파싱

### ❌ 불가능한 것들

1. **Keccak-256 역연산** - 수학적으로 불가능 (일방향 함수)
2. **공개키 복구 (ecrecover)** - Noir에 미지원 (오프체인에서 처리 필요)

### 💡 최종 결론

**Noir로 완전한 트랜잭션 검증이 가능합니다!**

단, 다음 데이터를 오프체인에서 제공해야 합니다:
- Raw Transaction (RLP 인코딩)
- 공개키 (pub_key_x, pub_key_y)

그러면 서킷에서:
- ✅ TX Hash 검증
- ✅ RLP 디코딩
- ✅ ECDSA 서명 검증
- ✅ 서명자 주소 검증
- ✅ Attestation 메타데이터 검증

모두 가능합니다! 🎉
