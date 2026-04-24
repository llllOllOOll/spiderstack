const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;
const core = @import("core");

const model = @import("model.zig");
const repository = @import("repository.zig");
const presenter = @import("presenter.zig");
const i18n = core.i18n;

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale_raw = req.locale orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);

    const games = try repository.findAll(alloc);
    const context = try presenter.buildGameListContext(alloc, req, locale, games);

    // return spider.renderView(alloc, req, view, context);
    return spider.chuckBerry(alloc, req, "games/index", context);
}

pub fn create(alloc: std.mem.Allocator, req: *Request) !Response {
    const input = try req.parseForm(alloc, model.CreateInput);

    _ = try repository.create(alloc, input);

    return Response.redirect(alloc, "/games");
}

pub fn update(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try core.utils.parseIdFromRequest(req);

    const updates = try req.parseForm(alloc, model.UpdateInput);

    _ = try repository.update(alloc, id, updates);

    return Response.redirect(alloc, "/games");
}

pub fn delete(alloc: std.mem.Allocator, req: *Request) !Response {
    const id = try core.utils.parseIdFromRequest(req);

    try repository.delete(alloc, id);

    return Response.text(alloc, "");
}
