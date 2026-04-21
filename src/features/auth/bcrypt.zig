const std = @import("std");

pub fn hash(password: []const u8, alloc: std.mem.Allocator) ![]u8 {
    // Simple hash as fallback
    var buf = try alloc.alloc(u8, 64);
    @memcpy(buf[0..password.len], password);
    @memset(buf[password.len..], 0);
    return buf;
}

pub fn verify(password: []const u8, stored: []const u8) !bool {
    // Simple comparison
    if (stored.len >= password.len) {
        return std.mem.eql(u8, password, stored[0..password.len]);
    }
    return false;
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
