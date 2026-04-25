const std = @import("std");
const spider = @import("spider");
const model = @import("model.zig");
const mod = @import("mod.zig");

const http_client = spider.http_client;

fn tmdbClient(io: std.Io, allocator: std.mem.Allocator) http_client.Client {
    const config = mod.getTmdbConfig();

    return http_client.Client.init(io, allocator, .{
        .base_url = config.base_url,
        .headers = &.{
            .{ .name = "Accept", .value = "application/json" },
        },
    });
}

pub fn searchMovies(allocator: std.mem.Allocator, io: std.Io, query: []const u8) !model.MovieSearchResult {
    const config = mod.getTmdbConfig();
    var client = tmdbClient(io, allocator);
    var res = try client.get("/search/movie", .{
        .query = &.{
            .{ "query", query },
            .{ "api_key", config.api_key },
        },
    });
    defer res.deinit();

    const parsed = try res.json(struct {
        page: u32,
        results: []model.Movie,
        total_pages: u32,
        total_results: u32,
    });

    return model.MovieSearchResult{
        .page = parsed.value.page,
        .results = parsed.value.results,
        .total_pages = parsed.value.total_pages,
        .total_results = parsed.value.total_results,
    };
}

pub fn getPopularMovies(allocator: std.mem.Allocator, io: std.Io) !model.MovieListResult {
    const config = mod.getTmdbConfig();
    var client = tmdbClient(io, allocator);
    var res = try client.get("/movie/popular", .{
        .query = &.{.{ "api_key", config.api_key }},
    });
    defer res.deinit();

    const parsed = try res.json(struct {
        page: u32,
        results: []model.Movie,
        total_pages: u32,
        total_results: u32,
    });

    return model.MovieListResult{
        .page = parsed.value.page,
        .results = parsed.value.results,
        .total_pages = parsed.value.total_pages,
        .total_results = parsed.value.total_results,
    };
}

pub fn getMovieDetails(allocator: std.mem.Allocator, io: std.Io, movie_id: u32) !model.MovieDetails {
    const config = mod.getTmdbConfig();
    var client = tmdbClient(io, allocator);

    // convert movie_id to string for URL param
    var id_buf: [20]u8 = undefined;
    const id_str = std.fmt.bufPrint(&id_buf, "{d}", .{movie_id}) catch unreachable;

    var res = try client.get("/movie/:id", .{
        .params = &.{.{ "id", id_str }},
        .query = &.{.{ "api_key", config.api_key }},
    });
    defer res.deinit();

    const parsed = try res.json(model.MovieDetails);
    // No defer parsed.deinit() - caller owns the memory

    return parsed.value;
}
