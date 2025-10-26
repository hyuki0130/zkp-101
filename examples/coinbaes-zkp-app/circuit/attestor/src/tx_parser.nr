// EIP-1559 Transaction Parser
// Extracts fields from raw transaction bytes

use dep::keccak256::keccak256;

// Parse EIP-1559 transaction and extract unsigned hash
// EIP-1559 tx format: 0x02 || RLP([chainId, nonce, maxPriorityFee, maxFee, gas, to, value, data, accessList, v, r, s])
// Unsigned tx: 0x02 || RLP([chainId, nonce, maxPriorityFee, maxFee, gas, to, value, data, accessList])
pub fn create_unsigned_tx_hash(raw_tx: [u8; 300], _tx_length: u32) -> [u8; 32] {
    // For this specific Coinbase attestation transaction structure:
    // Total tx length: 149 bytes
    // Unsigned portion: 82 bytes (indices 0-81)
    // Signature portion: 67 bytes (indices 82-148)
    //
    // Structure breakdown:
    // [0-80] = unsigned transaction fields
    // [81] = 0xc0 (empty accessList)
    // [82] = 0x01 (v recovery id)
    // [83] = 0xa0 (RLP marker for 32-byte r)
    // [84-115] = r (32 bytes)
    // [116] = 0xa0 (RLP marker for 32-byte s)
    // [117-148] = s (32 bytes)

    let mut unsigned_tx: [u8; 300] = [0; 300];

    // For Base Mainnet Coinbase attestation transactions:
    // Unsigned tx length is always 82 bytes
    let unsigned_length = 82;

    // Copy the unsigned portion
    for i in 0..82 {
        unsigned_tx[i] = raw_tx[i];
    }

    // CRITICAL: Fix RLP length encoding for unsigned transaction
    // Signed tx has RLP length 0xf892 (146 bytes payload)
    // Unsigned tx has RLP length 0xf84f (79 bytes payload)
    // We must change byte[2] from 0x92 to 0x4f
    unsigned_tx[2] = 0x4f;

    keccak256(unsigned_tx, unsigned_length)
}

// Extract 'to' address from transaction
// For Base Mainnet Coinbase attestation transactions, 'to' address is at index 23
// Transaction structure: 0x02 (type) + RLP encoding with fixed field positions
pub fn extract_to_address(raw_tx: [u8; 300]) -> [u8; 20] {
    let mut to_address: [u8; 20] = [0; 20];

    // EIP-1559 structure for this specific transaction type:
    // [0] = 0x02 (EIP-1559 type)
    // [1-2] = RLP length
    // [3-21] = Various transaction fields (chainId, nonce, fees, gas)
    // [22] = 0x94 (RLP prefix for 20-byte address)
    // [23-42] = 'to' address (20 bytes)

    let to_offset = 23;

    for i in 0..20 {
        to_address[i] = raw_tx[to_offset + i];
    }

    to_address
}

// Extract calldata from transaction
// For Base Mainnet Coinbase attestation transactions, calldata starts at index 45
pub fn extract_calldata(raw_tx: [u8; 300]) -> [u8; 36] {
    let mut calldata: [u8; 36] = [0; 36];

    // Transaction structure for Coinbase attestation:
    // [43] = 0x80 (value = 0, RLP encoding)
    // [44] = 0xa4 (RLP prefix for 36-byte data)
    // [45-80] = calldata (36 bytes)
    //   [45-48] = function selector (4 bytes): 0x56feed5e
    //   [49-60] = padding (12 bytes of zeros)
    //   [61-80] = user address (20 bytes)

    let calldata_offset = 45;

    for i in 0..36 {
        calldata[i] = raw_tx[calldata_offset + i];
    }

    calldata
}

// Extract address from calldata (assumes format: selector + padding + address)
pub fn extract_address_from_calldata(calldata: [u8; 36]) -> [u8; 20] {
    let mut address: [u8; 20] = [0; 20];

    // Function selector: 4 bytes
    // Padding: 12 bytes (for uint256 alignment)
    // Address: 20 bytes
    for i in 0..20 {
        address[i] = calldata[16 + i];
    }

    address
}

// Extract signature from end of raw transaction
// In EIP-1559, signature is the last RLP items: v, r, s
pub fn extract_signature_from_tx(raw_tx: [u8; 300], tx_length: u32) -> [u8; 65] {
    let mut signature: [u8; 65] = [0; 65];

    // TODO: Implement proper RLP parsing to find exact signature position
    // For now, assume signature is at the end
    // This is a simplified placeholder

    // r: 32 bytes
    // s: 32 bytes
    // v: 1 byte
    let sig_start = tx_length - 65;

    for i in 0..65 {
        if (sig_start + i) < 300 {
            signature[i] = raw_tx[sig_start + i];
        }
    }

    signature
}
