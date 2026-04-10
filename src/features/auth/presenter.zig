const std = @import("std");
const i18n = @import("core").i18n;
const base_context = @import("core").context.base_context;

pub const LoginContext = struct {
    base: base_context.BaseContext,
    error_msg: ?[]const u8,
    google_auth_url: []const u8,
    google_button_text: []const u8,
    html_lang: []const u8,
    login_title: []const u8,
    login_subtitle: []const u8,
    login_terms: []const u8,
    login_footer: []const u8,
};

pub fn buildLoginContext(
    alloc: std.mem.Allocator,
    locale: i18n.Locale,
    email: []const u8,
    error_msg: ?[]const u8,
) !LoginContext {
    const base = try base_context.build(alloc, .{
        .name = "",
        .email = email,
        .avatar_url = null,
    }, locale);

    const html_lang = switch (locale) {
        .pt_BR => "pt-BR",
        .en_US => "en-US",
    };

    return LoginContext{
        .base = base,
        .error_msg = if (error_msg) |e| try alloc.dupe(u8, e) else null,
        .google_auth_url = "/auth/google",
        .google_button_text = i18n.t(locale, "login_google_button"),
        .html_lang = html_lang,
        .login_title = i18n.t(locale, "login_title"),
        .login_subtitle = i18n.t(locale, "login_subtitle"),
        .login_terms = i18n.t(locale, "login_terms"),
        .login_footer = i18n.t(locale, "login_footer"),
    };
}
