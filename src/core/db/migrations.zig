const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

// TODO: Upgrade to new PQ queries, don't use deprecated queries

const Migration = struct {
    version: [:0]const u8,
    sql_file: []const u8,
};

const MIGRATIONS = [_]Migration{
    .{
        .version = "20260408000001",
        .sql_file = @embedFile("./migrations/20260408000001_create_users.sql"),
    },
    .{
        .version = "20260408000002",
        .sql_file = @embedFile("./migrations/20260408000002_create_schema_migrations.sql"),
    },
};

fn extractUpSection(sql_file: []const u8) []const u8 {
    const up_marker = "-- migrate:up\n";
    const down_marker = "-- migrate:down";
    const start = std.mem.indexOf(u8, sql_file, up_marker) orelse return "";
    const content_start = start + up_marker.len;
    const end = std.mem.indexOf(u8, sql_file[content_start..], down_marker) orelse
        return sql_file[content_start..];
    return sql_file[content_start .. content_start + end];
}

pub fn run(alloc: std.mem.Allocator) !void {
    const create_migrations_table_sql: [:0]const u8 = "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) NOT NULL PRIMARY KEY, ran_at TIMESTAMPTZ NOT NULL DEFAULT NOW())";
    try db.execRaw(create_migrations_table_sql);

    for (MIGRATIONS) |migration| {
        var result = try db.queryWith(
            "SELECT 1 FROM schema_migrations WHERE version = $1 LIMIT 1",
            .{migration.version},
        );
        defer result.deinit();

        if (result.rows() == 0) {
            const up_sql = extractUpSection(migration.sql_file);
            if (up_sql.len == 0 or std.mem.trim(u8, up_sql, " \n\r\t").len == 0) {
                std.debug.print("MIGRATION: skipping empty {s}\n", .{migration.version});
            } else {
                const sql_z = try alloc.dupeZ(u8, up_sql);
                defer alloc.free(sql_z);
                try db.execRaw(
                    sql_z,
                );
                std.debug.print("MIGRATION: ran {s}\n", .{migration.version});
            }
            var insert_result = try db.queryWith(
                "INSERT INTO schema_migrations (version) VALUES ($1)",
                .{migration.version},
            );
            defer insert_result.deinit();
        }
    }
}
