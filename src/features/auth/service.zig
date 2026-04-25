const std = @import("std");
const spider = @import("spider");
const google = spider.google;
const http_client = spider.http_client;

pub fn fetchGoogleProfile(alloc: std.mem.Allocator, io: std.Io, code: []const u8, config: google.GoogleConfig) !google.GoogleProfile {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Request access token using pacman
    var token_res = try http_client.post(io, arena_allocator, "https://oauth2.googleapis.com/token", .{
        .body = .{ .form = &.{
            .{ "code", code },
            .{ "client_id", config.client_id },
            .{ "client_secret", config.client_secret },
            .{ "redirect_uri", config.redirect_uri },
            .{ "grant_type", "authorization_code" },
        } },
    });
    defer token_res.deinit();

    const TokenResponse = struct { access_token: []const u8 };
    const parsed_token = try token_res.json(TokenResponse);
    defer parsed_token.deinit();

    // Request user profile using pacman
    var profile_res = try http_client.get(io, arena_allocator, "https://www.googleapis.com/oauth2/v2/userinfo", .{
        .headers = &.{.{ .name = "Authorization", .value = try std.fmt.allocPrint(arena_allocator, "Bearer {s}", .{parsed_token.value.access_token}) }},
    });
    defer profile_res.deinit();

    const RawProfile = struct {
        id: []const u8,
        email: []const u8,
        name: []const u8,
        picture: []const u8,
    };
    const parsed_profile = try profile_res.json(RawProfile);
    defer parsed_profile.deinit();

    return google.GoogleProfile{
        .id = try alloc.dupe(u8, parsed_profile.value.id),
        .email = try alloc.dupe(u8, parsed_profile.value.email),
        .name = try alloc.dupe(u8, parsed_profile.value.name),
        .picture = try alloc.dupe(u8, parsed_profile.value.picture),
    };
}
