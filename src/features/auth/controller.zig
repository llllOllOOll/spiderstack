const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const Response = spider.Response;
const Request = spider.Request;
const auth = spider.auth;
const google = spider.google;
const http_client = spider.http_client;

const presenter = @import("presenter/mod.zig");
const repository = @import("repository.zig");
const model = @import("model.zig");
const AppClaims = @import("core").middleware.AppClaims;

const view = @embedFile("views/login.html");

fn getGoogleConfig() google.GoogleConfig {
    return .{
        .client_id = std.mem.span(std.c.getenv("GOOGLE_CLIENT_ID") orelse @panic("GOOGLE_CLIENT_ID not set")),
        .client_secret = std.mem.span(std.c.getenv("GOOGLE_CLIENT_SECRET") orelse @panic("GOOGLE_CLIENT_SECRET not set")),
        .redirect_uri = std.mem.span(std.c.getenv("GOOGLE_REDIRECT_URI") orelse "http://localhost:8080/auth/google/callback"),
    };
}

pub fn index(alloc: std.mem.Allocator, _: *Request) !Response {
    // Simple test data
    const data = .{
        .locale = "pt-BR",
        .tagline = "Zig + Spider + Tailwind + HTMX",
    };
    return spider.render(alloc, view, data);
}

pub fn redirectToGoogle(alloc: std.mem.Allocator, _: *Request) !Response {
    const google_client_id = std.c.getenv("GOOGLE_CLIENT_ID") orelse return error.MissingGoogleClientId;
    const redirect_uri = "http://localhost:8080/auth/google/callback";
    const scope = "openid profile email";

    const auth_url = try std.fmt.allocPrint(alloc, "https://accounts.google.com/o/oauth2/v2/auth?" ++
        "client_id={s}&" ++
        "redirect_uri={s}&" ++
        "response_type=code&" ++
        "scope={s}&" ++
        "access_type=offline", .{ std.mem.span(google_client_id), redirect_uri, scope });

    return Response.redirect(alloc, auth_url);
}

pub fn googleCallback(alloc: std.mem.Allocator, req: *Request) !Response {
    // Initialize ArenaAllocator for this request
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const code = (try req.queryParam("code", arena_allocator)) orelse {
        return Response.redirect(arena_allocator, "/auth/google");
    };

    // 1. Exchange code for access token
    const config = getGoogleConfig();
    const profile = try fetchGoogleProfile(arena_allocator, code, config);

    // 2. Find or create user
    const user = try findOrCreateOAuthUser(arena_allocator, profile);

    // 3. Generate JWT token
    const jwt_secret = std.c.getenv("JWT_SECRET") orelse return error.MissingJwtSecret;
    var tv: std.c.timeval = undefined;
    _ = std.c.gettimeofday(&tv, null);
    const exp = tv.sec + (60 * 60 * 24 * 7); // 7 days
    const token = try auth.jwtSign(arena_allocator, AppClaims{
        .sub = user.id,
        .email = user.email,
        .locale = user.locale,
        .locale_set = user.locale_set,
        .exp = exp,
    }, std.mem.span(jwt_secret));

    // 4. Set cookie and redirect
    const cookie_value = try auth.cookieSet(arena_allocator, token);
    var response = try Response.redirect(arena_allocator, "/");
    try response.headers.set(arena_allocator, "Set-Cookie", cookie_value);

    return response;
}

fn fetchGoogleProfile(alloc: std.mem.Allocator, code: []const u8, config: google.GoogleConfig) !google.GoogleProfile {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const token_body = try std.fmt.allocPrint(
        arena_allocator,
        "code={s}&client_id={s}&client_secret={s}&redirect_uri={s}&grant_type=authorization_code",
        .{ code, config.client_id, config.client_secret, config.redirect_uri },
    );
    const token_resp = try http_client.post(
        arena_allocator,
        "https://oauth2.googleapis.com/token",
        token_body,
        "application/x-www-form-urlencoded",
    );
    const TokenResponse = struct { access_token: []const u8 };
    const parsed_token = try std.json.parseFromSlice(TokenResponse, arena_allocator, token_resp, .{ .ignore_unknown_fields = true });
    defer parsed_token.deinit();
    const bearer = try std.fmt.allocPrint(arena_allocator, "Bearer {s}", .{parsed_token.value.access_token});
    const headers = [_]std.http.Header{.{ .name = "Authorization", .value = bearer }};
    const profile_resp = try http_client.get(
        arena_allocator,
        "https://www.googleapis.com/oauth2/v2/userinfo",
        &headers,
    );
    const RawProfile = struct {
        id: []const u8,
        email: []const u8,
        name: []const u8,
        picture: []const u8,
    };
    const parsed = try std.json.parseFromSlice(RawProfile, arena_allocator, profile_resp, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return google.GoogleProfile{
        .id = try arena_allocator.dupe(u8, parsed.value.id),
        .email = try arena_allocator.dupe(u8, parsed.value.email),
        .name = try arena_allocator.dupe(u8, parsed.value.name),
        .picture = try arena_allocator.dupe(u8, parsed.value.picture),
    };
}

fn findOrCreateOAuthUser(alloc: std.mem.Allocator, profile: google.GoogleProfile) !model.User {
    // Try to find by Google ID first
    if (try repository.findByGoogleId(alloc, profile.id)) |user| {
        return user;
    }

    // Try to find by email
    if (try repository.findByEmail(alloc, profile.email)) |user| {
        // Update with Google ID
        const updated_user = try repository.updateUser(alloc, user.id, .{
            .google_id = profile.id,
            .avatar_url = profile.picture,
        });
        return updated_user;
    }

    // Create new user
    return repository.createOAuthUser(alloc, profile.email, profile.name, profile.id, profile.picture);
}

pub fn handleLogin(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    _ = req;
    return spider.Response.text(alloc, "POST received");
}

test "transaction creates table but rolls back" {
    const alloc = std.testing.allocator;
    try db.init(alloc, .{}, .{});
    defer db.deinit();

    var tx = try db.begin();
    defer tx.rollback();

    try tx.queryExecute(void, alloc, "CREATE TABLE IF NOT EXISTS test_tx_temp (id SERIAL PRIMARY KEY, name TEXT)");
    try tx.commit();

    const result = try db.query(void, alloc, "DROP TABLE IF EXISTS test_tx_temp");
    _ = result;
}
