pub const User = struct {
    id: i32,
    email: []const u8,
    name: []const u8,
    google_id: ?[]const u8,
    avatar_url: ?[]const u8,
    created_at: []const u8,
    locale: []const u8,
    locale_set: bool,
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

pub const CreateUserInput = struct {
    email: []const u8,
    name: []const u8,
    google_id: ?[]const u8 = null,
    avatar_url: ?[]const u8 = null,
};
