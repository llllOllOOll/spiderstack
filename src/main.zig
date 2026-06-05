const std = @import("std");

const core = @import("core");
const migrations = core.db.migrations;
const middleware = core.middleware;
const db = @import("spider").pg;
const features = @import("features");
const auth = features.auth;
const home = features.home;
const games = features.games;
const todo = features.todo;
const movies = features.movies;
const spider = @import("spider");
const Response = spider.Response;

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

fn errorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    return c.text(@errorName(err), .{ .status = .internal_server_error });
}

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var server = spider.app(.{});
    defer server.deinit();

    _ = spider.env.get("JWT_SECRET") orelse {
        std.log.err("JWT_SECRET is not set! Check that .env file exists and it has JWT_SECRET variable set.", .{});
        return error.MissingJwtSecret;
    };

    db.init(arena, io, .{
        .host = "localhost",
        .port = 5434,
        .user = "spider",
        .password = "spider",
        .database = "spiderdb",
        .pool_size = 20,
    }) catch {
        std.log.err("Failed to initialize PostgreSQL\n", .{});
        return;
    };
    defer spider.pg.deinit();
    try migrations.run(arena);

    server
        .use(spider.logger)
        .use(middleware.auth)
        .get("/login", auth.controller.index)
        .get("/auth/google", auth.controller.redirectToGoogle)
        .get("/auth/google/callback", auth.controller.googleCallback)
        .post("/auth/email/register", auth.controller.handleEmailAuth)
        .post("/auth/email/login", auth.controller.handleEmailAuth)
        .get("/logout", auth.controller.logout)
        .get("/todo", todo.controller.index)
        .post("/todo/create", todo.controller.create)
        .post("/todo/:id/update", todo.controller.update)
        .post("/todo/:id/delete", todo.controller.delete)
        .get("/", home.controller.index)
        .post("/games/create", games.controller.create)
        .post("/games/:id/update", games.controller.update)
        .post("/games/:id/delete", games.controller.delete)
        .get("/games", games.controller.index)
        .get("/movies", movies.controller.index)
        .get("/movies/search", movies.controller.search)
        .get("/movies/popular", movies.controller.popular)
        .get("/movies/:id", movies.controller.movieDetails)
        .onError(errorHandler)
        .listen(.{ .port = 8080, .host = "0.0.0.0" }) catch |err| return err;
}
