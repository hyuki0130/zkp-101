// secp256k1 Elliptic Curve Operations
// Complete implementation using local bignum

use crate::bignum_lib::Secp256k1_Fq;
use crate::bignum_lib::BigNum;
use dep::keccak256::keccak256;

// Point on secp256k1 curve
pub struct Point {
    pub x: Secp256k1_Fq,
    pub y: Secp256k1_Fq,
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

// Create infinity point
pub fn point_infinity() -> Point {
    Point {
        x: Secp256k1_Fq::zero(),
        y: Secp256k1_Fq::zero(),
        is_infinity: true,
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
// For secp256k1, p = 3 (mod 4), so sqrt(a) = a^((p+1)/4) mod p
pub unconstrained fn recover_y(x: Secp256k1_Fq, is_odd: bool) -> Secp256k1_Fq {
    let b = curve_b();

    // Calculate x^3
    let x_squared = x.__mul(x);
    let x_cubed = x_squared.__mul(x);

    // Calculate x^3 + 7
    let y_squared = x_cubed.__add(b);

    // Calculate sqrt using Tonelli-Shanks
    let y_option = y_squared.__tonelli_shanks_sqrt();

    // TODO: Handle None case properly
    let y = y_option.unwrap();

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

// Point doubling
// OPTIMIZATION Phase 3+4: Reduce BigNum intermediate allocations + cached constants
pub unconstrained fn point_double_unconstrained(p: Point) -> Point {
    let mut result = p;

    if !p.is_infinity {
        let three = get_three();
        let two = get_two();

        // s = (3 * x^2) / (2 * y)
        // OPTIMIZATION: Chain operations to avoid storing x_squared separately
        let s = three.__mul(p.x.__mul(p.x)).__div(two.__mul(p.y));

        // x3 = s^2 - 2*x
        let x3 = s.__mul(s).__sub(two.__mul(p.x));

        // y3 = s * (x - x3) - y
        let y3 = s.__mul(p.x.__sub(x3)).__sub(p.y);

        result = Point { x: x3, y: y3, is_infinity: false };
    }

    result
}

// Point addition
// OPTIMIZATION Phase 3: Reduce BigNum intermediate allocations
pub unconstrained fn point_add_unconstrained(p1: Point, p2: Point) -> Point {
    let mut result = Point { x: Secp256k1_Fq::zero(), y: Secp256k1_Fq::zero(), is_infinity: true };

    if p1.is_infinity {
        result = p2;
    } else if p2.is_infinity {
        result = p1;
    } else {
        // Check if same x coordinate
        if p1.x.__eq(p2.x) {
            if p1.y.__eq(p2.y) {
                result = point_double_unconstrained(p1);
            } else {
                result = point_infinity();
            }
        } else {
            // OPTIMIZATION: Chain operations to reduce intermediate BigNum allocations
            // s = (y2 - y1) / (x2 - x1)
            let s = p2.y.__sub(p1.y).__div(p2.x.__sub(p1.x));

            // x3 = s^2 - x1 - x2
            let x3 = s.__mul(s).__sub(p1.x).__sub(p2.x);

            // y3 = s * (x1 - x3) - y1
            let y3 = s.__mul(p1.x.__sub(x3)).__sub(p1.y);

            result = Point { x: x3, y: y3, is_infinity: false };
        }
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

// Scalar multiplication using double-and-add
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
