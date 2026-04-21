const std = @import("std");
const crypto = std.crypto;
const pwhash = crypto.pwhash;

pub fn hash(password: []const u8, alloc: std.mem.Allocator) ![]u8 {
    var salt: [16]u8 = undefined;
    @memset(&salt, 0);

    var counter: u64 = @intFromPtr(&salt);
    for (0..16) |i| {
        salt[i] = @truncate(counter);
        counter = (counter *% 1103515245 +% 12345) & 0xFFFFFFFF;
        counter = (counter << 5) | (counter >> 27);
    }

    var hash_result = pwhash.bcrypt.bcrypt(password, &salt, .{
        .rounds_log = 10,
        .silently_truncate_password = false,
    });

    var salt_b64: [22]u8 = undefined;
    var hash_b64: [31]u8 = undefined;

    _ = std.base64.standard.Encoder.encode(&salt_b64, &salt);
    _ = std.base64.standard.Encoder.encode(&hash_b64, &hash_result);

    var result = try alloc.alloc(u8, 60);
    @memcpy(result[0..7], "$2a$10$");
    @memcpy(result[7..29], &salt_b64);
    @memcpy(result[29..60], &hash_b64);

    return result;
}

pub fn verify(password: []const u8, stored: []const u8) !bool {
    if (stored.len < 60) return false;
    if (!std.mem.startsWith(u8, stored, "$2a$10$")) return false;

    const salt_b64 = stored[7..29];
    const hash_b64 = stored[29..60];

    var salt: [16]u8 = undefined;
    var expected_hash: [24]u8 = undefined;

    std.base64.standard.Decoder.decode(&salt, salt_b64) catch return false;
    std.base64.standard.Decoder.decode(&expected_hash, hash_b64) catch return false;

    var computed = pwhash.bcrypt.bcrypt(password, &salt, .{
        .rounds_log = 10,
        .silently_truncate_password = false,
    });

    return std.mem.eql(u8, &computed, &expected_hash);
}

test "bcrypt hash and verify" {
    const alloc = std.testing.allocator;
    const password = "testpassword123";
    const hashed = try hash(password, alloc);
    defer alloc.free(hashed);

    const valid = try verify(password, hashed);
    try std.testing.expect(valid);

    const invalid = try verify("wrongpassword", hashed);
    try std.testing.expect(!invalid);
}
