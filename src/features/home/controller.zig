const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;
const i18n = @import("core").i18n;
const presenter = @import("presenter.zig");

const home_content = @embedFile("views/index.html");

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale_raw = req.params.get("_locale") orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);

    const user_id = req.params.get("_user_id") orelse "";
    const user_email = req.params.get("_user_email") orelse "";
    const user_name = req.params.get("_user_name") orelse "";

    const context = try presenter.buildHomeContext(alloc, locale, user_id, user_email, user_name);

    return spider.renderView(alloc, req, home_content, context);
}
