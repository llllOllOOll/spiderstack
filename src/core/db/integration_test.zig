// src/core/db/integration_test.zig
// zig build test-integration --summary all

const std = @import("std");
const spider = @import("spider");
const core = @import("core");

const db = spider.pg;

fn setupDb(arena: std.mem.Allocator) !void {
    spider.loadEnv(arena, ".env") catch {};
    try db.init(arena, std.testing.io, .{});
}

test "db: connection established" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try setupDb(arena.allocator());
    defer db.deinit();
}

test "db: migrations run successfully" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try setupDb(arena.allocator());
    defer db.deinit();

    try core.db.migrations.run(arena.allocator());
}

test "db: select from users table" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try setupDb(allocator);
    defer db.deinit();

    const User = struct { id: i32 };
    const result = try db.query(User, allocator, "SELECT id FROM users", .{});
    defer allocator.free(result);

    std.log.debug("users found: {d}", .{result.len});
    try std.testing.expect(result.len >= 0);
}
