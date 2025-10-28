//! Coinbase KYC Attestation Zero-Knowledge Verifier
//!
//! This circuit verifies that a Coinbase KYC attestation transaction was signed by
//! Coinbase's authorized wallet, without revealing the transaction signature or public key.
//!
//! # Architecture
//!
//! The circuit performs full ECRecover inside the ZK proof:
//! 1. Parses the raw Ethereum transaction
//! 2. Extracts the unsigned transaction hash
//! 3. Recovers the public key from the signature using ECRecover algorithm
//! 4. Verifies the recovered address matches Coinbase's authorized signer
//!
//! # Privacy Guarantees
//!
//! - Transaction signature remains private
//! - Recovered public key is never revealed in the proof
//! - Only the verification result (valid/invalid) is public

mod bigint;
mod bignum_lib;
mod secp256k1;
mod ecrecover;
mod tx_parser;

use dep::keccak256::keccak256;

/// Coinbase Attester contract address on Base Mainnet
/// Address: 0x357458739F90461b99789350868CD7CF330Dd7EE
global COINBASE_ATTESTER: [u8; 20] = [
    0x35, 0x74, 0x58, 0x73, 0x9F, 0x90, 0x46, 0x1b,
    0x99, 0x78, 0x93, 0x50, 0x86, 0x8C, 0xD7, 0xCF,
    0x33, 0x0D, 0xd7, 0xEE
];

/// Coinbase authorized signer wallet address
/// Address: 0x952f32128AF084422539C4Ff96df5C525322E564
global COINBASE_SIGNER: [u8; 20] = [
    0x95, 0x2f, 0x32, 0x12, 0x8A, 0xF0, 0x84, 0x42,
    0x25, 0x39, 0xC4, 0xFF, 0x96, 0xdf, 0x5C, 0x52,
    0x53, 0x22, 0xE5, 0x64
];

/// Verifies a Coinbase KYC attestation by proving the transaction was signed by Coinbase
///
/// # Public Inputs (visible in proof)
/// - `user_address`: The Ethereum address being attested
/// - `tx_hash`: Transaction hash for verification
/// - `tx_length`: Length of the transaction in bytes
///
/// # Private Inputs (hidden in proof)
/// - `raw_transaction`: Full signed EIP-1559 transaction bytes
/// - `tx_signature`: ECDSA signature (r, s, v components)
///
/// # Verification Flow
///
/// 1. **Transaction Hash Verification**: Ensures the provided transaction is authentic
/// 2. **Destination Verification**: Confirms transaction was sent to Coinbase Attester contract
/// 3. **User Address Verification**: Proves the attestation is for the specified user
/// 4. **Signature Recovery**: Recovers public key from signature using ECRecover
/// 5. **Signer Verification**: Confirms the signer is Coinbase's authorized wallet
///
/// # Security Properties
///
/// - The transaction signature remains private
/// - The recovered public key is never revealed in the proof
/// - Only the final verification result is public (proof valid/invalid)
/// - Uses constrained ECDSA verification to ensure soundness
fn main(
    user_address: pub [u8; 20],
    tx_hash: pub [u8; 32],
    tx_length: pub u32,
    raw_transaction: [u8; 300],
    tx_signature: [u8; 65],
) {
    // Verify transaction hash
    let computed_tx_hash: [u8; 32] = keccak256(raw_transaction, tx_length);
    assert(computed_tx_hash == tx_hash);

    // Verify transaction was sent to Coinbase Attester contract
    let to_address = tx_parser::extract_to_address(raw_transaction);
    assert(to_address == COINBASE_ATTESTER);

    // Verify attestation is for the specified user
    let calldata = tx_parser::extract_calldata(raw_transaction);
    let calldata_address = tx_parser::extract_address_from_calldata(calldata);
    assert(calldata_address == user_address);

    // Create unsigned transaction hash (the message that was signed)
    let unsigned_tx_hash = tx_parser::create_unsigned_tx_hash(raw_transaction, tx_length);

    // Extract signature components
    let (r, s, v) = ecrecover::extract_signature(tx_signature);

    // Recover public key from signature
    let (recovered_pubkey_x, recovered_pubkey_y) = ecrecover::ecrecover(
        unsigned_tx_hash,
        v,
        r,
        s
    );

    // Convert recovered public key to Ethereum address
    let recovered_address = secp256k1::pubkey_to_address(
        recovered_pubkey_x,
        recovered_pubkey_y
    );

    // Verify signer is Coinbase's authorized wallet
    assert(recovered_address == COINBASE_SIGNER);
}
