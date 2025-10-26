// Simple Address Ownership Proof
// 목표: 사용자가 주소의 실제 소유자임을 증명

use dep::std;

// Helper: Concatenate public key coordinates (x || y)
fn concat_pubkey(pubkey_x: [u8; 32], pubkey_y: [u8; 32]) -> [u8; 64] {
    let mut out: [u8; 64] = [0; 64];
    for i in 0..32 {
        out[i] = pubkey_x[i];
        out[i + 32] = pubkey_y[i];
    }
    out
}

fn main(
    // ============ Public Inputs ============
    user_address: pub [u8; 20],         // 공개: 유저 주소

    // ============ Private Inputs ============
    user_signature: [u8; 64],           // 비공개: 서명 (r || s)
    user_pubkey_x: [u8; 32],            // 비공개: 공개키 X
    user_pubkey_y: [u8; 32],            // 비공개: 공개키 Y
) {
    // ===================================================================
    // Step 1: 메시지 생성 (calldata)
    // ===================================================================

    // 간단한 메시지: "I own this address: <user_address>"
    let message_prefix: [u8; 23] = [
        0x49, 0x20, 0x6f, 0x77, 0x6e, 0x20, 0x74, 0x68,  // "I own th"
        0x69, 0x73, 0x20, 0x61, 0x64, 0x64, 0x72, 0x65,  // "is addre"
        0x73, 0x73, 0x3a, 0x20, 0x30, 0x78,              // "ss: 0x"
    ];

    // 전체 메시지: prefix + user_address
    let mut message: [u8; 43] = [0; 43];
    for i in 0..23 {
        message[i] = message_prefix[i];
    }
    for i in 0..20 {
        message[23 + i] = user_address[i];
    }

    // 메시지 해싱
    let message_hash = std::hash::keccak256(message, 43);

    // ===================================================================
    // Step 2: Ethereum Personal Sign 형식으로 변환
    // ===================================================================

    // Ethereum Personal Sign Prefix: "\x19Ethereum Signed Message:\n32"
    let eth_prefix: [u8; 28] = [
        0x19, 0x45, 0x74, 0x68, 0x65, 0x72, 0x65, 0x75,  // "\x19Ethereum"
        0x6d, 0x20, 0x53, 0x69, 0x67, 0x6e, 0x65, 0x64,  // " Signed"
        0x20, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65,  // " Message"
        0x3a, 0x0a, 0x33, 0x32                            // ":\n32"
    ];

    let mut eth_message: [u8; 60] = [0; 60];
    for i in 0..28 {
        eth_message[i] = eth_prefix[i];
    }
    for i in 0..32 {
        eth_message[28 + i] = message_hash[i];
    }

    // Ethereum Personal Sign 메시지 해싱
    let eth_message_hash = std::hash::keccak256(eth_message, 60);

    // ===================================================================
    // Step 3: ECDSA 서명 검증
    // ===================================================================

    let signature_valid = std::ecdsa_secp256k1::verify_signature(
        user_pubkey_x,
        user_pubkey_y,
        user_signature,
        eth_message_hash
    );

    assert(signature_valid, "Invalid signature");

    // ===================================================================
    // Step 4: 공개키로부터 주소 파생
    // ===================================================================

    // 공개키 결합 (x || y)
    let pubkey_full = concat_pubkey(user_pubkey_x, user_pubkey_y);

    // Keccak256(pubkey)
    let pubkey_hash = std::hash::keccak256(pubkey_full, 64);

    // 주소 = 마지막 20 bytes
    let mut derived_address: [u8; 20] = [0; 20];
    for i in 0..20 {
        derived_address[i] = pubkey_hash[12 + i];
    }

    // ===================================================================
    // Step 5: 주소 일치 확인
    // ===================================================================

    assert(derived_address == user_address, "Public key does not match address");

    // ===================================================================
    // ✅ 증명 완료!
    //
    // 이 Proof는 다음을 보장합니다:
    // 1. user_address의 실제 소유자임 (private key 보유)
    // 2. 서명이 유효함
    // 3. 공개키가 주소와 일치함
    // ===================================================================
}
