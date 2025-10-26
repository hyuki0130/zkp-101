import { ethers } from 'ethers';
import { getAttestations } from '@coinbase/onchainkit/identity';
import { base } from 'viem/chains';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Get from environment variables
const VERIFIED_ACCOUNT_SCHEMA = process.env.VERIFIED_ACCOUNT_SCHEMA || '0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9';
const USER_ADDRESS = process.env.USER_ADDRESS;

if (!USER_ADDRESS) {
    console.error('❌ ERROR: USER_ADDRESS not found in .env file');
    console.error('   Please copy .env.example to .env and fill in your address');
    process.exit(1);
}

// Base Mainnet RPC
const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');

async function testTransactionDecoding(txHash) {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔍 TX Hash로 Raw Transaction 추출 및 분석');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('TX Hash:', txHash);
    console.log('');

    try {
        // 1. TX Hash로 Transaction 조회
        console.log('📡 1. 블록체인에서 Transaction 조회 중...\n');
        const tx = await provider.getTransaction(txHash);

        if (!tx) {
            throw new Error('Transaction not found');
        }

        console.log('✅ Transaction 조회 성공!\n');

        // 2. Transaction 필드 출력 (이미 RLP 디코딩 완료)
        console.log('📦 2. Transaction 필드 (RLP 디코딩 완료):');
        console.log('  From:', tx.from);
        console.log('  To (EAS Contract):', tx.to);
        console.log('  Nonce:', tx.nonce);
        console.log('  Gas Limit:', tx.gasLimit?.toString());
        console.log('  Gas Price:', tx.gasPrice ? ethers.formatUnits(tx.gasPrice, 'gwei') + ' gwei' : 'N/A');
        console.log('  Max Fee Per Gas:', tx.maxFeePerGas ? ethers.formatUnits(tx.maxFeePerGas, 'gwei') + ' gwei' : 'N/A');
        console.log('  Max Priority Fee:', tx.maxPriorityFeePerGas ? ethers.formatUnits(tx.maxPriorityFeePerGas, 'gwei') + ' gwei' : 'N/A');
        console.log('  Value:', ethers.formatEther(tx.value || 0), 'ETH');
        console.log('  Chain ID:', tx.chainId);
        console.log('  Type:', tx.type, '(0=Legacy, 1=EIP-2930, 2=EIP-1559)');
        console.log('  Data Length:', tx.data.length, 'bytes');
        console.log('  Data (first 66 chars):', tx.data.slice(0, 66) + '...');
        console.log('');

        // 3. 서명 정보
        console.log('🔐 3. 서명 정보:');
        console.log('  v:', tx.signature?.v);
        console.log('  r:', tx.signature?.r);
        console.log('  s:', tx.signature?.s);
        console.log('');

        // 4. Raw Transaction (RLP 인코딩된 원본)
        console.log('📜 4. Raw Transaction (RLP 인코딩):');
        const serialized = ethers.Transaction.from(tx).serialized;
        console.log('  Length:', serialized.length, 'characters');
        console.log('  First 100 chars:', serialized.slice(0, 100) + '...');
        console.log('  Full:', serialized);
        console.log('');

        // 5. TX Hash 재계산 (검증)
        console.log('🧪 5. TX Hash 재계산 (검증):');
        const computedHash = ethers.keccak256(serialized);
        console.log('  Original TX Hash:', txHash);
        console.log('  Computed TX Hash:', computedHash);
        console.log('  Match:', txHash.toLowerCase() === computedHash.toLowerCase() ? '✅ YES' : '❌ NO');
        console.log('');

        // 6. Calldata 디코딩 (EAS Attest)
        console.log('🔍 6. Calldata 분석:');
        console.log('  Function Selector:', tx.data.slice(0, 10));
        console.log('  Expected (attest):', '0xf17325e7');
        console.log('  Match:', tx.data.slice(0, 10) === '0xf17325e7' ? '✅ YES' : '❌ NO');
        console.log('');

        // 7. EAS Attest ABI로 디코딩
        const EAS_ATTEST_ABI = [
            'function attest((bytes32 schema, (address recipient, uint64 expirationTime, bool revocable, bytes32 refUID, bytes data, uint256 value) data) request) payable returns (bytes32)'
        ];

        const iface = new ethers.Interface(EAS_ATTEST_ABI);

        try {
            const decoded = iface.parseTransaction({ data: tx.data });

            console.log('📋 7. Decoded Attest Parameters:');
            console.log('  Function:', decoded.name);
            console.log('  Schema:', decoded.args.request.schema);
            console.log('  Recipient:', decoded.args.request.data.recipient);
            console.log('  Expiration Time:', decoded.args.request.data.expirationTime.toString());
            console.log('  Revocable:', decoded.args.request.data.revocable);
            console.log('  Ref UID:', decoded.args.request.data.refUID);
            console.log('  Data:', decoded.args.request.data.data);
            console.log('  Value:', decoded.args.request.data.value.toString());
            console.log('');
        } catch (decodeError) {
            console.log('⚠️  Calldata 디코딩 실패:', decodeError.message);
            console.log('');
        }

        // 8. Transaction Receipt
        console.log('📋 8. Transaction Receipt:');
        const receipt = await provider.getTransactionReceipt(txHash);
        console.log('  Status:', receipt.status === 1 ? '✅ Success' : '❌ Failed');
        console.log('  Block Number:', receipt.blockNumber);
        console.log('  Gas Used:', receipt.gasUsed.toString());
        console.log('  Effective Gas Price:', ethers.formatUnits(receipt.gasPrice, 'gwei'), 'gwei');
        console.log('  Logs:', receipt.logs.length);
        console.log('');

        // 9. Attested Event 찾기
        console.log('✅ 9. Attested Event:');
        const ATTESTED_EVENT = '0x8bf46bf4cfd674fa735a3d63ec1c9ad4153f033c290341f3a588b75685141b35';
        const attestedLog = receipt.logs.find(log => log.topics[0] === ATTESTED_EVENT);

        if (attestedLog) {
            console.log('  Recipient:', '0x' + attestedLog.topics[1].slice(26));
            console.log('  Attester:', '0x' + attestedLog.topics[2].slice(26));
            console.log('  Schema UID:', attestedLog.topics[3]);
            console.log('  Attestation UID:', attestedLog.data);
        } else {
            console.log('  ⚠️  Attested event not found');
        }
        console.log('');

        return {
            transaction: tx,
            serialized,
            receipt,
            attestedEvent: attestedLog ? {
                recipient: '0x' + attestedLog.topics[1].slice(26),
                attester: '0x' + attestedLog.topics[2].slice(26),
                schemaUID: attestedLog.topics[3],
                attestationUID: attestedLog.data
            } : null
        };

    } catch (error) {
        console.error('❌ Error:', error.message);
        throw error;
    }
}

async function main() {
    try {
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🔐 Coinbase Attestation Transaction Analyzer');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        console.log('📋 설정:');
        console.log('  User Address:', USER_ADDRESS);
        console.log('  Schema:', VERIFIED_ACCOUNT_SCHEMA);
        console.log('  Network: Base Mainnet (Chain ID: 8453)');
        console.log('');

        // 1. Attestation 조회
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📡 Step 1: Attestation 조회 중...');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        const attestations = await getAttestations(USER_ADDRESS, base, {
            schemas: [VERIFIED_ACCOUNT_SCHEMA],
        });

        if (attestations.length === 0) {
            console.log('❌ No attestations found for this address');
            console.log('   Please make sure you have completed Coinbase KYC verification');
            return;
        }

        console.log(`✅ Found ${attestations.length} attestation(s)\n`);

        // 2. 각 Attestation에 대해 트랜잭션 분석
        for (let index = 0; index < attestations.length; index++) {
            const attestation = attestations[index];

            console.log(`\n${'='.repeat(80)}`);
            console.log(`📋 Attestation #${index + 1}`);
            console.log('='.repeat(80));
            console.log('');
            console.log('Basic Info:');
            console.log('  UID:', attestation.id);
            console.log('  TX Hash:', attestation.txid);
            console.log('  Attester:', attestation.attester);
            console.log('  Recipient:', attestation.recipient);
            console.log('  Schema:', attestation.schemaId);
            console.log('  Time:', new Date(attestation.time * 1000).toLocaleString());
            console.log('  Expiration:', attestation.expirationTime === 0 ? 'Never' : new Date(attestation.expirationTime * 1000).toLocaleString());
            console.log('  Revoked:', attestation.revoked);

            // Decoded data
            if (attestation.decodedDataJson) {
                try {
                    const decodedData = JSON.parse(attestation.decodedDataJson);
                    console.log('\n📋 Decoded Data:');
                    decodedData.forEach(field => {
                        console.log(`  - ${field.name}: ${field.value.value}`);
                    });
                    console.log('\n✅ Coinbase KYC Status:', decodedData?.[0]?.value?.value === true ? '✅ Verified' : '❌ Not Verified');
                } catch (e) {
                    console.log('⚠️  Failed to parse decoded data');
                }
            }

            // 3. Transaction 분석
            console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log(`📡 Step 2: Transaction Analysis (TX Hash → Raw Transaction)`);
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

            const txData = await testTransactionDecoding(attestation.txid);

            // 4. 요약
            console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log('📊 Summary');
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

            console.log('Attestation Data:');
            console.log('  UID:', attestation.id);
            console.log('  Recipient:', attestation.recipient);
            console.log('  Attester:', attestation.attester);
            console.log('  Schema:', attestation.schemaId);
            console.log('');

            console.log('Transaction Data:');
            console.log('  TX Hash:', attestation.txid);
            console.log('  From:', txData.transaction.from);
            console.log('  To:', txData.transaction.to);
            console.log('  Nonce:', txData.transaction.nonce);
            console.log('  Gas Used:', txData.receipt.gasUsed.toString());
            console.log('  Status:', txData.receipt.status === 1 ? '✅ Success' : '❌ Failed');
            console.log('');

            console.log('Raw Transaction:');
            console.log('  Length:', txData.serialized.length, 'characters');
            console.log('  Data:', txData.serialized);
            console.log('');

            console.log('Signature:');
            console.log('  v:', txData.transaction.signature?.v);
            console.log('  r:', txData.transaction.signature?.r);
            console.log('  s:', txData.transaction.signature?.s);
            console.log('');

            if (txData.attestedEvent) {
                console.log('Attested Event:');
                console.log('  Recipient:', txData.attestedEvent.recipient);
                console.log('  Attester:', txData.attestedEvent.attester);
                console.log('  Schema UID:', txData.attestedEvent.schemaUID);
                console.log('  Attestation UID:', txData.attestedEvent.attestationUID);
            }
        }

        console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('🎉 분석 완료!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        console.log('✅ 결론:');
        console.log('   1. TX Hash는 "해싱된 값"이지만');
        console.log('   2. 블록체인 노드가 원본 Raw Transaction을 저장');
        console.log('   3. RPC로 TX Hash → Raw Transaction 조회 가능');
        console.log('   4. Raw Transaction은 RLP로 인코딩되어 있음');
        console.log('   5. RLP 디코딩으로 모든 필드(nonce, gas, data, v, r, s) 추출 가능');
        console.log('   6. Attestation 생성에 사용된 모든 파라미터 검증 가능 ✅');
        console.log('');

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        console.error(error);
        process.exit(1);
    }
}

main();
