const std = @import("std");
const base_context = @import("core").context.base_context;
const BaseContext = base_context.BaseContext;
const i18n = @import("core").i18n;

const model = @import("model.zig");

pub const TodoContext = struct {
    base: BaseContext,
    todos: []const model.Todo,
};

pub fn buildContext(alloc: std.mem.Allocator, req: anytype, todos: []const model.Todo) !TodoContext {
    const locale_raw = req.locale orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);
    const base = try base_context.build(alloc, req, locale);

    return TodoContext{
        .base = base,
        .todos = todos,
    };
}
