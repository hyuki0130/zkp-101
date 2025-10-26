#!/bin/bash

# 간단한 배포 테스트 스크립트

set -x  # 디버그 모드: 실행되는 모든 명령어 출력

# .env 로드
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "=== 배포 테스트 시작 ==="
echo "RPC: $BASE_RPC_URL"
echo "Chain ID 확인 중..."
cast chain-id --rpc-url $BASE_RPC_URL

echo ""
echo "=== Forge 버전 ==="
forge --version

echo ""
echo "=== 컴파일 테스트 ==="
forge build --force

echo ""
echo "=== 배포 시작 (verbose 모드) ==="
forge create src/AttestorVerifier.sol:HonkVerifier \
    --rpc-url "$BASE_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --legacy \
    -vvvv

