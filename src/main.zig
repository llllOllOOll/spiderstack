const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const features = @import("features");

const auth = features.auth;
const home = features.home;
const db = @import("spider").pg;
const migrations = core.db.migrations;
const middleware = core.middleware;

const layout = @embedFile("shared/templates/layout.html");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    spider.loadEnv(arena, ".env") catch {};
    try db.init(arena, io, .{});
    defer db.deinit();
    try migrations.run(arena);

    var server = try spider.Spider.init(arena, io, "127.0.0.1", 8080, .{ .layout = layout });
    defer server.deinit();

    server
        .use(middleware.auth)
        .get("/", home.controller.index)
        .get("/login", auth.controller.index)
        .post("/login", auth.controller.handleLogin)
        .listen() catch |err| {
        std.log.err("server error: {}", .{err});
        return err;
    };
}
