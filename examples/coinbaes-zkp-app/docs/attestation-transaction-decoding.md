# Attestation 트랜잭션 디코딩 가이드

## 개요

Coinbase Attestation의 `txid` (Transaction Hash)를 사용하여:
1. 온체인에서 Raw Transaction 데이터 조회
2. RLP 디코딩으로 트랜잭션 필드 추출
3. Attestation 생성에 사용된 정확한 파라미터 확인

---

## 전체 흐름

```
┌─────────────────────┐
│  Attestation Data   │
│  (from EAS API)     │
└──────────┬──────────┘
           │
           │ txid (tx_hash)
           ▼
┌─────────────────────┐
│  RPC Provider       │
│  eth_getTransaction │
│  ByHash             │
└──────────┬──────────┘
           │
           │ Raw Transaction
           ▼
┌─────────────────────┐
│  RLP Decoder        │
└──────────┬──────────┘
           │
           │ Decoded Fields
           ▼
┌─────────────────────┐
│  - nonce            │
│  - gasPrice         │
│  - gasLimit         │
│  - to (EAS_CONTRACT)│
│  - value            │
│  - data (calldata)  │
│  - v, r, s          │
└─────────────────────┘
```

---

## 1단계: Transaction Hash로 데이터 조회

### JavaScript (ethers.js)

```javascript
import { ethers } from 'ethers';

async function getTransactionByHash(txHash) {
    // Base Mainnet RPC
    const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');

    // Transaction 조회
    const tx = await provider.getTransaction(txHash);

    if (!tx) {
        throw new Error('Transaction not found');
    }

    console.log('📦 Transaction Data:');
    console.log('  From:', tx.from);
    console.log('  To:', tx.to);
    console.log('  Nonce:', tx.nonce);
    console.log('  Gas Limit:', tx.gasLimit?.toString());
    console.log('  Gas Price:', tx.gasPrice?.toString());
    console.log('  Value:', ethers.formatEther(tx.value || 0), 'ETH');
    console.log('  Data:', tx.data);
    console.log('  Chain ID:', tx.chainId);
    console.log('  v:', tx.signature?.v);
    console.log('  r:', tx.signature?.r);
    console.log('  s:', tx.signature?.s);

    return tx;
}
```

### 실행 예제

```javascript
// Attestation에서 가져온 txid
const attestationTxHash = '0x123abc...';

const tx = await getTransactionByHash(attestationTxHash);
```

---

## 2단계: Raw Transaction 가져오기

### Method 1: ethers.js로 직렬화

```javascript
async function getRawTransaction(txHash) {
    const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
    const tx = await provider.getTransaction(txHash);

    // Transaction 객체를 Raw Transaction으로 직렬화
    const rawTx = ethers.Transaction.from(tx).serialized;

    console.log('📜 Raw Transaction:', rawTx);

    return rawTx;
}
```

### Method 2: RPC 직접 호출

```javascript
async function getRawTransactionRPC(txHash) {
    const response = await fetch('https://mainnet.base.org', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'eth_getRawTransactionByHash',
            params: [txHash],
            id: 1
        })
    });

    const result = await response.json();

    if (result.error) {
        throw new Error(result.error.message);
    }

    console.log('📜 Raw Transaction:', result.result);

    return result.result;
}
```

---

## 3단계: RLP 디코딩

### JavaScript RLP 디코딩

```javascript
import { RLP } from '@ethereumjs/rlp';
import { hexToBytes } from '@ethereumjs/util';

function decodeRawTransaction(rawTx) {
    // 0x 제거
    const cleanHex = rawTx.startsWith('0x') ? rawTx.slice(2) : rawTx;

    // Hex를 바이트로 변환
    const txBytes = hexToBytes(cleanHex);

    // RLP 디코딩
    const decoded = RLP.decode(txBytes);

    // Legacy Transaction 형식 (9개 필드)
    const [
        nonce,
        gasPrice,
        gasLimit,
        to,
        value,
        data,
        v,
        r,
        s
    ] = decoded;

    console.log('🔓 Decoded Transaction:');
    console.log('  Nonce:', Buffer.from(nonce).toString('hex'));
    console.log('  Gas Price:', Buffer.from(gasPrice).toString('hex'));
    console.log('  Gas Limit:', Buffer.from(gasLimit).toString('hex'));
    console.log('  To:', '0x' + Buffer.from(to).toString('hex'));
    console.log('  Value:', Buffer.from(value).toString('hex'));
    console.log('  Data:', '0x' + Buffer.from(data).toString('hex'));
    console.log('  v:', Buffer.from(v).toString('hex'));
    console.log('  r:', '0x' + Buffer.from(r).toString('hex'));
    console.log('  s:', '0x' + Buffer.from(s).toString('hex'));

    return {
        nonce: '0x' + Buffer.from(nonce).toString('hex'),
        gasPrice: '0x' + Buffer.from(gasPrice).toString('hex'),
        gasLimit: '0x' + Buffer.from(gasLimit).toString('hex'),
        to: '0x' + Buffer.from(to).toString('hex'),
        value: '0x' + Buffer.from(value).toString('hex'),
        data: '0x' + Buffer.from(data).toString('hex'),
        v: '0x' + Buffer.from(v).toString('hex'),
        r: '0x' + Buffer.from(r).toString('hex'),
        s: '0x' + Buffer.from(s).toString('hex')
    };
}
```

---

## 4단계: Calldata 디코딩 (EAS Attest Function)

Attestation 트랜잭션은 EAS 컨트랙트의 `attest` 함수를 호출합니다.

### EAS Attest Function Signature

```solidity
function attest(AttestationRequest calldata request)
    external
    payable
    returns (bytes32);

struct AttestationRequest {
    bytes32 schema;
    AttestationRequestData data;
}

struct AttestationRequestData {
    address recipient;
    uint64 expirationTime;
    bool revocable;
    bytes32 refUID;
    bytes data;
    uint256 value;
}
```

### JavaScript로 Calldata 디코딩

```javascript
import { ethers } from 'ethers';

// EAS Attest Function ABI
const EAS_ATTEST_ABI = [
    {
        "inputs": [
            {
                "components": [
                    { "name": "schema", "type": "bytes32" },
                    {
                        "components": [
                            { "name": "recipient", "type": "address" },
                            { "name": "expirationTime", "type": "uint64" },
                            { "name": "revocable", "type": "bool" },
                            { "name": "refUID", "type": "bytes32" },
                            { "name": "data", "type": "bytes" },
                            { "name": "value", "type": "uint256" }
                        ],
                        "name": "data",
                        "type": "tuple"
                    }
                ],
                "name": "request",
                "type": "tuple"
            }
        ],
        "name": "attest",
        "outputs": [{ "name": "", "type": "bytes32" }],
        "stateMutability": "payable",
        "type": "function"
    }
];

function decodeAttestCalldata(calldata) {
    const iface = new ethers.Interface(EAS_ATTEST_ABI);

    // Calldata 디코딩
    const decoded = iface.parseTransaction({ data: calldata });

    console.log('🔍 Decoded Attest Call:');
    console.log('  Function:', decoded.name);
    console.log('  Schema:', decoded.args.request.schema);
    console.log('  Recipient:', decoded.args.request.data.recipient);
    console.log('  Expiration Time:', decoded.args.request.data.expirationTime.toString());
    console.log('  Revocable:', decoded.args.request.data.revocable);
    console.log('  Ref UID:', decoded.args.request.data.refUID);
    console.log('  Data:', decoded.args.request.data.data);
    console.log('  Value:', decoded.args.request.data.value.toString());

    return {
        schema: decoded.args.request.schema,
        recipient: decoded.args.request.data.recipient,
        expirationTime: decoded.args.request.data.expirationTime.toString(),
        revocable: decoded.args.request.data.revocable,
        refUID: decoded.args.request.data.refUID,
        data: decoded.args.request.data.data,
        value: decoded.args.request.data.value.toString()
    };
}
```

---

## 5단계: 전체 통합 예제

### Attestation TX Hash → 모든 데이터 추출

```javascript
import { ethers } from 'ethers';
import { RLP } from '@ethereumjs/rlp';
import { hexToBytes } from '@ethereumjs/util';

class AttestationTransactionDecoder {
    constructor(rpcUrl = 'https://mainnet.base.org') {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.easInterface = new ethers.Interface(EAS_ATTEST_ABI);
    }

    /**
     * Attestation TX Hash로 모든 데이터 추출
     */
    async decodeAttestationTransaction(txHash) {
        console.log('🔍 Attestation 트랜잭션 분석 시작:', txHash);
        console.log('');

        // 1. Transaction 조회
        const tx = await this.provider.getTransaction(txHash);
        if (!tx) {
            throw new Error('Transaction not found');
        }

        console.log('📦 1. Transaction Basic Info:');
        console.log('  From:', tx.from);
        console.log('  To (EAS Contract):', tx.to);
        console.log('  Nonce:', tx.nonce);
        console.log('  Gas Limit:', tx.gasLimit?.toString());
        console.log('  Gas Price:', tx.gasPrice ? ethers.formatUnits(tx.gasPrice, 'gwei') + ' gwei' : 'N/A');
        console.log('  Value:', ethers.formatEther(tx.value || 0), 'ETH');
        console.log('  Chain ID:', tx.chainId);
        console.log('');

        // 2. Raw Transaction 가져오기
        console.log('📜 2. Raw Transaction:');
        const rawTx = ethers.Transaction.from(tx).serialized;
        console.log('  ', rawTx);
        console.log('  Length:', rawTx.length, 'characters');
        console.log('');

        // 3. RLP 디코딩
        console.log('🔓 3. RLP Decoded Fields:');
        const rlpDecoded = this.decodeRLP(rawTx);
        console.log('  Nonce:', rlpDecoded.nonce);
        console.log('  Gas Price:', rlpDecoded.gasPrice);
        console.log('  Gas Limit:', rlpDecoded.gasLimit);
        console.log('  To:', rlpDecoded.to);
        console.log('  Value:', rlpDecoded.value);
        console.log('  Data Length:', rlpDecoded.data.length, 'bytes');
        console.log('  v:', rlpDecoded.v);
        console.log('  r:', rlpDecoded.r);
        console.log('  s:', rlpDecoded.s);
        console.log('');

        // 4. Calldata 디코딩 (EAS Attest)
        console.log('🔍 4. Decoded Attest Call:');
        const attestData = this.decodeAttestCalldata(tx.data);
        console.log('  Schema:', attestData.schema);
        console.log('  Recipient:', attestData.recipient);
        console.log('  Expiration Time:', attestData.expirationTime);
        console.log('  Revocable:', attestData.revocable);
        console.log('  Ref UID:', attestData.refUID);
        console.log('  Data:', attestData.data);
        console.log('  Value:', attestData.value);
        console.log('');

        // 5. Transaction Receipt (실제 실행 결과)
        console.log('📋 5. Transaction Receipt:');
        const receipt = await this.provider.getTransactionReceipt(txHash);
        console.log('  Status:', receipt.status === 1 ? '✅ Success' : '❌ Failed');
        console.log('  Block Number:', receipt.blockNumber);
        console.log('  Gas Used:', receipt.gasUsed.toString());
        console.log('  Logs:', receipt.logs.length, 'events');
        console.log('');

        // 6. Attested Event 파싱
        const attestedEvent = this.parseAttestedEvent(receipt);
        if (attestedEvent) {
            console.log('✅ 6. Attested Event:');
            console.log('  Recipient:', attestedEvent.recipient);
            console.log('  Attester:', attestedEvent.attester);
            console.log('  UID:', attestedEvent.uid);
            console.log('  Schema:', attestedEvent.schemaUID);
        }

        return {
            transaction: tx,
            rawTransaction: rawTx,
            rlpDecoded,
            attestData,
            receipt,
            attestedEvent
        };
    }

    /**
     * RLP 디코딩
     */
    decodeRLP(rawTx) {
        const cleanHex = rawTx.startsWith('0x') ? rawTx.slice(2) : rawTx;
        const txBytes = hexToBytes(cleanHex);
        const decoded = RLP.decode(txBytes);

        const [nonce, gasPrice, gasLimit, to, value, data, v, r, s] = decoded;

        return {
            nonce: '0x' + Buffer.from(nonce).toString('hex'),
            gasPrice: '0x' + Buffer.from(gasPrice).toString('hex'),
            gasLimit: '0x' + Buffer.from(gasLimit).toString('hex'),
            to: '0x' + Buffer.from(to).toString('hex'),
            value: '0x' + Buffer.from(value).toString('hex'),
            data: '0x' + Buffer.from(data).toString('hex'),
            v: '0x' + Buffer.from(v).toString('hex'),
            r: '0x' + Buffer.from(r).toString('hex'),
            s: '0x' + Buffer.from(s).toString('hex')
        };
    }

    /**
     * Attest Calldata 디코딩
     */
    decodeAttestCalldata(calldata) {
        const decoded = this.easInterface.parseTransaction({ data: calldata });

        return {
            schema: decoded.args.request.schema,
            recipient: decoded.args.request.data.recipient,
            expirationTime: decoded.args.request.data.expirationTime.toString(),
            revocable: decoded.args.request.data.revocable,
            refUID: decoded.args.request.data.refUID,
            data: decoded.args.request.data.data,
            value: decoded.args.request.data.value.toString()
        };
    }

    /**
     * Attested Event 파싱
     */
    parseAttestedEvent(receipt) {
        const ATTESTED_EVENT = '0x8bf46bf4cfd674fa735a3d63ec1c9ad4153f033c290341f3a588b75685141b35';

        const attestedLog = receipt.logs.find(log => log.topics[0] === ATTESTED_EVENT);

        if (!attestedLog) {
            return null;
        }

        // Attested event signature:
        // event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID);

        return {
            recipient: '0x' + attestedLog.topics[1].slice(26), // 앞 24자(12바이트) 제거
            attester: '0x' + attestedLog.topics[2].slice(26),
            schemaUID: attestedLog.topics[3],
            uid: ethers.AbiCoder.defaultAbiCoder().decode(['bytes32'], attestedLog.data)[0]
        };
    }
}

// 사용 예제
async function main() {
    const decoder = new AttestationTransactionDecoder();

    // Attestation에서 가져온 txid
    const txHash = '0x...'; // 실제 Attestation txid

    const result = await decoder.decodeAttestationTransaction(txHash);

    console.log('🎉 분석 완료!');
}

main().catch(console.error);
```

---

## 6단계: Noir 서킷에서 활용

디코딩한 데이터를 Noir 서킷의 입력으로 사용할 수 있습니다.

### Prover.toml 생성

```javascript
async function generateProverToml(txHash) {
    const decoder = new AttestationTransactionDecoder();
    const result = await decoder.decodeAttestationTransaction(txHash);

    const attestData = result.attestData;

    // Prover.toml 형식으로 변환
    const proverToml = `
# Attestation Transaction Data
schema = "${attestData.schema}"
recipient = "${attestData.recipient}"
expiration_time = "${attestData.expirationTime}"
revocable = ${attestData.revocable}
ref_uid = "${attestData.refUID}"
data = "${attestData.data}"

# Transaction Signature
v = "${result.rlpDecoded.v}"
r = "${result.rlpDecoded.r}"
s = "${result.rlpDecoded.s}"

# Transaction Fields
nonce = "${result.rlpDecoded.nonce}"
gas_price = "${result.rlpDecoded.gasPrice}"
gas_limit = "${result.rlpDecoded.gasLimit}"
to = "${result.rlpDecoded.to}"
value = "${result.rlpDecoded.value}"
    `.trim();

    console.log('📝 Prover.toml:');
    console.log(proverToml);

    return proverToml;
}
```

---

## 실전 예제: query-attestation.js 통합

### 기존 코드에 트랜잭션 디코딩 추가

```javascript
// src/utils/query-attestation.js에 추가

import { AttestationTransactionDecoder } from './transaction-decoder.js';

async function queryAttestationWithTxDecoding() {
    const attestations = await getAttestations(myAddress, base, {
        schemas: [VERIFIED_ACCOUNT_SCHEMA],
    });

    for (const att of attestations) {
        console.log(`\n--- Attestation ${att.id} ---`);

        // 기존 Attestation 정보 출력
        console.log('UID:', att.id);
        console.log('TX Hash:', att.txid);
        console.log('Attester:', att.attester);
        console.log('Recipient:', att.recipient);

        // 🆕 트랜잭션 디코딩
        console.log('\n🔍 트랜잭션 디코딩 시작...\n');

        const decoder = new AttestationTransactionDecoder();
        const txData = await decoder.decodeAttestationTransaction(att.txid);

        // 디코딩된 데이터 활용
        console.log('📋 추출된 Attestation 파라미터:');
        console.log('  Schema:', txData.attestData.schema);
        console.log('  Recipient:', txData.attestData.recipient);
        console.log('  Expiration:', txData.attestData.expirationTime);
        console.log('  Revocable:', txData.attestData.revocable);
        console.log('  Ref UID:', txData.attestData.refUID);

        // Noir 서킷용 데이터 생성
        const proofInputs = {
            recipient: txData.attestData.recipient,
            schema: txData.attestData.schema,
            attester: txData.attestedEvent.attester,
            uid: txData.attestedEvent.uid,
            // ... 기타 필요한 필드
        };

        console.log('\n✅ Noir 서킷 입력 데이터 준비 완료');
    }
}
```

---

## 요약

### ✅ 가능한 것들

1. **TX Hash → Transaction 객체**
   ```javascript
   const tx = await provider.getTransaction(txHash);
   ```

2. **Transaction → Raw Transaction (RLP 인코딩)**
   ```javascript
   const rawTx = ethers.Transaction.from(tx).serialized;
   ```

3. **Raw Transaction → RLP 디코딩**
   ```javascript
   const decoded = RLP.decode(hexToBytes(rawTx));
   // [nonce, gasPrice, gasLimit, to, value, data, v, r, s]
   ```

4. **Calldata → Attest 파라미터**
   ```javascript
   const attestParams = iface.parseTransaction({ data: tx.data });
   // schema, recipient, expirationTime, revocable, refUID, data
   ```

5. **Transaction Receipt → Attested Event**
   ```javascript
   const event = receipt.logs.find(log => log.topics[0] === ATTESTED_EVENT);
   // uid, attester, recipient, schemaUID
   ```

### 🎯 활용 사례

- ✅ Attestation 검증
- ✅ ZKP 서킷 입력 데이터 생성
- ✅ 온체인 데이터 무결성 검증
- ✅ Replay Attack 방지 (nonce, chainId 확인)

---

## 참고 자료

- [Ethereum Raw Transaction Guide](./ethereum-raw-transaction-guide.md)
- [EAS Documentation](https://docs.attest.sh/)
- [RLP Specification](https://ethereum.org/developers/docs/data-structures-and-encoding/rlp/)
- [ethers.js Transaction](https://docs.ethers.org/v6/api/transaction/)
