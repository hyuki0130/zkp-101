import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import { UltraHonkBackend } from '@aztec/bb.js';
import { Noir } from '@noir-lang/noir_js';
import circuit from '../target/advanced.json';

// Configuration
const BASE_RPC_URL = 'https://mainnet.base.org';
const COINBASE_ATTESTER_CONTRACT = '0x357458739F90461b99789350868CD7CF330Dd7EE';
const ATTEST_ACCOUNT_SELECTOR = '0x56feed5e';
const EAS_GRAPHQL_URL = 'https://base.easscan.org/graphql';
const VERIFIED_ACCOUNT_SCHEMA = '0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9';
const VERIFIER_CONTRACT_ADDRESS = '0x353d7bd1ac24c36388500eF0FE253Ce4cBfa82fE';
const VERIFIER_ABI = [
    {
        "inputs": [
            {"internalType": "bytes", "name": "proof", "type": "bytes"},
            {"internalType": "bytes32[]", "name": "publicInputs", "type": "bytes32[]"}
        ],
        "name": "verify",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    }
];

// Known Coinbase Attestor signers
const AUTHORIZED_SIGNERS = [
    '0x952f32128AF084422539C4Ff96df5C525322E564',
    '0x8844591D47F17bcA6F5dF8f6B64F4a739F1C0080',
    '0x88fe64ea2e121f49bb77abea6c0a45e93638c3c5',
    '0x44ace9abb148e8412ac4492e9a1ae6bd88226803'
];

// Global state
let provider;
let signer;
let userAddress;
let attestationTx;
let proofInputs;
let proof;
let publicInputs;
let backend;
let noir;

// Utility: Show status message
function showStatus(elementId, message, type = 'loading') {
    const element = document.getElementById(elementId);
    element.className = `status active ${type}`;
    element.innerHTML = type === 'loading'
        ? `<div class="spinner"></div>${message}`
        : message;
}

// Utility: Hide status
function hideStatus(elementId) {
    const element = document.getElementById(elementId);
    element.className = 'status';
}

// Utility: Show result box
function showResult(elementId) {
    const element = document.getElementById(elementId);
    element.className = 'result-box active';
}

// Utility: Convert hex to byte array
function hexToBytes(hex) {
    const bytes = ethers.getBytes(hex);
    return Array.from(bytes);
}

// Utility: Extract pubkey coordinates
function extractPubkeyCoordinates(pubkey) {
    const pubkeyHex = pubkey.startsWith('0x04') ? pubkey.slice(4) : pubkey.slice(2);
    const x = '0x' + pubkeyHex.slice(0, 64);
    const y = '0x' + pubkeyHex.slice(64, 128);
    return { x, y };
}

// Utility: Create unsigned transaction hash
function createUnsignedTxHash(tx) {
    const unsignedTx = {
        type: 2,
        chainId: tx.chainId,
        nonce: tx.nonce,
        maxPriorityFeePerGas: tx.maxPriorityFeePerGas,
        maxFeePerGas: tx.maxFeePerGas,
        gasLimit: tx.gasLimit,
        to: tx.to,
        value: tx.value,
        data: tx.data,
        accessList: tx.accessList || []
    };

    const serialized = ethers.Transaction.from(unsignedTx).unsignedSerialized;
    return ethers.keccak256(serialized);
}

// Utility: Pad array to target length
function padArray(arr, targetLength) {
    const result = [...arr];
    while (result.length < targetLength) {
        result.push(0);
    }
    return result;
}

// Utility: Format byte array for Prover.toml
function formatByteArray(arr, name, bytesPerLine = 8) {
    const lines = [];
    for (let i = 0; i < arr.length; i += bytesPerLine) {
        const chunk = arr.slice(i, i + bytesPerLine);
        const formatted = chunk.map(b => `0x${b.toString(16).padStart(2, '0')}`).join(', ');
        lines.push(formatted + (i + bytesPerLine < arr.length ? ',' : ''));
    }
    return `${name} = [\n    ${lines.join('\n    ')}\n]`;
}

// Utility: Format 2D byte array for Prover.toml
function format2DByteArray(arr, name) {
    const lines = arr.map(inner => {
        const formatted = inner.map(b => `0x${b.toString(16).padStart(2, '0')}`).join(', ');
        return `    [${formatted}]`;
    });
    return `${name} = [\n${lines.join(',\n')}\n]`;
}

// Utility: Print Prover.toml format
function printProverToml(inputs) {
    console.log('\n' + '='.repeat(80));
    console.log('PROVER.TOML FORMAT - Copy and paste into Prover.toml');
    console.log('='.repeat(80) + '\n');

    console.log('# ============ Public Inputs ============\n');
    console.log(formatByteArray(inputs.signal_hash, 'signal_hash'));
    console.log('\n' + formatByteArray(inputs.signer_list_merkle_root, 'signer_list_merkle_root'));

    console.log('\n\n# ============ Private Inputs ============\n');
    console.log('# --- Part 1: User Ownership ---\n');
    console.log(formatByteArray(inputs.user_address, 'user_address'));
    console.log('\n' + formatByteArray(inputs.user_signature, 'user_signature'));
    console.log('\n' + formatByteArray(inputs.user_pubkey_x, 'user_pubkey_x'));
    console.log('\n' + formatByteArray(inputs.user_pubkey_y, 'user_pubkey_y'));

    console.log('\n\n# --- Part 2: Coinbase Attestation TX ---\n');
    console.log(`tx_length = ${inputs.tx_length}\n`);
    console.log(formatByteArray(inputs.raw_transaction, 'raw_transaction'));
    console.log('\n' + formatByteArray(inputs.coinbase_attester_pubkey_x, 'coinbase_attester_pubkey_x'));
    console.log('\n' + formatByteArray(inputs.coinbase_attester_pubkey_y, 'coinbase_attester_pubkey_y'));

    console.log('\n\n# --- Part 3: Merkle Proof ---\n');
    console.log(format2DByteArray(inputs.coinbase_signer_merkle_proof, 'coinbase_signer_merkle_proof'));
    console.log(`\ncoinbase_signer_leaf_index = ${inputs.coinbase_signer_leaf_index}`);
    console.log(`merkle_proof_depth = ${inputs.merkle_proof_depth}`);

    console.log('\n' + '='.repeat(80));
    console.log('END OF PROVER.TOML');
    console.log('='.repeat(80) + '\n');
}

// Step 1: Connect Wallet & Auto-fetch Attestation
document.getElementById('connectWallet').addEventListener('click', async () => {
    try {
        showStatus('walletStatus', 'Connecting to MetaMask...');

        if (!window.ethereum) {
            throw new Error('MetaMask not detected. Please install MetaMask.');
        }

        const accounts = await window.ethereum.request({
            method: 'eth_requestAccounts'
        });

        provider = new ethers.BrowserProvider(window.ethereum);
        signer = await provider.getSigner();
        userAddress = accounts[0];

        document.getElementById('connectedAddress').textContent = userAddress;

        showStatus('walletStatus', 'Wallet connected! Fetching attestation...', 'loading');
        showResult('walletResult');

        // Auto-fetch attestation transaction
        await fetchAttestationTransaction();

    } catch (error) {
        showStatus('walletStatus', `Error: ${error.message}`, 'error');
    }
});

// Fetch Attestation Transaction from EAS GraphQL
async function fetchAttestationTransaction() {
    try {
        showStatus('txStatus', 'Querying EAS for attestation...', 'loading');

        // Step 1: Query EAS GraphQL to get attestation
        const graphqlQuery = `
            query GetAttestations($recipient: String!) {
                attestations(
                    where: {
                        recipient: { equals: $recipient }
                        schemaId: { equals: "${VERIFIED_ACCOUNT_SCHEMA}" }
                    }
                    orderBy: [{ time: desc }]
                    take: 1
                ) {
                    id
                    txid
                    attester
                    recipient
                    schemaId
                    time
                }
            }
        `;

        const graphqlResponse = await fetch(EAS_GRAPHQL_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                query: graphqlQuery,
                variables: { recipient: userAddress.toLowerCase() }
            }),
        });

        const graphqlData = await graphqlResponse.json();
        const attestations = graphqlData?.data?.attestations || [];

        if (attestations.length === 0) {
            showStatus('txStatus',
                'No Coinbase KYC attestation found for this address. Please complete Coinbase KYC verification first.',
                'error'
            );
            showStatus('walletStatus',
                'Wallet connected, but no attestation found.',
                'error'
            );
            return;
        }

        const attestation = attestations[0];
        const txHash = attestation.txid;

        showStatus('txStatus', 'Attestation found! Fetching transaction...', 'loading');

        // Step 2: Fetch raw transaction from Base blockchain
        const baseProvider = new ethers.JsonRpcProvider(BASE_RPC_URL);
        attestationTx = await baseProvider.getTransaction(txHash);

        if (!attestationTx) {
            throw new Error('Transaction not found on blockchain');
        }

        // Verify it's an attestation transaction
        if (attestationTx.to.toLowerCase() !== COINBASE_ATTESTER_CONTRACT.toLowerCase()) {
            throw new Error(`Invalid transaction. Not sent to Coinbase Attester contract.`);
        }

        // Extract attested address from calldata
        const calldata = attestationTx.data;
        if (!calldata.startsWith(ATTEST_ACCOUNT_SELECTOR)) {
            throw new Error('Transaction does not call attestAccount function');
        }

        // Extract address from calldata (skip selector + padding, get last 20 bytes)
        const attestedAddr = '0x' + calldata.slice(-40);

        // Verify attested address matches connected wallet
        if (attestedAddr.toLowerCase() !== userAddress.toLowerCase()) {
            throw new Error(`Attestation is for ${attestedAddr}, but connected wallet is ${userAddress}`);
        }

        // Display results
        document.getElementById('txFrom').textContent = attestationTx.from;
        document.getElementById('txTo').textContent = attestationTx.to;

        const serialized = ethers.Transaction.from(attestationTx).serialized;
        const txLength = ethers.getBytes(serialized).length;
        document.getElementById('txLength').textContent = `${txLength} bytes`;
        document.getElementById('attestedAddress').textContent = attestedAddr;

        const attestationTime = new Date(attestation.time * 1000).toLocaleString();

        showStatus('walletStatus', 'Wallet connected and attestation found!', 'success');
        showStatus('txStatus', `Attestation fetched successfully! (Created: ${attestationTime})`, 'success');
        showResult('txResult');

        // Enable next step
        document.getElementById('generateInputs').disabled = false;

    } catch (error) {
        showStatus('txStatus', `Error: ${error.message}`, 'error');
        showStatus('walletStatus', 'Wallet connected, but attestation fetch failed.', 'error');
        console.error('Attestation fetch error:', error);
    }
}

// Step 2: Generate Proof Inputs
document.getElementById('generateInputs').addEventListener('click', async () => {
    const startTime = performance.now();
    try {
        console.log('=== Generate Inputs Started ===');
        showStatus('inputsStatus', 'Step 1/5: Generating random signal_hash...');

        // 1. Generate signal_hash
        const signal_hash = ethers.randomBytes(32);
        const signal_hash_hex = ethers.hexlify(signal_hash);
        console.log('Step 1/5: signal_hash generated:', signal_hash_hex);

        showStatus('inputsStatus', 'Step 2/5: Requesting user signature... (Check MetaMask)');
        console.log('Step 2/5: Requesting MetaMask signature...');
        console.log('⚠️ Please check MetaMask popup to sign the message');

        // 2. User signs signal_hash with timeout
        const signPromise = signer.signMessage(signal_hash);
        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error('MetaMask signature timeout (60s). Please check MetaMask popup.')), 60000)
        );

        const userSig = await Promise.race([signPromise, timeoutPromise]);
        console.log('Step 2/5: User signature received');
        const userSignature = ethers.Signature.from(userSig);

        showStatus('inputsStatus', 'Step 3/5: Recovering user public key...');
        console.log('Step 3/5: Recovering user public key...');

        // 3. Recover user's public key
        const messageHash = ethers.hashMessage(signal_hash);
        const userPubkey = ethers.SigningKey.recoverPublicKey(messageHash, userSig);
        const userPubkeyCoords = extractPubkeyCoordinates(userPubkey);
        console.log('Step 3/5: User pubkey recovered');

        showStatus('inputsStatus', 'Step 4/5: Recovering Coinbase signer public key...');
        console.log('Step 4/5: Recovering Coinbase signer public key...');

        // 4. Recover Coinbase signer's public key
        const unsigned_tx_hash = createUnsignedTxHash(attestationTx);
        const coinbaseSig = ethers.Signature.from({
            r: attestationTx.signature.r,
            s: attestationTx.signature.s,
            v: attestationTx.signature.v
        });

        const coinbasePubkey = ethers.SigningKey.recoverPublicKey(unsigned_tx_hash, coinbaseSig);
        const coinbasePubkeyCoords = extractPubkeyCoordinates(coinbasePubkey);
        const coinbaseSignerAddress = ethers.computeAddress(coinbasePubkey);
        console.log('Step 4/5: Coinbase signer recovered:', coinbaseSignerAddress);

        showStatus('inputsStatus', 'Step 5/5: Building Merkle tree...');
        console.log('Step 5/5: Building Merkle tree...');

        // 5. Build Merkle tree
        // IMPORTANT: Hash only the 20-byte address (not the hex string)
        // to match Noir's keccak256(address, 20) behavior
        const leaves = AUTHORIZED_SIGNERS.map(addr => {
            const addrBytes = ethers.getBytes(ethers.getAddress(addr));
            return ethers.keccak256(addrBytes);
        });
        console.log('Step 5/5: Leaves created, building tree...');

        const tree = new MerkleTree(leaves, ethers.keccak256, {
            sortPairs: false  // Match Noir's index-based left/right ordering
        });
        console.log('Step 5/5: Merkle tree built');

        const merkleRoot = tree.getRoot();
        const signerAddrBytes = ethers.getBytes(coinbaseSignerAddress);
        const signerLeaf = ethers.keccak256(signerAddrBytes);
        const proof = tree.getProof(signerLeaf);
        const leafIndex = AUTHORIZED_SIGNERS.findIndex(
            addr => addr.toLowerCase() === coinbaseSignerAddress.toLowerCase()
        );
        console.log('Step 5/5: Merkle proof generated, leaf index:', leafIndex);

        // Prepare proof array (pad to depth 8)
        const proofArray = [];
        for (let i = 0; i < 8; i++) {
            if (i < proof.length) {
                const proofHex = '0x' + proof[i].data.toString('hex');
                proofArray.push(hexToBytes(proofHex));
            } else {
                proofArray.push(new Array(32).fill(0));
            }
        }

        // Prepare transaction bytes
        console.log('Preparing transaction bytes...');
        const serialized = ethers.Transaction.from(attestationTx).serialized;
        const tx_bytes = hexToBytes(serialized);
        const tx_length = tx_bytes.length;
        console.log('TX bytes prepared, length:', tx_length);
        console.log('Serialized TX (with signature):', serialized);
        console.log('TX signature from attestationTx:', {
            r: attestationTx.signature.r,
            s: attestationTx.signature.s,
            v: attestationTx.signature.v
        });

        // Prepare all inputs for the circuit
        console.log('Creating proof inputs object...');
        proofInputs = {
            signal_hash: hexToBytes(signal_hash_hex),
            signer_list_merkle_root: Array.from(merkleRoot),
            user_address: hexToBytes(userAddress),
            user_signature: hexToBytes(userSignature.r + userSignature.s.slice(2)),
            user_pubkey_x: hexToBytes(userPubkeyCoords.x),
            user_pubkey_y: hexToBytes(userPubkeyCoords.y),
            raw_transaction: padArray(tx_bytes, 300),
            tx_length: tx_length,
            coinbase_attester_pubkey_x: hexToBytes(coinbasePubkeyCoords.x),
            coinbase_attester_pubkey_y: hexToBytes(coinbasePubkeyCoords.y),
            coinbase_signer_merkle_proof: proofArray,
            coinbase_signer_leaf_index: leafIndex === -1 ? 0 : leafIndex,
            merkle_proof_depth: proof.length
        };

        // Display results
        console.log('Displaying results...');
        document.getElementById('signalHash').textContent = signal_hash_hex;
        document.getElementById('merkleRoot').textContent = '0x' + merkleRoot.toString('hex');
        document.getElementById('recoveredSigner').textContent = coinbaseSignerAddress;
        document.getElementById('signerInList').textContent = leafIndex !== -1
            ? `YES (index ${leafIndex})`
            : 'NO - Warning: Signer not in authorized list!';

        if (leafIndex === -1) {
            showStatus('inputsStatus',
                'Warning: Signer not in authorized list. Proof will fail.',
                'error'
            );
        } else {
            showStatus('inputsStatus', 'All inputs generated successfully!', 'success');
        }

        showResult('inputsResult');

        // Enable next step
        document.getElementById('generateProof').disabled = false;

        const endTime = performance.now();
        const elapsedTime = ((endTime - startTime) / 1000).toFixed(2);
        console.log(`=== Generate Inputs Complete (${elapsedTime}s) ===`);

        // Output Prover.toml format for testing
        printProverToml(proofInputs);

    } catch (error) {
        const endTime = performance.now();
        const elapsedTime = ((endTime - startTime) / 1000).toFixed(2);
        showStatus('inputsStatus', `Error after ${elapsedTime}s: ${error.message}`, 'error');
        console.error(`Error after ${elapsedTime}s:`, error);
    }
});

// Step 3: Generate ZK Proof
document.getElementById('generateProof').addEventListener('click', async () => {
    try {
        showStatus('proofStatus', 'Initializing Noir backend...');

        // Initialize backend and noir with keccak oracle
        if (!backend) {
            backend = new UltraHonkBackend(circuit.bytecode, { keccak: true });
            noir = new Noir(circuit);
        }

        showStatus('proofStatus', 'Generating proof with Keccak ZK... This may take 10-30 seconds...');

        const startTime = performance.now();

        // Generate proof using execute + backend.generateProof with keccak: true
        const { witness } = await noir.execute(proofInputs);
        proof = await backend.generateProof(witness, { keccak: true });

        const endTime = performance.now();
        const proofTime = ((endTime - startTime) / 1000).toFixed(2);

        // Store public inputs for on-chain verification from proof object
        // bb.js automatically includes public inputs in the proof object as field elements
        publicInputs = proof.publicInputs.map(input => {
            // Convert field element to hex string (bytes32 format)
            const inputStr = input.toString(16).padStart(64, '0');
            const cleanHex = inputStr.startsWith('0x') ? inputStr.slice(2) : inputStr;
            return '0x' + cleanHex;
        });

        console.log('Public inputs stored for on-chain verification:');
        console.log('  Count:', publicInputs.length);
        console.log('  Values:', publicInputs);

        // Display results
        const proofHex = '0x' + Buffer.from(proof.proof).toString('hex');
        document.getElementById('proofHex').textContent = proofHex;
        document.getElementById('proofSize').textContent = `${proof.proof.length} bytes`;
        document.getElementById('proofTime').textContent = `${proofTime} seconds`;

        showStatus('proofStatus', 'Proof generated successfully!', 'success');
        showResult('proofResult');

        // Enable next steps
        document.getElementById('verifyProof').disabled = false;
        document.getElementById('verifyOnChain').disabled = false;

    } catch (error) {
        showStatus('proofStatus', `Error: ${error.message}`, 'error');
        console.error(error);
    }
});

// Step 4: Verify Proof
document.getElementById('verifyProof').addEventListener('click', async () => {
    try {
        showStatus('verifyStatus', 'Verifying proof...');

        const startTime = performance.now();

        // Verify proof using backend.verifyProof with keccak oracle
        const isValid = await backend.verifyProof(proof, { keccak: true });

        const endTime = performance.now();
        const verifyTime = ((endTime - startTime) / 1000).toFixed(2);

        // Display results
        document.getElementById('verificationStatus').textContent = isValid
            ? 'VALID - Proof verified successfully!'
            : 'INVALID - Proof verification failed!';
        document.getElementById('verifyTime').textContent = `${verifyTime} seconds`;

        showStatus('verifyStatus',
            isValid ? 'Proof is valid!' : 'Proof is invalid!',
            isValid ? 'success' : 'error'
        );
        showResult('verifyResult');

    } catch (error) {
        showStatus('verifyStatus', `Error: ${error.message}`, 'error');
        console.error(error);
    }
});

// Step 5: Verify Proof On-Chain
document.getElementById('verifyOnChain').addEventListener('click', async () => {
    try {
        showStatus('onChainStatus', 'Connecting to verifier contract...');

        // Check if wallet is connected
        if (!signer) {
            throw new Error('Wallet not connected. Please connect your wallet first.');
        }

        // Get verifier contract
        const verifierContract = new ethers.Contract(
            VERIFIER_CONTRACT_ADDRESS,
            VERIFIER_ABI,
            signer
        );

        showStatus('onChainStatus', 'Submitting proof to contract... (please confirm transaction)');

        const startTime = performance.now();

        // Prepare proof data
        const proofBytes = '0x' + Buffer.from(proof.proof).toString('hex');

        console.log('=== On-Chain Verification ===');
        console.log('Verifier Contract:', VERIFIER_CONTRACT_ADDRESS);
        console.log('Proof:', proofBytes.substring(0, 66) + '...');
        console.log('Public Inputs:', publicInputs);

        // Call verify function (this is a view function, no gas needed)
        const tx = await verifierContract.verify(proofBytes, publicInputs);

        const endTime = performance.now();
        const verifyTime = ((endTime - startTime) / 1000).toFixed(2);

        console.log('Verification result:', tx);

        // Display results
        const isValid = tx === true;
        document.getElementById('onChainVerificationStatus').textContent = isValid
            ? 'VALID - Proof verified on-chain successfully!'
            : 'INVALID - On-chain verification failed!';

        document.getElementById('onChainTxHash').textContent = 'Static call (no transaction hash)';
        document.getElementById('onChainGasUsed').textContent = 'View function (no gas cost)';
        document.getElementById('onChainVerifyTime').textContent = `${verifyTime} seconds`;

        showStatus('onChainStatus',
            isValid ? 'On-chain verification successful!' : 'On-chain verification failed!',
            isValid ? 'success' : 'error'
        );
        showResult('onChainResult');

    } catch (error) {
        // Handle specific contract errors
        let errorMessage = error.message;

        if (error.message.includes('ProofLengthWrong')) {
            errorMessage = 'Invalid proof length. The proof format may be incorrect.';
        } else if (error.message.includes('PublicInputsLengthWrong')) {
            errorMessage = 'Invalid public inputs length. Expected 2 bytes32 values.';
        } else if (error.message.includes('SumcheckFailed')) {
            errorMessage = 'Proof verification failed: Sumcheck verification failed.';
        } else if (error.message.includes('ShpleminiFailed')) {
            errorMessage = 'Proof verification failed: Shplemini verification failed.';
        }

        showStatus('onChainStatus', `Error: ${errorMessage}`, 'error');
        console.error('On-chain verification error:', error);
    }
});

// Initialize
console.log('Advanced Coinbase KYC Attestation - Privacy Enhanced');
console.log('Circuit loaded:', circuit.abi ? 'Yes' : 'No');
console.log('Verifier contract:', VERIFIER_CONTRACT_ADDRESS);
