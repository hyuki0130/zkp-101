# Ethereum Raw Transaction 생성 가이드

## 목차
1. [개요](#개요)
2. [RLP 인코딩 이해하기](#rlp-인코딩-이해하기)
3. [트랜잭션 구조](#트랜잭션-구조)
4. [Raw Transaction 생성 단계](#raw-transaction-생성-단계)
5. [코드 예제](#코드-예제)
6. [참고 자료](#참고-자료)

---

## 개요

Ethereum Raw Transaction은 서명된 트랜잭션을 RLP(Recursive Length Prefix) 인코딩 형식으로 직렬화한 것입니다. 이를 통해:
- 오프라인에서 트랜잭션을 생성 및 서명
- 나중에 네트워크에 브로드캐스트
- 트랜잭션을 안전하게 저장 및 전송

---

## RLP 인코딩 이해하기

### RLP란?

**RLP (Recursive Length Prefix)**는 Ethereum의 핵심 직렬화 프로토콜입니다.

**특징:**
- 중첩된 바이트 배열을 직렬화
- 데이터 타입이 아닌 구조(structure)만 저장
- 모든 구현에서 바이트 단위로 일관성 보장
- 최소주의적 설계 (minimalistic)

### RLP 인코딩 규칙

#### 1. 단일 바이트 인코딩 (0x00 ~ 0x7F)
바이트 값이 `0x00` ~ `0x7F` 범위면 그대로 인코딩합니다.

```
입력: 0x2a
출력: 0x2a
```

#### 2. 짧은 문자열 인코딩 (1-55 바이트)
문자열 길이가 1~55 바이트면:
- Prefix = `0x80 + length`
- 뒤에 문자열 내용 추가

```
입력: "dog" (0x64 0x6f 0x67)
길이: 3 바이트
Prefix: 0x80 + 3 = 0x83
출력: 0x83 0x64 0x6f 0x67
```

#### 3. 긴 문자열 인코딩 (> 55 바이트)
문자열 길이가 55 바이트 초과면:
- Prefix = `0xb7 + length_of_length`
- 길이를 big-endian으로 인코딩
- 뒤에 문자열 내용 추가

```
입력: 100바이트 문자열
길이: 100 = 0x64 (1바이트)
Prefix: 0xb7 + 1 = 0xb8
출력: 0xb8 0x64 [100바이트 데이터]
```

#### 4. 리스트 인코딩

**짧은 리스트 (총 길이 1-55 바이트):**
- Prefix = `0xc0 + total_length`
- 뒤에 리스트 아이템들 추가

```
입력: ["cat", "dog"]
cat: 0x83 0x63 0x61 0x74 (4바이트)
dog: 0x83 0x64 0x6f 0x67 (4바이트)
총 길이: 8바이트
Prefix: 0xc0 + 8 = 0xc8
출력: 0xc8 0x83 0x63 0x61 0x74 0x83 0x64 0x6f 0x67
```

**긴 리스트 (총 길이 > 55 바이트):**
- Prefix = `0xf7 + length_of_length`

#### 5. 특수 케이스
- **빈 문자열 / null / false**: `0x80`
- **빈 리스트**: `0xc0`

---

## 트랜잭션 구조

### Legacy Transaction (EIP-155 이전)

트랜잭션은 다음 9개 필드로 구성됩니다:

```
[
  nonce,        // 발신자가 보낸 트랜잭션 개수
  gasPrice,     // 가스 가격 (wei)
  gasLimit,     // 최대 가스 사용량
  to,           // 수신자 주소 (20 bytes)
  value,        // 전송할 ETH 양 (wei)
  data,         // 컨트랙트 호출 데이터
  v,            // 서명 복구 ID
  r,            // 서명 값 (x 좌표)
  s             // 서명 값
]
```

### EIP-155 Transaction (Chain ID 포함)

EIP-155는 Replay Attack 방지를 위해 Chain ID를 포함합니다.

**서명 전 (unsigned):**
```
[nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
```

**서명 후 (signed):**
```
v' = chainId * 2 + 35 + {0, 1}
```

### EIP-1559 Transaction (Type 2)

```
0x02 || RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])
```

---

## Raw Transaction 생성 단계

### 1단계: 트랜잭션 파라미터 준비

```javascript
const txParams = {
  nonce: '0x00',                    // 트랜잭션 nonce
  gasPrice: '0x09184e72a000',       // 10000000000000 wei
  gasLimit: '0x5208',               // 21000 (기본 전송)
  to: '0x1234567890123456789012345678901234567890',
  value: '0x0de0b6b3a7640000',      // 1 ETH
  data: '0x',                       // 빈 데이터
  chainId: 1                        // Ethereum Mainnet
};
```

### 2단계: 서명용 데이터 구성

EIP-155 형식:
```javascript
const unsignedTx = [
  txParams.nonce,
  txParams.gasPrice,
  txParams.gasLimit,
  txParams.to,
  txParams.value,
  txParams.data,
  txParams.chainId,
  '0x',  // r placeholder
  '0x'   // s placeholder
];
```

### 3단계: RLP 인코딩

```javascript
const rlpEncoded = RLP.encode(unsignedTx);
```

### 4단계: Keccak-256 해시

```javascript
const txHash = keccak256(rlpEncoded);
```

### 5단계: ECDSA 서명

```javascript
const signature = secp256k1.sign(txHash, privateKey);
const { r, s, v } = signature;
```

### 6단계: v 값 계산 (EIP-155)

```javascript
v' = chainId * 2 + 35 + recoveryId
```

예시:
- Chain ID = 1 (Ethereum Mainnet)
- Recovery ID = 0 or 1
- v = 1 * 2 + 35 + 0 = 37 (0x25)
- 또는 v = 1 * 2 + 35 + 1 = 38 (0x26)

### 7단계: 서명된 트랜잭션 RLP 인코딩

```javascript
const signedTx = [
  txParams.nonce,
  txParams.gasPrice,
  txParams.gasLimit,
  txParams.to,
  txParams.value,
  txParams.data,
  v,
  r,
  s
];

const rawTx = '0x' + RLP.encode(signedTx).toString('hex');
```

### 8단계: 브로드캐스트

```javascript
const txHash = await web3.eth.sendSignedTransaction(rawTx);
```

---

## 코드 예제

### JavaScript (ethers.js)

```javascript
import { ethers } from 'ethers';

async function createRawTransaction() {
  // 1. 지갑 생성
  const privateKey = '0x...';
  const wallet = new ethers.Wallet(privateKey);

  // 2. 트랜잭션 구성
  const tx = {
    nonce: 0,
    gasPrice: ethers.parseUnits('20', 'gwei'),
    gasLimit: 21000,
    to: '0x1234567890123456789012345678901234567890',
    value: ethers.parseEther('1.0'),
    data: '0x',
    chainId: 1
  };

  // 3. 서명
  const signedTx = await wallet.signTransaction(tx);

  console.log('Raw Transaction:', signedTx);

  // 4. 브로드캐스트 (선택)
  // const provider = new ethers.JsonRpcProvider('https://eth-mainnet.g.alchemy.com/v2/...');
  // const txResponse = await provider.broadcastTransaction(signedTx);
  // console.log('Transaction Hash:', txResponse.hash);

  return signedTx;
}
```

### Go (go-ethereum)

```go
package main

import (
    "context"
    "crypto/ecdsa"
    "encoding/hex"
    "fmt"
    "log"
    "math/big"

    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/core/types"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/ethclient"
)

func createRawTransaction() (string, error) {
    // 1. Private Key 로드
    privateKey, err := crypto.HexToECDSA("your_private_key_hex")
    if err != nil {
        return "", err
    }

    publicKey := privateKey.Public()
    publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
    if !ok {
        return "", fmt.Errorf("error casting public key to ECDSA")
    }

    fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)

    // 2. 트랜잭션 파라미터
    nonce := uint64(0)
    toAddress := common.HexToAddress("0x1234567890123456789012345678901234567890")
    value := big.NewInt(1000000000000000000) // 1 ETH in wei
    gasLimit := uint64(21000)
    gasPrice := big.NewInt(20000000000) // 20 gwei

    var data []byte // 빈 data

    // 3. 트랜잭션 생성
    tx := types.NewTransaction(nonce, toAddress, value, gasLimit, gasPrice, data)

    // 4. 서명
    chainID := big.NewInt(1) // Ethereum Mainnet
    signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
    if err != nil {
        return "", err
    }

    // 5. RLP 인코딩
    ts := types.Transactions{signedTx}
    rawTxBytes := ts.GetRlp(0)
    rawTxHex := hex.EncodeToString(rawTxBytes)

    return "0x" + rawTxHex, nil
}

func main() {
    rawTx, err := createRawTransaction()
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("Raw Transaction:", rawTx)
}
```

### Python (web3.py)

```python
from web3 import Web3
from eth_account import Account
from eth_utils import to_hex

def create_raw_transaction():
    # 1. Private Key 설정
    private_key = '0x...'
    account = Account.from_key(private_key)

    # 2. 트랜잭션 구성
    transaction = {
        'nonce': 0,
        'gasPrice': Web3.to_wei('20', 'gwei'),
        'gas': 21000,
        'to': '0x1234567890123456789012345678901234567890',
        'value': Web3.to_wei('1', 'ether'),
        'data': b'',
        'chainId': 1
    }

    # 3. 서명
    signed_txn = account.sign_transaction(transaction)

    # 4. Raw Transaction 출력
    raw_tx = to_hex(signed_txn.rawTransaction)
    print(f'Raw Transaction: {raw_tx}')

    # 5. 브로드캐스트 (선택)
    # w3 = Web3(Web3.HTTPProvider('https://eth-mainnet.g.alchemy.com/v2/...'))
    # tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    # print(f'Transaction Hash: {to_hex(tx_hash)}')

    return raw_tx

if __name__ == '__main__':
    create_raw_transaction()
```

---

## RLP 인코딩 예제 (상세)

### 예제 1: 간단한 ETH 전송

**트랜잭션 파라미터:**
```
nonce: 9
gasPrice: 20000000000 (0x04a817c800)
gasLimit: 21000 (0x5208)
to: 0x3535353535353535353535353535353535353535
value: 1000000000000000000 (0x0de0b6b3a7640000)
data: 0x
v: 37 (0x25)
r: 0x28ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276
s: 0x67cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83
```

**RLP 인코딩 단계:**

1. 각 필드를 바이트로 변환:
```
nonce:    0x09
gasPrice: 0x04a817c800
gasLimit: 0x5208
to:       0x3535353535353535353535353535353535353535
value:    0x0de0b6b3a7640000
data:     0x (empty)
v:        0x25
r:        0x28ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276
s:        0x67cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83
```

2. 각 필드 RLP 인코딩:
```
nonce:    0x09 (1 byte, 0x00~0x7f 범위) → 0x09
gasPrice: 0x04a817c800 (5 bytes) → 0x85 0x04a817c800
gasLimit: 0x5208 (2 bytes) → 0x82 0x5208
to:       20 bytes → 0x94 0x3535...
value:    0x0de0b6b3a7640000 (8 bytes) → 0x88 0x0de0b6b3a7640000
data:     empty → 0x80
v:        0x25 (1 byte) → 0x25
r:        32 bytes → 0xa0 0x28ef...
s:        32 bytes → 0xa0 0x67cb...
```

3. 리스트로 묶기:
```
총 길이 = 1 + 6 + 3 + 21 + 9 + 1 + 1 + 33 + 33 = 108 bytes
Prefix = 0xf7 + 1 = 0xf8 (긴 리스트)
Length = 0x6c (108)
```

**최종 Raw Transaction:**
```
0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83
```

---

## 트랜잭션 디코딩 (역과정)

Raw Transaction을 디코딩하여 트랜잭션 정보를 확인할 수 있습니다.

### JavaScript 디코딩 예제

```javascript
import { ethers } from 'ethers';

function decodeRawTransaction(rawTx) {
  const tx = ethers.Transaction.from(rawTx);

  console.log('Nonce:', tx.nonce);
  console.log('Gas Price:', tx.gasPrice?.toString());
  console.log('Gas Limit:', tx.gasLimit?.toString());
  console.log('To:', tx.to);
  console.log('Value:', ethers.formatEther(tx.value || 0), 'ETH');
  console.log('Data:', tx.data);
  console.log('Chain ID:', tx.chainId);
  console.log('v:', tx.signature?.v);
  console.log('r:', tx.signature?.r);
  console.log('s:', tx.signature?.s);

  // 발신자 주소 복구
  console.log('From:', tx.from);

  return tx;
}

// 사용 예
const rawTx = '0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83';

decodeRawTransaction(rawTx);
```

---

## 보안 고려사항

### 1. Private Key 관리
- **절대 하드코딩하지 마세요**
- 환경 변수 또는 보안 키 저장소 사용
- `.env` 파일을 `.gitignore`에 추가

```javascript
// ❌ 나쁜 예
const privateKey = '0x1234567890abcdef...';

// ✅ 좋은 예
import dotenv from 'dotenv';
dotenv.config();
const privateKey = process.env.PRIVATE_KEY;
```

### 2. Nonce 관리
- 동일한 nonce로 여러 트랜잭션 전송 시 충돌
- RPC로 현재 nonce 조회:

```javascript
const nonce = await provider.getTransactionCount(address, 'pending');
```

### 3. Gas Price 설정
- 너무 낮으면 트랜잭션 실패 가능
- 네트워크 상황에 따라 동적 조정:

```javascript
const feeData = await provider.getFeeData();
const gasPrice = feeData.gasPrice;
```

### 4. Chain ID 확인
- 잘못된 Chain ID는 Replay Attack 위험
- 항상 올바른 네트워크 Chain ID 사용

```javascript
const network = await provider.getNetwork();
const chainId = network.chainId;
```

### 5. 서명 전 검증
- 모든 파라미터 확인
- 수신자 주소 검증
- 금액 재확인

---

## 트러블슈팅

### 1. "insufficient funds for gas * price + value"
**원인**: 계정 잔액 부족

**해결**:
```javascript
const balance = await provider.getBalance(address);
console.log('Balance:', ethers.formatEther(balance), 'ETH');
```

### 2. "nonce too low"
**원인**: 이미 사용된 nonce

**해결**: 최신 nonce 조회
```javascript
const nonce = await provider.getTransactionCount(address, 'latest');
```

### 3. "invalid signature"
**원인**: 잘못된 Chain ID 또는 서명 오류

**해결**: Chain ID 확인
```javascript
console.log('Chain ID:', await provider.getNetwork().then(n => n.chainId));
```

### 4. "intrinsic gas too low"
**원인**: Gas Limit이 너무 낮음

**해결**: Gas Limit 증가
```javascript
const estimatedGas = await provider.estimateGas(tx);
tx.gasLimit = estimatedGas * 120n / 100n; // 20% 추가
```

---

## 실전 활용 사례

### 1. 오프라인 서명
```javascript
// 오프라인 환경
const signedTx = await wallet.signTransaction(tx);
// signedTx를 파일로 저장 또는 전송

// 온라인 환경
const txResponse = await provider.broadcastTransaction(signedTx);
```

### 2. 멀티시그 트랜잭션
```javascript
// 각 서명자가 개별적으로 서명
const sig1 = await wallet1.signMessage(txHash);
const sig2 = await wallet2.signMessage(txHash);
// 서명 수집 후 트랜잭션 구성
```

### 3. Batch 트랜잭션
```javascript
const transactions = [];
for (let i = 0; i < 10; i++) {
  const tx = {
    ...txParams,
    nonce: baseNonce + i,
    to: recipients[i]
  };
  const signedTx = await wallet.signTransaction(tx);
  transactions.push(signedTx);
}

// 순차 또는 병렬 브로드캐스트
```

---

## 참고 자료

### 공식 문서
- [Ethereum RLP Specification](https://ethereum.org/developers/docs/data-structures-and-encoding/rlp/)
- [EIP-155: Simple replay attack protection](https://eips.ethereum.org/EIPS/eip-155)
- [EIP-1559: Fee market change](https://eips.ethereum.org/EIPS/eip-1559)
- [EIP-2718: Typed Transaction Envelope](https://eips.ethereum.org/EIPS/eip-2718)

### 라이브러리
- [ethers.js](https://docs.ethers.org/)
- [web3.py](https://web3py.readthedocs.io/)
- [go-ethereum](https://geth.ethereum.org/docs/developers/dapp-developer/native)

### 도구
- [Etherscan Transaction Decoder](https://etherscan.io/pushTx)
- [RLP Encoder/Decoder](https://toolkit.abdk.consulting/ethereum#rlp)

### 튜토리얼
- [Ethereum Book - Transactions](https://github.com/ethereumbook/ethereumbook/blob/develop/06transactions.asciidoc)
- [Mastering RLP Serialization (2024)](https://thogiti.github.io/2024/04/30/RLP.html)

---

## 마치며

Raw Transaction 생성은 Ethereum 개발의 핵심 개념입니다. 이 가이드를 통해:
- ✅ RLP 인코딩 원리 이해
- ✅ 트랜잭션 구조 파악
- ✅ 안전한 서명 및 브로드캐스트 방법 습득
- ✅ 다양한 프로그래밍 언어로 구현 가능

실전에서는 대부분 라이브러리를 사용하지만, 내부 동작을 이해하면 디버깅과 최적화에 큰 도움이 됩니다.

**추가 질문이나 피드백은 GitHub Issues로 남겨주세요!** 🚀
