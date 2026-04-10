const std = @import("std");
const google = @import("spider").google;
const repository = @import("../repository.zig");
const model = @import("../model.zig");

pub fn findOrCreateOAuthUser(alloc: std.mem.Allocator, profile: google.GoogleProfile) !model.User {
    if (try repository.findByGoogleId(alloc, profile.id)) |user| {
        return user;
    }

    if (try repository.findByEmail(alloc, profile.email)) |user| {
        return repository.updateUser(alloc, user.id, .{
            .google_id = profile.id,
            .avatar_url = profile.picture,
        });
    }

    return repository.createOAuthUser(alloc, profile.email, profile.name, profile.id, profile.picture);
}
