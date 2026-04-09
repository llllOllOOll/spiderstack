pub const User = struct {
    id: i32,
    email: []const u8,
    password_hash: []const u8,
    name: []const u8,
    created_at: []const u8,
};

pub const CreateInput = struct {
    email: []const u8,
    password: []const u8,
    name: []const u8,
};

pub const LoginInput = struct {
    email: []const u8,
    password: []const u8,
};
