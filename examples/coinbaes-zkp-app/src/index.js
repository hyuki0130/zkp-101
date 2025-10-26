import './style.css';
import { Noir } from '@noir-lang/noir_js';
import { UltraHonkBackend } from '@aztec/bb.js';
import { ethers } from 'ethers';
import circuit from '../circuit/attestor/target/attestor.json';

// Constants
const EAS_CONTRACT = '0x4200000000000000000000000000000000000021';
const COINBASE_ATTESTER = '0x357458739F90461b99789350868CD7CF330Dd7EE';
const VERIFIED_ACCOUNT_SCHEMA = '0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9';
const VERIFIER_CONTRACT = '0x256C1679e1D90D069A32e5b200a0C8846821a77a';
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

// DOM Elements
let connectBtn;
let walletInfo;
let connectedAddress;
let generateBtn;
let verifyBtn;
let verifyOnchainBtn;
let loading;
let loadingText;
let resultDiv;
let txHashDisplay;
let txLengthDisplay;
let attestationInfoDiv;

// Noir & Backend
let noir;
let backend;
let currentProof = null;

// Wallet
let userAddress = null;
let provider = null;
let signer = null;

// Transaction data
let rawTransactionData = null;
let txSignatureData = null;
let txHashData = null;
let txLengthData = null;

// Initialize Noir with UltraHonk backend (Keccak ZK)
async function initNoir() {
    try {
        console.log('🔧 Initializing Noir + UltraHonk backend (Keccak ZK)...');

        // Backend 초기화 (Keccak ZK - bb.js 0.87.0)
        backend = new UltraHonkBackend(circuit.bytecode, { keccak: true });

        // Noir 초기화
        noir = new Noir(circuit, backend);

        console.log('✅ Noir initialized successfully with Keccak ZK!');
        console.log('📊 Circuit info:');
        console.log('  - Noir version:', circuit.noir_version);
        console.log('  - Circuit hash:', circuit.hash);

        return true;
    } catch (error) {
        console.error('❌ Noir initialization failed:', error);
        showResult('❌ Noir 초기화 실패:\n\n' + error.message, false);
        return false;
    }
}

// Convert hex string to byte array
function hexToBytes(hex) {
    const cleanHex = hex.startsWith('0x') ? hex.slice(2) : hex;
    const bytes = [];
    for (let i = 0; i < cleanHex.length; i += 2) {
        bytes.push(parseInt(cleanHex.substr(i, 2), 16));
    }
    return bytes;
}

// Pad byte array to specific length
function padBytes(bytes, length) {
    const padded = new Array(length).fill(0);
    for (let i = 0; i < Math.min(bytes.length, length); i++) {
        padded[i] = bytes[i];
    }
    return padded;
}

// Connect to MetaMask
async function connectWallet() {
    try {
        if (!window.ethereum) {
            alert('❌ MetaMask가 설치되어 있지 않습니다.\n\nhttps://metamask.io 에서 설치해주세요.');
            return false;
        }

        connectBtn.disabled = true;
        connectBtn.textContent = '연결 중...';

        provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer = await provider.getSigner();
        userAddress = await signer.getAddress();

        console.log('✅ Wallet connected:', userAddress);

        // Show wallet info
        connectedAddress.textContent = `${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
        walletInfo.style.display = 'block';
        connectBtn.style.display = 'none';

        // Auto-fetch attestation transaction
        await fetchAttestationTransaction();

        return true;
    } catch (error) {
        console.error('❌ Wallet connection failed:', error);
        alert('❌ MetaMask 연결 실패:\n\n' + error.message);
        connectBtn.disabled = false;
        connectBtn.textContent = '🦊 MetaMask 연결';
        return false;
    }
}

// Fetch Coinbase attestation transaction from Base network
async function fetchAttestationTransaction() {
    try {
        attestationInfoDiv.innerHTML = '<p style="margin: 5px 0;">🔍 Base 네트워크에서 Attestation 조회 중...</p>';
        console.log('📋 Querying attestations for:', userAddress);

        // Step 1: Query EAS GraphQL to get attestation
        const EAS_GRAPHQL_URL = 'https://base.easscan.org/graphql';
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
            attestationInfoDiv.innerHTML = `
                <p style="margin: 5px 0; color: #e74c3c;">❌ Coinbase KYC Attestation을 찾을 수 없습니다.</p>
                <small>Coinbase 계정에서 KYC 인증을 완료하고 Base Mainnet에 Attestation을 생성해주세요.</small>
            `;
            generateBtn.disabled = true;
            return;
        }

        const attestation = attestations[0];
        const txHash = attestation.txid;

        console.log('✅ Attestation found:', attestation);
        console.log('📄 Transaction hash:', txHash);

        // Step 2: Fetch raw transaction from Base blockchain
        const baseProvider = new ethers.JsonRpcProvider('https://mainnet.base.org');
        const tx = await baseProvider.getTransaction(txHash);

        if (!tx) {
            throw new Error('Transaction not found on blockchain');
        }

        // Serialize transaction to get raw bytes
        const serialized = ethers.Transaction.from(tx).serialized;
        console.log('✅ Raw transaction fetched:', serialized);

        // Step 3: Extract signature from transaction
        const txData = ethers.Transaction.from(tx);
        const signature = txData.signature;

        // Extract r, s, v from signature (ECRecover format)
        const r = signature.r.slice(2).padStart(64, '0'); // 32 bytes
        const s = signature.s.slice(2).padStart(64, '0'); // 32 bytes
        const v = signature.v; // 1 byte (27 or 28)

        console.log('🔑 Transaction Signature extracted:');
        console.log('  r:', r);
        console.log('  s:', s);
        console.log('  v:', v);

        // Step 4: Prepare circuit inputs
        const rawTxBytes = hexToBytes(serialized);
        const txLength = rawTxBytes.length;
        const paddedRawTx = padBytes(rawTxBytes, 300);

        // Signature: r (32) + s (32) + v (1) = 65 bytes
        const sigBytes = [
            ...hexToBytes('0x' + r),
            ...hexToBytes('0x' + s),
            v
        ];
        const paddedSig = padBytes(sigBytes, 65);

        // Store data for proof generation
        rawTransactionData = paddedRawTx;
        txSignatureData = paddedSig;
        txHashData = hexToBytes(txHash);
        txLengthData = txLength;

        console.log('✅ Circuit inputs prepared:');
        console.log('  - TX Hash:', txHash);
        console.log('  - TX Length:', txLength);
        console.log('  - Raw TX (300 bytes padded)');
        console.log('  - Signature (65 bytes: r + s + v)');

        // Display attestation info
        const attestationTime = new Date(attestation.time * 1000).toLocaleString('ko-KR');

        attestationInfoDiv.innerHTML = `
            <p style="margin: 5px 0;"><strong>✅ Attestation 발견!</strong></p>
            <p style="margin: 5px 0; font-size: 12px;">UID: ${attestation.id.slice(0, 10)}...${attestation.id.slice(-8)}</p>
            <p style="margin: 5px 0; font-size: 12px;">생성 시간: ${attestationTime}</p>
        `;

        // Display transaction info
        txHashDisplay.textContent = `${txHash.slice(0, 10)}...${txHash.slice(-8)}`;
        txLengthDisplay.textContent = `${txLength} bytes`;

        // Enable generate button
        generateBtn.disabled = false;

    } catch (error) {
        console.error('❌ Failed to fetch attestation transaction:', error);
        attestationInfoDiv.innerHTML = `
            <p style="margin: 5px 0; color: #e74c3c;">❌ 트랜잭션 조회 실패</p>
            <small>${error.message}</small>
        `;
        generateBtn.disabled = true;
    }
}

// Generate ZK Proof
async function generateProof() {
    if (!rawTransactionData || !txSignatureData || !txHashData || !txLengthData) {
        alert('❌ 먼저 트랜잭션 데이터를 불러와주세요.');
        return;
    }

    generateBtn.disabled = true;
    verifyBtn.disabled = true;
    loading.classList.add('show');
    resultDiv.classList.remove('show');

    try {
        // Step 1: Initialize Noir if not already initialized
        if (!noir) {
            loadingText.textContent = 'Initializing Noir circuit...';
            const initialized = await initNoir();
            if (!initialized) {
                throw new Error('Noir 초기화 실패');
            }
        }

        // Step 2: Prepare circuit inputs according to main.nr
        loadingText.textContent = 'Preparing circuit inputs...';
        console.log('⚙️ Preparing circuit inputs...');

        // Validate byte arrays (must be 0-255)
        const validateBytes = (arr, name) => {
            for (let i = 0; i < arr.length; i++) {
                if (arr[i] < 0 || arr[i] > 255 || !Number.isInteger(arr[i])) {
                    console.error(`❌ Invalid byte at ${name}[${i}]:`, arr[i]);
                    throw new Error(`Invalid byte value in ${name}[${i}]: ${arr[i]} (must be 0-255)`);
                }
            }
        };

        // IMPORTANT: Use lowercase address to match what's in the transaction calldata
        // Ethereum addresses in calldata are stored in lowercase, not EIP-55 checksum format
        const userAddressLowercase = userAddress.toLowerCase();
        const userAddressBytes = hexToBytes(userAddressLowercase);

        validateBytes(userAddressBytes, 'user_address');
        validateBytes(txHashData, 'tx_hash');
        validateBytes(rawTransactionData, 'raw_transaction');
        validateBytes(txSignatureData, 'tx_signature');

        console.log('✅ All byte arrays validated (0-255 range)');

        const inputs = {
            // PUBLIC INPUTS
            user_address: userAddressBytes,          // [u8; 20]
            tx_hash: txHashData,                     // [u8; 32]
            tx_length: txLengthData.toString(),      // u32 (must be string!)

            // PRIVATE INPUTS
            raw_transaction: rawTransactionData,     // [u8; 300]
            tx_signature: txSignatureData            // [u8; 65] - r(32) + s(32) + v(1)
        };

        console.log('📊 Circuit inputs:');
        console.log('  PUBLIC:');
        console.log('    - user_address:', userAddressLowercase, '→', userAddressBytes.length, 'bytes');
        console.log('    - user_address bytes:', JSON.stringify(userAddressBytes));
        console.log('    - tx_hash:', '0x' + txHashData.map(b => b.toString(16).padStart(2, '0')).join(''));
        console.log('    - tx_hash bytes:', JSON.stringify(txHashData));
        console.log('    - tx_length:', txLengthData);
        console.log('  PRIVATE:');
        console.log('    - raw_transaction: [300 bytes]', 'first 10:', rawTransactionData.slice(0, 10));
        console.log('    - raw_transaction ALL bytes:', JSON.stringify(rawTransactionData));
        console.log('    - tx_signature: [65 bytes]', 'first 10:', txSignatureData.slice(0, 10));
        console.log('    - tx_signature ALL bytes:', JSON.stringify(txSignatureData));

        console.log('\n=== COPY THIS FOR Prover.toml ===');
        console.log('user_address =', JSON.stringify(userAddressBytes));
        console.log('tx_hash =', JSON.stringify(txHashData));
        console.log('tx_length =', txLengthData);
        console.log('raw_transaction =', JSON.stringify(rawTransactionData));
        console.log('tx_signature =', JSON.stringify(txSignatureData));
        console.log('=================================\n');

        // Step 3: Generate witness
        loadingText.textContent = 'Generating witness...';
        console.log('🧮 Generating witness...');

        const { witness } = await noir.execute(inputs);
        console.log('✅ Witness generated successfully!');

        // Step 4: Generate proof with Keccak ZK
        loadingText.textContent = 'Generating proof with Keccak ZK... (이 작업은 시간이 걸릴 수 있습니다)';
        console.log('🔒 Generating proof with Keccak ZK...');

        const startTime = Date.now();
        const proof = await backend.generateProof(witness, { keccak: true });
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);

        console.log('✅ Proof generated successfully!');
        console.log('📊 Generation time:', duration, 'seconds');
        console.log('📊 Proof size:', (JSON.stringify(proof).length / 1024).toFixed(2), 'KB');

        // Store proof for verification
        currentProof = proof;

        showResult(
            `✅ Proof 생성 완료!\n\n` +
            `⏱️ 생성 시간: ${duration}초\n` +
            `📦 Proof 크기: ${(JSON.stringify(proof).length / 1024).toFixed(2)} KB\n\n` +
            `이제 "Verify Proof" 버튼을 클릭하여 검증하세요!`,
            true
        );

        // Enable verify buttons
        verifyBtn.disabled = false;
        verifyOnchainBtn.disabled = false;

    } catch (error) {
        console.error('❌ Proof generation failed:', error);
        showResult('❌ Proof 생성 실패:\n\n' + error.message, false);
    } finally {
        generateBtn.disabled = false;
        loading.classList.remove('show');
    }
}

// Verify ZK Proof (Local)
async function verifyProof() {
    if (!currentProof) {
        alert('❌ 먼저 Proof를 생성해주세요.');
        return;
    }

    verifyBtn.disabled = true;
    loading.classList.add('show');
    resultDiv.classList.remove('show');

    try {
        loadingText.textContent = 'Verifying proof locally with Keccak ZK...';
        console.log('🔍 Verifying proof locally with Keccak ZK...');

        const startTime = Date.now();
        const isValid = await backend.verifyProof(currentProof, { keccak: true });
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);

        console.log('✅ Local verification complete:', isValid);
        console.log('📊 Verification time:', duration, 'seconds');

        if (isValid) {
            showResult(
                `✅ Local Proof 검증 성공!\n\n` +
                `⏱️ 검증 시간: ${duration}초\n\n` +
                `🎉 Coinbase KYC Attestation이 Zero-Knowledge Proof로 검증되었습니다!\n\n` +
                `--- 검증 내용 ---\n` +
                `✅ Transaction Hash 일치 확인\n` +
                `✅ Transaction Signature로부터 Signer 복구 (ECRecover)\n` +
                `✅ Signer가 Coinbase Attester인지 확인\n` +
                `✅ Transaction Recipient가 User Address와 일치하는지 확인\n\n` +
                `🔒 모든 검증이 Zero-Knowledge Proof 내부에서 수행되어\n` +
                `   개인정보는 완전히 보호됩니다!`,
                true
            );
        } else {
            showResult(`❌ Local Proof 검증 실패\n\n증명이 유효하지 않습니다.`, false);
        }

    } catch (error) {
        console.error('❌ Local verification failed:', error);
        showResult('❌ 로컬 검증 실패:\n\n' + error.message, false);
    } finally {
        verifyBtn.disabled = false;
        loading.classList.remove('show');
    }
}

// Verify ZK Proof On-Chain
async function verifyProofOnchain() {
    if (!currentProof) {
        alert('❌ 먼저 Proof를 생성해주세요.');
        return;
    }

    if (!signer) {
        alert('❌ MetaMask를 먼저 연결해주세요.');
        return;
    }

    verifyOnchainBtn.disabled = true;
    loading.classList.add('show');
    resultDiv.classList.remove('show');

    try {
        loadingText.textContent = 'Preparing proof data for on-chain verification...';
        console.log('🔗 Verifying proof on-chain...');

        // Get network info
        const network = await provider.getNetwork();
        console.log('📡 Current network:', network.name, '(chainId:', network.chainId.toString(), ')');

        // Create contract instance
        const verifierContract = new ethers.Contract(VERIFIER_CONTRACT, VERIFIER_ABI, signer);

        // Prepare proof bytes
        const proofBytes = '0x' + Buffer.from(currentProof.proof).toString('hex');
        console.log('📦 Proof size:', proofBytes.length / 2, 'bytes');

        // Prepare public inputs (52 field elements from user_address + tx_hash)
        const publicInputs = currentProof.publicInputs.map(input => {
            // Convert field element to bytes32
            const hex = '0x' + input.toString(16).padStart(64, '0');
            return hex;
        });
        console.log('📊 Public inputs count:', publicInputs.length);
        console.log('📊 Public inputs:', publicInputs);

        loadingText.textContent = 'Calling verifier contract on-chain...';
        console.log('📞 Calling verify() on contract:', VERIFIER_CONTRACT);

        const startTime = Date.now();
        const isValid = await verifierContract.verify(proofBytes, publicInputs);
        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);

        console.log('✅ On-chain verification complete:', isValid);
        console.log('📊 Verification time:', duration, 'seconds');

        if (isValid) {
            showResult(
                `✅ On-Chain Proof 검증 성공!\n\n` +
                `⏱️ 검증 시간: ${duration}초\n` +
                `🌐 네트워크: ${network.name}\n` +
                `📍 Verifier: ${VERIFIER_CONTRACT}\n\n` +
                `🎉 블록체인에서 검증이 완료되었습니다!\n\n` +
                `--- 검증 내용 ---\n` +
                `✅ UltraHonk Proof 검증\n` +
                `✅ Public Inputs 일치 확인\n` +
                `✅ Verification Key 검증\n\n` +
                `🔒 Zero-Knowledge Proof가 스마트 컨트랙트에서\n` +
                `   성공적으로 검증되었습니다!`,
                true
            );
        } else {
            showResult(`❌ On-Chain Proof 검증 실패\n\n증명이 유효하지 않습니다.`, false);
        }

    } catch (error) {
        console.error('❌ On-chain verification failed:', error);
        let errorMessage = error.message;

        // Parse common errors
        if (error.message.includes('network')) {
            errorMessage = '네트워크 연결 오류입니다. MetaMask 네트워크를 확인해주세요.';
        } else if (error.message.includes('insufficient funds')) {
            errorMessage = '가스비가 부족합니다. (View 함수이므로 가스비는 실제로 소비되지 않습니다)';
        }

        showResult('❌ 온체인 검증 실패:\n\n' + errorMessage, false);
    } finally {
        verifyOnchainBtn.disabled = false;
        loading.classList.remove('show');
    }
}

// Show result
function showResult(message, success) {
    resultDiv.textContent = message;
    resultDiv.className = 'result show ' + (success ? 'success' : 'error');
}

// Initialize DOM and event listeners after page load
document.addEventListener('DOMContentLoaded', () => {
    // Get DOM elements
    connectBtn = document.getElementById('connectBtn');
    walletInfo = document.getElementById('walletInfo');
    connectedAddress = document.getElementById('connectedAddress');
    generateBtn = document.getElementById('generateBtn');
    verifyBtn = document.getElementById('verifyBtn');
    verifyOnchainBtn = document.getElementById('verifyOnchainBtn');
    loading = document.getElementById('loading');
    loadingText = document.getElementById('loadingText');
    resultDiv = document.getElementById('result');
    txHashDisplay = document.getElementById('txHash');
    txLengthDisplay = document.getElementById('txLength');
    attestationInfoDiv = document.getElementById('attestationInfo');

    console.log('🚀 Coinbase Attestor ZKP App loaded!');
    console.log('📦 Circuit: Complete ECRecover implementation');
    console.log('🔒 Privacy: Only raw_transaction and tx_signature as inputs');
    console.log('🔧 Using UltraHonk backend with Keccak ZK (bb.js 0.87.0)');
    console.log('🌐 Verifier Contract:', VERIFIER_CONTRACT);

    // Connect button event listener
    connectBtn.addEventListener('click', connectWallet);

    // Generate button event listener
    generateBtn.addEventListener('click', generateProof);

    // Verify button event listener (local)
    verifyBtn.addEventListener('click', verifyProof);

    // Verify button event listener (on-chain)
    verifyOnchainBtn.addEventListener('click', verifyProofOnchain);
});
