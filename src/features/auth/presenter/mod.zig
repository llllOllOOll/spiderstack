const std = @import("std");
const i18n = @import("core").i18n;

pub const LoginContext = struct {
    email: []const u8,
    error_msg: ?[]const u8,
    google_auth_url: []const u8,
    google_button_text: []const u8,
};

pub fn buildLoginContext(alloc: std.mem.Allocator, email: []const u8, error_msg: ?[]const u8) !LoginContext {
    const google_auth_url = "/auth/google";
    const google_button_text = i18n.t(i18n.Locale.pt_BR, "login_google_button");

    return .{
        .email = try alloc.dupe(u8, email),
        .error_msg = if (error_msg) |e| try alloc.dupe(u8, e) else null,
        .google_auth_url = google_auth_url,
        .google_button_text = google_button_text,
    };
}
