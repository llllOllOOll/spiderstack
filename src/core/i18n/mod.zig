const std = @import("std");
const spider = @import("spider");
const Request = spider.Request;
const pt_BR = @import("locales/pt_BR.zig");
const en_US = @import("locales/en_US.zig");

pub const Locale = enum { pt_BR, en_US };

pub fn t(locale: Locale, comptime key: []const u8) []const u8 {
    switch (locale) {
        .pt_BR => return @field(pt_BR.strings, key),
        .en_US => return @field(en_US.strings, key),
    }
}

pub fn currencySymbol(locale: Locale) []const u8 {
    return switch (locale) {
        .pt_BR => "R$",
        .en_US => "$",
    };
}

pub fn formatCurrencyFloat(alloc: std.mem.Allocator, locale: Locale, amount: f64) ![]const u8 {
    const cents: i64 = @intFromFloat(amount * 100);
    var buf: [32]u8 = undefined;
    return alloc.dupe(u8, try formatCurrency(locale, cents, &buf));
}

pub fn formatCurrency(locale: Locale, amount_cents: i64, buf: []u8) ![]u8 {
    const symbol = currencySymbol(locale);
    const thousand_sep: u8 = switch (locale) {
        .pt_BR => '.',
        .en_US => ',',
    };
    const decimal_sep: u8 = switch (locale) {
        .pt_BR => ',',
        .en_US => '.',
    };

    const abs_cents: u64 = if (amount_cents < 0) @as(u64, @intCast(-amount_cents)) else @as(u64, @intCast(amount_cents));
    const int_part: u64 = abs_cents / 100;
    const cents: u8 = @intCast(abs_cents % 100);

    var pos: usize = 0;

    if (amount_cents < 0) {
        buf[pos] = '-';
        pos += 1;
    }

    @memcpy(buf[pos..][0..symbol.len], symbol);
    pos += symbol.len;

    if (locale == .pt_BR) {
        buf[pos] = ' ';
        pos += 1;
    }

    var temp: [20]u8 = undefined;
    var len: usize = 0;
    var n = int_part;
    if (n == 0) {
        temp[0] = '0';
        len = 1;
    } else while (n > 0) : (n /= 10) {
        temp[len] = '0' + @as(u8, @intCast(n % 10));
        len += 1;
    }

    var i: usize = len;
    while (i > 0) {
        i -= 1;
        buf[pos] = temp[i];
        pos += 1;
        if (i > 0 and i % 3 == 0) {
            buf[pos] = thousand_sep;
            pos += 1;
        }
    }

    buf[pos] = decimal_sep;
    pos += 1;
    buf[pos] = '0' + (cents / 10);
    buf[pos + 1] = '0' + (cents % 10);
    pos += 2;

    return buf[0..pos];
}

pub fn localeFromStr(s: []const u8) Locale {
    const normalized = normalized: {
        var buf: [10]u8 = .{0} ** 10;
        const len = @min(s.len, 10);
        @memcpy(buf[0..len], s);
        for (buf[0..len]) |*c| {
            c.* = std.ascii.toLower(c.*);
        }
        break :normalized buf[0..len];
    };

    if (std.mem.eql(u8, normalized, "pt_br") or std.mem.eql(u8, normalized, "pt-br") or std.mem.eql(u8, normalized, "pt")) {
        return .pt_BR;
    }
    if (std.mem.eql(u8, normalized, "en_us") or std.mem.eql(u8, normalized, "en-us") or std.mem.eql(u8, normalized, "en")) {
        return .en_US;
    }
    return .pt_BR;
}

pub fn monthName(locale: Locale, month: u8) []const u8 {
    if (month < 1 or month > 12) return "";
    switch (locale) {
        .pt_BR => {
            const months_full = [_][]const u8{
                t(.pt_BR, "month_jan"), t(.pt_BR, "month_feb"), t(.pt_BR, "month_mar"),
                t(.pt_BR, "month_apr"), t(.pt_BR, "month_may"), t(.pt_BR, "month_jun"),
                t(.pt_BR, "month_jul"), t(.pt_BR, "month_aug"), t(.pt_BR, "month_sep"),
                t(.pt_BR, "month_oct"), t(.pt_BR, "month_nov"), t(.pt_BR, "month_dec"),
            };
            return months_full[month - 1];
        },
        .en_US => {
            const months_full = [_][]const u8{
                t(.en_US, "month_jan"), t(.en_US, "month_feb"), t(.en_US, "month_mar"),
                t(.en_US, "month_apr"), t(.en_US, "month_may"), t(.en_US, "month_jun"),
                t(.en_US, "month_jul"), t(.en_US, "month_aug"), t(.en_US, "month_sep"),
                t(.en_US, "month_oct"), t(.en_US, "month_nov"), t(.en_US, "month_dec"),
            };
            return months_full[month - 1];
        },
    }
}

pub fn monthShort(locale: Locale, month: u8) []const u8 {
    if (month < 1 or month > 12) return "";
    switch (locale) {
        .pt_BR => {
            const months_short = [_][]const u8{
                t(.pt_BR, "month_short_jan"), t(.pt_BR, "month_short_feb"), t(.pt_BR, "month_short_mar"),
                t(.pt_BR, "month_short_apr"), t(.pt_BR, "month_short_may"), t(.pt_BR, "month_short_jun"),
                t(.pt_BR, "month_short_jul"), t(.pt_BR, "month_short_aug"), t(.pt_BR, "month_short_sep"),
                t(.pt_BR, "month_short_oct"), t(.pt_BR, "month_short_nov"), t(.pt_BR, "month_short_dec"),
            };
            return months_short[month - 1];
        },
        .en_US => {
            const months_short = [_][]const u8{
                t(.en_US, "month_short_jan"), t(.en_US, "month_short_feb"), t(.en_US, "month_short_mar"),
                t(.en_US, "month_short_apr"), t(.en_US, "month_short_may"), t(.en_US, "month_short_jun"),
                t(.en_US, "month_short_jul"), t(.en_US, "month_short_aug"), t(.en_US, "month_short_sep"),
                t(.en_US, "month_short_oct"), t(.en_US, "month_short_nov"), t(.en_US, "month_short_dec"),
            };
            return months_short[month - 1];
        },
    }
}

test "t returns correct string for pt_BR" {
    try std.testing.expectEqualStrings("Visão Geral", t(.pt_BR, "nav_overview"));
    try std.testing.expectEqualStrings("Contas", t(.pt_BR, "nav_accounts"));
    try std.testing.expectEqualStrings("Perfil", t(.pt_BR, "nav_profile"));
}

test "t returns correct string for en_US" {
    try std.testing.expectEqualStrings("Overview", t(.en_US, "nav_overview"));
    try std.testing.expectEqualStrings("Accounts", t(.en_US, "nav_accounts"));
    try std.testing.expectEqualStrings("Profile", t(.en_US, "nav_profile"));
}

test "currencySymbol returns correct symbol for each locale" {
    try std.testing.expectEqualStrings("R$", currencySymbol(.pt_BR));
    try std.testing.expectEqualStrings("$", currencySymbol(.en_US));
}

test "formatCurrency formats correctly for pt_BR" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("R$ 1.234.567,89", try formatCurrency(.pt_BR, 123456789, &buf));
    try std.testing.expectEqualStrings("R$ 100,00", try formatCurrency(.pt_BR, 10000, &buf));
    try std.testing.expectEqualStrings("-R$ 50,99", try formatCurrency(.pt_BR, -5099, &buf));
    try std.testing.expectEqualStrings("R$ 0,00", try formatCurrency(.pt_BR, 0, &buf));
}

test "formatCurrency formats correctly for en_US" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("$1,234,567.89", try formatCurrency(.en_US, 123456789, &buf));
    try std.testing.expectEqualStrings("$100.00", try formatCurrency(.en_US, 10000, &buf));
    try std.testing.expectEqualStrings("-$50.99", try formatCurrency(.en_US, -5099, &buf));
    try std.testing.expectEqualStrings("$0.00", try formatCurrency(.en_US, 0, &buf));
}

test "localeFromStr handles pt_BR variants" {
    try std.testing.expectEqual(.pt_BR, localeFromStr("pt_BR"));
    try std.testing.expectEqual(.pt_BR, localeFromStr("pt-BR"));
    try std.testing.expectEqual(.pt_BR, localeFromStr("pt"));
    try std.testing.expectEqual(.pt_BR, localeFromStr("PT_BR"));
}

test "localeFromStr handles en_US variants" {
    try std.testing.expectEqual(.en_US, localeFromStr("en_US"));
    try std.testing.expectEqual(.en_US, localeFromStr("en-US"));
    try std.testing.expectEqual(.en_US, localeFromStr("en"));
    try std.testing.expectEqual(.en_US, localeFromStr("EN"));
}

test "localeFromStr fallback for unknown" {
    try std.testing.expectEqual(.pt_BR, localeFromStr("fr"));
    try std.testing.expectEqual(.pt_BR, localeFromStr("unknown"));
    try std.testing.expectEqual(.pt_BR, localeFromStr(""));
}

test "monthName returns correct month for pt_BR" {
    try std.testing.expectEqualStrings("Janeiro", monthName(.pt_BR, 1));
    try std.testing.expectEqualStrings("Julho", monthName(.pt_BR, 7));
    try std.testing.expectEqualStrings("Dezembro", monthName(.pt_BR, 12));
}

test "monthName returns correct month for en_US" {
    try std.testing.expectEqualStrings("January", monthName(.en_US, 1));
    try std.testing.expectEqualStrings("July", monthName(.en_US, 7));
    try std.testing.expectEqualStrings("December", monthName(.en_US, 12));
}

test "monthName returns empty for invalid month" {
    try std.testing.expectEqualStrings("", monthName(.pt_BR, 0));
    try std.testing.expectEqualStrings("", monthName(.pt_BR, 13));
    try std.testing.expectEqualStrings("", monthName(.en_US, 0));
    try std.testing.expectEqualStrings("", monthName(.en_US, 255));
}

test "monthShort returns correct month for pt_BR" {
    try std.testing.expectEqualStrings("jan", monthShort(.pt_BR, 1));
    try std.testing.expectEqualStrings("jul", monthShort(.pt_BR, 7));
    try std.testing.expectEqualStrings("dez", monthShort(.pt_BR, 12));
}

test "monthShort returns correct month for en_US" {
    try std.testing.expectEqualStrings("jan", monthShort(.en_US, 1));
    try std.testing.expectEqualStrings("jul", monthShort(.en_US, 7));
    try std.testing.expectEqualStrings("dec", monthShort(.en_US, 12));
}

test "monthShort returns empty for invalid month" {
    try std.testing.expectEqualStrings("", monthShort(.pt_BR, 0));
    try std.testing.expectEqualStrings("", monthShort(.pt_BR, 99));
    try std.testing.expectEqualStrings("", monthShort(.en_US, 0));
    try std.testing.expectEqualStrings("", monthShort(.en_US, 13));
}

pub fn resolveLocale(user: anytype, req: *Request) Locale {
    const header_locale = req.locale;
    return if (user.locale_set)
        localeFromStr(user.locale)
    else if (header_locale) |hl|
        localeFromStr(hl)
    else
        .pt_BR;
}
