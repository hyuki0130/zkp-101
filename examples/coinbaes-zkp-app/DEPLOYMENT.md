# Coinbase Attestation ZKP - 배포 가이드

이 문서는 Coinbase Attestation ZKP Verifier를 Base Mainnet에 배포하는 방법을 설명합니다.

## 사전 준비

### 1. 필수 도구 설치

```bash
# bb CLI (v0.87.0-nightly)
curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
bbup -v 0.87.0

# Nargo (v1.0.0-beta.9)
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup -v 1.0.0-beta.9

# Foundry (Solidity 배포용)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 환경 변수 설정

**.env 파일 사용 (권장):**

```bash
# .env.example을 복사하여 .env 파일 생성
cp .env.example .env

# .env 파일 편집
# PRIVATE_KEY=0x... (MetaMask에서 추출한 Private Key)
# ETHERSCAN_API_KEY=... (Basescan에서 발급받은 API Key, 선택사항)
```

**.env 파일 예시:**
```bash
PRIVATE_KEY=0x1234567890abcdef...
ETHERSCAN_API_KEY=ABC123DEF456...
BASE_RPC_URL=https://mainnet.base.org
```

**또는 수동으로 환경 변수 설정:**

```bash
# Base Mainnet 배포용 Private Key
export PRIVATE_KEY=0x...

# Base RPC URL (선택사항, 기본값: https://mainnet.base.org)
export BASE_RPC_URL=https://mainnet.base.org

# Basescan API Key (선택사항, Etherscan 검증용)
export ETHERSCAN_API_KEY=...
```

⚠️ **보안 주의**: `.env` 파일은 `.gitignore`에 포함되어 있어 Git에 커밋되지 않습니다. 절대 GitHub에 올리지 마세요!

## 배포 절차

### Step 1: Circuit 빌드

Noir circuit을 컴파일하고 Solidity Verifier를 생성합니다.

```bash
cd circuit/attestor
./build.sh
```

이 스크립트는 다음을 수행합니다:
- ✅ Noir circuit 컴파일 (`attestor.json` 생성)
- ✅ Verification Key 생성 (Keccak ZK 옵션)
- ✅ 테스트 Witness 생성
- ✅ 테스트 Proof 생성 및 검증
- ✅ Solidity Verifier 생성 (`../../contracts/AttestorVerifier.sol`)

**출력 파일:**
```
circuit/attestor/target/
  ├── attestor.json       # Compiled circuit
  ├── vk/vk               # Verification key
  ├── proof/proof         # Test proof
  ├── proof.hex           # Hex-encoded proof
  └── public_inputs       # Public inputs

contracts/
  └── AttestorVerifier.sol  # Solidity verifier
```

### Step 2: Verifier 배포

생성된 Solidity Verifier를 Base Mainnet에 배포합니다.

```bash
cd ../..  # coinbaes-zkp-app 루트로 이동

# .env 파일이 있으면 자동으로 로드됩니다
./deploy.sh
```

**배포 스크립트는 자동으로 다음을 수행합니다:**
1. `.env` 파일 자동 로드 (있는 경우)
2. 환경 변수 검증
3. Private Key로부터 지갑 주소 자동 파생
4. 잔액 확인 및 경고

**배포 과정:**
1. 환경 변수 확인 (`PRIVATE_KEY` 필수)
2. Verifier 파일 확인 (`contracts/AttestorVerifier.sol`)
3. Foundry 설치 확인
4. Verifier를 `src/` 디렉토리로 복사
5. Base Mainnet 정보 출력
6. 배포 확인 프롬프트
7. `forge create`로 배포

**배포 성공 시:**
```
✅ 배포 성공!

📊 배포 정보:
   - Network: Base Mainnet (Chain ID: 8453)
   - Contract: UltraVerifier
   - Explorer: https://basescan.org

💡 다음 단계:
   1. Basescan에서 컨트랙트 주소 확인
   2. src/index.js에서 VERIFIER_ADDRESS 업데이트
   3. 프론트엔드에서 'Onchain' 검증 테스트
```

### Step 3: 프론트엔드 설정

배포된 Verifier 주소를 프론트엔드에 설정합니다.

**src/index.js 수정:**

```javascript
// 배포된 Verifier 주소로 업데이트
const VERIFIER_ADDRESS = '0x...';  // deploy.sh 출력에서 확인한 주소
```

### Step 4: 프론트엔드 실행 및 테스트

```bash
npm run dev
```

브라우저에서 `http://localhost:5173` 접속 후:

1. **MetaMask 연결**: Base Mainnet으로 네트워크 전환
2. **Attestation UID 입력**: EAS Scan에서 확인한 UID 입력
3. **검증 방식 선택**: `Onchain (Base Mainnet)` 선택
4. **ZKP 생성 및 검증**: 버튼 클릭

## 빌드 옵션 설명

### build.sh 주요 옵션

```bash
bb write_vk --oracle_hash keccak    # Keccak hash 사용 (EVM 최적화)
bb prove --oracle_hash keccak       # Keccak으로 Proof 생성
bb verify --oracle_hash keccak      # Keccak으로 검증
```

**Keccak ZK를 사용하는 이유:**
- ✅ EVM 네이티브 해시 함수 (가스비 절감)
- ✅ Poseidon2 대비 빠른 온체인 검증
- ✅ Ethereum/Base 블록체인 호환성

### deploy.sh 동작

```bash
forge create src/AttestorVerifier.sol:UltraVerifier \
    --rpc-url "$BASE_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --verify --etherscan-api-key "$ETHERSCAN_API_KEY" \
    --legacy
```

**플래그 설명:**
- `--rpc-url`: Base Mainnet RPC 엔드포인트
- `--private-key`: 배포 계정 Private Key
- `--verify`: Basescan에 자동 검증 (API Key 필요)
- `--legacy`: Legacy transaction 사용 (EIP-1559 대신)

## 트러블슈팅

### build.sh 실패

**문제:** `bb: command not found`

**해결:**
```bash
# bb CLI 재설치
curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
bbup -v 0.87.0
```

**문제:** `nargo: command not found`

**해결:**
```bash
# Nargo 재설치
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup -v 1.0.0-beta.9
```

**문제:** `Verifier 생성 실패`

**해결:**
```bash
# Circuit 재컴파일
cd circuit/attestor
nargo clean
nargo compile
```

### deploy.sh 실패

**문제:** `PRIVATE_KEY 환경 변수가 설정되지 않았습니다`

**해결:**
```bash
export PRIVATE_KEY=0x...  # 실제 Private Key로 교체
```

**문제:** `insufficient funds for gas`

**해결:**
- Base Mainnet에 충분한 ETH 보유 필요 (약 0.01 ETH)
- Bridge 사용: https://bridge.base.org

**문제:** `forge: command not found`

**해결:**
```bash
# Foundry 설치
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 온체인 검증 실패

**문제:** `MetaMask에서 transaction 실패`

**체크리스트:**
1. ✅ Base Mainnet 네트워크 연결 확인
2. ✅ VERIFIER_ADDRESS가 올바른 주소인지 확인
3. ✅ Verifier 컨트랙트가 올바르게 배포되었는지 Basescan에서 확인
4. ✅ 충분한 가스비 (약 0.001 ETH)

**문제:** `Proof 검증 실패 (false)`

**원인:**
- Circuit과 Verifier 버전 불일치
- Keccak ZK 옵션 누락

**해결:**
```bash
# Circuit 재빌드 (Keccak ZK 옵션 확인)
cd circuit/attestor
./build.sh

# Verifier 재배포
cd ../..
./deploy.sh
```

## 비용 예상

### 빌드 비용
- ✅ 무료 (로컬 실행)

### 배포 비용 (Base Mainnet)
- 가스비: 약 0.005 - 0.01 ETH
- 시간: 약 30초 - 1분

### 온체인 검증 비용
- 가스비: 약 0.0005 - 0.001 ETH per verification
- 시간: 약 5-10초

## 참고 자료

- [Noir 공식 문서](https://noir-lang.org/docs/)
- [bb CLI 문서](https://github.com/AztecProtocol/aztec-packages/tree/master/barretenberg)
- [Foundry Book](https://book.getfoundry.sh/)
- [Base Network 문서](https://docs.base.org/)
- [Basescan](https://basescan.org/)
- [EAS (Ethereum Attestation Service)](https://docs.attest.sh/)

## 라이센스

MIT License
