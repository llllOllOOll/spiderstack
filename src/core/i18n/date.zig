const std = @import("std");
const i18n = @import("root.zig");
pub const Locale = i18n.Locale;

pub fn formatPeriod(locale: Locale, buf: []u8, from_day: u8, from_month: u8, from_year: u16, to_day: u8, to_month: u8, to_year: u16) ![]u8 {
    if (buf.len < 48) return error.BufferTooSmall;

    switch (locale) {
        .pt_BR => {
            return std.fmt.bufPrint(buf, "{d:0>2}/{d:0>2}/{d} a {d:0>2}/{d:0>2}/{d}", .{ from_day, from_month, from_year, to_day, to_month, to_year }) catch error.BufferTooSmall;
        },
        .en_US => {
            return std.fmt.bufPrint(buf, "{d:0>2}/{d:0>2}/{d} to {d:0>2}/{d:0>2}/{d}", .{ from_month, from_day, from_year, to_month, to_day, to_year }) catch error.BufferTooSmall;
        },
    }
}

pub fn formatMonthYear(locale: Locale, buf: []u8, month: u8, year: u16) ![]u8 {
    const month_name = i18n.monthName(locale, month);
    if (month_name.len == 0) return error.InvalidMonth;

    switch (locale) {
        .pt_BR => {
            if (buf.len < month_name.len + 5) return error.BufferTooSmall;
            return std.fmt.bufPrint(buf, "{s} {d}", .{ month_name, year }) catch error.BufferTooSmall;
        },
        .en_US => {
            if (buf.len < month_name.len + 6) return error.BufferTooSmall;
            return std.fmt.bufPrint(buf, "{s} {d}", .{ month_name, year }) catch error.BufferTooSmall;
        },
    }
}

test "formatPeriod pt_BR" {
    var buf: [48]u8 = undefined;
    const result = try formatPeriod(.pt_BR, &buf, 20, 7, 2025, 19, 8, 2025);
    try std.testing.expectEqualStrings("20/07/2025 a 19/08/2025", result);
}

test "formatPeriod en_US" {
    var buf: [48]u8 = undefined;
    const result = try formatPeriod(.en_US, &buf, 20, 7, 2025, 19, 8, 2025);
    try std.testing.expectEqualStrings("07/20/2025 to 08/19/2025", result);
}

test "formatPeriod buffer too small" {
    var buf: [47]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, formatPeriod(.pt_BR, &buf, 20, 7, 2025, 19, 8, 2025));
}

test "formatMonthYear pt_BR" {
    var buf: [20]u8 = undefined;
    const result = try formatMonthYear(.pt_BR, &buf, 7, 2025);
    try std.testing.expectEqualStrings("Julho 2025", result);
}

test "formatMonthYear en_US" {
    var buf: [20]u8 = undefined;
    const result = try formatMonthYear(.en_US, &buf, 7, 2025);
    try std.testing.expectEqualStrings("July 2025", result);
}

test "formatMonthYear invalid month" {
    var buf: [20]u8 = undefined;
    try std.testing.expectError(error.InvalidMonth, formatMonthYear(.pt_BR, &buf, 0, 2025));
    try std.testing.expectError(error.InvalidMonth, formatMonthYear(.en_US, &buf, 13, 2025));
}

test "formatMonthYear buffer too small" {
    var buf: [5]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, formatMonthYear(.pt_BR, &buf, 1, 2025));
}
