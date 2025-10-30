// EIP-1559 Transaction Parser
//
// Parses raw Ethereum transaction bytes and extracts fields needed for
// Coinbase attestation verification. Optimized for Base Mainnet EIP-1559 transactions.

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
/// For EIP-1559 transactions:
/// - Signature is RLP encoded: RLP(v) + RLP(r) + RLP(s)
/// - v encoding varies: 0x80 (1 byte for v=0), 0x01 (1 byte for v=1), or 0xc0 0x01 (2 bytes for v=1)
/// - r and s are always: 0xa0 + 32 bytes = 33 bytes each
/// - Total signature RLP length: (1-2) + 33 + 33 = 67-68 bytes
/// - This function dynamically calculates the signature RLP length
pub fn create_unsigned_tx_hash(raw_tx: [u8; 300], tx_length: u32) -> [u8; 32] {
    let mut unsigned_tx: [u8; 300] = [0; 300];

    // Calculate signature RLP length dynamically
    // Signature structure: v + r + s
    // - r is always: 0xa0 + 32 bytes = 33 bytes
    // - s is always: 0xa0 + 32 bytes = 33 bytes
    // - v varies: 1 or 2 bytes
    //
    // Strategy: Find r prefix (0xa0) from the end, which is at (tx_length - 66)
    // Then check what's before it to determine v length

    // r prefix is always at tx_length - 66 (33 bytes for r + 33 bytes for s)
    let r_start = tx_length - 66;
    let r_prefix = raw_tx[r_start];

    // Verify r prefix is 0xa0 (safety check)
    assert(r_prefix == 0xa0, "Invalid r prefix in signature");

    // Check the byte before r to determine v length
    let before_r = raw_tx[r_start - 1];

    let signature_rlp_length = if before_r == 0xc0 {
        // v is 2 bytes: 0xc0 0x?? + 33 (r) + 33 (s) = 68 bytes
        68
    } else {
        // v is 1 byte: 0x01 or 0x80 + 33 (r) + 33 (s) = 67 bytes
        67
    };

    let unsigned_length = tx_length - signature_rlp_length;

    // Copy unsigned transaction fields
    for i in 0..300 {
        if i < unsigned_length {
            unsigned_tx[i] = raw_tx[i];
        }
    }

    // Fix RLP length encoding: subtract signature length from RLP length byte
    // raw_tx[2] contains the RLP payload length (signed)
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

/// Extracts ECDSA signature from raw transaction
///
/// # Arguments
/// * `raw_tx` - Full transaction bytes
/// * `tx_length` - Length of the transaction
///
/// # Returns
/// 65-byte signature: r (32 bytes) + s (32 bytes) + v (1 byte)
///
/// # Implementation
/// Dynamically parses RLP-encoded signature at the end of the transaction.
/// Handles both 67-byte (v=1 byte) and 68-byte (v=2 bytes) RLP encodings.
pub fn extract_signature_from_tx(raw_tx: [u8; 300], tx_length: u32) -> [u8; 65] {
    let mut signature: [u8; 65] = [0; 65];

    // EIP-1559 signatures are RLP encoded:
    // Format at end of TX: RLP(v) RLP(r) RLP(s)
    // v can be: 0x80 (1 byte for v=0), 0x01 (1 byte for v=1), or 0xc0 0x01 (2 bytes for v=1)
    // r is always: 0xa0 [32 bytes] (33 bytes)
    // s is always: 0xa0 [32 bytes] (33 bytes)

    // r prefix is always at tx_length - 66 (33 bytes for r + 33 bytes for s)
    let r_start_pos = tx_length - 66;
    let r_prefix = raw_tx[r_start_pos];

    // Verify r prefix is 0xa0 (safety check)
    assert(r_prefix == 0xa0, "Invalid r prefix in signature extraction");

    // Check the byte before r to determine v length
    let before_r = raw_tx[r_start_pos - 1];

    let (rlp_sig_start, v_length) = if before_r == 0xc0 {
        // v is 2 bytes: 0xc0 0x??
        (r_start_pos - 2, 2)
    } else {
        // v is 1 byte: 0x01 or 0x80
        (r_start_pos - 1, 1)
    };

    // Extract v value
    let v_byte = if v_length == 2 {
        // Skip 0xc0 prefix, take next byte
        raw_tx[rlp_sig_start + 1]
    } else {
        // Single byte: if 0x80 then v=0, otherwise it's the value itself
        let v_raw = raw_tx[rlp_sig_start];
        if v_raw == 0x80 { 0 } else { v_raw }
    };

    // Extract r: skip v encoding, then skip 0xa0 prefix, take next 32 bytes
    let r_start = rlp_sig_start + v_length + 1;

    // Extract s: skip r (33 bytes from its prefix), then skip 0xa0 prefix, take next 32 bytes
    let s_start = r_start + 33;

    // Build signature: r (32) + s (32) + v (1) = 65 bytes
    for i in 0..32 {
        signature[i] = raw_tx[r_start + i];      // r
        signature[32 + i] = raw_tx[s_start + i]; // s
    }
    signature[64] = v_byte; // v at the end

    signature
}
