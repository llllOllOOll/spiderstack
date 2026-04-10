const std = @import("std");
const i18n = @import("core").i18n;
const base_context = @import("core").context.base_context;
const model = @import("model.zig");

pub const GameRow = struct {
    id: i32,
    rank: i32,
    name: []const u8,
    platform: []const u8,
    release_year: i32,
    genre: []const u8,
    developer: []const u8,
    sales: []const u8,
    rating: []const u8,
};

pub const GameListContext = struct {
    base: base_context.BaseContext,
    games: []GameRow,
    page_title: []const u8,
    empty_message: []const u8,
};

pub fn toRow(alloc: std.mem.Allocator, game: anytype, rank: i32, locale: i18n.Locale) !GameRow {
    _ = locale;
    const sales_str = try std.fmt.allocPrint(alloc, "{d:.2}", .{game.sales_millions});
    const rating_str = try std.fmt.allocPrint(alloc, "{d:.1}", .{game.rating});
    return GameRow{
        .id = game.id,
        .rank = rank,
        .name = game.name,
        .platform = game.platform,
        .release_year = game.release_year,
        .genre = game.genre,
        .developer = game.developer,
        .sales = sales_str,
        .rating = rating_str,
    };
}

pub fn buildGameListContext(
    alloc: std.mem.Allocator,
    user: anytype,
    locale: i18n.Locale,
    games: []const model.Game,
) !GameListContext {
    const base = try base_context.build(alloc, user, locale);

    var rows = try std.ArrayList(GameRow).initCapacity(alloc, games.len);
    errdefer rows.deinit(alloc);

    var rank: i32 = 1;
    for (games) |game| {
        const row = try toRow(alloc, game, rank, locale);
        try rows.append(alloc, row);
        rank += 1;
    }

    return GameListContext{
        .base = base,
        .games = rows.items,
        .page_title = i18n.t(locale, "games_title"),
        .empty_message = i18n.t(locale, "games_empty"),
    };
}
