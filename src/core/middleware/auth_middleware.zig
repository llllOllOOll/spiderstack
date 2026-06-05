const std = @import("std");

const spider = @import("spider");
const Ctx = spider.Ctx;
const Response = spider.Response;
const NextFn = spider.NextFn;
const auth = spider.auth;

pub const Features = struct {
    rbac_enabled: bool = false,
};

pub const features = Features{};

pub const AppClaims = struct {
    sub: []const u8,
    email: []const u8,
    name: []const u8,
    locale: []const u8,
    locale_set: bool,
    exp: i64,
    roles: []const []const u8,
    permissions: []const []const u8,
};

const PUBLIC_PATHS = [_][]const u8{
    "/login",
    "/auth/email/login",
    "/auth/email/register",
    "/auth/google",
    "/auth/google/callback",
};

fn isPublicPath(path: []const u8) bool {
    for (PUBLIC_PATHS) |p| {
        if (std.mem.eql(u8, path, p)) return true;
    }
    return false;
}

fn resolveLocale(c: *Ctx) []const u8 {
    const raw = c.header("Accept-Language") orelse return "pt_BR";
    const end = std.mem.indexOfAny(u8, raw, ",;") orelse raw.len;
    const tag = std.mem.trim(u8, raw[0..end], " ");
    return if (tag.len > 0) tag else "pt_BR";
}

pub fn hasPermission(claims: *const AppClaims, required: []const u8) bool {
    if (!features.rbac_enabled) return true;
    for (claims.permissions) |p| {
        if (std.mem.eql(u8, p, required)) return true;
    }
    return false;
}

pub fn requirePermission(claims: *const AppClaims, required: []const u8) bool {
    if (!features.rbac_enabled) return true;
    return hasPermission(claims, required);
}

pub fn authMiddleware(c: *Ctx, next: NextFn) !Response {
    const path = if (std.mem.indexOfScalar(u8, c.request.head.target, '?')) |q|
        c.request.head.target[0..q]
    else
        c.request.head.target;

    if (isPublicPath(path)) return next(c);

    const jwt_secret_z = std.c.getenv("JWT_SECRET") orelse return c.redirect("/login");
    const jwt_secret = std.mem.span(jwt_secret_z);

    const token = c.cookie(auth.COOKIE_NAME) orelse return c.redirect("/login");

    _ = auth.jwtVerify(AppClaims, c.arena, c._io, token, jwt_secret) catch return c.redirect("/login");

    return next(c);
}
