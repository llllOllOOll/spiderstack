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
        try req.params.put(alloc, try alloc.dupe(u8, "_locale"), try alloc.dupe(u8, localeFromHeader(req)));
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

    // ── Inject into req.params ────────────────────────────────────────
    const user_id = try std.fmt.allocPrint(alloc, "{d}", .{claims.sub});
    const email = try alloc.dupe(u8, claims.email);
    const user_name = try alloc.dupe(u8, claims.name);
    const user_locale = if (claims.locale_set)
        try alloc.dupe(u8, claims.locale)
    else
        try alloc.dupe(u8, resolved_locale);
    alloc.free(claims.email);
    alloc.free(claims.name);
    alloc.free(claims.locale);

    try req.params.put(alloc, try alloc.dupe(u8, "_user_id"), user_id);
    try req.params.put(alloc, try alloc.dupe(u8, "_user_email"), email);
    try req.params.put(alloc, try alloc.dupe(u8, "_user_name"), user_name);
    try req.params.put(alloc, try alloc.dupe(u8, "_locale"), user_locale);

    return next(alloc, req);
}
