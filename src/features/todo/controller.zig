const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;

const model = @import("model.zig");
const repository = @import("repository.zig");
const presenter = @import("presenter.zig");

// const view = @embedFile("views/index.html");

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const todos = try repository.findAll(alloc);
    defer alloc.free(todos);

    const context = try presenter.buildContext(alloc, req, todos);

    // return spider.renderView(alloc, req, view, context);
    return spider.chuckBerry(alloc, req, "todo/index", context);
}

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);
    _ = try repository.create(alloc, input);

    return Response.redirect(alloc, "/todo");
}

pub fn update(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try std.fmt.parseInt(i64, req.params.get("id") orelse "", 10);
    const updates = try req.parseForm(alloc, model.UpdateInput);

    _ = try repository.update(alloc, id, updates);

    return Response.redirect(alloc, "/todo");
}

pub fn delete(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try std.fmt.parseInt(i64, req.params.get("id") orelse "", 10);
    try repository.delete(alloc, id);

    return Response.text(alloc, "");
}
