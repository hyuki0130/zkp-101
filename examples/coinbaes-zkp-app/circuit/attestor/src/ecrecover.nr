// EC Public Key Recovery from ECDSA Signature
// OPTIMIZATION Phase 12: Use Jacobian coordinates to eliminate ~1,152 inversions!
// Phase 11: Add constrained ECDSA verification
// Phase 12: Use Jacobian projective coordinates (KEY optimization!)

use crate::secp256k1;
use crate::bignum_lib::Secp256k1_Fq;
use crate::bignum_lib::Secp256k1_Fr;
use crate::bignum_lib::BigNum;

// ECRecover: Recover public key from ECDSA signature
// Algorithm: pubkey = r^(-1) * (s*R - e*G)
//
// OPTIMIZATION Phase 11: Add constrained ECDSA verification
// OPTIMIZATION Phase 12: Use Jacobian coordinates (GAME CHANGER!)
//   - Before: ~384 inversions per scalar multiplication x 3 = ~1,152 inversions
//   - After: 1 inversion per scalar multiplication x 3 = 3 inversions
//   - Expected reduction: ~41,500 opcodes (60% reduction!)
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
    // Step 1: Recover pubkey using unconstrained computation
    // Safety: ecrecover_unconstrained performs elliptic curve operations that are verified
    // by the constrained ECDSA signature verification below
    let (pubkey_x, pubkey_y) = unsafe {
        ecrecover_unconstrained(message_hash, v, r_bytes, s_bytes)
    };

    // Step 2: CONSTRAINED VERIFICATION using Noir's built-in ECDSA verify
    // This proves that (pubkey_x, pubkey_y) is the correct public key
    // by verifying the signature against the recovered public key
    let mut signature: [u8; 64] = [0; 64];
    for i in 0..32 {
        signature[i] = r_bytes[i];
        signature[32 + i] = s_bytes[i];
    }

    // Noir's built-in secp256k1 signature verification (CONSTRAINED)
    // This adds ACIR opcodes but removes Brillig memory pressure
    let is_valid = std::ecdsa_secp256k1::verify_signature(
        pubkey_x,
        pubkey_y,
        signature,
        message_hash
    );

    // Assert signature is valid with recovered pubkey
    assert(is_valid);

    (pubkey_x, pubkey_y)
}

// Unconstrained ecrecover implementation
// OPTIMIZATION Phase 12: Use Jacobian point_mul (CRITICAL!)
//   - Replaces point_mul_unconstrained with point_mul_jacobian
//   - Each point_mul now has only 1 inversion instead of ~384 inversions
//   - Total inversions: 1,152 -> 3 (99.7% reduction!)
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

    // Step 3: Calculate s * R using JACOBIAN coordinates (1 inversion only!)
    temp_point = secp256k1::point_mul_jacobian(s_bytes, temp_point);

    // Step 4: Calculate e * G using JACOBIAN coordinates (1 inversion only!)
    // OPTIMIZATION: Use generator directly without intermediate variable
    let e_g = secp256k1::point_mul_jacobian(message_hash, secp256k1::generator());

    // Step 5: Calculate s*R - e*G (reuse temp_point)
    temp_point = secp256k1::point_sub_unconstrained(temp_point, e_g);

    // Step 6: Calculate r^(-1) mod n
    // OPTIMIZATION: Inline scalar operations to avoid temporary storage
    let r_inv_bytes: [u8; 32] = Secp256k1_Fr::from_be_bytes(r_bytes).__invmod().to_be_bytes();

    // Step 7: Calculate pubkey = r^(-1) * (s*R - e*G) using JACOBIAN (1 inversion only!)
    temp_point = secp256k1::point_mul_jacobian(r_inv_bytes, temp_point);

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
