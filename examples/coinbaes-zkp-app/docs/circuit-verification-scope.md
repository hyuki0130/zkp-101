# Noir 서킷 검증 범위 분석

## 개요

Attestation Transaction 데이터 중 **어디까지 Noir 서킷에서 검증 가능한지** 분석합니다.

---

## Noir Oracle의 이해

### Oracle이란?

```noir
#[oracle(functionName)]
unconstrained fn oracle_func(input: Field) -> Field { }

unconstrained fn call_oracle(input: Field) -> Field {
    oracle_func(input)
}
```

- **Unconstrained 함수**: ZK 회로 외부에서 실행
- **외부 데이터 조회** 가능
- **제약 조건 없음** (검증 불가)
- **반드시 추가 검증 필요**

### ⚠️ 중요한 제약사항

1. **Oracle 결과는 신뢰할 수 없음**
   - Oracle은 단순히 외부에서 데이터를 **가져올 뿐**
   - 가져온 데이터가 **정확한지 검증 필요**

2. **외부 Resolver 필요**
   - Nargo: `--oracle-resolver http://localhost:5555`
   - NoirJS: `foreignCallHandler` 콜백 함수

3. **계산 비용 높음**
   - Oracle 호출은 비싸므로 최소화 권장

---

## Attestation 데이터 검증 범위

### 현재 `test-tx-decode.js`에서 추출 가능한 데이터

```javascript
// 1. Attestation 기본 정보
{
  uid: '0x626de1...',
  recipient: '0xD6C71...',
  attester: '0x35745...',
  schema: '0xf8b05...',
  time: 1761146667,
  expirationTime: 0,
  revoked: false,
  decodedData: { verifiedAccount: true }
}

// 2. Transaction 데이터
{
  from: '0x952f3...',
  to: '0x35745...',  // EAS Contract
  nonce: 304602,
  gasLimit: 600000,
  gasPrice: '0.052558327 gwei',
  value: '0 ETH',
  chainId: 8453,  // Base Mainnet
  data: '0x56feed5e...',  // Calldata
}

// 3. Raw Transaction (RLP 인코딩)
rawTx: '0x02f8928221058304a5da...'

// 4. 서명 정보
{
  v: 28,
  r: '0x379321c817d35f4a180eea0abdba303ba40650279b5bc7e6802145f994f2cdf1',
  s: '0x3525ce1bf6f01506b31c1dd8921908f2f0b74317c2a5069e17902ff32faa1bc0'
}

// 5. Attested Event (Receipt)
{
  recipient: '0xd6c71...',
  attester: '0x35745...',
  schemaUID: '0xf8b05...',
  attestationUID: '0x626de1...'
}
```

---

## 서킷 검증 가능 범위 분석

### ✅ 레벨 1: 오프체인 데이터 검증 (현재 가능)

**입력 방식**: 프론트엔드에서 조회 → 서킷에 전달

```noir
// circuit/attestor/src/main.nr

fn main(
    // Private inputs (비공개)
    user_address: Field,
    user_signature: [u8; 64],

    // Public inputs (공개, 오프체인에서 조회)
    attestation_uid: Field,
    attester: Field,
    schema: Field,
    recipient: Field,
    time: Field,
    expiration_time: Field,
    revocation_time: Field
) {
    // 1. Recipient 검증
    assert(recipient == user_address);

    // 2. Attester 검증 (Coinbase)
    let expected_attester: Field = 0x357458739F90461b99789350868CD7CF330Dd7EE;
    assert(attester == expected_attester);

    // 3. Schema 검증
    let expected_schema: Field = 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9;
    assert(schema == expected_schema);

    // 4. 만료 확인
    assert(expiration_time == 0 || expiration_time > time);

    // 5. 취소 확인
    assert(revocation_time == 0);

    // ✅ 검증 완료: 사용자가 올바른 Coinbase Attestation 보유
}
```

**한계점**:
- 오프체인에서 가져온 데이터를 **신뢰**해야 함
- 사용자가 **잘못된 데이터**를 입력하면 검증 의미 없음

---

### ✅ 레벨 2: Oracle + 검증 (부분적 가능)

**입력 방식**: Oracle로 조회 → 서킷에서 검증

```noir
// circuit/attestor/src/main.nr

// Oracle 정의
#[oracle(getAttestation)]
unconstrained fn fetch_attestation(uid: Field) -> [Field; 7] { }

unconstrained fn get_attestation(uid: Field) -> [Field; 7] {
    fetch_attestation(uid)
}

fn main(
    user_address: Field,
    attestation_uid: pub Field
) {
    // 1. Oracle로 Attestation 조회 (unconstrained)
    let attestation = get_attestation(attestation_uid);

    // 2. 조회된 데이터 검증 (constrained)
    let recipient = attestation[0];
    let attester = attestation[1];
    let schema = attestation[2];

    assert(recipient == user_address);
    assert(attester == 0x357458739F90461b99789350868CD7CF330Dd7EE);
    assert(schema == 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9);

    // ✅ Oracle 데이터를 검증 완료
}
```

**외부 Oracle Resolver 구현**:

```javascript
// oracle-resolver.js
import express from 'express';
import { getAttestations } from '@coinbase/onchainkit/identity';
import { base } from 'viem/chains';

const app = express();
app.use(express.json());

app.post('/oracle', async (req, res) => {
    const { functionName, params } = req.body;

    if (functionName === 'getAttestation') {
        const uid = params[0];

        // Attestation 조회
        const attestations = await getAttestations(userAddress, base, {
            schemas: [VERIFIED_ACCOUNT_SCHEMA],
        });

        const attestation = attestations.find(a => a.id === uid);

        if (!attestation) {
            return res.status(404).json({ error: 'Attestation not found' });
        }

        // 서킷 형식으로 반환
        res.json({
            result: [
                attestation.recipient,
                attestation.attester,
                attestation.schemaId,
                attestation.time,
                attestation.expirationTime,
                attestation.revocationTime,
                attestation.revoked ? 1 : 0
            ]
        });
    }
});

app.listen(5555, () => {
    console.log('Oracle resolver running on http://localhost:5555');
});
```

**한계점**:
- Oracle Resolver를 **신뢰**해야 함
- Resolver가 거짓 데이터를 반환하면 검증 무의미
- **중앙화 문제**

---

### ⚠️ 레벨 3: 트랜잭션 서명 검증 (매우 어려움)

**목표**: 트랜잭션이 실제로 온체인에 존재함을 검증

```noir
// ECDSA 서명 검증 필요
fn main(
    raw_transaction: [u8; 300],
    tx_hash: Field,
    v: u8,
    r: [u8; 32],
    s: [u8; 32]
) {
    // 1. Raw Transaction 해싱
    let computed_hash = keccak256(raw_transaction);

    // 2. TX Hash 일치 확인
    assert(computed_hash == tx_hash);

    // 3. ECDSA 서명 검증 (매우 복잡)
    let recovered_address = ecdsa_recover(tx_hash, v, r, s);
    assert(recovered_address == expected_signer);

    // 4. RLP 디코딩 (매우 복잡)
    let decoded = rlp_decode(raw_transaction);

    // ❌ 문제: Noir에는 기본 ECDSA, RLP 라이브러리 부족
}
```

**한계점**:
- Noir에 **ECDSA 복구** 기능 부족
- Noir에 **RLP 디코딩** 라이브러리 부족
- **회로 크기 폭발** (수백만 constraints)

**가능한 대안**:
- **SP1** 또는 **RISC Zero** 같은 zkVM 사용
- **Ethereum State/Storage Proofs** 활용

---

### ✅ 레벨 4: Merkle Proof 검증 (권장)

**가장 실용적인 방법**: Ethereum State Proof

```noir
// circuit/attestor/src/main.nr
use noir_trie_proofs::storage_proof;

fn main(
    attestation_uid: pub Field,
    storage_proof: StorageProof,
    block_hash: Field,
    state_root: Field
) {
    // 1. Storage Proof 검증
    let verified = storage_proof::verify(
        storage_proof,
        state_root,
        EAS_CONTRACT_ADDRESS,
        attestation_uid
    );

    assert(verified == true);

    // 2. Block Hash 검증 (오프체인에서 제공)
    // ⚠️ 여전히 Block Hash를 신뢰해야 함

    // ✅ Attestation이 온체인에 존재함을 검증
}
```

**필요한 라이브러리**:
- `aragonzkresearch/noir-trie-proofs`
- Ethereum State/Storage Proof 생성 도구

**한계점**:
- Block Hash를 **신뢰**해야 함
- 라이트 클라이언트 구현 필요 (매우 복잡)

---

## 실제 구현 가능한 범위

### ✅ 즉시 구현 가능 (권장)

**방법**: 오프체인 데이터 → 서킷 검증

```
Frontend (JS)
    ↓
1. Attestation 조회 (OnchainKit API)
2. TX Hash → Raw Transaction (RPC)
3. 모든 데이터 추출
    ↓
Noir Circuit
    ↓
4. Private: user_address, signature
5. Public: attestation_uid, attester, schema, etc.
    ↓
6. 검증:
   - Recipient == user_address
   - Attester == Coinbase
   - Schema == Verified Account
   - Not expired
   - Not revoked
    ↓
7. ZK Proof 생성
    ↓
Verifier (Onchain/Offchain)
    ↓
8. Proof 검증
```

**장점**:
- ✅ 구현 간단
- ✅ 회로 크기 작음 (빠른 증명 생성)
- ✅ 개인정보 보호 (user_address 비공개)

**단점**:
- ❌ 오프체인 데이터 신뢰 필요
- ❌ 사용자가 거짓 데이터 입력 가능 (검증 의미 약화)

---

### 🔄 중간 수준 구현 (고급)

**방법**: Oracle + 검증

```
Frontend (JS)
    ↓
1. Attestation UID만 입력
    ↓
Noir Circuit + Oracle Resolver
    ↓
2. Oracle로 Attestation 조회
3. Oracle Resolver가 EAS API 호출
4. 데이터 반환
    ↓
5. 서킷에서 검증
   - Attester == Coinbase
   - Schema 확인
   - Expiration 확인
    ↓
6. ZK Proof 생성
```

**장점**:
- ✅ 사용자 입력 최소화
- ✅ Oracle Resolver 재사용 가능

**단점**:
- ❌ Oracle Resolver 신뢰 필요
- ❌ 중앙화 문제
- ❌ Resolver 운영 필요

---

### ⚡ 최고 수준 구현 (연구 단계)

**방법**: Ethereum State Proof + zkEVM

```
Frontend
    ↓
1. Attestation UID
2. Ethereum State Proof 생성
    ↓
Noir Circuit (or zkEVM)
    ↓
3. State Proof 검증
4. Attestation 온체인 존재 증명
5. ECDSA 서명 검증 (zkEVM)
6. RLP 디코딩 (zkEVM)
    ↓
7. ZK Proof 생성
```

**장점**:
- ✅ 완전한 탈중앙화
- ✅ 외부 신뢰 불필요
- ✅ 가장 강력한 보안

**단점**:
- ❌ 구현 매우 복잡
- ❌ 증명 생성 매우 느림 (수 분)
- ❌ 회로 크기 거대
- ❌ 현재 Noir로는 어려움 (SP1, RISC Zero 권장)

---

## 권장 구현 방안

### Phase 1: MVP (즉시 구현)

```noir
// circuit/attestor/src/main.nr

fn main(
    // Private
    user_address: Field,

    // Public (오프체인에서 조회)
    attestation_uid: pub Field,
    attester: pub Field,
    schema: pub Field,
    recipient: pub Field,
    expiration_time: pub Field,
    revocation_time: pub Field
) {
    // 검증
    assert(recipient == user_address);
    assert(attester == 0x357458739F90461b99789350868CD7CF330Dd7EE);
    assert(schema == 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9);
    assert(expiration_time == 0 || expiration_time > current_time);
    assert(revocation_time == 0);
}
```

**구현 시간**: 1-2일
**증명 생성 시간**: < 1초

---

### Phase 2: Oracle 통합 (고급)

```noir
#[oracle(getAttestation)]
unconstrained fn fetch_attestation(uid: Field) -> [Field; 7] { }

unconstrained fn get_attestation(uid: Field) -> [Field; 7] {
    fetch_attestation(uid)
}

fn main(
    user_address: Field,
    attestation_uid: pub Field
) {
    let attestation = get_attestation(attestation_uid);

    assert(attestation[0] == user_address);  // recipient
    assert(attestation[1] == 0x357458739F90461b99789350868CD7CF330Dd7EE);  // attester
    // ...
}
```

**구현 시간**: 3-5일 (Oracle Resolver 포함)
**증명 생성 시간**: < 2초

---

### Phase 3: State Proof (연구)

```noir
use noir_trie_proofs::storage_proof;

fn main(
    attestation_uid: pub Field,
    storage_proof: StorageProof,
    state_root: Field
) {
    let verified = storage_proof::verify(
        storage_proof,
        state_root,
        EAS_CONTRACT_ADDRESS,
        attestation_uid
    );

    assert(verified == true);
}
```

**구현 시간**: 2-4주
**증명 생성 시간**: 5-10초
**필요 라이브러리**: `noir-trie-proofs`

---

## 결론

### 서킷에서 검증 가능한 범위

| 검증 항목 | 레벨 1 (MVP) | 레벨 2 (Oracle) | 레벨 3 (State Proof) |
|----------|--------------|-----------------|---------------------|
| Recipient 검증 | ✅ | ✅ | ✅ |
| Attester 검증 | ✅ | ✅ | ✅ |
| Schema 검증 | ✅ | ✅ | ✅ |
| Expiration 검증 | ✅ | ✅ | ✅ |
| Revocation 검증 | ✅ | ✅ | ✅ |
| 온체인 존재 증명 | ❌ | ⚠️ (Resolver 신뢰) | ✅ |
| ECDSA 서명 검증 | ❌ | ❌ | ⚠️ (zkEVM 필요) |
| RLP 디코딩 | ❌ | ❌ | ⚠️ (라이브러리 부족) |

### 추천

**현재 프로젝트**: **레벨 1 (MVP)** 구현
- 빠른 개발
- 충분한 보안 (Verifier 온체인 배포 시)
- 실용적인 성능

**향후 개선**: **레벨 2 (Oracle)** 또는 **레벨 3 (State Proof)**
- 더 강력한 탈중앙화
- 사용자 경험 개선
- 연구 및 실험 가치

---

## 참고 자료

- [Noir Oracles Documentation](https://noir-lang.org/docs/how_to/how-to-oracles)
- [aragonzkresearch/noir-trie-proofs](https://github.com/aragonzkresearch/noir-trie-proofs)
- [Ethereum State Proofs](https://ethereum.org/developers/docs/data-structures-and-encoding/patricia-merkle-trie/)
- [SP1 zkVM](https://github.com/succinctlabs/sp1)
- [RISC Zero](https://www.risczero.com/)
