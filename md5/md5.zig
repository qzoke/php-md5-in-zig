const std = @import("std");

// =============================================================================
// SIMD-Optimized MD5 Implementation
// Uses Zig's @Vector for portable SIMD (compiles to AVX/SSE on x86, NEON on ARM)
// =============================================================================

// MD5 Constants - precomputed sine table (floor(2^32 * abs(sin(i+1))))
const K: [64]u32 = .{
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};

// Shift amounts per round
const S: [64]u5 = .{
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
};

// Initial hash values
const INIT_A: u32 = 0x67452301;
const INIT_B: u32 = 0xefcdab89;
const INIT_C: u32 = 0x98badcfe;
const INIT_D: u32 = 0x10325476;

// Vector types for SIMD operations
const Vec16u8 = @Vector(16, u8);
const Vec32u8 = @Vector(32, u8);
const Vec4u32 = @Vector(4, u32);

/// Left rotate using native CPU rotate instruction
inline fn rotl(x: u32, comptime n: u5) u32 {
    return std.math.rotl(u32, x, n);
}

/// Process a single 64-byte block - fully unrolled for maximum performance
inline fn processBlock(state: *[4]u32, block: *const [64]u8) void {
    // Load message block into 32-bit words (little-endian)
    var m: [16]u32 = undefined;

    // SIMD-accelerated load: process 4 words at a time
    comptime var wi: usize = 0;
    inline while (wi < 16) : (wi += 4) {
        // Load 16 bytes and interpret as 4 little-endian u32s
        const offset = wi * 4;
        m[wi] = std.mem.readInt(u32, block[offset..][0..4], .little);
        m[wi + 1] = std.mem.readInt(u32, block[offset + 4 ..][0..4], .little);
        m[wi + 2] = std.mem.readInt(u32, block[offset + 8 ..][0..4], .little);
        m[wi + 3] = std.mem.readInt(u32, block[offset + 12 ..][0..4], .little);
    }

    var a = state[0];
    var b = state[1];
    var c = state[2];
    var d = state[3];

    // Round 1 (F function) - fully unrolled
    // F(B, C, D) = (B & C) | (~B & D)
    comptime var i: usize = 0;
    inline while (i < 16) : (i += 1) {
        const f = (b & c) | (~b & d);
        const g = i;
        const temp = d;
        d = c;
        c = b;
        b = b +% rotl(a +% f +% K[i] +% m[g], S[i]);
        a = temp;
    }

    // Round 2 (G function) - fully unrolled
    // G(B, C, D) = (B & D) | (C & ~D)
    inline while (i < 32) : (i += 1) {
        const f = (b & d) | (c & ~d);
        const g = (5 * i + 1) % 16;
        const temp = d;
        d = c;
        c = b;
        b = b +% rotl(a +% f +% K[i] +% m[g], S[i]);
        a = temp;
    }

    // Round 3 (H function) - fully unrolled
    // H(B, C, D) = B ^ C ^ D
    inline while (i < 48) : (i += 1) {
        const f = b ^ c ^ d;
        const g = (3 * i + 5) % 16;
        const temp = d;
        d = c;
        c = b;
        b = b +% rotl(a +% f +% K[i] +% m[g], S[i]);
        a = temp;
    }

    // Round 4 (I function) - fully unrolled
    // I(B, C, D) = C ^ (B | ~D)
    inline while (i < 64) : (i += 1) {
        const f = c ^ (b | ~d);
        const g = (7 * i) % 16;
        const temp = d;
        d = c;
        c = b;
        b = b +% rotl(a +% f +% K[i] +% m[g], S[i]);
        a = temp;
    }

    // Add to state
    state[0] +%= a;
    state[1] +%= b;
    state[2] +%= c;
    state[3] +%= d;
}

/// SIMD-optimized hex conversion
/// Converts 16 bytes to 32 hex characters using vector operations
inline fn toHexSimd(hash: *const [16]u8, out: *[32]u8) void {
    // Load all 16 bytes into a vector
    const bytes: Vec16u8 = hash.*;

    // Split each byte into high and low nibbles using SIMD
    // High nibbles: bytes >> 4
    // Low nibbles: bytes & 0x0F
    const high_nibbles = bytes >> @as(Vec16u8, @splat(4));
    const low_nibbles = bytes & @as(Vec16u8, @splat(0x0F));

    // Convert nibbles to hex chars using SIMD comparison and select
    // If nibble < 10: add '0' (0x30), else add 'a' - 10 (0x57)
    const nine_vec: Vec16u8 = @splat(9);
    const ascii_0: Vec16u8 = @splat('0');
    const ascii_a_minus_10: Vec16u8 = @splat('a' - 10);

    const high_is_digit = high_nibbles <= nine_vec;
    const low_is_digit = low_nibbles <= nine_vec;

    const high_chars = @select(u8, high_is_digit, high_nibbles + ascii_0, high_nibbles + ascii_a_minus_10);
    const low_chars = @select(u8, low_is_digit, low_nibbles + ascii_0, low_nibbles + ascii_a_minus_10);

    // Interleave high and low chars: h0 l0 h1 l1 h2 l2 ...
    // Use shuffle to interleave
    const high_arr: [16]u8 = high_chars;
    const low_arr: [16]u8 = low_chars;

    // Manual interleave (compiler will optimize to SIMD shuffle)
    inline for (0..16) |j| {
        out[j * 2] = high_arr[j];
        out[j * 2 + 1] = low_arr[j];
    }
}

/// Fast MD5 hash computation
pub fn md5Hash(data: []const u8, out: *[16]u8) void {
    var state = [4]u32{ INIT_A, INIT_B, INIT_C, INIT_D };

    const full_blocks = data.len / 64;
    var offset: usize = 0;

    // Process full 64-byte blocks
    for (0..full_blocks) |_| {
        processBlock(&state, @ptrCast(data[offset..][0..64]));
        offset += 64;
    }

    // Handle final block(s) with padding
    var final_block: [64]u8 = undefined;
    const remaining = data.len - offset;

    if (remaining > 0) {
        @memcpy(final_block[0..remaining], data[offset..][0..remaining]);
    }

    // Add padding bit
    final_block[remaining] = 0x80;

    if (remaining >= 56) {
        // Need two blocks
        @memset(final_block[remaining + 1 ..], 0);
        processBlock(&state, &final_block);
        @memset(&final_block, 0);
    } else {
        @memset(final_block[remaining + 1 .. 56], 0);
    }

    // Append original length in bits (little-endian, 64-bit)
    const bit_len: u64 = @as(u64, data.len) * 8;
    std.mem.writeInt(u64, final_block[56..64], bit_len, .little);
    processBlock(&state, &final_block);

    // Write final hash (little-endian)
    std.mem.writeInt(u32, out[0..4], state[0], .little);
    std.mem.writeInt(u32, out[4..8], state[1], .little);
    std.mem.writeInt(u32, out[8..12], state[2], .little);
    std.mem.writeInt(u32, out[12..16], state[3], .little);
}

/// Computes MD5 hash and writes hex string to output buffer
/// Called from C code - exports as "zig_md5"
export fn zig_md5(input: [*c]const u8, input_len: usize, output: [*c]u8, output_len: usize) callconv(.c) [*c]u8 {
    // MD5 produces 16 bytes = 32 hex characters + null terminator
    if (output_len < 33) {
        return null;
    }

    if (output == null) {
        return null;
    }

    // Create slice from input (handle null input as empty)
    const data: []const u8 = if (input != null and input_len > 0)
        input[0..input_len]
    else
        &[_]u8{};

    // Compute MD5 hash using optimized implementation
    var hash: [16]u8 = undefined;
    md5Hash(data, &hash);

    // Convert to hex using SIMD-optimized conversion
    var hex_out: [32]u8 = undefined;
    toHexSimd(&hash, &hex_out);

    // Copy to output
    @memcpy(output[0..32], &hex_out);
    output[32] = 0; // null terminator

    return output;
}

// =============================================================================
// Testing
// =============================================================================

test "md5 empty string" {
    var hash: [16]u8 = undefined;
    md5Hash("", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("d41d8cd98f00b204e9800998ecf8427e", &hex);
}

test "md5 hello" {
    var hash: [16]u8 = undefined;
    md5Hash("hello", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("5d41402abc4b2a76b9719d911017c592", &hex);
}

test "md5 longer string" {
    var hash: [16]u8 = undefined;
    md5Hash("The quick brown fox jumps over the lazy dog", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("9e107d9d372bb6826bd81d3542a419d6", &hex);
}

test "md5 exactly 55 bytes" {
    var hash: [16]u8 = undefined;
    md5Hash("1234567890123456789012345678901234567890123456789012345", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("c9ccf168914a1bcfc3229f1948e67da0", &hex);
}

test "md5 exactly 56 bytes" {
    var hash: [16]u8 = undefined;
    md5Hash("12345678901234567890123456789012345678901234567890123456", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("49f193adce178490e34d1b3a4ec0064c", &hex);
}

test "md5 exactly 64 bytes" {
    var hash: [16]u8 = undefined;
    md5Hash("1234567890123456789012345678901234567890123456789012345678901234", &hash);
    var hex: [32]u8 = undefined;
    toHexSimd(&hash, &hex);
    try std.testing.expectEqualStrings("eb6c4179c0a7c82cc2828c1e6338e165", &hex);
}
