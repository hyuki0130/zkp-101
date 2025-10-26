// Local bignum library - copied from noir-bignum to avoid dependency issues

pub mod bignum;
pub mod params;
pub mod constants;
pub(crate) mod fns;
pub(crate) mod utils;

// Re-export main types
pub use bignum::BigNum;
pub use bignum::derive_bignum;

// Re-export secp256k1 types
pub mod secp256k1Fq;
pub mod secp256k1Fr;

pub use secp256k1Fq::Secp256k1_Fq;
pub use secp256k1Fr::Secp256k1_Fr;
