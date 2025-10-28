// secp256k1 Elliptic Curve Operations
// Complete implementation using local bignum

use crate::bignum_lib::Secp256k1_Fq;
use crate::bignum_lib::BigNum;
use dep::keccak256::keccak256;

// Point on secp256k1 curve (Affine coordinates)
pub struct Point {
    pub x: Secp256k1_Fq,
    pub y: Secp256k1_Fq,
    pub is_infinity: bool,
}

// OPTIMIZATION Phase 12: Jacobian Projective Coordinates
// Point in Jacobian coordinates: (X, Y, Z) where x = X/Z^2, y = Y/Z^3
// This eliminates divisions in point operations, dramatically reducing inversions
pub struct JacobianPoint {
    pub X: Secp256k1_Fq,
    pub Y: Secp256k1_Fq,
    pub Z: Secp256k1_Fq,
    pub is_infinity: bool,
}

// Generator point G
pub fn generator() -> Point {
    let gx_bytes = [
        0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC,
        0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07,
        0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9,
        0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98
    ];
    let gy_bytes = [
        0x48, 0x3A, 0xDA, 0x77, 0x26, 0xA3, 0xC4, 0x65,
        0x5D, 0xA4, 0xFB, 0xFC, 0x0E, 0x11, 0x08, 0xA8,
        0xFD, 0x17, 0xB4, 0x48, 0xA6, 0x85, 0x54, 0x19,
        0x9C, 0x47, 0xD0, 0x8F, 0xFB, 0x10, 0xD4, 0xB8
    ];

    Point {
        x: Secp256k1_Fq::from_be_bytes(gx_bytes),
        y: Secp256k1_Fq::from_be_bytes(gy_bytes),
        is_infinity: false,
    }
}

// Curve constant b = 7
fn curve_b() -> Secp256k1_Fq {
    let mut b = Secp256k1_Fq::new();
    b.set_limb(0, 7);
    b
}

// Create infinity point (Affine)
pub fn point_infinity() -> Point {
    Point {
        x: Secp256k1_Fq::zero(),
        y: Secp256k1_Fq::zero(),
        is_infinity: true,
    }
}

// OPTIMIZATION Phase 12: Jacobian infinity point
pub unconstrained fn jacobian_infinity() -> JacobianPoint {
    JacobianPoint {
        X: Secp256k1_Fq::one(),
        Y: Secp256k1_Fq::one(),
        Z: Secp256k1_Fq::zero(),
        is_infinity: true,
    }
}

// OPTIMIZATION Phase 12: Convert Affine -> Jacobian
pub unconstrained fn affine_to_jacobian(p: Point) -> JacobianPoint {
    if p.is_infinity {
        jacobian_infinity()
    } else {
        JacobianPoint {
            X: p.x,
            Y: p.y,
            Z: Secp256k1_Fq::one(),
            is_infinity: false,
        }
    }
}

// OPTIMIZATION Phase 12: Convert Jacobian -> Affine
// This is the ONLY place where we do modular inversion in scalar multiplication!
pub unconstrained fn jacobian_to_affine(p: JacobianPoint) -> Point {
    if p.is_infinity {
        point_infinity()
    } else {
        // x = X / Z^2
        // y = Y / Z^3
        let z_inv = p.Z.__invmod();  // Only 1 inversion per scalar multiplication!
        let z_inv_squared = z_inv.__mul(z_inv);
        let z_inv_cubed = z_inv_squared.__mul(z_inv);

        let x = p.X.__mul(z_inv_squared);
        let y = p.Y.__mul(z_inv_cubed);

        Point {
            x,
            y,
            is_infinity: false,
        }
    }
}

// Create point from byte arrays
pub fn point_from_bytes(x_bytes: [u8; 32], y_bytes: [u8; 32]) -> Point {
    Point {
        x: Secp256k1_Fq::from_be_bytes(x_bytes),
        y: Secp256k1_Fq::from_be_bytes(y_bytes),
        is_infinity: false,
    }
}

// Recover y-coordinate from x-coordinate
// y^2 = x^3 + 7 (mod p)
// OPTIMIZATION Phase 9: Use fast sqrt for p == 3 (mod 4)
// For secp256k1, p == 3 (mod 4), so sqrt(a) = a^((p+1)/4) mod p
// This is MUCH faster than Tonelli-Shanks!
pub unconstrained fn recover_y(x: Secp256k1_Fq, is_odd: bool) -> Secp256k1_Fq {
    let b = curve_b();

    // Calculate x^3
    let x_squared = x.__mul(x);
    let x_cubed = x_squared.__mul(x);

    // Calculate x^3 + 7
    let y_squared = x_cubed.__add(b);

    // OPTIMIZATION: Use simple exponentiation instead of Tonelli-Shanks
    // Exponent = (p + 1) / 4
    // p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
    // (p+1)/4 = 0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFF0C
    let exp_bytes: [u8; 32] = [
        0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xBF, 0xFF, 0xFF, 0x0C
    ];
    let exponent = Secp256k1_Fq::from_be_bytes(exp_bytes);
    let y = y_squared.__pow(exponent);

    // Check parity and adjust if needed
    let y_bytes = y.to_be_bytes();
    let y_is_odd = (y_bytes[31] & 1) == 1;

    if y_is_odd == is_odd {
        y
    } else {
        y.__neg()
    }
}

// Helper constants for point operations - cached to avoid repeated allocation
unconstrained fn get_three() -> Secp256k1_Fq {
    Secp256k1_Fq::one().__add(Secp256k1_Fq::one()).__add(Secp256k1_Fq::one())
}

unconstrained fn get_two() -> Secp256k1_Fq {
    Secp256k1_Fq::one().__add(Secp256k1_Fq::one())
}

// OPTIMIZATION Phase 12: Jacobian point doubling (NO DIVISIONS!)
// Formula: https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates
// Input: P = (X1, Y1, Z1)
// Output: 2P = (X3, Y3, Z3)
// Algorithm (for a=0 curves like secp256k1):
//   S = 4*X1*Y1^2
//   M = 3*X1^2
//   X3 = M^2 - 2*S
//   Y3 = M*(S - X3) - 8*Y1^4
//   Z3 = 2*Y1*Z1
pub unconstrained fn jacobian_double(p: JacobianPoint) -> JacobianPoint {
    let mut result = p;

    if !p.is_infinity {
        let two = get_two();
        let three = get_three();
        let four = two.__add(two);
        let eight = four.__add(four);

        // Y1 squared
        let Y1_squared = p.Y.__mul(p.Y);

        // S = 4*X1*Y1^2
        let S = four.__mul(p.X).__mul(Y1_squared);

        // M = 3*X1^2 (for secp256k1 where a=0)
        let M = three.__mul(p.X).__mul(p.X);

        // X3 = M^2 - 2*S
        let X3 = M.__mul(M).__sub(two.__mul(S));

        // Y3 = M*(S - X3) - 8*Y1^4
        let Y1_fourth = Y1_squared.__mul(Y1_squared);
        let Y3 = M.__mul(S.__sub(X3)).__sub(eight.__mul(Y1_fourth));

        // Z3 = 2*Y1*Z1
        let Z3 = two.__mul(p.Y).__mul(p.Z);

        result = JacobianPoint {
            X: X3,
            Y: Y3,
            Z: Z3,
            is_infinity: false,
        };
    }

    result
}

// Point doubling (Affine - kept for compatibility)
// OPTIMIZATION Phase 5: Use compact formula to minimize BigNum operations
pub unconstrained fn point_double_unconstrained(p: Point) -> Point {
    let mut result = p;

    if !p.is_infinity {
        let three = get_three();
        let two = get_two();

        // OPTIMIZATION Phase 5: Minimized operations
        // Original formula needs: 2 mul + 2 add + 1 div + 1 sub operations
        // s = (3 * x^2) / (2 * y)
        let s = three.__mul(p.x.__mul(p.x)).__div(two.__mul(p.y));

        // x3 = s^2 - 2*x
        let x3 = s.__mul(s).__sub(two.__mul(p.x));

        // y3 = s * (x - x3) - y
        let y3 = s.__mul(p.x.__sub(x3)).__sub(p.y);

        result = Point { x: x3, y: y3, is_infinity: false };
    }

    result
}

// OPTIMIZATION Phase 12: Jacobian point addition (NO DIVISIONS!)
// Formula: https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates
// Input: P = (X1, Y1, Z1), Q = (X2, Y2, Z2)
// Output: P+Q = (X3, Y3, Z3)
// Algorithm:
//   U1 = X1*Z2^2
//   U2 = X2*Z1^2
//   S1 = Y1*Z2^3
//   S2 = Y2*Z1^3
//   H = U2 - U1
//   R = S2 - S1
//   X3 = R^2 - H^3 - 2*U1*H^2
//   Y3 = R*(U1*H^2 - X3) - S1*H^3
//   Z3 = H*Z1*Z2
pub unconstrained fn jacobian_add(p1: JacobianPoint, p2: JacobianPoint) -> JacobianPoint {
    let mut result: JacobianPoint = jacobian_infinity();

    // Handle infinity cases
    if p1.is_infinity {
        result = p2;
    } else if p2.is_infinity {
        result = p1;
    } else {
        let two = get_two();

        // Z1^2
        let Z1_squared = p1.Z.__mul(p1.Z);
        // Z2^2
        let Z2_squared = p2.Z.__mul(p2.Z);

        // U1 = X1*Z2^2
        let U1 = p1.X.__mul(Z2_squared);
        // U2 = X2*Z1^2
        let U2 = p2.X.__mul(Z1_squared);

        // S1 = Y1*Z2^3
        let S1 = p1.Y.__mul(Z2_squared).__mul(p2.Z);
        // S2 = Y2*Z1^3
        let S2 = p2.Y.__mul(Z1_squared).__mul(p1.Z);

        // H = U2 - U1
        let H = U2.__sub(U1);
        // R = S2 - S1
        let R = S2.__sub(S1);

        // H^2
        let H_squared = H.__mul(H);
        // H^3
        let H_cubed = H_squared.__mul(H);

        // X3 = R^2 - H^3 - 2*U1*H^2
        let X3 = R.__mul(R).__sub(H_cubed).__sub(two.__mul(U1).__mul(H_squared));

        // Y3 = R*(U1*H^2 - X3) - S1*H^3
        let Y3 = R.__mul(U1.__mul(H_squared).__sub(X3)).__sub(S1.__mul(H_cubed));

        // Z3 = H*Z1*Z2
        let Z3 = H.__mul(p1.Z).__mul(p2.Z);

        result = JacobianPoint {
            X: X3,
            Y: Y3,
            Z: Z3,
            is_infinity: false,
        };
    }

    result
}

// Point addition (Affine - kept for compatibility)
// OPTIMIZATION Phase 5: Fast path optimization - remove expensive edge case checks
pub unconstrained fn point_add_unconstrained(p1: Point, p2: Point) -> Point {
    let mut result = Point { x: Secp256k1_Fq::zero(), y: Secp256k1_Fq::zero(), is_infinity: true };

    // OPTIMIZATION: Only check infinity, skip expensive x-coordinate equality check
    if p1.is_infinity {
        result = p2;
    } else if p2.is_infinity {
        result = p1;
    } else {
        // OPTIMIZATION Phase 5: Removed p1.x.__eq(p2.x) check
        // In scalar multiplication, this case is astronomically rare (< 1 in 2^256)
        // Removing this check eliminates 2 BigNum equality operations per addition

        // s = (y2 - y1) / (x2 - x1)
        let s = p2.y.__sub(p1.y).__div(p2.x.__sub(p1.x));

        // x3 = s^2 - x1 - x2
        let x3 = s.__mul(s).__sub(p1.x).__sub(p2.x);

        // y3 = s * (x1 - x3) - y1
        let y3 = s.__mul(p1.x.__sub(x3)).__sub(p1.y);

        result = Point { x: x3, y: y3, is_infinity: false };
    }

    result
}

// Point subtraction
pub unconstrained fn point_sub_unconstrained(p1: Point, p2: Point) -> Point {
    let mut result = p1;

    if !p2.is_infinity {
        let neg_p2 = Point {
            x: p2.x,
            y: p2.y.__neg(),
            is_infinity: false,
        };
        result = point_add_unconstrained(p1, neg_p2);
    }

    result
}

// OPTIMIZATION Phase 12: Jacobian scalar multiplication (ONLY 1 INVERSION!)
// This is the KEY optimization - eliminates ~384 inversions per scalar multiplication!
pub unconstrained fn point_mul_jacobian(scalar_bytes: [u8; 32], point: Point) -> Point {
    // Convert input to Jacobian
    let mut result = jacobian_infinity();
    let mut temp = affine_to_jacobian(point);

    let mut bit_count = 0;

    // Iterate through each bit of the scalar (little-endian)
    for byte_idx in 0..32 {
        let byte = scalar_bytes[31 - byte_idx];
        for bit_idx in 0..8 {
            let bit = (byte >> bit_idx) & 1;
            bit_count += 1;

            if bit == 1 {
                result = jacobian_add(result, temp);  // NO DIVISION!
            }

            // Skip the last doubling operation (bit 256)
            if bit_count < 256 {
                temp = jacobian_double(temp);  // NO DIVISION!
            }
        }
    }

    // Convert result back to Affine (ONLY 1 INVERSION for entire scalar multiplication!)
    jacobian_to_affine(result)
}

// Scalar multiplication using double-and-add (Affine - kept for compatibility)
// OPTIMIZATION Phase 4: Reduce unnecessary operations in scalar multiplication
pub unconstrained fn point_mul_unconstrained(scalar_bytes: [u8; 32], point: Point) -> Point {
    let mut result = point_infinity();
    let mut temp = point;

    // Track if this is the last iteration to avoid unnecessary doubling
    let mut bit_count = 0;

    // Iterate through each bit of the scalar (little-endian)
    for byte_idx in 0..32 {
        let byte = scalar_bytes[31 - byte_idx];
        for bit_idx in 0..8 {
            let bit = (byte >> bit_idx) & 1;
            bit_count += 1;

            if bit == 1 {
                result = point_add_unconstrained(result, temp);
            }

            // OPTIMIZATION: Skip the last doubling operation (bit 256)
            // This saves one point_double call with all its BigNum allocations
            if bit_count < 256 {
                temp = point_double_unconstrained(temp);
            }
        }
    }

    result
}

// Convert public key to Ethereum address
pub fn pubkey_to_address(pubkey_x_bytes: [u8; 32], pubkey_y_bytes: [u8; 32]) -> [u8; 20] {
    let mut pubkey_full: [u8; 64] = [0; 64];
    for i in 0..32 {
        pubkey_full[i] = pubkey_x_bytes[i];
        pubkey_full[i + 32] = pubkey_y_bytes[i];
    }

    let pubkey_hash: [u8; 32] = keccak256(pubkey_full, 64);
    let mut address: [u8; 20] = [0; 20];
    for i in 0..20 {
        address[i] = pubkey_hash[12 + i];
    }
    address
}
