// Coinbase KYC Attestation Zero-Knowledge Verifier
// Verifies Coinbase attestation by recovering signer from transaction signature
//
// IMPORTANT: This circuit implements full ecrecover - no external pubkey input!
// All cryptographic operations happen inside the circuit for maximum privacy.

mod bigint;
mod bignum_lib;
mod secp256k1;
mod ecrecover;
mod tx_parser;

use dep::keccak256::keccak256;

// Coinbase Attester contract address on Base Mainnet
global COINBASE_ATTESTER: [u8; 20] = [
    0x35, 0x74, 0x58, 0x73, 0x9F, 0x90, 0x46, 0x1b,
    0x99, 0x78, 0x93, 0x50, 0x86, 0x8C, 0xD7, 0xCF,
    0x33, 0x0D, 0xd7, 0xEE
];

// Coinbase Signer wallet address (recovered from Base Mainnet transaction)
// Address: 0x952f32128AF084422539C4Ff96df5C525322E564
global COINBASE_SIGNER: [u8; 20] = [
    0x95, 0x2f, 0x32, 0x12, 0x8A, 0xF0, 0x84, 0x42,
    0x25, 0x39, 0xC4, 0xFF, 0x96, 0xdf, 0x5C, 0x52,
    0x53, 0x22, 0xE5, 0x64
];

fn main(
    // ============================================================
    // PUBLIC INPUTS (visible in proof)
    // ============================================================
    user_address: pub [u8; 20],    // User's Ethereum address
    tx_hash: pub [u8; 32],          // Transaction hash (for verification)
    tx_length: pub u32,             // Length of transaction bytes

    // ============================================================
    // PRIVATE INPUTS (hidden in proof)
    // ============================================================
    raw_transaction: [u8; 300],     // Full signed transaction
    tx_signature: [u8; 65],         // Signature: r(32) + s(32) + v(1)
) {
    // ============================================================
    // PART 1: Transaction Structure Verification
    // ============================================================

    // 1. Verify transaction hash
    // This ensures the raw_transaction provided is authentic
    let computed_tx_hash: [u8; 32] = keccak256(raw_transaction, tx_length);
    assert(computed_tx_hash == tx_hash);

    // 2. Verify transaction was sent to Coinbase Attester contract
    // This ensures the transaction is for Coinbase attestation
    let to_address = tx_parser::extract_to_address(raw_transaction);
    assert(to_address == COINBASE_ATTESTER);

    // 3. Extract calldata and verify it contains the user's address
    // This proves the attestation is for the specific user
    let calldata = tx_parser::extract_calldata(raw_transaction);
    let calldata_address = tx_parser::extract_address_from_calldata(calldata);
    assert(calldata_address == user_address);

    // ============================================================
    // PART 2: Coinbase Signature Verification via ECRecover
    // ============================================================

    // 4. Create unsigned transaction hash
    // This is the message that was signed by Coinbase
    let unsigned_tx_hash = tx_parser::create_unsigned_tx_hash(raw_transaction, tx_length);

    // 5. Extract signature components
    let (r, s, v) = ecrecover::extract_signature(tx_signature);

    // 6. RECOVER PUBLIC KEY FROM SIGNATURE
    // This is the core cryptographic operation - recovering Coinbase's pubkey
    // Algorithm: pubkey = r^(-1) * (s*R - e*G)
    let (recovered_pubkey_x, recovered_pubkey_y) = ecrecover::ecrecover(
        unsigned_tx_hash,
        v,
        r,
        s
    );

    // 7. Convert recovered public key to Ethereum address
    let recovered_address = secp256k1::pubkey_to_address(
        recovered_pubkey_x,
        recovered_pubkey_y
    );

    // 8. Verify the signer is Coinbase's authorized wallet
    assert(recovered_address == COINBASE_SIGNER);

    // ============================================================
    // VERIFICATION COMPLETE
    // ============================================================
    //
    // At this point, we have cryptographically proven:
    //
    // 1. The transaction hash is valid and authentic
    // 2. The transaction was sent to the Coinbase Attester contract
    // 3. The transaction calldata contains the user's address
    // 4. The transaction signature is valid (via ecrecover)
    // 5. The signer is Coinbase's authorized wallet
    //
    // THEREFORE: Coinbase has issued a valid KYC attestation for user_address
    //
    // PRIVACY: The Coinbase signer's public key is recovered inside the circuit
    //          and is NOT revealed in the proof. Only the verification result
    //          (valid/invalid) is known.
}
