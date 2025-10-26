#!/bin/bash

# bb CLI v0.87.0-nightly + Keccak을 사용한 전체 빌드 스크립트
# Coinbase Attestation ZKP - EVM 최적화된 빠른 온체인 검증을 위한 빌드!

set -e

echo "🔧 bb CLI v0.87.0-nightly + Keccak으로 빌드 시작..."
echo ""

# 버전 확인
BB_VERSION=$(bb --version)
echo "📌 bb CLI 버전: $BB_VERSION"
echo ""

rm -rf ./target ../../contracts && mkdir ../../contracts

# 1. Noir 컴파일
echo "📝 1. Noir circuit 컴파일 중..."
nargo compile
echo "✅ 컴파일 완료"
echo ""

# 2. Verification Key 생성 (Keccak oracle hash + ZK)
echo "🔑 2. Verification Key 생성 중 (Keccak + ZK)..."
bb write_vk \
  -b ./target/attestor.json \
  -o ./target/vk \
  --oracle_hash keccak
echo "✅ VK 생성 완료"
echo ""

# 3. Witness 생성 (예제 데이터)
echo "👤 3. Witness 생성 중..."
nargo execute witness
echo "✅ Witness 생성 완료"
echo ""

# 4. Proof 생성 (Keccak oracle hash + ZK)
echo "🔐 4. Proof 생성 중 (Keccak + ZK)..."
bb prove \
  -b ./target/attestor.json \
  -w ./target/witness.gz \
  -o ./target/proof \
  --oracle_hash keccak
PROOF_SIZE=$(wc -c < ./target/proof/proof)
echo "✅ Proof 생성 완료: $PROOF_SIZE bytes"
echo ""

# 5. Proof를 16진수로 변환
echo "🔄 5. Proof → Hex 변환 중..."
xxd -p ./target/proof/proof | tr -d '\n' > ./target/proof.hex
echo "0x$(cat ./target/proof.hex)" > ./target/proof.hex
echo "✅ Hex 변환 완료"
echo ""

# 6. Proof 검증 (Keccak oracle hash + ZK)
echo "✅ 6. Proof 검증 중 (Keccak + ZK)..."
# bb verify expects public_inputs in ./target directory
cp ./target/proof/public_inputs ./target/public_inputs
bb verify \
  -p ./target/proof/proof \
  -k ./target/vk/vk \
  --oracle_hash keccak
echo "✅ 검증 성공!"
echo ""

# 7. Solidity Verifier 생성
echo "📜 7. Solidity Verifier 생성 중 (Keccak + ZK)..."
bb write_solidity_verifier \
  -k ./target/vk/vk \
  -o ../../contracts/AttestorVerifier.sol
VERIFIER_LINES=$(wc -l < ../../contracts/AttestorVerifier.sol)
echo "✅ Verifier 생성 완료: $VERIFIER_LINES lines"
echo ""

# Verifier 타입 확인
echo "📊 Verifier 분석 중..."
if grep -q "BaseZKHonkVerifier" ../../contracts/AttestorVerifier.sol; then
    VERIFIER_TYPE="BaseZKHonkVerifier (빠른 EVM 검증! ⚡)"
elif grep -q "BaseHonkVerifier" ../../contracts/AttestorVerifier.sol; then
    VERIFIER_TYPE="BaseHonkVerifier (느린 검증)"
else
    VERIFIER_TYPE="Unknown"
fi
echo "  Verifier 타입: $VERIFIER_TYPE"

KECCAK_COUNT=$(grep -c "keccak256" ../../contracts/AttestorVerifier.sol || echo "0")
POSEIDON_COUNT=$(grep -c "Poseidon2" ../../contracts/AttestorVerifier.sol || echo "0")
echo "  keccak256 사용: $KECCAK_COUNT 번"
echo "  Poseidon2 사용: $POSEIDON_COUNT 번"
echo ""

echo "🎉 전체 빌드 완료!"
echo ""
echo "📊 생성된 파일:"
echo "  - Proof: ./target/proof/proof ($PROOF_SIZE bytes)"
echo "  - Public Inputs: ./target/proof/public_inputs"
echo "  - Proof Hex: ./target/proof.hex"
echo "  - VK: ./target/vk/vk"
echo "  - Verifier: ../../contracts/AttestorVerifier.sol ($VERIFIER_LINES lines)"
echo ""
echo "💡 bb CLI 버전: $BB_VERSION"
echo "🚀 Oracle Hash: Keccak (EVM 최적화!)"
echo ""
echo "📦 다음 단계: deploy.sh로 Base Mainnet에 배포하세요!"
