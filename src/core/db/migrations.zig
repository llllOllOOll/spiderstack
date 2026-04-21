const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

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
    .{
        .version = "20260410120001",
        .sql_file = @embedFile("./migrations/20260410120001_create_games.sql"),
    },
    .{
        .version = "20260417100001",
        .sql_file = @embedFile("./migrations/20260417100001_create_todos.sql"),
    },
    .{
        .version = "20260421000001",
        .sql_file = @embedFile("./migrations/20260421000001_add_uuid_to_users.sql"),
    },
    .{
        .version = "20260421000002",
        .sql_file = @embedFile("./migrations/20260421000002_create_auth_tables.sql"),
    },
    .{
        .version = "20260421000003",
        .sql_file = @embedFile("./migrations/20260421000003_migrate_auth_data.sql"),
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
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const create_migrations_table_sql: [:0]const u8 = "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) NOT NULL PRIMARY KEY, ran_at TIMESTAMPTZ NOT NULL DEFAULT NOW())";
    try db.queryExecute(void, arena.allocator(), create_migrations_table_sql);

    for (MIGRATIONS) |migration| {
        const MigrationCheck = struct { count: i32 };
        const checks = try db.query(
            MigrationCheck,
            arena.allocator(),
            "SELECT COUNT(*) as count FROM schema_migrations WHERE version = $1",
            .{migration.version},
        );

        // If there are no results OR count is 0, run the migration
        if (checks.len == 0 or checks[0].count == 0) {
            const up_sql = extractUpSection(migration.sql_file);
            if (up_sql.len == 0 or std.mem.trim(u8, up_sql, " \n\r\t").len == 0) {
                std.debug.print("MIGRATION: skipping empty {s}\n", .{migration.version});
            } else {
                const sql_z = try arena.allocator().dupeZ(u8, up_sql);
                try db.queryExecute(void, arena.allocator(), sql_z);
                std.debug.print("MIGRATION: ran {s}\n", .{migration.version});
            }
            try db.query(void, arena.allocator(), "INSERT INTO schema_migrations (version) VALUES ($1)", .{migration.version});
        }
    }
}
