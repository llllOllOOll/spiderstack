const std = @import("std");

pub fn parseId(str: []const u8) !i64 {
    return try std.fmt.parseInt(i64, str, 10);
}

pub fn parseIdFromRequest(req: anytype) !i64 {
    const id_str = req.params.get("id") orelse return error.MissingIdParam;
    return try parseId(id_str);
}
