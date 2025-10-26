import { ethers } from 'ethers';

/**
 * Simple Address Ownership Proof 테스트
 *
 * 목표: 사용자가 메시지에 서명하고, 서킷이 이를 검증
 */

async function testSimpleOwnership() {
    console.log('🔐 Simple Address Ownership Proof Test\n');

    // 1. 지갑 생성 (테스트용)
    const wallet = ethers.Wallet.createRandom();
    console.log('📋 Test Wallet:');
    console.log('  Address:', wallet.address);
    console.log('  Private Key:', wallet.privateKey);
    console.log('');

    // 2. 메시지 생성
    const message = `I own this address: ${wallet.address}`;
    console.log('📝 Message:', message);
    console.log('');

    // 3. 메시지 서명
    const signature = await wallet.signMessage(message);
    console.log('✍️  Signature:', signature);
    console.log('');

    // 4. 서명을 r, s로 분리
    const sig = ethers.Signature.from(signature);
    console.log('📊 Signature Components:');
    console.log('  r:', sig.r);
    console.log('  s:', sig.s);
    console.log('  v:', sig.v);
    console.log('');

    // 5. 공개키 추출
    const signingKey = wallet.signingKey;
    const publicKey = signingKey.publicKey;
    console.log('🔑 Public Key:', publicKey);

    // 공개키를 x, y 좌표로 분리
    // Public key format: 0x04 + x (32 bytes) + y (32 bytes)
    const pubKeyX = '0x' + publicKey.slice(4, 68);
    const pubKeyY = '0x' + publicKey.slice(68, 132);
    console.log('  X:', pubKeyX);
    console.log('  Y:', pubKeyY);
    console.log('');

    // 6. Noir 서킷 입력 준비
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔧 Noir Circuit Inputs (Prover.toml format)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Public Input: user_address
    const userAddressBytes = ethers.getBytes(wallet.address);
    console.log('# Public Inputs');
    console.log(`user_address = [${Array.from(userAddressBytes).join(', ')}]`);
    console.log('');

    // Private Inputs: signature, pubkey
    const rBytes = ethers.getBytes(ethers.zeroPadValue(sig.r, 32));
    const sBytes = ethers.getBytes(ethers.zeroPadValue(sig.s, 32));
    const signatureBytes = new Uint8Array([...rBytes, ...sBytes]);

    const pubKeyXBytes = ethers.getBytes(pubKeyX);
    const pubKeyYBytes = ethers.getBytes(pubKeyY);

    console.log('# Private Inputs');
    console.log(`user_signature = [${Array.from(signatureBytes).join(', ')}]`);
    console.log('');
    console.log(`user_pubkey_x = [${Array.from(pubKeyXBytes).join(', ')}]`);
    console.log('');
    console.log(`user_pubkey_y = [${Array.from(pubKeyYBytes).join(', ')}]`);
    console.log('');

    // 7. 검증 (ethers.js로 미리 확인)
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Verification (ethers.js)');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    const recoveredAddress = ethers.verifyMessage(message, signature);
    console.log('  Original Address:', wallet.address);
    console.log('  Recovered Address:', recoveredAddress);
    console.log('  Match:', wallet.address === recoveredAddress ? '✅ YES' : '❌ NO');
    console.log('');

    // 8. Prover.toml 파일 생성
    const proverToml = `# Simple Address Ownership Proof - Test Inputs

# Public Inputs
user_address = [${Array.from(userAddressBytes).join(', ')}]

# Private Inputs
user_signature = [${Array.from(signatureBytes).join(', ')}]

user_pubkey_x = [${Array.from(pubKeyXBytes).join(', ')}]

user_pubkey_y = [${Array.from(pubKeyYBytes).join(', ')}]
`;

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📝 Generated Prover.toml');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log(proverToml);

    // 9. 서킷 컴파일 및 실행 안내
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🚀 Next Steps');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('1. Prover.toml 파일 업데이트:');
    console.log('   Copy the above content to circuit/attestor/Prover.toml');
    console.log('');

    console.log('2. main.nr 수정:');
    console.log('   Change: mod main;');
    console.log('   To:     mod simple_ownership;');
    console.log('');

    console.log('3. 서킷 컴파일:');
    console.log('   cd circuit/attestor');
    console.log('   nargo compile');
    console.log('');

    console.log('4. Proof 생성:');
    console.log('   nargo prove');
    console.log('');

    console.log('5. Proof 검증:');
    console.log('   nargo verify');
    console.log('');

    return {
        wallet,
        message,
        signature,
        publicKey,
        proverToml
    };
}

testSimpleOwnership().catch(console.error);
