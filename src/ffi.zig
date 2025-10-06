const std = @import("std");

pub const c = @cImport({
    @cInclude("play.h");
});

var player: ?*c.player_t = null;

pub export fn setup() void {
    if (player == null) {
        player = c.player_create();
    }
}

pub export fn play(file_name: [*:0]const u8) c_int {
    if (player == null) {
        player = c.player_create();
    }
    if (!c.player_play(player, file_name)) {
        std.debug.print("failed to play file", .{});
        return 0;
    }
    return 1;
}

pub export fn pause() void {
    if (player) |p| {
        c.player_pause(p);
    }
}

pub export fn @"resume"() void {
    if (player) |p| {
        c.player_resume(p);
    }
}

pub export fn stop() c_int {
    if (player) |p| {
        if (!c.player_stop(p)) {
            return 0;
        }
    }
    return 1;
}

pub export fn has_stopped() c_int {
    if (player) |p| {
        return @intFromBool(c.player_has_stopped(p));
    }
    return 0;
}

pub export fn get_volume() f32 {
    if (player) |p| {
        return c.player_get_volume(p);
    }
    return 0.0;
}
pub export fn set_volume(vol: f32) void {
    if (player) |p| {
        c.player_set_volume(p, @floatCast(vol));
    }
}

pub export fn deinit() void {
    if (player != null) {
        c.player_destroy(&player);
    }
}

pub export fn version() [*:0]const u8 {
    // push string to be a return value
    return "0.0.1";
}
