const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const Response = spider.Response;
const Request = spider.Request;
const auth = spider.auth;
const google = spider.google;

const presenter = @import("presenter.zig");
const repository = @import("repository.zig");
const model = @import("model.zig");
const service = @import("service.zig");
const use_case = @import("use_case/index.zig");
const config = @import("mod.zig");
const AppClaims = @import("core").middleware.AppClaims;
const i18n = @import("core").i18n;

const view = @embedFile("views/login.html");

fn resolveLocale(req: *Request) i18n.Locale {
    const raw = req.headers.get("Accept-Language") orelse return .pt_BR;
    std.log.info("Accept-Language header: {s}", .{raw});
    const end = std.mem.indexOfAny(u8, raw, ",;") orelse raw.len;
    const tag = std.mem.trim(u8, raw[0..end], " ");
    if (tag.len == 0) return .pt_BR;
    const locale = i18n.localeFromStr(tag);
    std.log.info("Resolved locale: {}", .{locale});
    return locale;
}

fn requireAuth(alloc: std.mem.Allocator, req: *Request) !void {
    const cookie_header = req.headers.get("Cookie") orelse return error.Unauthorized;
    const token = auth.cookieGet(cookie_header) orelse return error.Unauthorized;
    const jwt_secret = std.c.getenv("JWT_SECRET") orelse return error.MissingJwtSecret;
    _ = try auth.jwtVerify(AppClaims, alloc, token, std.mem.span(jwt_secret));
}

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale = resolveLocale(req);
    const email = req.params.get("_user_email") orelse "";

    const data = try presenter.buildLoginContext(alloc, locale, email, null);
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
    const googleConfig = config.getGoogleConfig();
    const profile = try service.fetchGoogleProfile(arena_allocator, code, googleConfig);

    // 2. Find or create user
    const user = try use_case.findOrCreateOAuthUser(arena_allocator, profile);

    // 3. Generate JWT token (arena is fine now - jwtVerify will copy strings)
    const jwt_secret = std.c.getenv("JWT_SECRET") orelse return error.MissingJwtSecret;
    var tv: std.c.timeval = undefined;
    _ = std.c.gettimeofday(&tv, null);
    const exp = tv.sec + (60 * 60 * 24 * 7); // 7 days
    const token = try auth.jwtSign(arena_allocator, AppClaims{
        .sub = user.id,
        .email = user.email,
        .name = user.name,
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
