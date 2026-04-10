pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const repository = @import("repository.zig");
pub const presenter = @import("presenter.zig");
pub const service = @import("service.zig");
pub const use_case = @import("use_case/index.zig");
pub const controller = @import("controller.zig");

const std = @import("std");
const google = spider.google;

pub fn getGoogleConfig() google.GoogleConfig {
    return .{
        .client_id = std.mem.span(std.c.getenv("GOOGLE_CLIENT_ID") orelse @panic("GOOGLE_CLIENT_ID not set")),
        .client_secret = std.mem.span(std.c.getenv("GOOGLE_CLIENT_SECRET") orelse @panic("GOOGLE_CLIENT_SECRET not set")),
        .redirect_uri = std.mem.span(std.c.getenv("GOOGLE_REDIRECT_URI") orelse "http://localhost:8080/auth/google/callback"),
    };
}

pub const index = controller.index;
pub const redirectToGoogle = controller.redirectToGoogle;
pub const googleCallback = controller.googleCallback;
pub const handleLogin = controller.handleLogin;
