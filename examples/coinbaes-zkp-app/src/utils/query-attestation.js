import { getAttestations } from '@coinbase/onchainkit/identity';
import { base } from 'viem/chains';
import { createPublicClient, http } from 'viem';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Get from environment variables
const VERIFIED_ACCOUNT_SCHEMA = process.env.VERIFIED_ACCOUNT_SCHEMA || '0xf8b05c79f090979bf4a80270aba232dff11a10d9ca55c4f88de95317970f0de9';
const myAddress = process.env.USER_ADDRESS;

if (!myAddress) {
    console.error('❌ ERROR: USER_ADDRESS not found in .env file');
    console.error('   Please copy .env.example to .env and fill in your address');
    process.exit(1);
}

// EAS GraphQL endpoint for Base Mainnet
const EAS_GRAPHQL_URL = 'https://base.easscan.org/graphql';

// Create viem client for Base
const client = createPublicClient({
    chain: base,
    transport: http()
});

async function queryAttestation() {
    try {
        console.log('🔍 Querying attestations for:', myAddress);

        const attestations = await getAttestations(myAddress, base, {
            schemas: [VERIFIED_ACCOUNT_SCHEMA],
        });

        if (attestations.length === 0) {
            console.log('❌ No attestations found');
            return;
        }

        console.log('✅ Attestations found:', attestations.length);

        // Query EAS GraphQL for detailed attestation data
        for (let index = 0; index < attestations.length; index++) {
            const att = attestations[index];
            console.log(`\n--- Attestation ${index + 1} ---`);

            // Decoded data 파싱
            let decodedData = null;
            if (att.decodedDataJson) {
                try {
                    decodedData = JSON.parse(att.decodedDataJson);
                } catch (e) {
                    console.log('⚠️  Data 파싱 실패');
                }
            }

            // ⭐ 주의: 실제 API는 id, schemaId, decodedDataJson 사용
            console.log('UID:', att.id);
            console.log('TX Hash:', att.txid);
            console.log('Schema:', att.schemaId);
            console.log('Attester:', att.attester);
            console.log('Recipient:', att.recipient);
            console.log('Time:', new Date(att.time * 1000).toLocaleString());
            console.log('Time (Unix):', att.time); // For Prover.toml
            console.log('Expiration:', att.expirationTime === 0 ? 'Never' : new Date(att.expirationTime * 1000).toLocaleString());
            console.log('Expiration (Unix):', att.expirationTime); // For Prover.toml
            console.log('Revoked:', att.revoked);
            console.log('Revocation Time:', att.revocationTime);

            if (decodedData) {
                console.log('\n📋 Decoded Data:');
                decodedData.forEach(field => {
                    console.log(`  - ${field.name}: ${field.value.value}`);
                });
            }

            console.log('\n✅ Coinbase KYC 인증 상태:', decodedData?.[0]?.value?.value === true ? '✅ 인증됨' : '❌ 미인증');

            // Query EAS GraphQL for additional fields (refUID, salt, signature)
            console.log('\n🔍 Querying EAS GraphQL for detailed data...');
            try {
                const graphqlQuery = `
                    query GetAttestation($uid: String!) {
                        attestation(where: { id: $uid }) {
                            id
                            attester
                            recipient
                            refUID
                            revocable
                            revocationTime
                            expirationTime
                            data
                        }
                    }
                `;

                const response = await fetch(EAS_GRAPHQL_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        query: graphqlQuery,
                        variables: { uid: att.id }
                    })
                });

                const result = await response.json();

                if (result.data?.attestation) {
                    const easData = result.data.attestation;
                    console.log('\n📋 EAS GraphQL Data:');
                    console.log('  RefUID:', easData.refUID);
                    console.log('  Revocable:', easData.revocable);
                    console.log('  Data (raw):', easData.data);
                } else {
                    console.log('⚠️  No additional data from EAS GraphQL');
                }
            } catch (easError) {
                console.log('⚠️  EAS GraphQL query failed:', easError.message);
            }

            // Query transaction data for salt
            console.log('\n🔍 Querying transaction for salt...');
            try {
                const txReceipt = await client.getTransactionReceipt({ hash: att.txid });

                // EAS Attested event signature
                const ATTESTED_EVENT = '0x8bf46bf4cfd674fa735a3d63ec1c9ad4153f033c290341f3a588b75685141b35';

                const attestedLog = txReceipt.logs.find(log => log.topics[0] === ATTESTED_EVENT);

                if (attestedLog) {
                    console.log('\n📋 Transaction Log Data:');
                    console.log('  Topics:', attestedLog.topics);
                    console.log('  Data:', attestedLog.data);
                    // Salt is typically in the data field of the Attested event
                } else {
                    console.log('⚠️  Attested event not found in transaction');
                }
            } catch (txError) {
                console.log('⚠️  Transaction query failed:', txError.message);
            }
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

queryAttestation();
