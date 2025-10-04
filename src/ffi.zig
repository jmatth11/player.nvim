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

export fn get_volume() f32 {
    return c.player_get_volume(player);
}
export fn set_volume(vol: f32) void {
    c.player_set_volume(player, @floatCast(vol));
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

