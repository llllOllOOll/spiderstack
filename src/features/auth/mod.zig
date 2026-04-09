pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const repository = @import("repository.zig");
pub const presenter = @import("presenter/mod.zig");
pub const controller = @import("controller.zig");

pub const index = controller.index;
pub const redirectToGoogle = controller.redirectToGoogle;
pub const googleCallback = controller.googleCallback;
pub const handleLogin = controller.handleLogin;
