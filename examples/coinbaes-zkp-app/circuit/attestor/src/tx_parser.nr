//! EIP-1559 Transaction Parser
//!
//! Parses raw Ethereum transaction bytes and extracts fields needed for
//! Coinbase attestation verification. Optimized for Base Mainnet EIP-1559 transactions.

use dep::keccak256::keccak256;

/// Creates the unsigned transaction hash for signature verification
///
/// # EIP-1559 Transaction Format
///
/// Signed: 0x02 || RLP([chainId, nonce, maxPriorityFee, maxFee, gas, to, value, data, accessList, v, r, s])
/// Unsigned: 0x02 || RLP([chainId, nonce, maxPriorityFee, maxFee, gas, to, value, data, accessList])
///
/// # Arguments
/// * `raw_tx` - Full signed transaction bytes
/// * `tx_length` - Total transaction length (including signature)
///
/// # Returns
/// Keccak256 hash of the unsigned transaction
///
/// # Implementation Notes
///
/// For Coinbase attestation transactions on Base Mainnet:
/// - EIP-1559 signature is 67 bytes in RLP encoding: v (1-3 bytes) + r (33 bytes) + s (33 bytes)
/// - Unsigned portion = tx_length - 67
/// - RLP length byte at index 2 must be adjusted by subtracting 67
pub fn create_unsigned_tx_hash(raw_tx: [u8; 300], tx_length: u32) -> [u8; 32] {
    let mut unsigned_tx: [u8; 300] = [0; 300];

    // EIP-1559 signature is 67 bytes in RLP: v + r + s
    let signature_rlp_length = 67;
    let unsigned_length = tx_length - signature_rlp_length;

    // Copy unsigned transaction fields
    for i in 0..300 {
        if i < unsigned_length {
            unsigned_tx[i] = raw_tx[i];
        }
    }

    // Fix RLP length encoding: subtract signature length from RLP length byte
    // raw_tx[2] contains the RLP payload length (signed)
    // We need to subtract 67 to get the unsigned RLP payload length
    let signed_rlp_length = raw_tx[2];
    let unsigned_rlp_length = signed_rlp_length - (signature_rlp_length as u8);
    unsigned_tx[2] = unsigned_rlp_length;

    keccak256(unsigned_tx, unsigned_length)
}

/// Extracts the destination address from the transaction
///
/// # Arguments
/// * `raw_tx` - Full transaction bytes
///
/// # Returns
/// The 20-byte Ethereum address the transaction was sent to
///
/// # Implementation
/// Searches for the RLP address prefix (0x94) which indicates a 20-byte address follows.
/// This is dynamic to handle different transaction sizes.
pub fn extract_to_address(raw_tx: [u8; 300]) -> [u8; 20] {
    let mut to_address: [u8; 20] = [0; 20];

    // Find 0x94 (RLP prefix for 20-byte address) in the transaction
    // Start searching from index 3 (after type and RLP header)
    let mut found_offset = 0;
    for i in 3..50 {
        if (raw_tx[i] == 0x94) & (found_offset == 0) {
            found_offset = i + 1;  // Address starts after 0x94
        }
    }

    // Extract 20-byte address
    for i in 0..20 {
        to_address[i] = raw_tx[found_offset + i];
    }

    to_address
}

/// Extracts calldata from the transaction
///
/// # Arguments
/// * `raw_tx` - Full transaction bytes
///
/// # Returns
/// 36 bytes of calldata containing function selector and parameters
///
/// # Calldata Structure
/// - [0-3]: Function selector (0x56feed5e for Coinbase attestation)
/// - [4-15]: Zero padding (for uint256 alignment)
/// - [16-35]: User address (20 bytes)
///
/// # Implementation
/// Calldata comes after: to_address (20 bytes) + value (1 byte for 0x80) + data length prefix (1 byte for 0xa4)
pub fn extract_calldata(raw_tx: [u8; 300]) -> [u8; 36] {
    let mut calldata: [u8; 36] = [0; 36];

    // Find to_address first (find 0x94)
    let mut to_address_offset = 0;
    for i in 3..50 {
        if (raw_tx[i] == 0x94) & (to_address_offset == 0) {
            to_address_offset = i + 1;
        }
    }

    // Calldata starts after: to_address (20 bytes) + value (1 byte) + data_length_prefix (1 byte)
    let calldata_offset = to_address_offset + 20 + 1 + 1;

    for i in 0..36 {
        calldata[i] = raw_tx[calldata_offset + i];
    }

    calldata
}

/// Extracts the user address from calldata
///
/// # Arguments
/// * `calldata` - Transaction calldata (36 bytes)
///
/// # Returns
/// The 20-byte Ethereum address extracted from calldata
///
/// # Format
/// Assumes calldata format: selector (4 bytes) + padding (12 bytes) + address (20 bytes)
pub fn extract_address_from_calldata(calldata: [u8; 36]) -> [u8; 20] {
    let mut address: [u8; 20] = [0; 20];

    for i in 0..20 {
        address[i] = calldata[16 + i];
    }

    address
}

/// Extracts ECDSA signature from raw transaction (utility function)
///
/// # Arguments
/// * `raw_tx` - Full transaction bytes
/// * `tx_length` - Length of the transaction
///
/// # Returns
/// 65-byte signature: r (32 bytes) + s (32 bytes) + v (1 byte)
///
/// # Note
/// This is a simplified implementation assuming signature is at the end.
/// Full RLP parsing would be needed for general transactions.
pub fn extract_signature_from_tx(raw_tx: [u8; 300], tx_length: u32) -> [u8; 65] {
    let mut signature: [u8; 65] = [0; 65];
    let sig_start = tx_length - 65;

    for i in 0..65 {
        if (sig_start + i) < 300 {
            signature[i] = raw_tx[sig_start + i];
        }
    }

    signature
}
