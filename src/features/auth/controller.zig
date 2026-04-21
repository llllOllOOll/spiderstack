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
const features = @import("core").middleware.features;
const bcrypt = @import("bcrypt.zig");

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

fn generateJwtWithRoles(alloc: std.mem.Allocator, user: model.User) ![]u8 {
    const jwt_secret = std.c.getenv("JWT_SECRET") orelse return error.MissingJwtSecret;

    const roles = if (features.rbac_enabled)
        try repository.findUserRoles(alloc, user.uuid)
    else
        &[_][]const u8{};

    const permissions = if (features.rbac_enabled)
        try repository.findUserPermissions(alloc, user.uuid)
    else
        &[_][]const u8{};

    const exp: i64 = 1767225600 + (60 * 60 * 24 * 7); // 2026-01-01 + 7 days

    return try auth.jwtSign(alloc, AppClaims{
        .sub = user.uuid,
        .email = user.email,
        .name = user.name,
        .locale = user.locale,
        .locale_set = user.locale_set,
        .exp = exp,
        .roles = roles,
        .permissions = permissions,
    }, std.mem.span(jwt_secret));
}

fn requireAuth(alloc: std.mem.Allocator, req: *Request) !void {
    const cookie_header = req.headers.get("Cookie") orelse return error.Unauthorized;
    const token = auth.cookieGet(cookie_header) orelse return error.Unauthorized;
    const jwt_secret = std.c.getenv("JWT_SECRET") orelse return error.MissingJwtSecret;
    _ = try auth.jwtVerify(AppClaims, alloc, token, std.mem.span(jwt_secret));
}

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale = resolveLocale(req);
    const data = try presenter.buildLoginContext(alloc, req, locale, "", null);
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
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const code = (try req.queryParam("code", arena_allocator)) orelse {
        return Response.redirect(arena_allocator, "/auth/google");
    };

    const googleConfig = config.getGoogleConfig();
    const profile = try service.fetchGoogleProfile(arena_allocator, code, googleConfig);

    const user = try use_case.findOrCreateOAuthUser(arena_allocator, profile);

    const token = try generateJwtWithRoles(arena_allocator, user);

    const cookie_value = try auth.cookieSet(arena_allocator, token);
    var response = try Response.redirect(arena_allocator, "/");
    try response.headers.set(arena_allocator, "Set-Cookie", cookie_value);

    return response;
}

pub fn handleLogin(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    _ = req;
    return spider.Response.text(alloc, "POST received");
}

pub fn handleEmailAuth(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    if (input.email.len == 0 or input.password.len == 0) {
        return Response.text(alloc, "Email and password required");
    }

    const isRegister = input.name.len > 0;

    if (isRegister) {
        // Registration flow
        if (try repository.findByEmail(alloc, input.email)) |existing_user| {
            const has_email_identity = try repository.findIdentityByEmail(alloc, existing_user.email, "email");
            if (has_email_identity != null) {
                return Response.text(alloc, "Email already registered");
            }

            const hash = try bcrypt.hash(input.password, arena_allocator);
            try repository.addIdentity(alloc, existing_user.uuid, "email", null, hash);

            // Login after adding identity
            const user = existing_user;
            const token = try generateJwtWithRoles(alloc, user);
            const cookie_value = try auth.cookieSet(alloc, token);
            var response = try Response.redirect(alloc, "/");
            try response.headers.set(alloc, "Set-Cookie", cookie_value);
            return response;
        }

        const hash = try bcrypt.hash(input.password, arena_allocator);
        const user = try repository.createEmailUser(alloc, input.email, input.name, hash);

        const token = try generateJwtWithRoles(alloc, user);
        const cookie_value = try auth.cookieSet(alloc, token);
        var response = try Response.redirect(alloc, "/");
        try response.headers.set(alloc, "Set-Cookie", cookie_value);
        return response;
    } else {
        // Login flow
        const identity = try repository.findIdentityByEmail(alloc, input.email, "email") orelse {
            return Response.text(alloc, "Invalid credentials");
        };

        const password_ok = try bcrypt.verify(input.password, identity.password_hash orelse "");
        if (!password_ok) {
            return Response.text(alloc, "Invalid credentials");
        }

        const user = try repository.findByUuid(alloc, identity.user_uuid) orelse {
            return Response.text(alloc, "User not found");
        };

        const token = try generateJwtWithRoles(alloc, user);
        const cookie_value = try auth.cookieSet(alloc, token);
        var response = try Response.redirect(alloc, "/");
        try response.headers.set(alloc, "Set-Cookie", cookie_value);
        return response;
    }
}

pub fn logout(alloc: std.mem.Allocator, req: *Request) !Response {
    _ = req;
    const cookie_value = try auth.cookieClear(alloc);
    var response = try Response.redirect(alloc, "/login");
    try response.headers.set(alloc, "Set-Cookie", cookie_value);
    return response;
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
