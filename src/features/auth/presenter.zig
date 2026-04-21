const std = @import("std");
const spider = @import("spider");
const Request = spider.Request;
const i18n = @import("core").i18n;
const base_context = @import("core").context.base_context;

pub const LoginContext = struct {
    base: base_context.BaseContext,
    error_msg: ?[]const u8,
    google_auth_url: []const u8,
    google_button_text: []const u8,
    html_lang: []const u8,
    auth_page_title: []const u8,
    auth_subtitle: []const u8,
    login_tab: []const u8,
    register_tab: []const u8,
    name_label: []const u8,
    name_placeholder: []const u8,
    email_label: []const u8,
    email_placeholder: []const u8,
    password_label: []const u8,
    password_placeholder: []const u8,
    login_button: []const u8,
    register_button: []const u8,
    forgot_password_link: []const u8,
    forgot_password_title: []const u8,
    forgot_password_desc: []const u8,
    forgot_success_message: []const u8,
    send_reset_button: []const u8,
    back_to_login: []const u8,
    or_divider: []const u8,
    auth_terms: []const u8,
    login_footer: []const u8,
};

pub fn buildLoginContext(
    alloc: std.mem.Allocator,
    req: *Request,
    locale: i18n.Locale,
    email: []const u8,
    error_msg: ?[]const u8,
) !LoginContext {
    _ = email; // email not used in base context for public routes
    const base = try base_context.build(alloc, req, locale);

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
        .auth_page_title = i18n.t(locale, "auth_page_title"),
        .auth_subtitle = i18n.t(locale, "auth_subtitle"),
        .login_tab = i18n.t(locale, "login_tab"),
        .register_tab = i18n.t(locale, "register_tab"),
        .name_label = i18n.t(locale, "name_label"),
        .name_placeholder = i18n.t(locale, "name_placeholder"),
        .email_label = i18n.t(locale, "email_label"),
        .email_placeholder = i18n.t(locale, "email_placeholder"),
        .password_label = i18n.t(locale, "password_label"),
        .password_placeholder = i18n.t(locale, "password_placeholder"),
        .login_button = i18n.t(locale, "login_button"),
        .register_button = i18n.t(locale, "register_button"),
        .forgot_password_link = i18n.t(locale, "forgot_password_link"),
        .forgot_password_title = i18n.t(locale, "forgot_password_title"),
        .forgot_password_desc = i18n.t(locale, "forgot_password_desc"),
        .forgot_success_message = i18n.t(locale, "forgot_success_message"),
        .send_reset_button = i18n.t(locale, "send_reset_button"),
        .back_to_login = i18n.t(locale, "back_to_login"),
        .or_divider = i18n.t(locale, "or_divider"),
        .auth_terms = i18n.t(locale, "auth_terms"),
        .login_footer = i18n.t(locale, "login_footer"),
    };
}
