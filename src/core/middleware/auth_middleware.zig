// src/core/middleware/auth_middleware.zig
const std = @import("std");
const spider = @import("spider");

const Request = spider.Request;
const Response = spider.Response;
const NextFn = spider.web.NextFn;
const auth = spider.auth;

pub const AppClaims = struct {
    sub: i32,
    email: []const u8,
    name: []const u8,
    locale: []const u8,
    locale_set: bool,
    exp: i64,
};

const PUBLIC_PATHS = [_][]const u8{
    "/public/",
    "/assets",
    "/up",
    "/auth/google",
    "/auth/google/callback",
    "/login",
    "/dev/form",
};

fn isPublicPath(path: []const u8) bool {
    for (PUBLIC_PATHS) |p| {
        if (std.mem.eql(u8, path, p)) return true;
    }
    return false;
}

fn methodHasBody(req: *Request) bool {
    const method = @tagName(req.method);
    return std.mem.eql(u8, method, "POST") or
        std.mem.eql(u8, method, "PUT") or
        std.mem.eql(u8, method, "PATCH");
}

fn localeFromHeader(req: *Request) []const u8 {
    const raw = req.headers.get("Accept-Language") orelse return "pt_BR";
    const end = std.mem.indexOfAny(u8, raw, ",;") orelse raw.len;
    const tag = std.mem.trim(u8, raw[0..end], " ");
    return if (tag.len > 0) tag else "pt_BR";
}

pub fn authMiddleware(alloc: std.mem.Allocator, req: *Request, next: NextFn) !Response {
    // ── Public routes: skip auth, resolve locale from header ──────────
    if (isPublicPath(req.path)) {
        req.locale = localeFromHeader(req);
        return next(alloc, req);
    }

    // ── Validate body requests ────────────────────────────────────────
    const has_content_length = req.headers.get("Content-Length") != null or
        req.headers.get("Transfer-Encoding") != null;

    if (methodHasBody(req) and !has_content_length) {
        const msg =
            "400 Bad Request\n\n" ++
            "POST/PUT requests require Content-Length header.\n" ++
            "Please include a valid Content-Length or use GET for public resources.\n";
        return Response.text(alloc, msg);
    }

    // ── Validate JWT ──────────────────────────────────────────────────
    const jwt_secret_z = std.c.getenv("JWT_SECRET") orelse
        return Response.redirect(alloc, "/login");
    const jwt_secret = std.mem.span(jwt_secret_z);

    const cookie_header = req.headers.get("Cookie") orelse
        return Response.redirect(alloc, "/login");

    const token = auth.cookieGet(cookie_header) orelse
        return Response.redirect(alloc, "/login");

    const claims = auth.jwtVerify(AppClaims, alloc, token, jwt_secret) catch
        return Response.redirect(alloc, "/login");

    // ── Resolve locale: JWT preference > Accept-Language header ──────
    const resolved_locale = if (claims.locale_set)
        claims.locale
    else
        localeFromHeader(req);

    // ── Inject into req.user (NEW) and req.params (DEPRECATED) ────────
    req.locale = resolved_locale;
    req.user = .{
        .id = try std.fmt.allocPrint(alloc, "{d}", .{claims.sub}),
        .email = try alloc.dupe(u8, claims.email),
        .name = try alloc.dupe(u8, claims.name),
    };
    alloc.free(claims.email);
    alloc.free(claims.name);
    alloc.free(claims.locale);

    // DEPRECATED: usar req.user.id/email/name ao invés disso
    try req.params.put(alloc, try alloc.dupe(u8, "_user_id"), try alloc.dupe(u8, req.user.id.?));
    try req.params.put(alloc, try alloc.dupe(u8, "_user_email"), try alloc.dupe(u8, req.user.email.?));
    try req.params.put(alloc, try alloc.dupe(u8, "_user_name"), try alloc.dupe(u8, req.user.name.?));

    return next(alloc, req);
}
