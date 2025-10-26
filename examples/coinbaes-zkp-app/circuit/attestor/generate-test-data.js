// Generate test data for Prover.toml
// This script generates calldata and signature for testing the circuit

import { ethers } from 'ethers';

const ATTEST_FUNCTION_SELECTOR = '0x56feed5e';

// Real user address from KYC attestation
const USER_ADDRESS = '0xD6C714247037E5201B7e3dEC97a3ab59a9d2F739';

// Test private key (Hardhat test account #1)
// IMPORTANT: This is a TEST private key. In production, user signs with their own key
// For testing, we'll use this to generate a valid signature
const TEST_PRIVATE_KEY = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

function hexToBytes(hex) {
    hex = hex.startsWith('0x') ? hex.slice(2) : hex;
    const bytes = [];
    for (let i = 0; i < hex.length; i += 2) {
        bytes.push(parseInt(hex.slice(i, i + 2), 16));
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

    // Copy address at offset 16 (4 bytes selector + 12 bytes padding)
    for (let i = 0; i < 20; i++) {
        calldata[16 + i] = addr[i];
    }

    return calldata;
}

async function generateTestData() {
    console.log('🔧 Generating test data for Prover.toml...\n');

    // Create wallet from test private key
    const wallet = new ethers.Wallet(TEST_PRIVATE_KEY);
    const walletAddress = await wallet.getAddress();

    console.log('Test Wallet Address:', walletAddress);
    console.log('Target User Address:', USER_ADDRESS);

    if (walletAddress.toLowerCase() !== USER_ADDRESS.toLowerCase()) {
        console.warn('⚠️  WARNING: Wallet address does not match USER_ADDRESS!');
        console.warn('⚠️  You need to use the correct private key for the test user.');
    }

    // Generate calldata
    const calldata = generateCalldata(USER_ADDRESS);
    const calldataHex = '0x' + calldata.map(b => b.toString(16).padStart(2, '0')).join('');

    console.log('\n📝 Calldata:', calldataHex);
    console.log('📝 Calldata array:', JSON.stringify(calldata));

    // Compute digest
    const digest = ethers.keccak256(calldataHex);
    console.log('\n🔢 Digest:', digest);

    // Sign with Ethereum Personal Sign
    const signature = await wallet.signMessage(ethers.getBytes(digest));
    console.log('\n✅ Signature:', signature);

    // Extract r, s from signature
    const sigBytes = ethers.getBytes(signature);
    const r = Array.from(sigBytes.slice(0, 32));
    const s = Array.from(sigBytes.slice(32, 64));
    const userSig = Array.from(sigBytes.slice(0, 64)); // r + s (no v)

    console.log('\n🔑 Signature r:', JSON.stringify(r));
    console.log('🔑 Signature s:', JSON.stringify(s));
    console.log('🔑 User signature (r+s):', JSON.stringify(userSig));

    // Recover public key
    const msgHash = ethers.hashMessage(ethers.getBytes(digest));
    console.log('\n📨 Message hash:', msgHash);

    const pubKey = ethers.SigningKey.recoverPublicKey(msgHash, signature);
    console.log('\n🔑 Recovered Public Key:', pubKey);

    const pubKeyHex = pubKey.slice(4); // Remove '0x04' prefix
    const pubKeyX = hexToBytes('0x' + pubKeyHex.slice(0, 64));
    const pubKeyY = hexToBytes('0x' + pubKeyHex.slice(64));

    console.log('🔑 Public Key X:', JSON.stringify(pubKeyX));
    console.log('🔑 Public Key Y:', JSON.stringify(pubKeyY));

    // Generate Prover.toml additions
    console.log('\n========================================');
    console.log('Add these lines to Prover.toml:');
    console.log('========================================\n');

    console.log('calldata = ' + JSON.stringify(calldata));
    console.log('\nuser_signature = ' + JSON.stringify(userSig));
}

generateTestData().catch(console.error);
