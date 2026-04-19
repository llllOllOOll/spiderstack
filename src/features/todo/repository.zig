const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

pub fn findAll(alloc: std.mem.Allocator) ![]model.Todo {
    const sql = "SELECT id, title, completed, created_at, updated_at FROM todos ORDER BY created_at DESC";
    return try db.query(model.Todo, alloc, sql, .{});
}

pub fn findById(alloc: std.mem.Allocator, id: i64) !?model.Todo {
    const sql = "SELECT id, title, completed, created_at, updated_at FROM todos WHERE id = $1 LIMIT 1";
    return try db.queryOne(model.Todo, alloc, sql, .{id});
}

pub fn create(alloc: std.mem.Allocator, input: model.CreateInput) !?model.Todo {
    const sql = "INSERT INTO todos (title) VALUES ($1) RETURNING id, title, completed, created_at, updated_at";
    return try db.queryOne(model.Todo, alloc, sql, .{input.title});
}

pub fn update(alloc: std.mem.Allocator, id: i64, updates: model.UpdateInput) !?model.Todo {
    const current = try findById(alloc, id) orelse return null;

    const new_title = if (updates.title) |t| t else current.title;
    const new_completed = updates.completed orelse current.completed;

    const sql = "UPDATE todos SET title = $1, completed = $2, updated_at = NOW() WHERE id = $3 RETURNING id, title, completed, created_at, updated_at";
    return try db.queryOne(model.Todo, alloc, sql, .{ new_title, new_completed, id });
}

pub fn delete(alloc: std.mem.Allocator, id: i64) !void {
    const sql = "DELETE FROM todos WHERE id = $1";
    _ = try db.query(void, alloc, sql, .{id});
}
