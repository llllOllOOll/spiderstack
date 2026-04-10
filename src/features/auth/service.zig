const std = @import("std");
const spider = @import("spider");
const google = spider.google;
const http_client = spider.http_client;

pub fn fetchGoogleProfile(alloc: std.mem.Allocator, code: []const u8, config: google.GoogleConfig) !google.GoogleProfile {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const token_body = try std.fmt.allocPrint(
        arena_allocator,
        "code={s}&client_id={s}&client_secret={s}&redirect_uri={s}&grant_type=authorization_code",
        .{ code, config.client_id, config.client_secret, config.redirect_uri },
    );

    const token_resp = try http_client.post(
        arena_allocator,
        "https://oauth2.googleapis.com/token",
        token_body,
        "application/x-www-form-urlencoded",
    );

    const TokenResponse = struct { access_token: []const u8 };
    const parsed_token = try std.json.parseFromSlice(TokenResponse, arena_allocator, token_resp, .{ .ignore_unknown_fields = true });
    defer parsed_token.deinit();

    const bearer = try std.fmt.allocPrint(arena_allocator, "Bearer {s}", .{parsed_token.value.access_token});
    const headers = [_]std.http.Header{.{ .name = "Authorization", .value = bearer }};

    const profile_resp = try http_client.get(
        arena_allocator,
        "https://www.googleapis.com/oauth2/v2/userinfo",
        &headers,
    );

    const RawProfile = struct {
        id: []const u8,
        email: []const u8,
        name: []const u8,
        picture: []const u8,
    };

    const parsed = try std.json.parseFromSlice(RawProfile, arena_allocator, profile_resp, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    return google.GoogleProfile{
        .id = try arena_allocator.dupe(u8, parsed.value.id),
        .email = try arena_allocator.dupe(u8, parsed.value.email),
        .name = try arena_allocator.dupe(u8, parsed.value.name),
        .picture = try arena_allocator.dupe(u8, parsed.value.picture),
    };
}
