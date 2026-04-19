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

fn isHxRequest(req: *Request) bool {
    return req.headers.get("HX-Request") != null;
}

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);
    const todo = (try repository.create(alloc, input)) orelse return Response.text(alloc, "Error creating todo");

    if (isHxRequest(req)) {
        const context = try presenter.buildItemContext(alloc, req, todo);
        return spider.chuckBerry(alloc, req, "todo/item_todo", context);
    }

    return Response.redirect(alloc, "/todo");
}

pub fn update(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try std.fmt.parseInt(i64, req.params.get("id") orelse "", 10);
    const updates = try req.parseForm(alloc, model.UpdateInput);
    const todo = (try repository.update(alloc, id, updates)) orelse return Response.text(alloc, "Error updating todo");

    if (isHxRequest(req)) {
        const context = try presenter.buildItemContext(alloc, req, todo);
        return spider.chuckBerry(alloc, req, "todo/item_todo", context);
    }

    return Response.redirect(alloc, "/todo");
}

pub fn delete(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try std.fmt.parseInt(i64, req.params.get("id") orelse "", 10);
    try repository.delete(alloc, id);

    if (isHxRequest(req)) {
        return Response.text(alloc, "");
    }

    return Response.redirect(alloc, "/todo");
}
