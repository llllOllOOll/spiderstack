pub const Game = struct {
    id: i64,
    name: []const u8,
    platform: []const u8,
    release_year: i32,
    genre: []const u8,
    developer: []const u8,
    sales_millions: f64,
    rating: f64,
};

pub const CreateInput = struct {
    name: []const u8,
    platform: []const u8,
    release_year: i32,
    genre: []const u8,
    developer: []const u8,
    sales_millions: f64,
    rating: f64,
};

pub const UpdateInput = struct {
    name: ?[]const u8 = null,
    platform: ?[]const u8 = null,
    release_year: ?i32 = null,
    genre: ?[]const u8 = null,
    developer: ?[]const u8 = null,
    sales_millions: ?f64 = null,
    rating: ?f64 = null,
};
