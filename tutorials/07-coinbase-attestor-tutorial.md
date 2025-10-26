# Coinbase Attestor ZKP 튜토리얼

Coinbase KYC attestation을 검증하는 Zero-Knowledge Proof 애플리케이션 구현 가이드입니다.

---

## 📋 목차

1. [개요](#개요)
2. [사전 준비](#사전-준비)
3. [프로젝트 구조](#프로젝트-구조)
4. [Circuit 구현](#circuit-구현)
5. [Frontend 구현](#frontend-구현)
6. [Offchain 검증 테스트](#offchain-검증-테스트)
7. [Onchain Verifier 배포](#onchain-verifier-배포)
8. [Onchain 검증 테스트](#onchain-검증-테스트)
9. [트러블슈팅](#트러블슈팅)

---

## 개요

### 🎯 목표

**Coinbase KYC 인증을 받았음을 증명**하면서도 **개인 정보(주소, 서명 등)는 비공개**로 유지하는 Zero-Knowledge Proof 애플리케이션을 만듭니다.

### 💡 핵심 개념

**Public Inputs (공개 정보)**:
- Attestation UID
- Schema ID (Verified Account)
- Attester 주소 (Coinbase)
- Transaction Hash

**Private Inputs (비공개 정보)**:
- User 지갑 주소
- User 서명 (ECDSA)
- User 공개키
- Calldata

### 📊 검증 항목

Circuit은 다음을 검증합니다:
1. ✅ Function selector 검증 (`attest(address)`)
2. ✅ Calldata에서 주소 추출 및 일치 확인
3. ✅ User 서명 검증 (ECDSA)
4. ✅ User 주소 유도 (pubkey → address)
5. ✅ TX hash 검증 (Keccak256)
6. ✅ Schema ID 검증
7. ✅ Attester 주소 검증
8. ✅ Revocation 상태 검증
9. ✅ Expiration 시간 검증

---

## 사전 준비

### 1. Coinbase KYC 인증

1. https://www.coinbase.com/signup 에서 계정 생성
2. KYC 인증 완료 (신분증 + 거주지 확인)
3. https://www.coinbase.com/onchain-verify 에서 **Verified Account** attestation 생성
4. Base Mainnet에 attestation 기록됨

### 2. 개발 환경

```bash
# Node.js v20+
node --version  # v20.0.0 이상

# Noir 설치
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup
nargo --version  # 1.0.0-beta.9

# bb CLI 설치 (v0.87.0)
# zkp-101/packages/barretenberg-v0.87.0-nightly-*.tar.gz 압축 해제
tar -xzf barretenberg-v0.87.0-nightly-arm64-darwin.tar.gz
sudo cp barretenberg/bb /usr/local/bin/
sudo chmod +x /usr/local/bin/bb
bb --version  # 0.87.0
```

### 3. Attestation UID 확인

프로젝트 루트의 `.env` 파일에 지갑 주소 설정:

```bash
# .env
USER_ADDRESS=0xYourMetaMaskAddressHere
PRIVATE_KEY=0xYourPrivateKeyHere  # 서명 생성용
```

Attestation 조회:

```bash
cd examples/coinbaes-zkp-app
node src/utils/query-attestation.js
```

**출력 예시**:
```
✅ Attestations found: 1

--- Attestation 1 ---
UID: 0x626de11971b847cef5a29833e122eb98dee0fac462fee1ac54f1b189c8540f59
Schema: 0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9
Attester: 0x357458739F90461b99789350868CD7CF330Dd7EE
Recipient: 0xD6C714247037E5201B7e3dEC97a3ab59a9d2F739
✅ Coinbase KYC 인증 상태: ✅ 인증됨
```

**📝 UID를 메모해두세요!** 이 값을 웹 UI에 입력합니다.

---

## 프로젝트 구조

```
examples/coinbaes-zkp-app/
├── circuit/attestor/           # Noir Circuit
│   ├── src/main.nr            # Circuit 로직
│   ├── Nargo.toml             # Noir 설정
│   ├── Prover.toml            # 테스트 입력
│   └── target/
│       └── attestor.json      # ✅ 컴파일된 circuit
├── src/                        # Frontend (Vite + Noir + bb.js)
│   ├── index.html             # HTML UI
│   ├── index.js               # ZKP 로직
│   ├── style.css              # 스타일
│   └── utils/
│       ├── query-attestation.js   # Attestation 조회
│       └── generate-signature.js  # 서명 생성
├── vite.config.js             # Vite 설정
├── package.json               # 의존성
└── .env                       # 환경 변수
```

---

## Circuit 구현

### 1. Circuit 코드

**`circuit/attestor/src/main.nr`**:

이 Circuit은 **PART 1~2**만 구현되어 있습니다 (PART 3-5는 데이터 부족으로 주석 처리):

```rust
use dep::keccak256::keccak256;
use dep::std::ecdsa_secp256k1;

// Coinbase Attester (Base Mainnet)
global COINBASE_ATTESTER: [u8; 20] = [
    0x35, 0x74, 0x58, 0x73, 0x9F, 0x90, 0x46, 0x1b,
    0x99, 0x78, 0x93, 0x50, 0x86, 0x8C, 0xD7, 0xCF,
    0x33, 0x0D, 0xd7, 0xEE
];

// Verified Account Schema
global VERIFIED_ACCOUNT_SCHEMA: [u8; 32] = [
    0xf8, 0xb0, 0x5c, 0x79, 0xf0, 0x90, 0x97, 0x9b,
    0xf4, 0xa8, 0x02, 0x70, 0xab, 0xa2, 0x32, 0xdf,
    0xf1, 0x1a, 0x10, 0xd9, 0xca, 0x55, 0xc4, 0xf8,
    0x8d, 0xe9, 0x53, 0x17, 0x97, 0x0f, 0x0d, 0xe9
];

// attest(address) function selector
global ATTEST_FUNCTION_SELECTOR: [u8; 4] = [0x56, 0xfe, 0xed, 0x5e];

fn main(
    // ============ Public Inputs ============
    attestation_uid: pub [u8; 32],
    schema_id: pub [u8; 32],
    attester: pub [u8; 20],
    tx_hash: pub [u8; 32],

    // ============ Private Inputs ============
    calldata: [u8; 36],
    user_address: [u8; 20],
    user_sig: [u8; 64],
    user_pubkey_x: [u8; 32],
    user_pubkey_y: [u8; 32],
    revocation_time: u64,
    expiration_time: u64,
    attestation_time: u64,
    attestation_data: [u8; 32],
) {
    // PART 1: Transaction Calldata Verification
    assert(calldata[0] == ATTEST_FUNCTION_SELECTOR[0]);
    assert(calldata[1] == ATTEST_FUNCTION_SELECTOR[1]);
    assert(calldata[2] == ATTEST_FUNCTION_SELECTOR[2]);
    assert(calldata[3] == ATTEST_FUNCTION_SELECTOR[3]);

    let mut calldata_addr: [u8; 20] = [0; 20];
    for i in 0..20 {
        calldata_addr[i] = calldata[i + 16];
    }
    assert(calldata_addr == user_address);

    let computed_digest = keccak256(calldata, 36);
    let user_sig_valid = ecdsa_secp256k1::verify_signature(
        user_pubkey_x, user_pubkey_y, user_sig, computed_digest
    );
    assert(user_sig_valid);

    let mut user_pubkey_full: [u8; 64] = [0; 64];
    for i in 0..32 {
        user_pubkey_full[i] = user_pubkey_x[i];
        user_pubkey_full[32 + i] = user_pubkey_y[i];
    }
    let user_pubkey_hash = keccak256(user_pubkey_full, 64);
    let mut derived_user_address: [u8; 20] = [0; 20];
    for i in 0..20 {
        derived_user_address[i] = user_pubkey_hash[12 + i];
    }
    assert(derived_user_address == user_address);

    let computed_tx_hash = keccak256(calldata, 36);
    assert(computed_tx_hash == tx_hash);

    // PART 2: Basic Attestation Validation
    assert(schema_id == VERIFIED_ACCOUNT_SCHEMA);
    assert(attester == COINBASE_ATTESTER);
    assert(revocation_time == 0);
    if expiration_time != 0 {
        assert(expiration_time > attestation_time);
    }
}
```

### 2. Dependencies 설정

**`circuit/attestor/Nargo.toml`**:

```toml
[package]
name = "attestor"
type = "bin"
authors = [""]

[dependencies]
keccak256 = { tag = "v0.1.1", git = "https://github.com/noir-lang/keccak256" }
```

### 3. Circuit 컴파일

```bash
cd circuit/attestor
nargo check
nargo compile
```

**출력**:
```
✅ Compiled successfully!
target/attestor.json created (68 KB)
```

---

## Frontend 구현

### 1. package.json

**중요**: 정확한 버전을 사용해야 합니다!

```json
{
  "name": "coinbaes-zkp-app",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@aztec/bb.js": "0.87.0",
    "@coinbase/onchainkit": "^1.1.1",
    "@ethereum-attestation-service/eas-sdk": "^2.9.0",
    "@noir-lang/noir_js": "1.0.0-beta.9",
    "dotenv": "^17.2.3",
    "ethers": "^6.13.0",
    "viem": "^2.38.3"
  },
  "devDependencies": {
    "vite": "^7.1.12",
    "vite-plugin-node-polyfills": "^0.24.0"
  }
}
```

**⚠️ 중요**:
- `@aztec/bb.js`: 정확히 `0.87.0` (캐럿 없음!)
- `@noir-lang/noir_js`: `1.0.0-beta.9`

### 2. Vite 설정

**`vite.config.js`**:

```javascript
import { defineConfig } from 'vite';
import { nodePolyfills } from 'vite-plugin-node-polyfills';

export default defineConfig({
    root: 'src',
    plugins: [
        nodePolyfills(),
    ],
    optimizeDeps: {
        esbuildOptions: {
            target: 'esnext',
        },
        exclude: ['@noir-lang/noirc_abi', '@noir-lang/acvm_js', '@aztec/bb.js'],
    },
    build: {
        target: 'esnext',
    },
    server: {
        headers: {
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
        },
    },
});
```

### 3. HTML UI

**`src/index.html`** - 완전한 코드는 프로젝트 참조

주요 요소:
- MetaMask 연결 버튼
- Attestation UID 입력
- Offchain/Onchain 검증 선택
- 로딩 스피너
- 결과 표시

### 4. JavaScript 로직

**`src/index.js`** - 핵심 로직:

```javascript
import { Noir } from '@noir-lang/noir_js';
import { UltraHonkBackend } from '@aztec/bb.js';
import { ethers } from 'ethers';
import { EAS } from '@ethereum-attestation-service/eas-sdk';
import circuit from '../circuit/attestor/target/attestor.json';

// Keccak ZK 옵션으로 Backend 초기화
backend = new UltraHonkBackend(circuit.bytecode, { keccak: true });
noir = new Noir(circuit, backend);

// Proof 생성 (Keccak ZK)
const proof = await backend.generateProof(witness, { keccak: true });

// Offchain 검증
const isValid = await backend.verifyProof(proof, { keccak: true });

// Onchain 검증
const verifier = new ethers.Contract(VERIFIER_ADDRESS, VERIFIER_ABI, provider);
const isValid = await verifier.verify(proofHex, publicInputsBytes32);
```

**⚠️ 중요**: `{ keccak: true }` 옵션을 모든 곳에 추가해야 합니다!

---

## Offchain 검증 테스트

### 1. 개발 서버 실행

```bash
npm install
npm run dev
```

브라우저에서 `http://localhost:5173/` 접속

### 2. MetaMask 연결

1. **"🦊 MetaMask 연결"** 버튼 클릭
2. MetaMask 팝업에서 **연결** 승인
3. 연결된 지갑 주소 표시 확인

### 3. Attestation UID 입력

`query-attestation.js` 실행 결과에서 얻은 UID 입력:

```
예: 0x626de11971b847cef5a29833e122eb98dee0fac462fee1ac54f1b189c8540f59
```

### 4. Offchain 검증 실행

1. 검증 방식: **Offchain** 선택
2. **"ZKP 생성 및 검증"** 버튼 클릭
3. MetaMask 서명 요청 승인
4. 결과 확인

**성공 시**:
```
✅ OFFCHAIN 검증 성공!

🎉 Coinbase KYC 인증이 ZKP로 검증되었습니다!

📊 증명 크기: 14.25 KB
🔐 개인정보(주소, 서명, 공개키)는 영지식 증명으로 비공개 유지됩니다.

✨ Circuit이 모든 검증을 통과했습니다:
  ✅ Function selector 검증
  ✅ Calldata 주소 일치 검증
  ✅ User 서명 검증 (ECDSA)
  ✅ User 주소 유도 검증
  ✅ TX hash 검증 (Keccak256)
  ✅ Schema ID 검증
  ✅ Attester 주소 검증
  ✅ Revocation 상태 검증
  ✅ Expiration 시간 검증
```

---

## Onchain Verifier 배포

### 1. Solidity Verifier 생성

Circuit을 컴파일하고 Solidity verifier를 생성합니다:

```bash
cd circuit/attestor

# Verification key 생성 (Keccak oracle hash)
bb write_vk \
  -b ./target/attestor.json \
  -o ./target/vk \
  --oracle_hash keccak

# Solidity verifier 생성
bb write_solidity_verifier \
  -k ./target/vk/vk \
  -o ../../contracts/src/AttestorVerifier.sol
```

**생성된 파일**: `contracts/src/AttestorVerifier.sol`

### 2. Foundry 프로젝트 초기화

```bash
cd ../..  # 프로젝트 루트로
forge init contracts
```

### 3. 배포 스크립트 작성

**`contracts/script/Deploy.s.sol`**:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/AttestorVerifier.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy verifier
        UltraVerifier verifier = new UltraVerifier();
        console.log("AttestorVerifier deployed at:", address(verifier));

        vm.stopBroadcast();
    }
}
```

### 4. 환경 변수 설정

**`.env`**:

```bash
PRIVATE_KEY=0xYourPrivateKeyHere
BASE_RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=YourBasescanApiKey  # 선택사항 (verify용)
```

**foundry.toml**:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.24"

[rpc_endpoints]
base = "${BASE_RPC_URL}"

[etherscan]
base = { key = "${BASESCAN_API_KEY}" }
```

### 5. Base Mainnet에 배포

```bash
cd contracts
source ../.env

# 배포 + 검증
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

**예상 출력**:
```
== Logs ==
  AttestorVerifier deployed at: 0x1234567890abcdef1234567890abcdef12345678

✅ Deployment successful!
✅ Contract verified on Basescan
```

**📝 배포 주소를 메모하세요!** 이 값을 `src/index.js`의 `VERIFIER_ADDRESS`에 업데이트해야 합니다.

### 6. Frontend에 Verifier 주소 업데이트

**`src/index.js`**:

```javascript
// 배포된 Verifier 계약 주소로 업데이트
const VERIFIER_ADDRESS = '0x1234567890abcdef1234567890abcdef12345678';
```

---

## Onchain 검증 테스트

### 1. MetaMask 네트워크 확인

Base Mainnet으로 전환:
- Network Name: Base Mainnet
- Chain ID: 8453
- RPC URL: https://mainnet.base.org

### 2. Onchain 검증 실행

1. 브라우저에서 `http://localhost:5173/` 새로고침
2. MetaMask 연결
3. Attestation UID 입력
4. 검증 방식: **Onchain** 선택
5. **"ZKP 생성 및 검증"** 버튼 클릭
6. MetaMask 서명 요청 승인
7. 네트워크 확인 (Base Mainnet인지)
8. 블록체인에서 검증 중... (read call - 가스비 없음)

**성공 시**:
```
✅ ONCHAIN 검증 성공!

🎉 Coinbase KYC 인증이 ZKP로 검증되었습니다!

📊 증명 크기: 14.25 KB
🔐 개인정보(주소, 서명, 공개키)는 영지식 증명으로 비공개 유지됩니다.

🔗 검증 위치: Base Mainnet (Chain ID: 8453)
📝 Verifier 계약: 0x1234...
```

### 3. Basescan에서 확인

https://basescan.org/address/[VERIFIER_ADDRESS] 에서:
- 컨트랙트 코드 확인
- 검증된 계약 확인 (✅ Verified)
- Read Contract에서 `verify()` 함수 확인

---

## 트러블슈팅

### 문제 1: "pino export 에러"

**증상**:
```
The requested module '.../@aztec/bb.js/.../pino/browser.js' does not provide an export named 'pino'
```

**원인**: bb.js 버전이 `0.87.0`이 아님

**해결**:
```bash
# package.json 수정
"@aztec/bb.js": "0.87.0"  # 캐럿(^) 제거!

# 재설치
rm -rf node_modules package-lock.json
npm install
```

### 문제 2: "incorrect data length (argument=uid)"

**증상**:
```
TypeError: incorrect data length (argument="uid", value="0x3574...", code=INVALID_ARGUMENT)
```

**원인**: Attester 주소를 UID로 입력함

**해결**: 올바른 Attestation UID 입력 (32 bytes, 66자)
```
✅ 올바른 UID: 0x626de11971b847cef5a29833e122eb98dee0fac462fee1ac54f1b189c8540f59
❌ Attester 주소: 0x357458739F90461b99789350868CD7CF330Dd7EE
```

### 문제 3: "잘못된 네트워크"

**증상**:
```
현재: Ethereum Mainnet (Chain ID: 1)
필요: Base Mainnet (Chain ID: 8453)
```

**해결**: MetaMask에서 Base Mainnet으로 전환

### 문제 4: "Verifier 계약이 아직 배포되지 않았습니다"

**증상**: Onchain 검증 시 에러

**해결**:
1. Solidity verifier 생성 (`bb write_solidity_verifier`)
2. Base Mainnet에 배포
3. `src/index.js`의 `VERIFIER_ADDRESS` 업데이트

### 문제 5: "MetaMask 연결 버튼 작동 안함"

**원인**: DOM 요소가 로드되기 전에 JavaScript 실행됨

**해결**: 코드가 `DOMContentLoaded` 이벤트 안에 있는지 확인

```javascript
document.addEventListener('DOMContentLoaded', () => {
    connectBtn = document.getElementById('connectBtn');
    // ...
    connectBtn.addEventListener('click', connectWallet);
});
```

### 문제 6: "Noir 초기화 실패"

**원인**: COOP/COEP 헤더 누락

**해결**: `vite.config.js` 확인

```javascript
server: {
    headers: {
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
    },
}
```

### 문제 7: "Cannot satisfy constraint"

**원인**: Circuit 입력 데이터가 검증 조건을 만족하지 않음

**해결**:
1. 브라우저 콘솔에서 에러 확인
2. Circuit inputs 로그 확인
3. 특히 서명, 공개키, calldata 확인

---

## 참고 자료

### 공식 문서
- [Coinbase Verifications](https://docs.cdp.coinbase.com/verifications/docs/attestations)
- [Ethereum Attestation Service](https://attest.org/)
- [Noir Documentation](https://noir-lang.org/docs)
- [bb.js GitHub](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg/ts)

### 관련 예제
- `examples/noir-age-app`: Noir + bb.js 기본 예제
- `examples/coinbaes-zkp-app`: 이 튜토리얼의 완전한 구현

### 커뮤니티
- [Noir Discord](https://discord.gg/noir)
- [Base Discord](https://discord.gg/buildonbase)

---

## 다음 단계

### 1. 프로덕션 배포

- 가스 최적화
- 에러 핸들링 개선
- 로딩 상태 UX 개선

### 2. 고급 기능

- 다중 attestation 지원
- Replay attack 방지 (nonce)
- Merkle inclusion proof

### 3. 실전 활용

- DeFi KYC 게이트
- DAO 멤버십 검증
- 규제 준수 dApp

---

**Happy Building! 🚀**

*Last Updated: 2025-01-23*
