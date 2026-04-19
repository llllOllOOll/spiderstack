pub const Todo = struct {
    id: i64,
    title: []const u8,
    completed: bool = false,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const CreateInput = struct {
    title: []const u8,
};

pub const UpdateInput = struct {
    title: ?[]const u8 = null,
    completed: ?bool = null,
};
