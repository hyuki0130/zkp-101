// BigInt arithmetic operations for secp256k1
// Handles 256-bit unsigned integer operations using constrained operations

// Helper: compare two byte arrays for equality
pub fn eq(a: [u8; 32], b: [u8; 32]) -> bool {
    let mut result = true;
    for i in 0..32 {
        if a[i] != b[i] {
            result = false;
        }
    }
    result
}

// Check if a number is zero
pub fn is_zero(a: [u8; 32]) -> bool {
    let mut result = true;
    for i in 0..32 {
        if a[i] != 0 {
            result = false;
        }
    }
    result
}
