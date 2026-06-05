const std = @import("std");

/// Hashes a password using SHA256 and returns the hashed password as a hex string.
/// This is mainly for demo purposes. In a real world scenario, you should use a more secure
/// password hashing algorithm like Argon2, scrypt or bcrypt.
pub fn hash(
    alloc: std.mem.Allocator,
    password: []const u8,
) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(password, &digest, .{});

    return try std.fmt.allocPrint(
        alloc,
        "{x}",
        .{digest},
    );
}

pub fn verify(alloc: std.mem.Allocator, password: []const u8, stored: []const u8) !bool {
    const hashed_password = hash(alloc, password) catch |err| {
        std.log.err("pwd verify failed: {s}", .{@errorName(err)});
        return false;
    };
    return std.mem.eql(u8, hashed_password, stored);
}

test "bcrypt hash and verify" {
    const alloc = std.testing.allocator;
    const password = "testpassword123";
    const hashed = try hash(alloc, password);
    defer alloc.free(hashed);

    const valid = try verify(alloc, password, hashed);
    try std.testing.expect(valid);

    const invalid = try verify(alloc, "wrongpassword", hashed);
    try std.testing.expect(!invalid);
}
