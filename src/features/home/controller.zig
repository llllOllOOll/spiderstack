const std = @import("std");
const spider = @import("spider");
const Response = spider.Response;
const Request = spider.Request;
const i18n = @import("core").i18n;
const buildBaseContext = @import("core").context.build;

const home_content = @embedFile("views/index.html");

pub fn index(alloc: std.mem.Allocator, req: *Request) !Response {
    const locale = i18n.Locale.pt_BR;
    const user: struct { name: []const u8, email: []const u8, avatar_url: ?[]const u8 } = .{
        .name = "Seven",
        .email = "",
        .avatar_url = null,
    };

    const base = try buildBaseContext(alloc, user, locale);

    const context = .{
        .locale = base.locale,
        .title = "Home",
        .nav_overview = base.nav_overview,
        .nav_accounts = base.nav_accounts,
        .nav_categories = base.nav_categories,
        .user_name = base.user_name,
        .user_initials = base.user_initials,
        .page_title = "Bem-vindo!",
        .page_subtitle = "Este é o seu dashboard.",
    };

    return spider.renderView(alloc, req, home_content, context);
}
