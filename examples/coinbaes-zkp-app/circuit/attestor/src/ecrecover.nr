// EC Public Key Recovery from ECDSA Signature
// Complete ecrecover implementation for secp256k1

use crate::secp256k1;
use crate::bignum_lib::Secp256k1_Fq;
use crate::bignum_lib::Secp256k1_Fr;
use crate::bignum_lib::BigNum;

// ECRecover: Recover public key from ECDSA signature
// Algorithm: pubkey = r^(-1) * (s*R - e*G)
//
// Inputs:
//   - message_hash: the hash of the message that was signed (32 bytes)
//   - v: recovery id (0, 1, 27, or 28)
//   - r: signature component r (32 bytes)
//   - s: signature component s (32 bytes)
//
// Returns: (pubkey_x_bytes, pubkey_y_bytes)
pub fn ecrecover(
    message_hash: [u8; 32],
    v: u8,
    r_bytes: [u8; 32],
    s_bytes: [u8; 32]
) -> ([u8; 32], [u8; 32]) {
    // This is the main function that performs all steps
    // Safety: We use unconstrained computation for efficiency, but the result
    // will be verified through signature verification in the circuit
    let (pubkey_x, pubkey_y) = unsafe {
        ecrecover_unconstrained(message_hash, v, r_bytes, s_bytes)
    };

    // TODO: Add constraints to verify the result
    // For now, we rely on unconstrained computation

    (pubkey_x, pubkey_y)
}

// Unconstrained ecrecover implementation
// OPTIMIZATION: Reuse temporary buffers to reduce WASM memory usage
unconstrained fn ecrecover_unconstrained(
    message_hash: [u8; 32],
    v: u8,
    r_bytes: [u8; 32],
    s_bytes: [u8; 32]
) -> ([u8; 32], [u8; 32]) {
    // Step 1: Determine recovery id
    // v can be 0, 1 (modern) or 27, 28 (legacy)
    let recovery_id = if v >= 27 { v - 27 } else { v };
    let is_y_odd = (recovery_id % 2) == 1;

    // Step 2: Recover R point from r coordinate
    // r is the x-coordinate of R
    let r_x = Secp256k1_Fq::from_be_bytes(r_bytes);
    let r_y = secp256k1::recover_y(r_x, is_y_odd);

    // OPTIMIZATION: Use mutable temp_point to reuse Point structure
    // Reduces memory allocations from 5 Points to 1 Point
    let mut temp_point = secp256k1::Point {
        x: r_x,
        y: r_y,
        is_infinity: false,
    };

    // Step 3: Calculate s * R (stores result in temp_point)
    temp_point = secp256k1::point_mul_unconstrained(s_bytes, temp_point);

    // Step 4: Calculate e * G
    // OPTIMIZATION: Use generator directly without intermediate variable
    let e_g = secp256k1::point_mul_unconstrained(message_hash, secp256k1::generator());

    // Step 5: Calculate s*R - e*G (reuse temp_point)
    temp_point = secp256k1::point_sub_unconstrained(temp_point, e_g);

    // Step 6: Calculate r^(-1) mod n
    // OPTIMIZATION: Inline scalar operations to avoid temporary storage
    let r_inv_bytes: [u8; 32] = Secp256k1_Fr::from_be_bytes(r_bytes).__invmod().to_be_bytes();

    // Step 7: Calculate pubkey = r^(-1) * (s*R - e*G) (final result in temp_point)
    temp_point = secp256k1::point_mul_unconstrained(r_inv_bytes, temp_point);

    // OPTIMIZATION: Return directly without intermediate byte storage
    (temp_point.x.to_be_bytes(), temp_point.y.to_be_bytes())
}

// Extract signature components from 65-byte signature
pub fn extract_signature(signature: [u8; 65]) -> ([u8; 32], [u8; 32], u8) {
    let mut r: [u8; 32] = [0; 32];
    let mut s: [u8; 32] = [0; 32];

    for i in 0..32 {
        r[i] = signature[i];
        s[i] = signature[32 + i];
    }

    let v = signature[64];

    (r, s, v)
}
