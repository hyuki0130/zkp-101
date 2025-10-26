import { ethers } from 'ethers';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const USER_ADDRESS = process.env.USER_ADDRESS;

if (!USER_ADDRESS) {
    console.error('ERROR: USER_ADDRESS not found in .env file');
    console.error('Please copy .env.example to .env and fill in your address');
    process.exit(1);
}

// Base Mainnet RPC
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');

/**
 * Test Raw Transaction Verification
 *
 * This script demonstrates how to extract and prepare data for the ZK circuit
 * that verifies Coinbase KYC attestation transactions.
 */
async function testRawTransactionVerification() {
    console.log('Coinbase Attestation Raw Transaction Verification Test\n');
    console.log('User Address:', USER_ADDRESS);
    console.log('');

    try {
        // Step 1: Get a sample transaction hash
        // In production, this would come from querying attestations
        console.log('Step 1: Get transaction hash');
        console.log('Note: You need to provide a real attestation tx hash');
        console.log('');

        // Example: Replace with actual attestation transaction hash
        const TX_HASH = process.env.ATTESTATION_TX_HASH || '0x0000000000000000000000000000000000000000000000000000000000000000';

        if (TX_HASH === '0x0000000000000000000000000000000000000000000000000000000000000000') {
            console.log('WARNING: Using placeholder TX_HASH');
            console.log('Set ATTESTATION_TX_HASH in .env for real testing');
            console.log('');
        }

        console.log('TX Hash:', TX_HASH);
        console.log('');

        // Step 2: Query transaction from blockchain
        console.log('Step 2: Query transaction from blockchain');
        const tx = await provider.getTransaction(TX_HASH);

        if (!tx) {
            throw new Error('Transaction not found');
        }

        console.log('Transaction found:');
        console.log('  From:', tx.from);
        console.log('  To:', tx.to);
        console.log('  Nonce:', tx.nonce);
        console.log('  Gas Limit:', tx.gasLimit?.toString());
        console.log('  Type:', tx.type);
        console.log('');

        // Step 3: Get raw transaction (RLP encoded)
        console.log('Step 3: Get raw transaction (RLP encoded)');
        const serialized = ethers.Transaction.from(tx).serialized;
        console.log('  Serialized TX length:', serialized.length, 'characters');
        console.log('  Serialized TX (first 100 chars):', serialized.slice(0, 100) + '...');
        console.log('');

        // Step 4: Verify TX hash
        console.log('Step 4: Verify TX hash');
        const computedHash = ethers.keccak256(serialized);
        console.log('  Original TX Hash:', TX_HASH);
        console.log('  Computed TX Hash:', computedHash);
        console.log('  Match:', TX_HASH.toLowerCase() === computedHash.toLowerCase() ? 'YES' : 'NO');
        console.log('');

        // Step 5: Extract signature components
        console.log('Step 5: Extract signature components');
        console.log('  v:', tx.signature?.v);
        console.log('  r:', tx.signature?.r);
        console.log('  s:', tx.signature?.s);
        console.log('');

        // Step 6: Recover public key
        console.log('Step 6: Recover public key from signature');

        // For Ethereum transactions, we need to reconstruct the signing message
        // The transaction hash is what was signed (for legacy and EIP-155)
        const txHashBytes = ethers.getBytes(computedHash);

        // Create signature object
        const signature = ethers.Signature.from({
            r: tx.signature.r,
            s: tx.signature.s,
            v: tx.signature.v
        });

        // Recover public key
        const publicKey = ethers.SigningKey.recoverPublicKey(
            txHashBytes,
            signature
        );

        console.log('  Public Key:', publicKey);

        const pubKeyHex = publicKey.slice(4); // Remove '0x04' prefix
        const pubKeyX = '0x' + pubKeyHex.slice(0, 64);
        const pubKeyY = '0x' + pubKeyHex.slice(64);

        console.log('  Public Key X:', pubKeyX);
        console.log('  Public Key Y:', pubKeyY);
        console.log('');

        // Step 7: Verify address derivation
        console.log('Step 7: Verify address derivation from public key');
        const derivedAddress = ethers.computeAddress(publicKey);
        console.log('  Original From:', tx.from);
        console.log('  Derived Address:', derivedAddress);
        console.log('  Match:', tx.from.toLowerCase() === derivedAddress.toLowerCase() ? 'YES' : 'NO');
        console.log('');

        // Step 8: Prepare circuit inputs
        console.log('Step 8: Prepare Noir circuit inputs');
        console.log('');

        // Convert raw transaction to byte array
        const rawTxBytes = ethers.getBytes(serialized);

        // Pad to 300 bytes (circuit expects fixed size)
        const paddedTx = new Uint8Array(300);
        for (let i = 0; i < Math.min(rawTxBytes.length, 300); i++) {
            paddedTx[i] = rawTxBytes[i];
        }

        // Convert to format for Prover.toml
        function hexToBytes(hex) {
            const cleanHex = hex.startsWith('0x') ? hex.slice(2) : hex;
            const bytes = [];
            for (let i = 0; i < cleanHex.length; i += 2) {
                bytes.push(parseInt(cleanHex.substr(i, 2), 16));
            }
            return bytes;
        }

        const userAddressBytes = hexToBytes(USER_ADDRESS);  // Actual user address, not tx.from
        const txHashBytes2 = hexToBytes(computedHash);
        const attesterPubKeyXBytes = hexToBytes(pubKeyX);
        const attesterPubKeyYBytes = hexToBytes(pubKeyY);

        console.log('Prover.toml format:');
        console.log('');
        console.log('# Public Inputs');
        console.log(`user_address = [${userAddressBytes.join(', ')}]`);
        console.log('');
        console.log(`tx_hash = [${txHashBytes2.join(', ')}]`);
        console.log('');
        console.log('# Private Inputs');
        console.log(`raw_transaction = [${Array.from(paddedTx).join(', ')}]`);
        console.log('');
        console.log(`attester_pubkey_x = [${attesterPubKeyXBytes.join(', ')}]`);
        console.log('');
        console.log(`attester_pubkey_y = [${attesterPubKeyYBytes.join(', ')}]`);
        console.log('');

        // Generate Prover.toml content
        const proverToml = `# Coinbase Attestation Transaction Verification - Circuit Inputs

# Public Inputs (visible in proof)
user_address = [${userAddressBytes.join(', ')}]

tx_hash = [${txHashBytes2.join(', ')}]

# Private Inputs (hidden in proof)
raw_transaction = [${Array.from(paddedTx).join(', ')}]

attester_pubkey_x = [${attesterPubKeyXBytes.join(', ')}]

attester_pubkey_y = [${attesterPubKeyYBytes.join(', ')}]
`;

        console.log('');
        console.log('========================================');
        console.log('Next Steps:');
        console.log('========================================');
        console.log('');
        console.log('1. Copy the above Prover.toml content');
        console.log('2. Save to: circuit/attestor/Prover.toml');
        console.log('3. Compile: cd circuit/attestor && nargo compile');
        console.log('4. Execute: nargo execute');
        console.log('');
        console.log('Note: Current circuit uses simplified RLP extraction');
        console.log('      Production version needs proper RLP decoding library');
        console.log('');

        return {
            tx,
            serialized,
            publicKey,
            proverToml
        };

    } catch (error) {
        console.error('ERROR:', error.message);
        throw error;
    }
}

testRawTransactionVerification().catch(console.error);
