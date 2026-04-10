const std = @import("std");
const i18n = @import("../i18n/mod.zig");
// const User = @import("../models/user.zig").User;
// const getInitials = @import("../helpers.zig").getInitials;

pub const BaseContext = struct {
    locale: i18n.Locale,
    nav_overview: []const u8,
    nav_accounts: []const u8,
    nav_transactions: []const u8,
    nav_recurring: []const u8,
    nav_bills: []const u8,
    nav_receivables: []const u8,
    nav_budget: []const u8,
    nav_categories: []const u8,
    nav_profile: []const u8,
    nav_search: []const u8,
    nav_settings: []const u8,
    dropdown_profile: []const u8,
    dropdown_logout: []const u8,
    user_name: []const u8,
    user_email: []const u8,
    user_avatar: []const u8,
    user_initials: [2]u8,
    dashboard_empty_month: []const u8,
};

/// Builds the base layout context for rendering.
///
/// All fields are either static strings (i18n keys resolved at comptime),
/// slices borrowed from `user` (owned by the caller), or value types ([2]u8).
/// No heap allocation is needed, so `arena` is intentionally unused.
/// If future fields require dynamic formatting, use `arena` at that point.
pub fn build(_: std.mem.Allocator, user: anytype, locale: i18n.Locale) !BaseContext {
    return BaseContext{
        .locale = locale,
        .nav_overview = i18n.t(locale, "nav_overview"),
        .nav_accounts = i18n.t(locale, "nav_accounts"),
        .nav_transactions = i18n.t(locale, "nav_transactions"),
        .nav_recurring = i18n.t(locale, "nav_recurring"),
        .nav_bills = i18n.t(locale, "nav_bills"),
        .nav_receivables = i18n.t(locale, "nav_receivables"),
        .nav_budget = i18n.t(locale, "nav_budget"),
        .nav_categories = i18n.t(locale, "nav_categories"),
        .nav_profile = i18n.t(locale, "nav_profile"),
        .nav_search = i18n.t(locale, "nav_search"),
        .nav_settings = i18n.t(locale, "nav_settings"),
        .dropdown_profile = i18n.t(locale, "dropdown_profile"),
        .dropdown_logout = i18n.t(locale, "dropdown_logout"),
        .user_name = user.name,
        .user_email = user.email,
        .user_avatar = user.avatar_url orelse "",
        .user_initials = getInitials(user.name),
        .dashboard_empty_month = i18n.t(locale, "dashboard_empty_month"),
    };
}

pub fn getInitials(name: []const u8) [2]u8 {
    var result: [2]u8 = .{ '?', ' ' };
    var iter = std.mem.splitSequence(u8, name, " ");
    if (iter.next()) |first| {
        if (first.len > 0) result[0] = std.ascii.toUpper(first[0]);
    }
    if (iter.next()) |second| {
        if (second.len > 0) result[1] = std.ascii.toUpper(second[0]);
    }
    return result;
}
