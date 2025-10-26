#!/bin/bash

# Coinbase Attestation ZKP Verifier - Base Mainnet 배포 스크립트
# Foundry를 사용한 Solidity Verifier 배포

set -e

# 색상 코드
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🚀 Coinbase Attestation ZKP Verifier - Base Mainnet 배포"
echo ""

# 0. .env 파일 로드
if [ -f .env ]; then
    echo "📄 .env 파일 로드 중..."
    export $(grep -v '^#' .env | xargs)
    echo -e "${GREEN}✅ .env 파일 로드 완료${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠️  .env 파일이 없습니다. 환경 변수를 수동으로 설정해주세요.${NC}"
    echo ""
fi

# 1. 환경 변수 확인
echo "📋 1. 환경 변수 확인 중..."
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY 환경 변수가 설정되지 않았습니다!${NC}"
    echo ""
    echo "사용법:"
    echo "  export PRIVATE_KEY=0x..."
    echo "  ./deploy.sh"
    echo ""
    exit 1
fi

if [ -z "$BASE_RPC_URL" ]; then
    BASE_RPC_URL="https://mainnet.base.org"
    echo -e "${YELLOW}⚠️  BASE_RPC_URL 미설정, 기본값 사용: $BASE_RPC_URL${NC}"
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  ETHERSCAN_API_KEY 미설정, Etherscan 검증 건너뜀${NC}"
    VERIFY_FLAG=""
else
    VERIFY_FLAG="--verify --etherscan-api-key $ETHERSCAN_API_KEY"
fi

echo -e "${GREEN}✅ 환경 변수 확인 완료${NC}"
echo ""

# 2. Verifier 파일 확인
VERIFIER_PATH="./contracts/AttestorVerifier.sol"
if [ ! -f "$VERIFIER_PATH" ]; then
    echo -e "${RED}❌ Verifier 파일이 없습니다: $VERIFIER_PATH${NC}"
    echo ""
    echo "먼저 빌드를 실행하세요:"
    echo "  cd circuit/attestor"
    echo "  ./build.sh"
    echo ""
    exit 1
fi

echo "📝 2. Verifier 파일 확인: $VERIFIER_PATH"
VERIFIER_LINES=$(wc -l < "$VERIFIER_PATH")
echo "   - 라인 수: $VERIFIER_LINES"
echo -e "${GREEN}✅ Verifier 파일 확인 완료${NC}"
echo ""

# 3. Foundry 설치 확인
echo "🔧 3. Foundry 설치 확인 중..."
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry가 설치되지 않았습니다!${NC}"
    echo ""
    echo "Foundry 설치:"
    echo "  curl -L https://foundry.paradigm.xyz | bash"
    echo "  foundryup"
    echo ""
    exit 1
fi

FORGE_VERSION=$(forge --version | head -n 1)
echo "   - Forge 버전: $FORGE_VERSION"
echo -e "${GREEN}✅ Foundry 설치 확인 완료${NC}"
echo ""

# 4. Foundry 프로젝트 초기화 (이미 있으면 스킵)
if [ ! -f "foundry.toml" ]; then
    echo "📦 4. Foundry 프로젝트 초기화 중..."
    forge init --no-git --force .
    echo -e "${GREEN}✅ Foundry 프로젝트 초기화 완료${NC}"
    echo ""
else
    echo "📦 4. Foundry 프로젝트 이미 초기화됨"
    echo ""
fi

# 5. Verifier를 src 디렉토리로 복사
echo "📂 5. Verifier 파일 복사 중..."
mkdir -p src
cp "$VERIFIER_PATH" src/
echo -e "${GREEN}✅ src/AttestorVerifier.sol 복사 완료${NC}"
echo ""

# 6. Base 네트워크 정보 확인
echo "🌐 6. Base 네트워크 정보 확인 중..."
CHAIN_ID=$(cast chain-id --rpc-url $BASE_RPC_URL 2>/dev/null || echo "Unknown")

if [ "$CHAIN_ID" = "8453" ]; then
    NETWORK_NAME="Base Mainnet"
    EXPLORER="https://basescan.org"
    echo -e "${GREEN}   - Network: Base Mainnet${NC}"
elif [ "$CHAIN_ID" = "84532" ]; then
    NETWORK_NAME="Base Sepolia Testnet"
    EXPLORER="https://sepolia.basescan.org"
    echo -e "${YELLOW}   - Network: Base Sepolia (Testnet)${NC}"
else
    NETWORK_NAME="Unknown (Chain ID: $CHAIN_ID)"
    EXPLORER="Unknown"
    echo -e "${RED}   - Network: Unknown (Chain ID: $CHAIN_ID)${NC}"
fi

echo "   - Chain ID: $CHAIN_ID"
echo "   - RPC URL: $BASE_RPC_URL"
echo "   - Explorer: $EXPLORER"
echo ""

# 7. Private Key에서 지갑 주소 파생 및 잔액 확인
echo "💰 7. 배포 지갑 확인 중..."
DEPLOYER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "")
if [ -n "$DEPLOYER_ADDRESS" ]; then
    echo "   - 배포 지갑: $DEPLOYER_ADDRESS"
    BALANCE=$(cast balance $DEPLOYER_ADDRESS --rpc-url $BASE_RPC_URL 2>/dev/null || echo "Unknown")
    if [ "$BALANCE" != "Unknown" ]; then
        ETH_BALANCE=$(cast from-wei $BALANCE 2>/dev/null || echo "Unknown")
        echo "   - 잔액: $ETH_BALANCE ETH"

        # 잔액이 충분한지 확인 (0.001 ETH 이상 권장)
        MIN_BALANCE="1000000000000000"  # 0.001 ETH in wei
        if [ "$BALANCE" != "Unknown" ] && [ "$BALANCE" -lt "$MIN_BALANCE" ]; then
            echo -e "${YELLOW}   ⚠️  잔액이 부족할 수 있습니다. 최소 0.01 ETH 권장${NC}"
        fi
    else
        echo -e "${YELLOW}   - RPC 연결 실패, 잔액 확인 불가${NC}"
    fi
else
    echo -e "${YELLOW}   - Private Key로부터 주소 파생 실패${NC}"
fi
echo ""

# 8. 배포 확인
if [ "$CHAIN_ID" = "8453" ]; then
    echo -e "${RED}⚠️  Base Mainnet에 배포하려고 합니다! (실제 ETH 소모)${NC}"
else
    echo -e "${YELLOW}⚠️  $NETWORK_NAME 에 배포하려고 합니다!${NC}"
fi
echo ""
echo "계속하시겠습니까? (y/N)"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "배포 취소됨"
    exit 0
fi

echo ""
echo "🚀 8. AttestorVerifier 배포 중..."
echo ""

# 9. Forge로 배포 (실시간 출력)
echo "컴파일 및 배포 시작..."
echo ""

set +e  # 에러가 나도 계속 진행

forge create src/AttestorVerifier.sol:HonkVerifier \
    --rpc-url "$BASE_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    $VERIFY_FLAG \
    --broadcast \
    --legacy \
    2>&1 | tee /tmp/deploy_output.log

DEPLOY_EXIT_CODE=${PIPESTATUS[0]}

set -e  # 다시 에러 시 중단 모드로

echo ""
echo "배포 완료, 결과 처리 중..."

# 배포된 컨트랙트 주소 추출
DEPLOYED_ADDRESS=$(grep -i "Deployed to:" /tmp/deploy_output.log | awk '{print $3}')

if [ $DEPLOY_EXIT_CODE -eq 0 ] && [ -n "$DEPLOYED_ADDRESS" ]; then
    echo ""
    echo -e "${GREEN}🎉 배포 성공!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}📍 배포된 컨트랙트 주소:${NC}"
    echo ""
    echo -e "   ${YELLOW}$DEPLOYED_ADDRESS${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 배포 정보:"
    echo "   - Network: $NETWORK_NAME (Chain ID: $CHAIN_ID)"
    echo "   - Contract: HonkVerifier"
    echo "   - Deployer: $DEPLOYER_ADDRESS"
    echo ""
    echo "🔗 Explorer:"
    echo "   $EXPLORER/address/$DEPLOYED_ADDRESS"
    echo ""
    echo "💡 다음 단계:"
    echo ""
    echo "   1. src/index.js 파일 열기"
    echo ""
    echo "   2. VERIFIER_ADDRESS 업데이트:"
    echo -e "      ${YELLOW}const VERIFIER_ADDRESS = '$DEPLOYED_ADDRESS';${NC}"
    echo ""
    echo "   3. 프론트엔드 재시작:"
    echo "      npm run dev"
    echo ""
    echo "   4. MetaMask를 Base Sepolia로 전환 후 'Onchain' 검증 테스트"
    echo ""
elif [ $DEPLOY_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 배포 성공!${NC}"
    echo ""
    echo "⚠️  컨트랙트 주소를 자동으로 추출하지 못했습니다."
    echo "   위의 출력에서 'Deployed to:' 줄을 확인하세요."
    echo ""
    echo "📊 배포 정보:"
    echo "   - Network: $NETWORK_NAME (Chain ID: $CHAIN_ID)"
    echo "   - Contract: HonkVerifier"
    echo "   - Explorer: $EXPLORER"
    echo ""
else
    echo ""
    echo -e "${RED}❌ 배포 실패 (Exit code: $DEPLOY_EXIT_CODE)${NC}"
    echo ""
    exit 1
fi
