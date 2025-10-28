// EC Public Key Recovery from ECDSA Signature
// Recovers the public key from an ECDSA signature using the ECRecover algorithm

use crate::secp256k1;
use crate::bignum_lib::Secp256k1_Fq;
use crate::bignum_lib::Secp256k1_Fr;
use crate::bignum_lib::BigNum;

/// Recovers a public key from an ECDSA signature
///
/// Uses Jacobian projective coordinates for efficient scalar multiplication,
/// then verifies the result with constrained ECDSA signature verification
///
/// # Arguments
/// * `message_hash` - The hash of the signed message (32 bytes)
/// * `v` - Recovery id (0, 1, 27, or 28)
/// * `r_bytes` - Signature r component (32 bytes)
/// * `s_bytes` - Signature s component (32 bytes)
///
/// # Returns
/// Tuple of (pubkey_x, pubkey_y) as byte arrays
pub fn ecrecover(
    message_hash: [u8; 32],
    v: u8,
    r_bytes: [u8; 32],
    s_bytes: [u8; 32]
) -> ([u8; 32], [u8; 32]) {
    // Recover pubkey using unconstrained elliptic curve operations
    // Safety: The recovered pubkey is verified by ECDSA signature verification below
    let (pubkey_x, pubkey_y) = unsafe {
        ecrecover_unconstrained(message_hash, v, r_bytes, s_bytes)
    };

    // Verify the recovered public key with constrained ECDSA verification
    let mut signature: [u8; 64] = [0; 64];
    for i in 0..32 {
        signature[i] = r_bytes[i];
        signature[32 + i] = s_bytes[i];
    }

    let is_valid = std::ecdsa_secp256k1::verify_signature(
        pubkey_x,
        pubkey_y,
        signature,
        message_hash
    );

    assert(is_valid);

    (pubkey_x, pubkey_y)
}

/// Unconstrained ECRecover implementation using Jacobian coordinates
/// Algorithm: pubkey = r^(-1) * (s*R - e*G)
unconstrained fn ecrecover_unconstrained(
    message_hash: [u8; 32],
    v: u8,
    r_bytes: [u8; 32],
    s_bytes: [u8; 32]
) -> ([u8; 32], [u8; 32]) {
    // Determine recovery id (v can be 0, 1 or 27, 28)
    let recovery_id = if v >= 27 { v - 27 } else { v };
    let is_y_odd = (recovery_id % 2) == 1;

    // Recover R point from r coordinate
    let r_x = Secp256k1_Fq::from_be_bytes(r_bytes);
    let r_y = secp256k1::recover_y(r_x, is_y_odd);

    let mut temp_point = secp256k1::Point {
        x: r_x,
        y: r_y,
        is_infinity: false,
    };

    // Calculate s * R
    temp_point = secp256k1::point_mul_jacobian(s_bytes, temp_point);

    // Calculate e * G
    let e_g = secp256k1::point_mul_jacobian(message_hash, secp256k1::generator());

    // Calculate s*R - e*G
    temp_point = secp256k1::point_sub_unconstrained(temp_point, e_g);

    // Calculate r^(-1) mod n
    let r_inv_bytes: [u8; 32] = Secp256k1_Fr::from_be_bytes(r_bytes).__invmod().to_be_bytes();

    // Calculate pubkey = r^(-1) * (s*R - e*G)
    temp_point = secp256k1::point_mul_jacobian(r_inv_bytes, temp_point);

    (temp_point.x.to_be_bytes(), temp_point.y.to_be_bytes())
}

/// Extracts signature components from a 65-byte signature
/// Format: r (32 bytes) + s (32 bytes) + v (1 byte)
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
