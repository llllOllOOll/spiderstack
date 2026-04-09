const std = @import("std");
// const i18n = @import("../../core/mod.zig").i18n;
const i18n = @import("core").i18n;

pub const HomeContext = struct {
    locale: i18n.Locale,
    page_title: []const u8,
    page_subtitle: []const u8,
};

pub fn buildContext(alloc: std.mem.Allocator, locale: i18n.Locale) !HomeContext {
    _ = alloc;
    return HomeContext{
        .locale = locale,
        .page_title = i18n.t(locale, "home_title"),
        .page_subtitle = i18n.t(locale, "home_subtitle"),
    };
}
