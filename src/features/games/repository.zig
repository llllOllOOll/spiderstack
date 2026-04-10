const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

pub fn findAll(alloc: std.mem.Allocator) ![]model.Game {
    const sql = "SELECT id, name, platform, release_year, genre, developer, sales_millions, rating FROM games ORDER BY sales_millions DESC";
    return try db.query(model.Game, alloc, sql, .{});
}

pub fn findById(alloc: std.mem.Allocator, id: i32) !?model.Game {
    const sql = "SELECT id, name, platform, release_year, genre, developer, sales_millions, rating FROM games WHERE id = $1 LIMIT 1";
    return try db.queryOne(model.Game, alloc, sql, .{id});
}

pub fn create(alloc: std.mem.Allocator, input: model.CreateInput) !?model.Game {
    const sql = "INSERT INTO games (name, platform, release_year, genre, developer, sales_millions, rating) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, name, platform, release_year, genre, developer, sales_millions, rating";
    return try db.queryOne(model.Game, alloc, sql, .{ input.name, input.platform, input.release_year, input.genre, input.developer, input.sales_millions, input.rating });
}

pub fn update(alloc: std.mem.Allocator, id: i32, updates: model.UpdateInput) !?model.Game {
    const current = try findById(alloc, id) orelse return null;

    const new_name = if (updates.name) |n| n else current.name;
    const new_platform = if (updates.platform) |p| p else current.platform;
    const new_release_year = updates.release_year orelse current.release_year;
    const new_genre = if (updates.genre) |g| g else current.genre;
    const new_developer = if (updates.developer) |d| d else current.developer;
    const new_sales = if (updates.sales_millions) |s| s else current.sales_millions;
    const new_rating = if (updates.rating) |r| r else current.rating;

    const sql = "UPDATE games SET name = $1, platform = $2, release_year = $3, genre = $4, developer = $5, sales_millions = $6, rating = $7 WHERE id = $8 RETURNING id, name, platform, release_year, genre, developer, sales_millions, rating";
    return try db.queryOne(model.Game, alloc, sql, .{ new_name, new_platform, new_release_year, new_genre, new_developer, new_sales, new_rating, id });
}

pub fn delete(alloc: std.mem.Allocator, id: i32) !void {
    const sql = "DELETE FROM games WHERE id = $1";
    _ = try db.query(void, alloc, sql, .{id});
}
