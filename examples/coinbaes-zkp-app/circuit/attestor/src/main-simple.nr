// Coinbase Attestation Zero-Knowledge Verifier - Simplified Version
// Verifies that a transaction sent to Coinbase Attester contains the user's address

use dep::std;
use dep::keccak256::keccak256;

// Coinbase Attester Proxy address on Base Mainnet
global COINBASE_ATTESTER: [u8; 20] = [
    0x35, 0x74, 0x58, 0x73, 0x9F, 0x90, 0x46, 0x1b,
    0x99, 0x78, 0x93, 0x50, 0x86, 0x8C, 0xD7, 0xCF,
    0x33, 0x0D, 0xd7, 0xEE
];

// Helper: Extract 'to' address from transaction
fn extract_to_address(raw_tx: [u8; 300]) -> [u8; 20] {
    let mut to_address: [u8; 20] = [0; 20];
    // For EIP-1559 tx, 'to' address is at byte index 23
    for i in 0..20 {
        to_address[i] = raw_tx[23 + i];
    }
    to_address
}

// Helper: Extract recipient address from calldata
fn extract_recipient_from_calldata(raw_tx: [u8; 300]) -> [u8; 20] {
    let mut recipient: [u8; 20] = [0; 20];
    // In the attestation calldata, recipient address is at bytes 61-80
    for i in 0..20 {
        recipient[i] = raw_tx[61 + i];
    }
    recipient
}

fn main(
    // ============ Public Inputs ============
    user_address: pub [u8; 20],         // User's Ethereum address
    tx_hash: pub [u8; 32],              // Transaction hash
    tx_length: pub u32,                 // Actual transaction length

    // ============ Private Inputs ============
    raw_transaction: [u8; 300],         // RLP-encoded raw transaction (padded)
) {
    // Step 1: Verify TX hash
    let computed_tx_hash: [u8; 32] = keccak256(raw_transaction, tx_length);
    assert(computed_tx_hash == tx_hash, "Transaction hash mismatch");

    // Step 2: Verify transaction is sent to Coinbase Attester
    let to_address = extract_to_address(raw_transaction);
    assert(to_address == COINBASE_ATTESTER, "Not sent to Coinbase Attester");

    // Step 3: Verify user address in calldata
    let recipient = extract_recipient_from_calldata(raw_transaction);
    assert(recipient == user_address, "Recipient mismatch");
}
