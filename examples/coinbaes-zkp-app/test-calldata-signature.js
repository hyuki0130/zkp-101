import { ethers } from 'ethers';

/**
 * index.js와 동일한 방식으로 Calldata 서명 생성 및 테스트
 *
 * index.js 로직:
 * 1. generateCalldata(userAddress) - 36 bytes calldata 생성
 * 2. keccak256(calldata) - digest 계산
 * 3. signer.signMessage(digest) - Ethereum Personal Sign
 * 4. 공개키 복구
 */

const ATTEST_FUNCTION_SELECTOR = '0x56feed5e';

function hexToBytes(hex) {
    const cleanHex = hex.startsWith('0x') ? hex.slice(2) : hex;
    const bytes = [];
    for (let i = 0; i < cleanHex.length; i += 2) {
        bytes.push(parseInt(cleanHex.substr(i, 2), 16));
    }
    return bytes;
}

function generateCalldata(address) {
    const selector = hexToBytes(ATTEST_FUNCTION_SELECTOR);
    const addr = hexToBytes(address);

    // Function selector (4 bytes) + padding (12 bytes) + address (20 bytes) = 36 bytes
    const calldata = new Array(36).fill(0);

    // Copy function selector
    for (let i = 0; i < 4; i++) {
        calldata[i] = selector[i];
    }

    // Skip 12 bytes padding (already 0)

    // Copy address
    for (let i = 0; i < 20; i++) {
        calldata[16 + i] = addr[i];
    }

    return calldata;
}

async function testCalldataSignature() {
    console.log('🔐 Calldata Signature Test (index.js와 동일한 로직)\n');

    // 1. 테스트용 지갑 생성
    const wallet = ethers.Wallet.createRandom();
    console.log('📋 Test Wallet:');
    console.log('  Address:', wallet.address);
    console.log('  Private Key:', wallet.privateKey);
    console.log('');

    // 2. Calldata 생성 (index.js의 generateCalldata와 동일)
    console.log('🔧 Step 1: Generate Calldata');
    const calldata = generateCalldata(wallet.address);
    const calldataHex = '0x' + calldata.map(b => b.toString(16).padStart(2, '0')).join('');
    console.log('  Calldata:', calldataHex);
    console.log('  Length:', calldata.length, 'bytes');
    console.log('');

    // 3. Digest 계산 (keccak256)
    console.log('🔢 Step 2: Calculate Digest');
    const digest = ethers.keccak256(calldataHex);
    console.log('  Digest (keccak256):', digest);
    console.log('');

    // 4. Ethereum Personal Sign으로 서명
    console.log('✍️  Step 3: Sign with Ethereum Personal Sign');
    const signature = await wallet.signMessage(ethers.getBytes(digest));
    console.log('  Signature:', signature);
    console.log('');

    // 5. 공개키 복구
    console.log('🔑 Step 4: Recover Public Key');
    const msgHash = ethers.hashMessage(ethers.getBytes(digest));
    const pubKey = ethers.SigningKey.recoverPublicKey(msgHash, signature);

    console.log('  Message Hash:', msgHash);
    console.log('  Public Key:', pubKey);

    const pubKeyHex = pubKey.slice(4); // Remove '0x04' prefix
    const pubKeyX = '0x' + pubKeyHex.slice(0, 64);
    const pubKeyY = '0x' + pubKeyHex.slice(64);

    console.log('  Public Key X:', pubKeyX);
    console.log('  Public Key Y:', pubKeyY);
    console.log('');

    // 6. 서명 분리 (r, s)
    console.log('📊 Step 5: Extract Signature Components');
    const sigBytes = ethers.getBytes(signature);
    const r = '0x' + Array.from(sigBytes.slice(0, 32)).map(b => b.toString(16).padStart(2, '0')).join('');
    const s = '0x' + Array.from(sigBytes.slice(32, 64)).map(b => b.toString(16).padStart(2, '0')).join('');
    const v = sigBytes[64];

    console.log('  r:', r);
    console.log('  s:', s);
    console.log('  v:', v);
    console.log('');

    // 7. 검증 (ethers.js)
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Verification (ethers.js)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    const recoveredAddress = ethers.verifyMessage(ethers.getBytes(digest), signature);
    console.log('  Original Address:', wallet.address);
    console.log('  Recovered Address:', recoveredAddress);
    console.log('  Match:', wallet.address === recoveredAddress ? '✅ YES' : '❌ NO');
    console.log('');

    // 8. Noir 서킷 입력 준비
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔧 Noir Circuit Inputs (Prover.toml format)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    const userAddressBytes = hexToBytes(wallet.address);
    const userSig = Array.from(sigBytes.slice(0, 64)); // r, s only (no v)
    const pubKeyXBytes = hexToBytes(pubKeyX);
    const pubKeyYBytes = hexToBytes(pubKeyY);

    console.log('# Public Inputs');
    console.log(`user_address = [${userAddressBytes.join(', ')}]`);
    console.log('');

    console.log('# Private Inputs');
    console.log(`user_signature = [${userSig.join(', ')}]`);
    console.log('');
    console.log(`user_pubkey_x = [${pubKeyXBytes.join(', ')}]`);
    console.log('');
    console.log(`user_pubkey_y = [${pubKeyYBytes.join(', ')}]`);
    console.log('');

    // 9. Prover.toml 생성
    const proverToml = `# Calldata Signature Test - Test Inputs (index.js 로직과 동일)

# Public Inputs
user_address = [${userAddressBytes.join(', ')}]

# Private Inputs
user_signature = [${userSig.join(', ')}]

user_pubkey_x = [${pubKeyXBytes.join(', ')}]

user_pubkey_y = [${pubKeyYBytes.join(', ')}]
`;

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📝 Generated Prover.toml');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log(proverToml);

    // 10. 다음 단계 안내
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🚀 Next Steps');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('1. Prover.toml 파일 업데이트:');
    console.log('   Copy the above content to circuit/attestor/Prover.toml');
    console.log('');

    console.log('2. 서킷 컴파일:');
    console.log('   cd circuit/attestor');
    console.log('   nargo compile');
    console.log('');

    console.log('3. Proof 생성:');
    console.log('   nargo prove');
    console.log('');

    console.log('4. Proof 검증:');
    console.log('   nargo verify');
    console.log('');

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📋 Summary');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('index.js와 동일한 로직:');
    console.log('  ✅ generateCalldata(userAddress) - 36 bytes');
    console.log('  ✅ keccak256(calldata) - digest');
    console.log('  ✅ signer.signMessage(digest) - Ethereum Personal Sign');
    console.log('  ✅ 공개키 복구');
    console.log('');

    console.log('서킷 검증 내용:');
    console.log('  1. Calldata 생성 (function selector + padding + address)');
    console.log('  2. Digest 계산 (keccak256)');
    console.log('  3. Ethereum Personal Sign 형식 변환');
    console.log('  4. ECDSA 서명 검증');
    console.log('  5. 공개키로부터 주소 파생');
    console.log('  6. 주소 일치 확인');
    console.log('');

    return {
        wallet,
        calldata,
        digest,
        signature,
        pubKey,
        proverToml
    };
}

testCalldataSignature().catch(console.error);
