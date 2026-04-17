const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

pub fn findByGoogleId(alloc: std.mem.Allocator, google_id: []const u8) !?model.User {
    const sql = "SELECT id, email, name, google_id, avatar_url, created_at, locale, locale_set FROM users WHERE google_id = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{google_id});
    return result;
}

pub fn findByEmail(alloc: std.mem.Allocator, email: []const u8) !?model.User {
    const sql = "SELECT id, email, name, google_id, avatar_url, created_at, locale, locale_set FROM users WHERE email = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{email});
    return result;
}

pub fn findById(alloc: std.mem.Allocator, id: i64) !?model.User {
    const sql = "SELECT id, email, name, google_id, avatar_url, created_at, locale, locale_set FROM users WHERE id = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{id});
    return result;
}

pub fn createOAuthUser(alloc: std.mem.Allocator, email: []const u8, name: []const u8, google_id: []const u8, avatar_url: ?[]const u8) !model.User {
    const sql = "INSERT INTO users (email, name, google_id, avatar_url, locale, locale_set) VALUES ($1, $2, $3, $4, 'pt_BR', false) RETURNING id, email, name, google_id, avatar_url, created_at, locale, locale_set";
    const result = try db.queryOne(model.User, alloc, sql, .{ email, name, google_id, avatar_url });
    return result orelse error.UserCreationFailed;
}

pub fn updateUser(alloc: std.mem.Allocator, user_id: i64, updates: struct {
    name: ?[]const u8 = null,
    google_id: ?[]const u8 = null,
    avatar_url: ?[]const u8 = null,
    locale: ?[]const u8 = null,
    locale_set: ?bool = null,
}) !model.User {
    const current = try findById(alloc, user_id) orelse error.UserNotFound;

    const current_user = try current;

    const new_name = if (updates.name) |n| try alloc.dupe(u8, n) else try alloc.dupe(u8, current_user.name);
    errdefer alloc.free(new_name);

    const new_google_id = if (updates.google_id) |g| try alloc.dupe(u8, g) else if (current_user.google_id) |g| try alloc.dupe(u8, g) else "";
    errdefer alloc.free(new_google_id);

    const new_avatar_url = if (updates.avatar_url) |a| try alloc.dupe(u8, a) else if (current_user.avatar_url) |a| try alloc.dupe(u8, a) else "";
    errdefer alloc.free(new_avatar_url);

    const new_locale = if (updates.locale) |l| try alloc.dupe(u8, l) else try alloc.dupe(u8, current_user.locale);
    errdefer alloc.free(new_locale);

    const new_locale_set = updates.locale_set orelse current_user.locale_set;

    const sql = "UPDATE users SET name = $1, google_id = $2, avatar_url = $3, locale = $4, locale_set = $5 WHERE id = $6";

    _ = try db.query(void, alloc, sql, .{ new_name, new_google_id, new_avatar_url, new_locale, new_locale_set, user_id });

    return model.User{
        .id = user_id,
        .email = try alloc.dupe(u8, current_user.email),
        .name = new_name,
        .google_id = if (new_google_id.len > 0) new_google_id else null,
        .avatar_url = if (new_avatar_url.len > 0) new_avatar_url else null,
        .created_at = try alloc.dupe(u8, current_user.created_at),
        .locale = new_locale,
        .locale_set = new_locale_set,
    };
}
