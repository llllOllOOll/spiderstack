const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;

const presenter = @import("presenter/mod.zig");

const view = @embedFile("views/login.html");

pub fn index(alloc: std.mem.Allocator, _: *Request) !Response {
    const data = try presenter.buildLoginContext(alloc, "", null);
    return spider.render(alloc, view, data);
}

pub fn handleLogin(alloc: std.mem.Allocator, req: *spider.Request) !spider.Response {
    _ = req;
    return spider.Response.text(alloc, "POST received");
}
