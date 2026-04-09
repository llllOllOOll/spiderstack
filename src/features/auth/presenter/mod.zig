const std = @import("std");

pub const LoginContext = struct {
    email: []const u8,
    error_msg: ?[]const u8,
};

pub fn buildLoginContext(alloc: std.mem.Allocator, email: []const u8, error_msg: ?[]const u8) !LoginContext {
    return .{
        .email = try alloc.dupe(u8, email),
        .error_msg = if (error_msg) |e| try alloc.dupe(u8, e) else null,
    };
}
