const std = @import("std");

pub const c = @cImport({
    @cInclude("play.h");
});

var player: ?*c.player_t = null;

export fn setup() void {
    if (player == null) {
        player = c.player_create();
    }
}

export fn play(file_name: [*:0]const u8) c_int {
    if (player == null) {
        player = c.player_create();
    }
    if (!c.player_play(player, file_name)) {
        std.debug.print("failed to play file", .{});
        return 0;
    }
    return 1;
}

export fn pause() c_int {
    if (player) |p| {
        if (!c.player_pause(p)) {
            return 0;
        }
    } else {
        return 0;
    }
    return 1;
}

export fn get_volume() f32 {
    if (player) |p| {
        return c.player_get_volume(p);
    }
    return 0.0;
}
export fn set_volume(vol: f32) void {
    if (player) |p| {
        c.player_set_volume(p, @floatCast(vol));
    }
}

export fn deinit() void {
    if (player != null) {
        c.player_destroy(&player);
    }
}

export fn version() [*:0]const u8 {
    // push string to be a return value
    return "0.0.1";
}

