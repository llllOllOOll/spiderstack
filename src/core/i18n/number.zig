const std = @import("std");
const i18n = @import("root.zig");
pub const Locale = i18n.Locale;

pub fn formatPercent(locale: Locale, buf: []u8, value: f64) ![]u8 {
    _ = locale;
    var pos: usize = 0;
    if (value < 0) {
        if (pos >= buf.len) return error.BufferTooSmall;
        buf[pos] = '-';
        pos += 1;
    } else {
        if (pos >= buf.len) return error.BufferTooSmall;
        buf[pos] = '+';
        pos += 1;
    }

    const abs_value = @abs(value);
    if (pos + 5 > buf.len) return error.BufferTooSmall;
    const int_part: u64 = @intFromFloat(@floor(abs_value));
    const frac: u8 = @intFromFloat(@round((abs_value - @as(f64, @floatFromInt(int_part))) * 10));

    var i: u64 = int_part;
    var digits: [15]u8 = undefined;
    var digit_count: usize = 0;
    if (i == 0) {
        digits[0] = '0';
        digit_count = 1;
    } else {
        while (i > 0) {
            digits[digit_count] = '0' + @as(u8, @intCast(i % 10));
            digit_count += 1;
            i /= 10;
        }
    }

    var j = digit_count;
    while (j > 0) {
        j -= 1;
        buf[pos] = digits[j];
        pos += 1;
    }

    buf[pos] = '.';
    buf[pos + 1] = '0' + frac;
    buf[pos + 2] = '%';
    pos += 3;

    return buf[0..pos];
}

pub fn formatDecimal(locale: Locale, buf: []u8, cents: i64) ![]u8 {
    const is_negative = cents < 0;
    const abs_cents: u64 = @intCast(if (is_negative) -cents else cents);

    const int_part: u64 = abs_cents / 100;
    const frac_part: u8 = @intCast(abs_cents % 100);

    var pos: usize = 0;

    if (is_negative) {
        if (pos >= buf.len) return error.BufferTooSmall;
        buf[pos] = '-';
        pos += 1;
    }

    var temp: [20]u8 = undefined;
    var len: usize = 0;
    var n = int_part;
    if (n == 0) {
        temp[0] = '0';
        len = 1;
    } else {
        while (n > 0) : (n /= 10) {
            temp[len] = '0' + @as(u8, @intCast(n % 10));
            len += 1;
        }
    }

    switch (locale) {
        .pt_BR => {
            var digits_before_dot: usize = len % 3;
            if (digits_before_dot == 0) digits_before_dot = if (len > 0) 3 else 0;

            var written: usize = 0;
            for (0..len) |idx| {
                const digit_idx = len - 1 - idx;
                if (idx == digits_before_dot and idx > 0) {
                    if (pos >= buf.len) return error.BufferTooSmall;
                    buf[pos] = '.';
                    pos += 1;
                    digits_before_dot += 3;
                }
                if (pos >= buf.len) return error.BufferTooSmall;
                buf[pos] = temp[digit_idx];
                pos += 1;
                written += 1;
            }
            if (pos + 3 > buf.len) return error.BufferTooSmall;
            buf[pos] = ',';
            buf[pos + 1] = '0' + (frac_part / 10);
            buf[pos + 2] = '0' + (frac_part % 10);
            pos += 3;
        },
        .en_US => {
            var digits_before_comma: usize = len % 3;
            if (digits_before_comma == 0) digits_before_comma = if (len > 0) 3 else 0;

            for (0..len) |idx| {
                const digit_idx = len - 1 - idx;
                if (idx == digits_before_comma and idx > 0) {
                    if (pos >= buf.len) return error.BufferTooSmall;
                    buf[pos] = ',';
                    pos += 1;
                    digits_before_comma += 3;
                }
                if (pos >= buf.len) return error.BufferTooSmall;
                buf[pos] = temp[digit_idx];
                pos += 1;
            }
            if (pos + 3 > buf.len) return error.BufferTooSmall;
            buf[pos] = '.';
            buf[pos + 1] = '0' + (frac_part / 10);
            buf[pos + 2] = '0' + (frac_part % 10);
            pos += 3;
        },
    }

    return buf[0..pos];
}

test "formatPercent positive" {
    var buf: [10]u8 = undefined;
    const result = try formatPercent(.pt_BR, &buf, 18.0);
    try std.testing.expectEqualStrings("+18.0%", result);
}

test "formatPercent negative" {
    var buf: [10]u8 = undefined;
    const result = try formatPercent(.pt_BR, &buf, -5.5);
    try std.testing.expectEqualStrings("-5.5%", result);
}

test "formatPercent zero" {
    var buf: [10]u8 = undefined;
    const result = try formatPercent(.en_US, &buf, 0.0);
    try std.testing.expectEqualStrings("+0.0%", result);
}

test "formatPercent buffer too small" {
    var buf: [3]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, formatPercent(.pt_BR, &buf, 10.0));
}

test "formatDecimal pt_BR" {
    var buf: [20]u8 = undefined;
    const result = try formatDecimal(.pt_BR, &buf, 123450);
    try std.testing.expectEqualStrings("1.234,50", result);
}

test "formatDecimal en_US" {
    var buf: [20]u8 = undefined;
    const result = try formatDecimal(.en_US, &buf, 123450);
    try std.testing.expectEqualStrings("1,234.50", result);
}

test "formatDecimal negative pt_BR" {
    var buf: [20]u8 = undefined;
    const result = try formatDecimal(.pt_BR, &buf, -123450);
    try std.testing.expectEqualStrings("-1.234,50", result);
}

test "formatDecimal zero" {
    var buf: [20]u8 = undefined;
    const result = try formatDecimal(.pt_BR, &buf, 0);
    try std.testing.expectEqualStrings("0,00", result);
}

test "formatDecimal buffer too small" {
    var buf: [3]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, formatDecimal(.pt_BR, &buf, 100));
}

test "formatDecimal small number" {
    var buf: [20]u8 = undefined;
    const result = try formatDecimal(.pt_BR, &buf, 10050);
    try std.testing.expectEqualStrings("100,50", result);
}
