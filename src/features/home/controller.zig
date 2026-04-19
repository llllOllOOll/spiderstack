const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;
const i18n = @import("core").i18n;
const presenter = @import("presenter.zig");

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale_raw = req.locale orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);

    const context = try presenter.buildHomeContext(alloc, req, locale);

    return spider.chuckBerry(alloc, req, "home/index", context);
}
