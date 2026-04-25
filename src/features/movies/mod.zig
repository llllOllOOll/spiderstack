pub const spider = @import("spider");
pub const model = @import("model.zig");
pub const service = @import("service.zig");
pub const controller = @import("controller.zig");

const std = @import("std");

pub const TmdbConfig = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://api.themoviedb.org/3",
};

pub fn getTmdbConfig() TmdbConfig {
    return .{
        .api_key = std.mem.span(std.c.getenv("TMDB_API_KEY") orelse @panic("TMDB_API_KEY not set")),
        .base_url = std.mem.span(std.c.getenv("TMDB_BASE_URL") orelse "https://api.themoviedb.org/3"),
    };
}

pub const index = controller.index;
pub const search = controller.search;
pub const popular = controller.popular;
pub const movieDetails = controller.movieDetails;
