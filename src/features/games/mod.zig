pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const repository = @import("repository.zig");
pub const presenter = @import("presenter.zig");
pub const controller = @import("controller.zig");

pub const index = controller.index;
pub const handleCreate = controller.handleCreate;
pub const handleUpdate = controller.handleUpdate;
pub const handleDelete = controller.handleDelete;
