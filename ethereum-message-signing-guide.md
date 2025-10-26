# 이더리움 메시지 서명 완전 가이드

## 📋 목차
1. [메시지 서명이란?](#메시지-서명이란)
2. [실생활 예시들](#실생활-예시들)
3. [코드 예시: 전체 과정](#코드-예시-전체-과정)
4. [단계별 상세 과정](#단계별-상세-과정)
5. [실제 사용 흐름 예시](#실제-사용-흐름-예시)
6. [서명 시 주의사항](#서명-시-주의사항)
7. [보안 원리 요약](#보안-원리-요약)

---

## 🎯 메시지 서명이란?

**"내가 이 메시지에 동의한다"는 것을 암호학적으로 증명하는 행위**

### 일상 비유
```
종이 문서에 내 도장 찍기 = 메시지에 디지털 서명하기
- 도장 = 개인키
- 도장 모양 = 공개키
- 찍힌 도장 = 서명(signature)
```

### Digest의 의미

**Digest = "요약" 또는 "다이제스트"**

원래 의미는 "소화하다, 요약하다"입니다. 암호학에서는:
- **긴 메시지를 짧은 고정 길이 해시값으로 요약한 것**
- Message digest = 메시지 요약본
- 어떤 길이의 데이터든 → 항상 32바이트(256비트)로 압축

비유:
```
원본 책(메시지) → 짧은 요약본(digest)
1000페이지든 10페이지든 → 항상 1페이지 요약
```

### 전체 흐름

```
[서명 생성]
메시지(calldata)
  ↓ keccak256 해싱
Digest (32 bytes) - 메시지 요약
  ↓ 개인키로 암호화
Signature (r, s, v) - 디지털 도장

[서명 검증]
Digest + Signature + 공개키
  ↓ verify_signature()
✅ true (유효) / ❌ false (위조됨)
```

---

## 📱 실생활 예시들

### 예시 1: MetaMask 로그인 (가장 흔한 경우)

**시나리오**: "Sign in with Ethereum" 버튼 클릭

```
[웹사이트]
"다음 메시지에 서명해서 로그인하세요"

메시지:
┌─────────────────────────────────────┐
│ Welcome to OpenSea!                 │
│                                     │
│ Click to sign in and accept the     │
│ OpenSea Terms of Service:           │
│ https://opensea.io/tos              │
│                                     │
│ This request will not trigger a     │
│ blockchain transaction or cost      │
│ any gas fees.                       │
│                                     │
│ Wallet address:                     │
│ 0x742d35Cc6634C0532925a3b844Bc9e75 │
│                                     │
│ Nonce: 32891757                     │
└─────────────────────────────────────┘

[MetaMask 팝업]
┌─────────────────────────────────────┐
│ Signature Request                   │
│                                     │
│ OpenSea is asking you to sign       │
│ this message...                     │
│                                     │
│ [Cancel]  [Sign] ← 클릭!            │
└─────────────────────────────────────┘

[내부 동작]
1. 메시지 → keccak256 → digest
2. digest + 내 개인키 → signature 생성
3. signature를 웹사이트로 전송

[웹사이트 검증]
1. 메시지 + signature + 내 지갑주소
2. "이 사람이 이 지갑 주소의 개인키를 가지고 있구나!"
3. 로그인 성공
```

**중요**:
- ✅ 이건 그냥 서명일 뿐 (가스비 없음)
- ✅ 블록체인에 기록 안됨
- ✅ 돈이 빠져나가지 않음
- ⚠️ 하지만 서명 = "동의한다"는 의미

---

### 예시 2: NFT 판매 승인 (OpenSea)

```javascript
// 1. OpenSea가 요청하는 메시지
const sellOrder = {
    marketplace: "OpenSea",
    seller: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0",
    nftContract: "0x...",
    tokenId: "1234",
    price: "1.5 ETH",
    expirationTime: "2025-12-31",
};

// 2. 이 메시지를 JSON으로 변환
const message = JSON.stringify(sellOrder);

// 3. MetaMask로 서명 요청
const signature = await ethereum.request({
    method: 'personal_sign',
    params: [message, myAddress],
});

// signature 결과:
// "0x8f3e2d1a4b... (130자의 16진수 문자열)"

// 4. OpenSea에 전송
// OpenSea: "오케이, 이 사람이 정말 1.5 ETH에 팔겠다고 서명했네!"
// 누군가 구매하면 → 그때 블록체인 트랜잭션 발생
```

**왜 이렇게 하는가?**
- 즉시 블록체인에 올리면 가스비 발생
- 서명만 해두면 무료
- 누가 사겠다고 하면 그때 블록체인에 제출

---

### 예시 3: 토큰 전송 승인 (EIP-2612 Permit)

```javascript
// 전통적인 방식 (2단계, 가스비 2번)
// 1단계: approve 트랜잭션 (가스비 발생)
await tokenContract.approve(spenderAddress, amount);
// 2단계: transferFrom 트랜잭션 (가스비 발생)
await tokenContract.transferFrom(myAddress, toAddress, amount);

// 새로운 방식 (서명 활용, 가스비 1번만)
// 1단계: 메시지 서명 (무료!)
const permitSignature = await signPermit({
    owner: myAddress,
    spender: spenderAddress,
    value: amount,
    deadline: Date.now() + 3600,
});

// 2단계: permit + transferFrom (가스비 1번만)
await tokenContract.permit(
    myAddress,
    spenderAddress,
    amount,
    deadline,
    signature.v,
    signature.r,
    signature.s
);
```

---

## 💻 코드 예시: 전체 과정

### Frontend (JavaScript)

#### 1. 간단한 메시지 서명

```javascript
async function signSimpleMessage() {
    const accounts = await ethereum.request({
        method: 'eth_requestAccounts'
    });
    const myAddress = accounts[0];

    // 서명할 메시지
    const message = "I agree to the terms and conditions";

    // MetaMask로 서명 요청
    const signature = await ethereum.request({
        method: 'personal_sign',
        params: [
            ethers.utils.hexlify(ethers.utils.toUtf8Bytes(message)),
            myAddress
        ]
    });

    console.log("Message:", message);
    console.log("Signature:", signature);
    // Signature: "0x8f3e2d1a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f..."
}
```

#### 2. 서명 검증 (서버에서)

```javascript
async function verifySignature(message, signature, expectedAddress) {
    const recoveredAddress = ethers.utils.verifyMessage(message, signature);

    if (recoveredAddress.toLowerCase() === expectedAddress.toLowerCase()) {
        console.log("✅ 서명 유효! 이 사람이 개인키를 가지고 있음");
        return true;
    } else {
        console.log("❌ 서명 무효! 다른 사람이 서명했거나 메시지가 변조됨");
        return false;
    }
}
```

#### 3. EIP-712 Typed Data 서명 (구조화된 데이터)

```javascript
async function signTypedData() {
    const domain = {
        name: 'MyDApp',
        version: '1',
        chainId: 1,
        verifyingContract: '0x...'
    };

    const types = {
        Mail: [
            { name: 'from', type: 'address' },
            { name: 'to', type: 'address' },
            { name: 'contents', type: 'string' }
        ]
    };

    const value = {
        from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0',
        to: '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199',
        contents: 'Hello, World!'
    };

    const signature = await signer._signTypedData(domain, types, value);
    console.log("Typed Data Signature:", signature);
}
```

---

### Smart Contract (Solidity)

#### 서명 검증 컨트랙트

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SignatureVerifier {
    // 메시지와 서명으로부터 서명자 주소 복구
    function recoverSigner(
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (address) {
        // 서명을 r, s, v로 분리
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // 이더리움 서명 프리픽스 추가
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // ecrecover로 서명자 주소 복구
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    // 서명 검증
    function verifySignature(
        address expectedSigner,
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (bool) {
        address recoveredSigner = recoverSigner(messageHash, signature);
        return recoveredSigner == expectedSigner;
    }
}
```

#### 로그인 컨트랙트 예시

```solidity
contract LoginWithSignature {
    mapping(address => uint256) public nonces;
    mapping(address => bool) public isLoggedIn;

    event UserLoggedIn(address user);

    function login(
        string memory message,
        bytes memory signature
    ) public {
        // 1. 메시지 해시 계산
        bytes32 messageHash = keccak256(abi.encodePacked(
            "Login to MyDApp\n",
            "Nonce: ", nonces[msg.sender]
        ));

        // 2. 서명 검증
        address signer = recoverSigner(messageHash, signature);
        require(signer == msg.sender, "Invalid signature");

        // 3. 로그인 처리
        isLoggedIn[msg.sender] = true;
        nonces[msg.sender]++; // Replay attack 방지

        emit UserLoggedIn(msg.sender);
    }

    function recoverSigner(
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
```

---

## 🔄 단계별 상세 과정

### Phase 1: 서명 생성 (클라이언트)

```
Step 1: 메시지 준비
─────────────────────────
원본 메시지: "I agree to sell NFT #1234 for 1.5 ETH"

Step 2: 메시지 해싱
─────────────────────────
messageHash = keccak256("I agree to sell NFT #1234 for 1.5 ETH")
           = 0x1a2b3c4d5e6f... (32 bytes)

Step 3: 이더리움 프리픽스 추가
─────────────────────────
// 왜? → 이더리움 서명임을 명확히 하기 위해
ethSignedHash = keccak256(
    "\x19Ethereum Signed Message:\n32" + messageHash
)

Step 4: 개인키로 서명
─────────────────────────
signature = ECDSA_sign(ethSignedHash, privateKey)
         = {
             r: 0x8f3e2d1a..., // 32 bytes
             s: 0x4b5c6d7e..., // 32 bytes
             v: 27 or 28      // 1 byte (recovery id)
         }

Step 5: 서명 인코딩
─────────────────────────
finalSignature = r + s + v (총 65 bytes)
              = "0x8f3e2d1a4b5c6d7e..." (130자 hex 문자열)
```

---

### Phase 2: 서명 검증 (서버/컨트랙트)

```
Input:
- message: "I agree to sell NFT #1234 for 1.5 ETH"
- signature: "0x8f3e2d1a4b5c6d7e..."
- 예상 서명자 주소: 0x742d35Cc...

Step 1: 메시지 해시 재계산
─────────────────────────
messageHash = keccak256(message)
ethSignedHash = keccak256("\x19Ethereum..." + messageHash)

Step 2: 서명에서 r, s, v 추출
─────────────────────────
r = signature[0:32]
s = signature[32:64]
v = signature[64]

Step 3: ecrecover로 서명자 주소 복구
─────────────────────────
recoveredAddress = ecrecover(ethSignedHash, v, r, s)
                = 0x742d35Cc... (서명자의 공개키로부터 계산된 주소)

Step 4: 주소 비교
─────────────────────────
if (recoveredAddress == 예상 서명자 주소) {
    ✅ "이 사람이 이 메시지에 서명했음!"
} else {
    ❌ "서명이 위조되었거나 메시지가 변조됨!"
}
```

---

## 🎬 실제 사용 흐름 예시

### 시나리오: DeFi에서 대출 승인

```
[1단계: 사용자 행동]
사용자: "Aave에서 1 ETH 빌리고 싶어"

[2단계: DApp이 메시지 생성]
DApp: "다음 메시지에 서명해주세요"

메시지 내용:
{
  "action": "borrow",
  "protocol": "Aave",
  "asset": "ETH",
  "amount": "1.0",
  "collateral": "2.0 USDC",
  "interestRate": "3.5%",
  "deadline": "2025-12-31T23:59:59Z",
  "nonce": 12345
}

[3단계: MetaMask 팝업]
┌─────────────────────────────────────┐
│ 🦊 MetaMask                         │
│                                     │
│ Aave is requesting signature        │
│                                     │
│ You are approving:                  │
│ - Borrow 1 ETH                      │
│ - Collateral: 2 USDC                │
│ - Interest: 3.5% APR                │
│                                     │
│ ⚠️ Only sign if you trust this site │
│                                     │
│ [Reject]  [Sign]                    │
└─────────────────────────────────────┘

[4단계: 사용자가 "Sign" 클릭]

[5단계: MetaMask 내부 동작]
개인키 (MetaMask 안에만 있음, 절대 밖으로 안 나감)
  ↓
메시지 해시 계산
  ↓
ECDSA 서명 생성
  ↓
Signature: "0x8f3e2d1a4b5c6d7e..." (65 bytes)

[6단계: DApp으로 서명 전달]

[7단계: DApp이 스마트컨트랙트에 제출]
await aaveContract.borrowWithSignature(
    borrowAmount,
    collateralAmount,
    signature,
    { from: userAddress }
);

[8단계: 스마트컨트랙트 검증]
contract Aave {
    function borrowWithSignature(
        uint256 amount,
        uint256 collateral,
        bytes memory signature
    ) external {
        // 서명 검증
        bytes32 messageHash = keccak256(abi.encode(
            "borrow", amount, collateral, msg.sender
        ));

        address signer = recoverSigner(messageHash, signature);
        require(signer == msg.sender, "Invalid signature");

        // 대출 실행
        _executeBorrow(msg.sender, amount, collateral);
    }
}

[9단계: 대출 실행]
✅ 1 ETH가 사용자 지갑으로 전송됨
✅ 2 USDC가 담보로 잠김
```

---

## ⚠️ 서명 시 주의사항

### 위험한 서명 예시

```javascript
// ❌ 절대 하지 말아야 할 것들

// 1. 빈 메시지 서명
await ethereum.request({
    method: 'personal_sign',
    params: ['', myAddress]  // ← 위험!
});
// 공격자가 나중에 아무 내용이나 넣을 수 있음

// 2. 모르는 내용 서명
const unknownMessage = "0x1a2b3c4d..."; // 해시만 보임
await ethereum.request({
    method: 'personal_sign',
    params: [unknownMessage, myAddress]  // ← 위험!
});
// 무슨 내용인지 모르는데 서명하는 것

// 3. 무한 권한 부여
const message = {
    "approve": "unlimited",  // ← 매우 위험!
    "token": "USDC",
    "spender": "0x..."
};
// 내 모든 USDC를 가져갈 수 있는 권한

// 4. Nonce 없는 서명
const message = "Transfer 100 USDC to Alice";
// 공격자가 이 서명을 여러 번 재사용 가능 (Replay Attack)
```

---

### 안전한 서명 체크리스트

```
✅ 체크리스트:
1. 메시지 내용이 명확하게 보이는가?
2. 신뢰할 수 있는 사이트인가?
3. 금액/권한이 합리적인가?
4. 만료 시간(deadline)이 있는가?
5. Nonce가 포함되어 있는가? (재사용 방지)
6. 무한 권한(unlimited approval)이 아닌가?
```

---

## 🔐 보안 원리 요약

### 서명 검증이 무엇을 보장하는가?

#### 1. 메시지 무결성 (Integrity)
```
원본 메시지: "Bob에게 100 ETH 전송"
digest = keccak256("Bob에게 100 ETH 전송")

만약 누가 메시지를 변조하면:
변조된 메시지: "Alice에게 100 ETH 전송"
digest2 = keccak256("Alice에게 100 ETH 전송")

digest ≠ digest2 → 서명 검증 실패!
```

**보장**: 메시지가 1바이트라도 바뀌면 서명이 무효화됨

#### 2. 인증 (Authentication)
```
Coinbase 개인키로 서명 → Coinbase만 만들 수 있는 signature

검증 시:
Coinbase 공개키 + signature → "이게 진짜 Coinbase가 서명한 거야!"
```

**보장**: Coinbase 개인키를 모르는 사람은 유효한 서명을 만들 수 없음

#### 3. 부인 방지 (Non-repudiation)
```
Coinbase: "나 그런 attestation 안 줬어!"
검증자: "여기 당신 공개키로 검증되는 서명이 있는데요?"
Coinbase: "..." (부인 불가)
```

**보장**: 나중에 "나 안 했어"라고 발뺌 못함

---

### 수학적 보장

```
서명 = 개인키로 암호화한 메시지의 증명

[타원곡선 암호학 원리]
1. 개인키 없이는 유효한 서명을 만들 수 없음
2. 서명을 보고 개인키를 알아낼 수 없음
3. 메시지 1비트만 바뀌어도 서명이 무효화됨
4. 서명으로부터 서명자의 주소를 복구 가능 (ecrecover)

[타원곡선 일방향 함수]
개인키 (256 bits) ──┐
                    ↓ 일방향 변환 (쉬움)
공개키 (512 bits) ──┐
                    ↓ keccak256 + 마지막 20바이트
주소 (160 bits) ────┘

역방향은 수학적으로 불가능 (슈퍼컴퓨터로 수백년 걸림)
```

---

### 공격 시나리오와 방어

#### ❌ 공격 시나리오 1: 메시지 변조
```
공격자: "내가 calldata를 수정해서 다른 사람 주소로 바꾸자"
calldata 변조: "0x742d..." → "0x9999..."
  ↓
새 digest = keccak256(변조된 calldata)
  ↓
기존 signature로 검증 시도
  ↓
❌ 실패! (digest가 바뀌었으니 signature가 안 맞음)
```

#### ❌ 공격 시나리오 2: 위조 서명
```
공격자: "내가 직접 서명을 만들자"
  ↓
문제: Coinbase 개인키를 모름
  ↓
임의 signature 생성
  ↓
Coinbase 공개키로 검증 시도
  ↓
❌ 실패! (타원곡선 수학이 맞지 않음)
```

#### ❌ 공격 시나리오 3: 자기가 만든 attestation
```
공격자: "내 개인키로 서명해서 제출하자"
내 calldata 생성 → 내 개인키로 서명 → 제출
  ↓
서킷 검증 시:
  ↓
Coinbase 공개키로 검증
  ↓
❌ 실패! (다른 공개키로 만든 서명이라 안 맞음)
```

---

## 💡 핵심 정리

### 메시지 서명 = 디지털 도장 찍기

| 종이 문서 | 디지털 메시지 |
|----------|--------------|
| 1. 계약서 작성 | 1. 메시지 작성 |
| 2. 내용 확인 | 2. 메시지 해싱 (digest) |
| 3. 도장 찍기 | 3. 개인키로 서명 |
| 4. 도장 날인 | 4. Signature 생성 |
| 5. 상대방 확인 | 5. 공개키로 검증 |

---

### 언제 사용하는가?

- 🔐 **로그인**: Sign in with Ethereum
- 💰 **토큰 승인**: EIP-2612 Permit
- 🖼️ **NFT 거래**: OpenSea, Blur 주문
- 📝 **투표**: Snapshot
- ✍️ **계약 동의**: DeFi 프로토콜

---

### 핵심 원리

```
✅ 개인키는 절대 노출되지 않음 (MetaMask 안에만 있음)
✅ 서명만으로 "나" 임을 증명 가능
✅ 블록체인에 올리지 않아도 됨 (가스비 절약)
✅ 나중에 필요할 때 블록체인에 제출
```

---

### Digest의 역할

```
긴 메시지 → 32바이트 요약
"어떤 메시지였는지"를 고유하게 식별
1비트만 바뀌어도 완전히 다른 digest
```

---

### Signature의 역할

```
"이 digest를 개인키 소유자가 승인했다"는 증거
수학적으로 위조 불가능
공개키로 검증 가능
```

---

### 보안 3요소

1. **무결성**: 메시지 변조 → 서명 무효
2. **인증**: 개인키 소유자만 만들 수 있는 서명
3. **부인 방지**: 나중에 발뺌 못함

---

## 📚 참고 자료

- [EIP-191: Signed Data Standard](https://eips.ethereum.org/EIPS/eip-191)
- [EIP-712: Typed structured data hashing](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-2612: Permit Extension for ERC-20](https://eips.ethereum.org/EIPS/eip-2612)
- [MetaMask Signing Data](https://docs.metamask.io/wallet/how-to/sign-data/)
- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)

---

## 🔗 관련 문서

- [Coinbase Attestor Circuit 보안 분석](./coinbase-attestor-circuit.md)
- [Zero-Knowledge Proof 튜토리얼](./tutorials/)

---

*Last Updated: 2025-01-22*
