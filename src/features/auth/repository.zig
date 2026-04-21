const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("model.zig");

pub const UserIdentity = struct {
    id: []const u8,
    user_uuid: []const u8,
    provider: []const u8,
    provider_user_id: ?[]const u8,
    password_hash: ?[]const u8,
    created_at: []const u8,
};

pub const Role = struct {
    id: []const u8,
    name: []const u8,
    description: ?[]const u8,
    is_default: bool,
};

pub fn findByUuid(alloc: std.mem.Allocator, user_uuid: []const u8) !?model.User {
    const sql = "SELECT id, uuid, email, name, google_id, avatar_url, created_at, locale, locale_set, tenant_id FROM users WHERE uuid = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{user_uuid});
    return result;
}

pub fn findByGoogleId(alloc: std.mem.Allocator, google_id: []const u8) !?model.User {
    const sql =
        \\SELECT u.id, u.uuid, u.email, u.name, u.google_id, u.avatar_url, u.created_at, u.locale, u.locale_set, u.tenant_id
        \\FROM users u
        \\JOIN user_identities ui ON ui.user_uuid = u.uuid
        \\WHERE ui.provider = 'google' AND ui.provider_user_id = $1
        \\LIMIT 1
    ;
    const result = try db.queryOne(model.User, alloc, sql, .{google_id});
    return result;
}

pub fn findByEmail(alloc: std.mem.Allocator, email: []const u8) !?model.User {
    const sql = "SELECT id, uuid, email, name, google_id, avatar_url, created_at, locale, locale_set, tenant_id FROM users WHERE email = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{email});
    return result;
}

pub fn findById(alloc: std.mem.Allocator, id: i64) !?model.User {
    const sql = "SELECT id, uuid, email, name, google_id, avatar_url, created_at, locale, locale_set, tenant_id FROM users WHERE id = $1 LIMIT 1";
    const result = try db.queryOne(model.User, alloc, sql, .{id});
    return result;
}

pub fn createOAuthUser(alloc: std.mem.Allocator, email: []const u8, name: []const u8, google_id: []const u8, avatar_url: ?[]const u8, locale: []const u8) !model.User {
    var tx = try db.begin();
    defer tx.rollback();

    const user_sql =
        \\INSERT INTO users (uuid, email, name, google_id, avatar_url, locale, locale_set)
        \\VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, false)
        \\RETURNING id, uuid, email, name, google_id, avatar_url, created_at, locale, locale_set, tenant_id
    ;
    const user_result = try tx.queryOne(model.User, alloc, user_sql, .{ email, name, google_id, avatar_url, locale });
    const created_user = user_result orelse return error.UserCreationFailed;

    const user_uuid = try alloc.dupe(u8, created_user.uuid);
    errdefer alloc.free(user_uuid);

    const identity_sql =
        \\INSERT INTO user_identities (user_uuid, provider, provider_user_id)
        \\VALUES ($1, 'google', $2)
    ;
    _ = try tx.query(void, alloc, identity_sql, .{ user_uuid, google_id });

    const default_role_sql = "SELECT id FROM roles WHERE is_default = true LIMIT 1";
    const role_result = try tx.queryOne(struct { id: []const u8 }, alloc, default_role_sql, .{});
    if (role_result) |role| {
        const user_role_sql = "INSERT INTO user_roles (user_uuid, role_id) VALUES ($1, $2)";
        _ = try tx.query(void, alloc, user_role_sql, .{ user_uuid, role.id });
    }

    try tx.commit();

    return created_user;
}

pub fn createEmailUser(alloc: std.mem.Allocator, email: []const u8, name: []const u8, password_hash: []const u8) !model.User {
    var tx = try db.begin();
    defer tx.rollback();

    const user_sql =
        \\INSERT INTO users (uuid, email, name, locale, locale_set)
        \\VALUES (gen_random_uuid(), $1, $2, 'pt_BR', false)
        \\RETURNING id, uuid, email, name, google_id, avatar_url, created_at, locale, locale_set, tenant_id
    ;
    const user_result = try tx.queryOne(model.User, alloc, user_sql, .{ email, name });
    const created_user = user_result orelse return error.UserCreationFailed;

    const user_uuid = try alloc.dupe(u8, created_user.uuid);
    errdefer alloc.free(user_uuid);

    const identity_sql =
        \\INSERT INTO user_identities (user_uuid, provider, password_hash)
        \\VALUES ($1, 'email', $2)
    ;
    _ = try tx.query(void, alloc, identity_sql, .{ user_uuid, password_hash });

    const default_role_sql = "SELECT id FROM roles WHERE is_default = true LIMIT 1";
    const role_result = try tx.queryOne(struct { id: []const u8 }, alloc, default_role_sql, .{});
    if (role_result) |role| {
        const user_role_sql = "INSERT INTO user_roles (user_uuid, role_id) VALUES ($1, $2)";
        _ = try tx.query(void, alloc, user_role_sql, .{ user_uuid, role.id });
    }

    try tx.commit();

    return created_user;
}

pub fn findIdentityByEmail(alloc: std.mem.Allocator, email: []const u8, provider: []const u8) !?UserIdentity {
    const sql =
        \\SELECT ui.id, ui.user_uuid, ui.provider, ui.provider_user_id, ui.password_hash, ui.created_at
        \\FROM user_identities ui
        \\JOIN users u ON u.uuid = ui.user_uuid
        \\WHERE u.email = $1 AND ui.provider = $2
        \\LIMIT 1
    ;
    const result = try db.queryOne(UserIdentity, alloc, sql, .{ email, provider });
    return result;
}

pub fn addIdentity(alloc: std.mem.Allocator, user_uuid: []const u8, provider: []const u8, provider_user_id: ?[]const u8, password_hash: ?[]const u8) !void {
    const sql =
        \\INSERT INTO user_identities (user_uuid, provider, provider_user_id, password_hash)
        \\VALUES ($1, $2, $3, $4)
        \\ON CONFLICT (user_uuid, provider) DO UPDATE SET provider_user_id = $3, password_hash = $4
    ;
    _ = try db.query(void, alloc, sql, .{ user_uuid, provider, provider_user_id, password_hash });
}

pub fn findUserRoles(alloc: std.mem.Allocator, user_uuid: []const u8) ![][]const u8 {
    const sql =
        \\SELECT r.name FROM user_roles ur
        \\JOIN roles r ON r.id = ur.role_id
        \\WHERE ur.user_uuid = $1
    ;
    const result = try db.query(struct { name: []const u8 }, alloc, sql, .{user_uuid});

    var roles = try alloc.alloc([]const u8, result.len);
    for (result, 0..) |row, i| {
        roles[i] = try alloc.dupe(u8, row.name);
    }

    return roles;
}

pub fn findUserPermissions(alloc: std.mem.Allocator, user_uuid: []const u8) ![][]const u8 {
    const sql =
        \\SELECT DISTINCT rp.permission FROM user_roles ur
        \\JOIN role_permissions rp ON rp.role_id = ur.role_id
        \\WHERE ur.user_uuid = $1
    ;
    const result = try db.query(struct { permission: []const u8 }, alloc, sql, .{user_uuid});

    var perms = try alloc.alloc([]const u8, result.len);
    for (result, 0..) |row, i| {
        perms[i] = try alloc.dupe(u8, row.permission);
    }

    return perms;
}

pub fn updateUser(alloc: std.mem.Allocator, user_uuid: []const u8, updates: struct {
    name: ?[]const u8 = null,
    google_id: ?[]const u8 = null,
    avatar_url: ?[]const u8 = null,
    locale: ?[]const u8 = null,
    locale_set: ?bool = null,
    tenant_id: ?[]const u8 = null,
}) !model.User {
    const user_result = try findByUuid(alloc, user_uuid);
    const current_user = user_result orelse return error.UserNotFound;

    const new_name = if (updates.name) |n| try alloc.dupe(u8, n) else (try alloc.dupe(u8, current_user.name));
    errdefer alloc.free(new_name);

    const new_avatar_url = if (updates.avatar_url) |a| try alloc.dupe(u8, a) else if (current_user.avatar_url) |a| try alloc.dupe(u8, a) else "";

    const new_locale = if (updates.locale) |l| try alloc.dupe(u8, l) else (try alloc.dupe(u8, current_user.locale));
    errdefer alloc.free(new_locale);

    const new_locale_set = updates.locale_set orelse current_user.locale_set;

    const new_tenant_id = if (updates.tenant_id) |t| try alloc.dupe(u8, t) else if (current_user.tenant_id) |t| try alloc.dupe(u8, t) else "";

    const sql = "UPDATE users SET name = $1, avatar_url = $2, locale = $3, locale_set = $4, tenant_id = $5 WHERE uuid = $6";

    _ = try db.query(void, alloc, sql, .{ new_name, new_avatar_url, new_locale, new_locale_set, new_tenant_id, user_uuid });

    return model.User{
        .id = current_user.id,
        .uuid = try alloc.dupe(u8, user_uuid),
        .email = try alloc.dupe(u8, current_user.email),
        .name = new_name,
        .google_id = current_user.google_id,
        .avatar_url = if (new_avatar_url.len > 0) new_avatar_url else null,
        .created_at = try alloc.dupe(u8, current_user.created_at),
        .locale = new_locale,
        .locale_set = new_locale_set,
        .tenant_id = if (new_tenant_id.len > 0) new_tenant_id else null,
    };
}
