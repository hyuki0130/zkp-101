# 🎯 사용 가이드 - Coinbase Attestor ZKP

## 🚀 빠른 시작

### 1. 서버 실행

```bash
./start-browser-test.sh
```

또는

```bash
npm run dev
```

브라우저가 자동으로 http://localhost:3000 에서 열립니다.

## 📋 사용 방법

### Step 1: MetaMask 연결 🦊

1. **"🦊 Connect MetaMask" 버튼 클릭**
2. MetaMask 팝업에서 연결 승인
3. 연결되면 버튼이 "연결됨: 0x1234...5678"로 변경됨
4. User Address 필드에 자동으로 지갑 주소 입력됨

**주의사항:**
- MetaMask가 설치되어 있어야 합니다
- Base Mainnet에 Coinbase KYC Attestation이 있어야 합니다

### Step 2: Coinbase KYC Transaction 가져오기 📡

1. **"🔍 Base에서 트랜잭션 가져오기" 버튼 클릭**
2. 자동으로 Base 네트워크의 EAS GraphQL에서 조회
3. Coinbase KYC Attestation을 찾아서 트랜잭션 데이터 추출
4. 모든 입력 필드가 자동으로 채워짐:
   - User Address
   - Transaction Hash
   - Transaction Length
   - Raw Transaction (300 bytes)
   - Transaction Signature (65 bytes: r + s + v)

**작동 방식:**
```
1. EAS GraphQL Query → Attestation UID + TX Hash
2. Base RPC → Raw Transaction Data
3. Extract Signature → r, s, v
4. Format for Circuit → byte arrays
```

**에러 처리:**
- "Attestation을 찾을 수 없습니다" → Coinbase KYC 인증 필요
- "Transaction not found" → 블록체인 동기화 대기

### Step 3: Circuit Inputs 확인 📝

이 단계에서는 자동으로 채워진 입력을 확인할 수 있습니다:

- ✅ **User Address**: 지갑 주소 (20 bytes)
- ✅ **TX Hash**: 트랜잭션 해시 (32 bytes)
- ✅ **TX Length**: 실제 트랜잭션 길이
- ✅ **Raw Transaction**: 직렬화된 트랜잭션 (300 bytes, 패딩 포함)
- ✅ **TX Signature**: ECDSA 서명 (r: 32 bytes, s: 32 bytes, v: 1 byte)

**필드는 readonly 상태입니다** (자동 입력만 가능)

**테스트용 샘플 데이터:**
- "Load Sample Data (테스트용)" 버튼으로 플레이스홀더 데이터 로드 가능
- 실제 증명 생성은 불가능하지만 UI 테스트에 유용

### Step 4: Proof 생성 및 검증 ⚡

#### 증명 생성
1. **"🔨 Generate Proof" 버튼 클릭**
2. 진행 상황 확인:
   ```
   📝 Reading inputs...
   🔨 Generating proof... This may take a while...
   ```
3. 10-30초 대기 (하드웨어에 따라 다름)
4. 성공 메시지:
   ```
   ✅ Proof generated successfully in XX.XXs!
   ```

**증명 생성 과정:**
```
1. Parse inputs → Validate format
2. Execute circuit → Complete ECRecover
   - Parse raw transaction
   - Extract signature (r, s, v)
   - Recover public key from signature
   - Convert pubkey to address
   - Verify signer is Coinbase
3. Generate ZK proof → Barretenberg backend
```

#### 증명 검증
1. **"✅ Verify Proof" 버튼 클릭** (증명 생성 후 활성화됨)
2. 1-3초 대기
3. 검증 결과 확인:
   ```json
   {
     "valid": true,
     "verificationTime": "1.23s",
     "message": "✅ The proof is valid!"
   }
   ```

## 📊 결과 확인

### Proof 메트릭스
- **Generation Time**: 증명 생성 시간 (초)
- **Proof Size**: 증명 크기 (KB)
- **Public Inputs**: 공개 입력 개수

### 검증 결과
- ✅ **Valid**: 트랜잭션이 Coinbase에 의해 서명되었음을 증명
- ❌ **Invalid**: 서명이 유효하지 않거나 입력이 잘못됨

## 🔍 디버깅

### 브라우저 콘솔 (F12)

모든 단계의 상세 로그를 확인할 수 있습니다:

```javascript
// 초기화
🚀 Coinbase Attestor ZKP - Browser Test loaded!
✅ Noir backend initialized successfully!

// MetaMask 연결
✅ Wallet connected: 0x...

// 트랜잭션 조회
📋 Querying attestations for: 0x...
✅ Attestation found: {...}
📄 Transaction hash: 0x...
✅ Raw transaction fetched: 0x...
🔑 Signature extracted:
  r: ...
  s: ...
  v: ...

// 증명 생성
Circuit inputs: {...}
Proof generated: {...}
```

## ⚠️ 문제 해결

### 1. MetaMask 연결 실패
**증상**: "MetaMask가 설치되어 있지 않습니다"
**해결**: https://metamask.io 에서 MetaMask 설치

### 2. Attestation을 찾을 수 없음
**증상**: "Coinbase KYC Attestation을 찾을 수 없습니다"
**해결**:
- Coinbase 앱에서 KYC 인증 완료
- Base Mainnet에 Attestation 생성 확인
- 올바른 지갑 주소로 연결했는지 확인

### 3. 증명 생성 실패
**증상**: "Proof generation failed"
**원인**:
- 잘못된 입력 형식
- 회로 제약조건 위반
- 메모리 부족

**해결**:
- 브라우저 콘솔에서 에러 메시지 확인
- 입력 데이터 형식 검증
- 브라우저 재시작

### 4. 증명 검증 실패
**증상**: "Proof verification failed"
**원인**:
- 증명이 올바르게 생성되지 않음
- 공개 입력이 변경됨

**해결**:
- 증명을 다시 생성
- 입력 데이터 확인

## 🎯 워크플로우 요약

```
1. 🦊 Connect MetaMask
   ↓
2. 📡 Fetch Transaction from Base
   ↓
3. 📝 Review Circuit Inputs (auto-filled)
   ↓
4. 🔨 Generate Proof (10-30s)
   ↓
5. ✅ Verify Proof (1-3s)
   ↓
6. 📊 Check Results
```

## 💡 팁

1. **첫 번째 증명이 가장 느립니다**
   - WASM 초기화 시간 포함
   - 이후 증명은 더 빠름

2. **네트워크 연결 필요**
   - Base 네트워크 조회를 위해 인터넷 연결 필요
   - GraphQL API 호출 필요

3. **브라우저 성능**
   - Chrome/Edge 권장 (WebAssembly 최적화)
   - 최소 4GB RAM 권장

4. **개발자 도구 활용**
   - F12 → Console: 상세 로그
   - F12 → Network: API 호출 확인
   - F12 → Application: Storage 확인

## 🔗 관련 문서

- [QUICK-START.md](./QUICK-START.md) - 빠른 시작 가이드
- [BROWSER-TEST.md](./BROWSER-TEST.md) - 브라우저 테스트 상세
- [CLAUDE.md](./CLAUDE.md) - 구현 요구사항

## 🎉 성공 사례

증명이 성공적으로 생성되고 검증되면:

```
✅ Proof generated successfully in 15.32s!

Metrics:
- Generation Time: 15.32s
- Proof Size: 8.45 KB
- Public Inputs: 3

✅ Proof verified successfully in 1.23s!

Result:
{
  "valid": true,
  "message": "✅ The proof is valid!
              The transaction was signed by the expected signer."
}
```

이제 영지식 증명으로 Coinbase KYC 인증을 검증했습니다! 🎊
