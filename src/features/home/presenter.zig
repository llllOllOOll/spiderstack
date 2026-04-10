const std = @import("std");
const i18n = @import("core").i18n;
const base_context = @import("core").context.base_context;

pub const HomeContext = struct {
    base: base_context.BaseContext,
    spider_title: []const u8,
    spider_subtitle: []const u8,
    spider_card_title: []const u8,
    spider_card_desc: []const u8,
    spider_card_cta: []const u8,
    tech_stack_title: []const u8,
};

pub fn buildHomeContext(
    alloc: std.mem.Allocator,
    locale: i18n.Locale,
) !HomeContext {
    const user: struct { name: []const u8, email: []const u8, avatar_url: ?[]const u8 } = .{
        .name = "",
        .email = "",
        .avatar_url = null,
    };

    const base = try base_context.build(alloc, user, locale);

    return HomeContext{
        .base = base,
        .spider_title = "SpiderStack",
        .spider_subtitle = i18n.t(locale, "home_tech_stack"),
        .spider_card_title = i18n.t(locale, "home_spider_title"),
        .spider_card_desc = i18n.t(locale, "home_spider_desc"),
        .spider_card_cta = i18n.t(locale, "home_spider_cta"),
        .tech_stack_title = i18n.t(locale, "home_tech_stack"),
    };
}
