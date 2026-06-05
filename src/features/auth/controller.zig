const std = @import("std");

const AppClaims = @import("core").middleware.AppClaims;
const features = @import("core").middleware.features;
const i18n = @import("core").i18n;
const spider = @import("spider");
const db = spider.pg;
const auth = spider.auth;
const google = spider.google;

const bcrypt = @import("bcrypt.zig");
const config = @import("mod.zig");
const model = @import("model.zig");
const presenter = @import("presenter.zig");
const repository = @import("repository.zig");
const service = @import("service.zig");
const use_case = @import("use_case/index.zig");

fn urlDecode(alloc: std.mem.Allocator, str: []const u8) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < str.len) {
        if (str[i] == '%' and i + 2 < str.len) {
            const hex = str[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                try list.append(alloc, str[i]);
                i += 1;
                continue;
            };
            try list.append(alloc, byte);
            i += 3;
        } else if (str[i] == '+') {
            try list.append(alloc, ' ');
            i += 1;
        } else {
            try list.append(alloc, str[i]);
            i += 1;
        }
    }
    return list.toOwnedSlice(alloc);
}

// const view = @embedFile("views/login.html");

fn resolveLocale(c: *spider.Ctx) i18n.Locale {
    const raw = c.header("Accept-Language") orelse return .pt_BR;
    const end = std.mem.indexOfAny(u8, raw, ",;") orelse raw.len;
    const tag = std.mem.trim(u8, raw[0..end], " ");
    if (tag.len == 0) return .pt_BR;
    return i18n.localeFromStr(tag);
}

fn generateJwtWithRoles(alloc: std.mem.Allocator, io: std.Io, user: model.User) ![]u8 {
    const jwt_secret = spider.env.getOr("JWT_SECRET", "");

    const roles = if (features.rbac_enabled)
        try repository.findUserRoles(alloc, user.uuid)
    else
        &[_][]const u8{};

    const permissions = if (features.rbac_enabled)
        try repository.findUserPermissions(alloc, user.uuid)
    else
        &[_][]const u8{};

    const now = std.Io.Clock.now(.real, io);
    const exp: i64 = now.toSeconds() + (60 * 60 * 24 * 7);

    return try auth.jwtSign(alloc, AppClaims{
        .sub = user.uuid,
        .email = user.email,
        .name = user.name,
        .locale = user.locale,
        .locale_set = user.locale_set,
        .exp = exp,
        .roles = roles,
        .permissions = permissions,
    }, jwt_secret);
}

fn requireAuth(c: *spider.Ctx) !void {
    const token = c.cookie(auth.COOKIE_NAME) orelse return error.Unauthorized;
    const jwt_secret = spider.env.getOr("JWT_SECRET", "");
    _ = try auth.jwtVerify(AppClaims, c.arena, token, jwt_secret);
}

pub fn index(c: *spider.Ctx) !spider.Response {
    const locale = resolveLocale(c);
    const data = try presenter.buildLoginContext(c.arena, c, locale, "", null);
    return c.view("auth/login", data, .{});
}

pub fn redirectToGoogle(c: *spider.Ctx) !spider.Response {
    const redirect_uri = spider.env.getOr("GOOGLE_REDIRECT_URI", "http://localhost:8080/auth/google/callback");
    const scope = "openid profile email";

    const auth_url = try std.fmt.allocPrint(c.arena, "https://accounts.google.com/o/oauth2/v2/auth?" ++
        "client_id={s}&" ++
        "redirect_uri={s}&" ++
        "response_type=code&" ++
        "scope={s}&" ++
        "access_type=offline", .{ spider.env.getOr("GOOGLE_CLIENT_ID", ""), redirect_uri, scope });

    return c.redirect(auth_url);
}

pub fn googleCallback(c: *spider.Ctx) !spider.Response {
    const code_encoded = c.query("code") orelse return c.redirect("/auth/google");
    const code = try urlDecode(c.arena, code_encoded);
    const googleConfig = config.getGoogleConfig();

    const profile = service.fetchGoogleProfile(c, code, googleConfig) catch |err| {
        std.debug.print("[auth/google] fetchGoogleProfile failed: {s}\n", .{@errorName(err)});
        return c.redirect("/login");
    };
    const user = blk: {
        var retries: usize = 3;
        break :blk while (retries > 0) : (retries -= 1) {
            break :blk use_case.findOrCreateOAuthUser(c.arena, profile) catch |err| {
                if (retries > 1 and err == error.ConnectionBusy) {
                    std.debug.print("[auth/google] findOrCreateOAuthUser failed: {s} (retrying...)\n", .{@errorName(err)});
                    var ts = std.os.linux.timespec{ .sec = 0, .nsec = 100 * std.time.ns_per_ms };
                    _ = std.os.linux.nanosleep(&ts, null);
                    continue;
                }
                std.debug.print("[auth/google] findOrCreateOAuthUser failed: {s}\n", .{@errorName(err)});
                return c.redirect("/login");
            };
        } else unreachable;
    };
    const token = generateJwtWithRoles(c.arena, c._io, user) catch |err| {
        std.debug.print("[auth/google] generateJwtWithRoles failed: {s}\n", .{@errorName(err)});
        return c.redirect("/login");
    };
    const cookie_value = auth.cookieSet(c.arena, token) catch |err| {
        std.debug.print("[auth/google] cookieSet failed: {s}\n", .{@errorName(err)});
        return c.redirect("/login");
    };

    const headers = try c.arena.alloc([2][]const u8, 2);
    headers[0] = .{ "Location", "/" };
    headers[1] = .{ "Set-Cookie", cookie_value };
    return spider.Response{
        .status = .found,
        .body = null,
        .content_type = "text/plain",
        .headers = headers,
    };
}

pub fn handleLogin(c: *spider.Ctx) !spider.Response {
    return c.text("POST received", .{});
}

pub fn handleEmailAuth(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(model.CreateInput);

    if (input.email.len == 0 or input.password.len == 0) {
        return c.text("Email and password required", .{});
    }

    const isRegister = input.name.len > 0;

    if (isRegister) {
        // Registration flow
        if (try repository.findByEmail(c.arena, input.email)) |existing_user| {
            const has_email_identity = try repository.findIdentityByEmail(c.arena, existing_user.email, "email");
            if (has_email_identity != null) {
                return c.text("Email already registered", .{});
            }

            const hash = try bcrypt.hash(c.arena, input.password);
            try repository.addIdentity(c.arena, existing_user.uuid, "email", null, hash);

            // Login after adding identity
            const user = existing_user;
            const token = try generateJwtWithRoles(c.arena, c._io, user);
            const cookie_value = try auth.cookieSet(c.arena, token);
            const headers1 = try c.arena.alloc([2][]const u8, 2);
            headers1[0] = .{ "Location", "/" };
            headers1[1] = .{ "Set-Cookie", cookie_value };
            return spider.Response{
                .status = .found,
                .body = null,
                .content_type = "text/plain",
                .headers = headers1,
            };
        }

        const hash = try bcrypt.hash(c.arena, input.password);
        const user = try repository.createEmailUser(c.arena, input.email, input.name, hash);

        const token2 = try generateJwtWithRoles(c.arena, c._io, user);
        const cookie_value2 = try auth.cookieSet(c.arena, token2);
        const headers2 = try c.arena.alloc([2][]const u8, 2);
        headers2[0] = .{ "Location", "/" };
        headers2[1] = .{ "Set-Cookie", cookie_value2 };
        return spider.Response{
            .status = .found,
            .body = null,
            .content_type = "text/plain",
            .headers = headers2,
        };
    } else {
        // Login flow
        const identity = try repository.findIdentityByEmail(c.arena, input.email, "email") orelse {
            return c.text("Invalid credentials", .{});
        };

        const password_ok = try bcrypt.verify(c.arena, input.password, identity.password_hash orelse "");
        if (!password_ok) {
            return c.text("Invalid credentials", .{});
        }

        const user = try repository.findByUuid(c.arena, identity.user_uuid) orelse {
            return c.text("User not found", .{});
        };

        const token = try generateJwtWithRoles(c.arena, c._io, user);
        const cookie_value = try auth.cookieSet(c.arena, token);
        const headers = try c.arena.alloc([2][]const u8, 2);
        headers[0] = .{ "Location", "/" };
        headers[1] = .{ "Set-Cookie", cookie_value };
        return spider.Response{
            .status = .found,
            .body = null,
            .content_type = "text/plain",
            .headers = headers,
        };
    }
}

pub fn logout(c: *spider.Ctx) !spider.Response {
    const cookie_value = try auth.cookieClear(c.arena);
    const headers = try c.arena.alloc([2][]const u8, 2);
    headers[0] = .{ "Location", "/login" };
    headers[1] = .{ "Set-Cookie", cookie_value };
    return spider.Response{
        .status = .found,
        .body = null,
        .content_type = "text/plain",
        .headers = headers,
    };
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
