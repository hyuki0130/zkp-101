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

// Point doubling
pub unconstrained fn point_double_unconstrained(p: Point) -> Point {
    let mut result = p;

    if !p.is_infinity {
        let three = Secp256k1_Fq::one().__add(Secp256k1_Fq::one()).__add(Secp256k1_Fq::one());
        let two = Secp256k1_Fq::one().__add(Secp256k1_Fq::one());

        // s = (3 * x^2) / (2 * y)
        let x_squared = p.x.__mul(p.x);
        let numerator = three.__mul(x_squared);
        let denominator = two.__mul(p.y);
        let s = numerator.__div(denominator);

        // x3 = s^2 - 2*x
        let s_squared = s.__mul(s);
        let two_x = two.__mul(p.x);
        let x3 = s_squared.__sub(two_x);

        // y3 = s * (x - x3) - y
        let x_diff = p.x.__sub(x3);
        let s_x_diff = s.__mul(x_diff);
        let y3 = s_x_diff.__sub(p.y);

        result = Point { x: x3, y: y3, is_infinity: false };
    }

    result
}

// Point addition
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
            // s = (y2 - y1) / (x2 - x1)
            let y_diff = p2.y.__sub(p1.y);
            let x_diff = p2.x.__sub(p1.x);
            let s = y_diff.__div(x_diff);

            // x3 = s^2 - x1 - x2
            let s_squared = s.__mul(s);
            let x3_temp = s_squared.__sub(p1.x);
            let x3 = x3_temp.__sub(p2.x);

            // y3 = s * (x1 - x3) - y1
            let x_diff2 = p1.x.__sub(x3);
            let s_x_diff = s.__mul(x_diff2);
            let y3 = s_x_diff.__sub(p1.y);

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
pub unconstrained fn point_mul_unconstrained(scalar_bytes: [u8; 32], point: Point) -> Point {
    let mut result = point_infinity();
    let mut temp = point;

    // Iterate through each bit of the scalar (little-endian)
    for byte_idx in 0..32 {
        let byte = scalar_bytes[31 - byte_idx];
        for bit_idx in 0..8 {
            let bit = (byte >> bit_idx) & 1;

            if bit == 1 {
                result = point_add_unconstrained(result, temp);
            }
            temp = point_double_unconstrained(temp);
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
