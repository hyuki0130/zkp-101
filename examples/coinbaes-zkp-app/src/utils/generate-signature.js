import { ethers } from 'ethers';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Get from environment variables
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const USER_ADDRESS = process.env.USER_ADDRESS;

// Validate environment variables
if (!PRIVATE_KEY || PRIVATE_KEY === '0xYOUR_PRIVATE_KEY_HERE') {
    console.error('❌ ERROR: PRIVATE_KEY not found in .env file');
    console.error('   Please copy .env.example to .env and fill in your private key');
    console.error('   Get it from MetaMask: Account Details → Show Private Key');
    process.exit(1);
}

if (!USER_ADDRESS) {
    console.error('❌ ERROR: USER_ADDRESS not found in .env file');
    console.error('   Please copy .env.example to .env and fill in your address');
    process.exit(1);
}

async function generateSignatureData() {
    console.log('🔐 Generating signature data for Noir circuit...\n');

    // 1. Create wallet from private key
    const wallet = new ethers.Wallet(PRIVATE_KEY);

    console.log('✅ Wallet address:', wallet.address);
    console.log('📝 Expected address:', USER_ADDRESS);

    if (wallet.address.toLowerCase() !== USER_ADDRESS.toLowerCase()) {
        console.error('❌ ERROR: Wallet address does not match!');
        console.error('   Your wallet:', wallet.address);
        console.error('   Expected:', USER_ADDRESS);
        process.exit(1);
    }
    console.log('✅ Address matches!\n');

    // 2. Construct calldata
    // Function: attest(address) - selector: 0x56feed5e
    // Format: selector (4 bytes) + padding (12 bytes) + address (20 bytes) = 36 bytes
    const selector = '0x56feed5e';
    const addressWithoutPrefix = USER_ADDRESS.slice(2); // Remove '0x'
    const paddedAddress = addressWithoutPrefix.padStart(64, '0'); // Pad to 32 bytes (64 hex chars)
    const calldata = selector + paddedAddress;

    console.log('📞 Calldata:', calldata);
    console.log('   Length:', ethers.getBytes(calldata).length, 'bytes\n');

    // 3. Compute digest (keccak256 of calldata)
    const calldataBytes = ethers.getBytes(calldata);
    const digest = ethers.keccak256(calldataBytes);

    console.log('🔐 Digest (keccak256 of calldata):', digest, '\n');

    // 4. Sign the digest (WITH Ethereum Personal Sign prefix - PRODUCTION)
    // This adds "\x19Ethereum Signed Message:\n32" + digest
    const signature = await wallet.signMessage(ethers.getBytes(digest));
    const sig = ethers.Signature.from(signature);

    console.log('✍️  Signature (Ethereum Personal Sign):');
    console.log('   Full:', signature);
    console.log('   r:', sig.r);
    console.log('   s:', sig.s);
    console.log('   v:', sig.v, '\n');

    // 5. Get public key
    const publicKey = wallet.signingKey.publicKey;
    // Remove '0x04' prefix (uncompressed public key marker)
    const pubKeyHex = publicKey.slice(4);
    const pubKeyX = '0x' + pubKeyHex.slice(0, 64);
    const pubKeyY = '0x' + pubKeyHex.slice(64);

    console.log('🔑 Public Key (uncompressed):');
    console.log('   Full:', publicKey);
    console.log('   X:', pubKeyX);
    console.log('   Y:', pubKeyY, '\n');

    // 6. Verify signature locally (Ethereum Personal Sign)
    const recoveredAddress = ethers.verifyMessage(ethers.getBytes(digest), signature);
    console.log('✅ Signature verification:');
    console.log('   Recovered address:', recoveredAddress);
    console.log('   Original address:', wallet.address);
    console.log('   Match:', recoveredAddress === wallet.address, '\n');

    // 7. Convert to Prover.toml format
    console.log('=' .repeat(80));
    console.log('📋 Data for Prover.toml:');
    console.log('=' .repeat(80), '\n');

    // Convert calldata to byte array
    const calldataArray = Array.from(calldataBytes).map(b => `"0x${b.toString(16).padStart(2, '0')}"`);
    console.log('calldata = [');
    console.log('   ', calldataArray.join(', '));
    console.log(']\n');

    // Convert signature to byte array (r + s, 64 bytes total)
    const sigBytes = ethers.getBytes(sig.r + sig.s.slice(2)); // Remove '0x' from s
    const sigArray = Array.from(sigBytes).map(b => `"0x${b.toString(16).padStart(2, '0')}"`);
    console.log('user_sig = [');
    for (let i = 0; i < sigArray.length; i += 8) {
        console.log('   ', sigArray.slice(i, i + 8).join(', ') + (i + 8 < sigArray.length ? ',' : ''));
    }
    console.log(']\n');

    // Convert public key X to byte array
    const pubKeyXBytes = ethers.getBytes(pubKeyX);
    const pubKeyXArray = Array.from(pubKeyXBytes).map(b => `"0x${b.toString(16).padStart(2, '0')}"`);
    console.log('user_pubkey_x = [');
    console.log('   ', pubKeyXArray.join(', '));
    console.log(']\n');

    // Convert public key Y to byte array
    const pubKeyYBytes = ethers.getBytes(pubKeyY);
    const pubKeyYArray = Array.from(pubKeyYBytes).map(b => `"0x${b.toString(16).padStart(2, '0')}"`);
    console.log('user_pubkey_y = [');
    console.log('   ', pubKeyYArray.join(', '));
    console.log(']\n');

    // Convert tx_hash (digest) to byte array
    const txHashBytes = ethers.getBytes(digest);
    const txHashArray = Array.from(txHashBytes).map(b => `"0x${b.toString(16).padStart(2, '0')}"`);
    console.log('tx_hash = [');
    console.log('   ', txHashArray.join(', '));
    console.log(']\n');

    console.log('=' .repeat(80));
    console.log('✅ Copy the above data to your Prover.toml file!');
    console.log('=' .repeat(80));
}

generateSignatureData().catch(console.error);
