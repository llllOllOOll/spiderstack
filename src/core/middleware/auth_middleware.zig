const std = @import("std");
const spider = @import("spider");
const Request = spider.Request;
const Response = spider.Response;
const NextFn = spider.web.NextFn;
const auth = spider.auth;

const PUBLIC_PATHS = [_][]const u8{
    "/public/",
    "/assets",
    "/up",
    "/auth/google",
    "/auth/google/callback",
    "/login",
    "/dev/form",
};

fn methodHasBody(req: *Request) bool {
    const method = @tagName(req.method);
    return std.mem.eql(u8, method, "POST") or
        std.mem.eql(u8, method, "PUT") or
        std.mem.eql(u8, method, "PATCH");
}

pub fn authMiddleware(alloc: std.mem.Allocator, req: *Request, next: NextFn) !Response {
    for (PUBLIC_PATHS) |path| {
        if (std.mem.eql(u8, req.path, path)) return next(alloc, req);
    }

    const has_content_length = req.headers.get("Content-Length") != null or
        req.headers.get("Transfer-Encoding") != null;

    if (methodHasBody(req) and !has_content_length) {
        const msg = "400 Bad Request\n\nPOST/PUT requests require Content-Length header.\nPlease include a valid Content-Length or use GET for public resources.\n";
        return Response.text(alloc, msg);
    }

    const jwt_secret_z = std.c.getenv("JWT_SECRET") orelse
        return Response.redirect(alloc, "/login");
    const jwt_secret = std.mem.span(jwt_secret_z);
    const cookie_header = req.headers.get("Cookie") orelse
        return Response.redirect(alloc, "/login");
    const token = auth.cookieGet(cookie_header) orelse
        return Response.redirect(alloc, "/login");
    const claims = auth.jwtVerify(alloc, token, jwt_secret) catch
        return Response.redirect(alloc, "/login");
    const user_id = try std.fmt.allocPrint(alloc, "{d}", .{claims.sub});
    const email = try alloc.dupe(u8, claims.email);
    alloc.free(claims.email);
    try req.params.put(alloc, try alloc.dupe(u8, "_user_id"), user_id);
    try req.params.put(alloc, try alloc.dupe(u8, "_user_email"), email);
    return next(alloc, req);
}
