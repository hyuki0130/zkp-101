# 🚀 Coinbase Attestor ZKP - Quick Start Guide

## 📁 프로젝트 구조

```
attestor/
├── src/
│   ├── index.html          # 브라우저 UI
│   ├── index.js            # 브라우저 로직
│   ├── main.nr             # 메인 회로
│   ├── ecrecover.nr        # ECRecover 구현
│   ├── secp256k1.nr        # secp256k1 타원곡선 연산
│   ├── tx_parser.nr        # 트랜잭션 파싱
│   └── bignum_lib/         # 로컬 bignum 라이브러리
├── target/
│   └── attestor.json       # 컴파일된 회로 (1.2 MB)
├── package.json            # npm 의존성
├── vite.config.js          # Vite 설정
└── start-browser-test.sh   # 원클릭 실행 스크립트
```

## ⚡ 빠른 시작 (3단계)

### 1️⃣ 스크립트 실행

```bash
./start-browser-test.sh
```

### 2️⃣ 브라우저 열기

자동으로 브라우저가 열립니다: http://localhost:3000 (또는 3001)

### 3️⃣ 테스트

1. "Load Sample Data" 버튼 클릭
2. "Generate Proof" 버튼 클릭 (10-30초 소요)
3. "Verify Proof" 버튼 클릭 (1-3초 소요)

## 🎯 현재 상태

✅ **회로 컴파일 완료**
- ACIR Opcodes: 6,326개
- Brillig Opcodes: 133,596개
- 회로 크기: 1.2 MB

✅ **브라우저 UI 완성**
- 입력 폼 (user_address, tx_hash, raw_transaction, tx_signature)
- 증명 생성/검증 버튼
- 실시간 상태 표시
- 결과 시각화

✅ **완전한 ECRecover 구현**
- secp256k1 타원곡선 연산
- 공개키 복구
- 주소 변환
- Coinbase 서명자 검증

## 🔧 수동 실행 (디버깅용)

```bash
# 1. 의존성 설치
npm install

# 2. 회로 확인 (이미 컴파일됨)
ls -lh target/attestor.json

# 3. 개발 서버 시작
npm run dev

# 4. 브라우저에서 http://localhost:3000 열기
```

## 📊 성능 메트릭

**증명 생성:**
- 시간: 10-30초 (하드웨어에 따라 다름)
- 증명 크기: ~5-10 KB

**증명 검증:**
- 시간: 1-3초
- 결과: true/false

## ⚠️ 참고 사항

1. **샘플 데이터는 플레이스홀더입니다**
   - 실제 Coinbase 트랜잭션 데이터로 교체 필요
   - 현재는 UI 테스트용

2. **첫 번째 증명 생성이 가장 느립니다**
   - WASM 초기화 시간 포함
   - 이후 증명은 더 빠름

3. **브라우저 콘솔 확인**
   - F12 → Console 탭
   - 상세한 로그 및 에러 메시지 확인

## 🐛 문제 해결

### 포트가 이미 사용 중
```
Port 3000 is in use, trying another one...
```
→ 자동으로 3001 포트 사용됨 (정상)

### Circuit not found
```
Failed to initialize: Cannot find module '../target/attestor.json'
```
→ `nargo compile` 실행 필요

### npm install 실패
```
npm error code ETARGET
```
→ Node.js 버전 확인: `node --version` (v18+ 필요)

## 📚 상세 가이드

자세한 사용법은 다음 문서를 참고하세요:
- [BROWSER-TEST.md](./BROWSER-TEST.md) - 브라우저 테스트 가이드
- [CLAUDE.md](./CLAUDE.md) - 구현 요구사항 및 제약사항
- [README.md](./README.md) - 프로젝트 개요

## 🎉 성공!

브라우저에서 이렇게 보이면 성공입니다:

```
🔐 Coinbase Attestor ZKP
Browser-based Zero-Knowledge Proof Generation and Verification

✅ Noir backend initialized successfully!
```

이제 "Load Sample Data" → "Generate Proof" → "Verify Proof" 순서로 테스트하세요!
