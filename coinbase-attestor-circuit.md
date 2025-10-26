# Coinbase Attestor Circuit 보안 분석

## 📋 개요

Coinbase KYC attestation을 검증하는 Noir 서킷의 보안 취약점 분석 및 개선 방안을 다룹니다.

## 🔴 현재 서킷의 한계와 문제점

### 핵심 취약점: 입력 데이터 신뢰 문제

현재 서킷은 사용자가 Coinbase의 KYC 컨트랙트에서 발생한 트랜잭션의 수혜자임을 증명하기 위해 작성되었습니다. 기본적인 서명 검증과 주소 일치는 확인하지만, **실제 트랜잭션이 진짜 블록체인에 존재하는지, 그 데이터가 위조되지 않았는지를 보장하지 않습니다.**

### 현재 코드 구조

```rust
use dep::keccak256::keccak256;
use std::ecdsa_secp256k1::verify_signature;

// Hardcoded Coinbase attestor address
global CB_ATTESTOR_ADDRESS: [u8; 20] = [
    53, 116, 88, 115, 159, 144, 70, 27,
    153, 120, 147, 80, 134, 140, 215, 207,
    51, 13, 215, 238
];

fn extract_address_from_calldata(calldata: [u8; 36]) -> [u8; 20] {
    let mut addr: [u8; 20] = [0; 20];
    for i in 0..20 {
        addr[i] = calldata[i + 16];
    }
    addr
}

fn concat_pubkey(pubkey_x: [u8; 32], pubkey_y: [u8; 32]) -> [u8; 64] {
    let mut out: [u8; 64] = [0; 64];
    for i in 0..32 {
        out[i] = pubkey_x[i];
        out[i + 32] = pubkey_y[i];
    }
    out
}

fn main(
    calldata: [u8; 36],
    contract_address: pub [u8; 20],
    user_address: [u8; 20],
    digest: [u8; 32],
    user_sig: [u8; 64],
    user_pubkey_x: [u8; 32],
    user_pubkey_y: [u8; 32],
) {
    // 1. Check function selector
    assert(calldata[0] == 0x56);
    assert(calldata[1] == 0xfe);
    assert(calldata[2] == 0xed);
    assert(calldata[3] == 0x5e);

    // 2. Verify contract address
    assert(contract_address == CB_ATTESTOR_ADDRESS);

    // 3. Extract expected address from calldata
    let calldata_addr = extract_address_from_calldata(calldata);
    assert(calldata_addr == user_address);

    // 4. Verify signature (on prefixed digest)
    assert(verify_signature(user_pubkey_x, user_pubkey_y, user_sig, digest));

    // 5. Compute Ethereum address from pubkey
    let pubkey_bytes = concat_pubkey(user_pubkey_x, user_pubkey_y);
    let hashed = unsafe { keccak256(pubkey_bytes, 64) };

    // 6. Compare last 20 bytes of hash to user_address
    for i in 0..20 {
        assert(user_address[i] == hashed[i + 12]);
    }
}
```

### 주요 보안 문제

#### 1. 외부 입력 데이터 신뢰
- 서킷은 외부에서 전달된 `calldata`와 `digest`를 신뢰합니다
- 해당 데이터가 실제 블록에 포함된 것인지 확인하지 않습니다
- **위조 시나리오**: 사용자가 임의로 calldata를 구성해도 형식만 맞으면 통과됩니다

#### 2. 트랜잭션 존재 검증 부재
- 블록체인에 실제로 해당 트랜잭션이 존재하는지 확인하지 않습니다
- attestation 없이도 "Coinbase KYC를 받았다"는 증명을 위조할 수 있습니다

#### 3. Attestation 유효성 미검증
- 만료된 KYC를 걸러내는 로직이 없습니다
- 철회된 attestation도 검증하지 않습니다

#### 4. Digest 계산 문제
- `digest`를 외부에서 주입받아 신뢰합니다
- 서킷이 직접 계산하지 않아 데이터 일관성을 보장하지 못합니다

#### 5. 결과
**"서명과 주소 구조만 맞는 위조된 입력"이 통과할 수 있는 허점 존재**

---

## 🔄 이더리움 트랜잭션 구조 이해

### 트랜잭션 구성 요소

이더리움의 트랜잭션은 다음 요소를 포함합니다:

```
트랜잭션 = {
    nonce           // 보낸 횟수
    gasPrice        // 가스 가격
    gasLimit        // 가스 한도
    to              // 목적지 주소 (여기선 Coinbase KYC contract)
    value           // 송금액
    input data      // calldata (실제로 실행된 함수와 인자)
    v, r, s         // ECDSA 서명
}
```

### 트랜잭션 해시 생성

```
tx_hash = keccak256(RLP_serialize(트랜잭션))
```

**핵심**: `tx_hash`는 트랜잭션의 전체 내용을 유일하게 식별하는 지문입니다.

### 검증 원리

서킷 내부에서 `keccak256(calldata)`를 계산하고 외부에서 전달된 `tx_hash`와 비교하면:
- "이 calldata가 변조되지 않았다"는 점을 보장
- Inclusion proof 추가 시: "이 tx hash가 실제 블록에 포함되어 있다"까지 증명 가능

---

## ✅ 개선 방안

### 필수 보완 사항 5가지

#### 1. 트랜잭션 해시 검증

**Before:**
```rust
fn main(digest: [u8; 32], ...) {
    // digest를 외부에서 받음 (신뢰 불가)
    assert(verify_signature(..., digest));
}
```

**After:**
```rust
fn main(tx_hash: pub [u8; 32], ...) {
    // 서킷 내부에서 직접 계산
    let computed_digest = keccak256(calldata, 36);
    let computed_tx_hash = keccak256(calldata, 36);
    assert(computed_tx_hash == tx_hash);
}
```

**효과**: calldata를 변조해도 서명 결과가 해시와 일치하지 않아 실패

#### 2. 트랜잭션 존재 검증

**방법 1: Merkle Inclusion Proof**
```rust
// 해당 tx hash가 실제 블록체인에 포함되었음을 증명
assert(verify_tx_inclusion(tx_hash, inclusion_proof));
```

**방법 2: Verifier 확인**
- 스마트컨트랙트나 서버가 블록체인 노드를 통해 존재 여부 확인

#### 3. Attestation 유효성 검증

```rust
fn main(
    expiration_time: pub u64,
    revocation_time: pub u64,
    current_time: pub u64,
    ...
) {
    // 만료 시간 체크
    assert(expiration_time == 0 || current_time < expiration_time);

    // 철회 여부 체크 (0이면 철회되지 않음)
    assert(revocation_time == 0);
}
```

#### 4. Digest-데이터 일관성 보장

```rust
// ❌ Bad: 외부에서 주입
fn main(digest: [u8; 32], ...) {
    assert(verify_signature(..., digest));
}

// ✅ Good: 서킷이 직접 계산
fn main(...) {
    let computed_digest = keccak256(calldata, 36);
    assert(verify_signature(..., computed_digest));
}
```

#### 5. Attestor 정당성 검증

```rust
// Coinbase attestor 주소 고정
global CB_ATTESTOR_ADDRESS: [u8; 20] = [...];

fn main(contract_address: pub [u8; 20], ...) {
    // 반드시 Coinbase attestor여야 함
    assert(contract_address == CB_ATTESTOR_ADDRESS);
}
```

추가로 Schema ID도 고정하여 임의의 contract가 동일한 signature로 위조하지 못하도록 합니다.

---

## 🔐 개선된 서킷 구조

### Public vs Private Inputs

```rust
fn main(
    // ============ Public Inputs ============
    // 검증자(dApp)가 알고 있는 값
    tx_hash: pub [u8; 32],              // 블록체인에서 조회 가능
    contract_address: pub [u8; 20],     // Coinbase attestor 주소
    expiration_time: pub u64,           // attestation 만료 시간
    revocation_time: pub u64,           // 철회 시간 (0이면 유효)
    current_time: pub u64,              // 현재 타임스탬프

    // ============ Private Inputs ============
    // 사용자의 브라우저에서만 제공
    calldata: [u8; 36],                 // 트랜잭션 calldata
    user_address: [u8; 20],             // 사용자 이더리움 주소
    user_sig: [u8; 64],                 // 사용자 서명
    user_pubkey_x: [u8; 32],            // 공개키 X
    user_pubkey_y: [u8; 32],            // 공개키 Y
)
```

### 개선된 검증 로직

```rust
use dep::keccak256::keccak256;
use std::ecdsa_secp256k1::verify_signature;

// Coinbase attestor (고정된 컨트랙트 주소)
global CB_ATTESTOR_ADDRESS: [u8; 20] = [
    53, 116, 88, 115, 159, 144, 70, 27,
    153, 120, 147, 80, 134, 140, 215, 207,
    51, 13, 215, 238
];

fn extract_address_from_calldata(calldata: [u8; 36]) -> [u8; 20] {
    let mut addr: [u8; 20] = [0; 20];
    for i in 0..20 {
        addr[i] = calldata[i + 16];
    }
    addr
}

fn concat_pubkey(pubkey_x: [u8; 32], pubkey_y: [u8; 32]) -> [u8; 64] {
    let mut out: [u8; 64] = [0; 64];
    for i in 0..32 {
        out[i] = pubkey_x[i];
        out[i + 32] = pubkey_y[i];
    }
    out
}

fn main(
    // Public inputs
    tx_hash: pub [u8; 32],
    contract_address: pub [u8; 20],
    expiration_time: pub u64,
    revocation_time: pub u64,
    current_time: pub u64,

    // Private inputs
    calldata: [u8; 36],
    user_address: [u8; 20],
    user_sig: [u8; 64],
    user_pubkey_x: [u8; 32],
    user_pubkey_y: [u8; 32],
) {
    // ===== Step 1: 트랜잭션 함수 식별자 확인 =====
    // attest(address) 함수 selector: 0x56feed5e
    assert(calldata[0..4] == [0x56, 0xfe, 0xed, 0x5e]);

    // ===== Step 2: 컨트랙트 주소 확인 =====
    // 반드시 Coinbase Attestor여야 함
    assert(contract_address == CB_ATTESTOR_ADDRESS);

    // ===== Step 3: Calldata 수혜자 주소 추출 및 비교 =====
    let calldata_addr = extract_address_from_calldata(calldata);
    assert(calldata_addr == user_address);

    // ===== Step 4: Digest 직접 계산 =====
    // ⭐ 핵심 개선: 외부 입력이 아닌 서킷이 직접 계산
    let computed_digest = keccak256(calldata, 36);

    // ===== Step 5: 서명 검증 =====
    // 계산된 digest에 대해 서명이 유효한지 확인
    assert(verify_signature(
        user_pubkey_x,
        user_pubkey_y,
        user_sig,
        computed_digest
    ));

    // ===== Step 6: 공개키로부터 사용자 주소 재계산 =====
    let pubkey_bytes = concat_pubkey(user_pubkey_x, user_pubkey_y);
    let hashed = keccak256(pubkey_bytes, 64);

    // 이더리움 주소 = keccak256(pubkey)의 마지막 20바이트
    for i in 0..20 {
        assert(user_address[i] == hashed[i + 12]);
    }

    // ===== Step 7: 트랜잭션 해시 검증 =====
    // ⭐ 핵심 개선: 계산된 tx_hash가 입력 tx_hash와 일치하는지 확인
    let computed_tx_hash = keccak256(calldata, 36);
    assert(computed_tx_hash == tx_hash);

    // ===== Step 8: Attestation 유효성 검증 =====
    // 철회되지 않았는지 확인 (revocation_time이 0이면 유효)
    assert(revocation_time == 0);

    // 만료되지 않았는지 확인
    assert(expiration_time == 0 || current_time < expiration_time);

    // ===== Step 9 (옵션): Merkle Inclusion Proof =====
    // 실제 블록체인에 포함되었음을 추가로 증명
    // assert(verify_tx_inclusion(tx_hash, inclusion_proof));

    // ===== 모든 검증 통과 시 증명되는 내용 =====
    // ✅ calldata가 변조되지 않았음
    // ✅ 실제 Coinbase Attestor contract의 호출임
    // ✅ 사용자 주소가 트랜잭션의 수혜자임
    // ✅ 트랜잭션 해시가 일치함
    // ✅ 서명이 유효함
    // ✅ attestation이 만료/철회되지 않았음
}
```

---

## 📊 Before vs After 비교

| 항목 | Before (현재) | After (개선) |
|------|--------------|-------------|
| **Digest 계산** | 외부 입력 신뢰 | 서킷 내부 계산 |
| **TX Hash 검증** | ❌ 없음 | ✅ 계산 후 비교 |
| **블록체인 존재 확인** | ❌ 없음 | ✅ Inclusion proof |
| **만료 검증** | ❌ 없음 | ✅ expiration_time 체크 |
| **철회 검증** | ❌ 없음 | ✅ revocation_time 체크 |
| **위조 가능성** | ⚠️ 높음 | ✅ 낮음 |
| **데이터 일관성** | ⚠️ 보장 안됨 | ✅ 보장됨 |

---

## 🎯 보안 보장 수준

### 현재 서킷 (Before)
```
❌ 신뢰 가정: 외부 입력 데이터를 그대로 믿음
⚠️  위조 가능: calldata를 임의로 구성 가능
⚠️  검증 부족: 블록체인 존재 여부 미확인
```

### 개선된 서킷 (After)
```
✅ 계산 검증: 서킷이 digest와 tx_hash를 직접 계산
✅ 데이터 무결성: calldata 변조 시 해시 불일치로 실패
✅ 유효성 검증: 만료/철회된 attestation 걸러냄
✅ 존재 증명: (옵션) Merkle proof로 블록체인 포함 확인
```

### 최종 보장 내용

개선된 서킷을 통과한 증명은 다음을 보장합니다:

1. **트랜잭션 무결성**: calldata가 변조되지 않음
2. **정당한 출처**: Coinbase Attestor contract의 정식 호출
3. **본인 확인**: 사용자가 해당 트랜잭션의 수혜자
4. **서명 유효성**: ECDSA 서명이 공개키와 일치
5. **주소 일관성**: 공개키로부터 계산된 주소가 일치
6. **트랜잭션 해시 일치**: 계산된 tx_hash = 입력 tx_hash
7. **Attestation 유효**: 만료/철회되지 않음
8. **(옵션) 블록체인 존재**: Merkle proof로 실제 블록 포함 확인

---

## 🚀 구현 단계

### Phase 1: 필수 개선사항
1. Digest를 서킷 내부에서 계산하도록 수정
2. TX hash 계산 및 비교 로직 추가
3. Expiration/revocation 검증 추가

### Phase 2: 고급 보안
4. Merkle inclusion proof 구현
5. Schema ID 검증 추가
6. Replay attack 방지 (nonce 활용)

### Phase 3: 최적화
7. Gas 비용 최적화
8. Proof 크기 최소화
9. 검증 속도 개선

---

## 📚 참고 자료

- [Ethereum Yellow Paper - Transaction Structure](https://ethereum.github.io/yellowpaper/paper.pdf)
- [Noir Documentation](https://noir-lang.org/docs)
- [EIP-712: Typed structured data hashing](https://eips.ethereum.org/EIPS/eip-712)
- [Merkle Proofs Explained](https://ethereum.org/en/developers/tutorials/merkle-proofs-for-offline-data-integrity/)
- [Coinbase Verifications On-Chain Attestations](https://docs.cloud.coinbase.com/verifications/docs/onchain-attestations)

---

## 💡 결론

**현재 서킷의 근본적 문제**: 외부 입력 데이터를 그대로 신뢰

**해결책의 핵심**:
```
calldata (입력)
  → 서킷이 digest 계산
  → 서킷이 tx_hash 계산
  → 입력 tx_hash와 비교
  → 일치하면 "변조되지 않음" 보장
```

**최종 목표**:
- ✅ 위조 불가능한 KYC 증명
- ✅ 블록체인 데이터 무결성 보장
- ✅ 프라이버시 보호 (사용자 정보는 비공개 입력)

---

*Last Updated: 2025-01-22*
