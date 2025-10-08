const std = @import("std");

pub const c = @cImport({
    @cInclude("play.h");
});

/// Playback callback for the player.
pub const playback_cb = *const fn(elapsed_time: f64, ended: bool) callconv(.c) void;

/// The singleton player instance.
var player: ?*c.player_t = null;

/// Setup the player.
///
/// @param cb The playback callback.
pub export fn setup(cb: playback_cb) void {
    if (player == null) {
        player = c.player_create(@ptrCast(cb));
    }
}

/// Play the given song with the player.
///
/// @param file_name The song filename.
/// @return 1 for success, 0 for failure.
pub export fn play(file_name: [*:0]const u8) c_int {
    if (player == null) {
        return 0;
    }
    if (!c.player_play(player, file_name)) {
        std.log.err("failed to play file", .{});
        return 0;
    }
    return 1;
}

/// Pause the player.
pub export fn pause() void {
    if (player) |p| {
        c.player_pause(p);
    }
}

/// Resume the player.
pub export fn @"resume"() void {
    if (player) |p| {
        c.player_resume(p);
    }
}

/// Stop the player.
///
/// @return 1 for success, 0 for failure.
pub export fn stop() c_int {
    if (player) |p| {
        if (!c.player_stop(p)) {
            return 0;
        }
    }
    return 1;
}

/// Flag for if the player has stopped.
///
/// @return 1 for true, 0 for false.
pub export fn has_stopped() c_int {
    if (player) |p| {
        return @intFromBool(c.player_has_stopped(p));
    }
    return 0;
}

/// Get the volume of the player.
pub export fn get_volume() f32 {
    if (player) |p| {
        return c.player_get_volume(p);
    }
    return 0.0;
}

/// Get the current playtime of the audio in seconds.
pub export fn get_current_playtime() u64 {
    if (player) |p| {
        var playtime: u64 = 0;
        if (!c.player_get_current_playtime(p, &playtime)) {
            return 0;
        }
        return playtime;
    }
    return 0;
}

/// Get the total time of the audio in seconds.
pub export fn get_audio_length() u64 {
    if (player) |p| {
        var length: u64 = 0;
        if (!c.player_get_length(p, &length)) {
            return 0;
        }
        return length;
    }
    return 0;
}

/// Set the volume of the player.
///
/// @param vol The volume. value between 0 - 1.
pub export fn set_volume(vol: f32) void {
    if (player) |p| {
        c.player_set_volume(p, @floatCast(vol));
    }
}

/// Deinitialize the player instance.
pub export fn deinit() void {
    if (player != null) {
        c.player_destroy(&player);
    }
}

/// Get the version number.
pub export fn version() [*:0]const u8 {
    // push string to be a return value
    return "0.0.1";
}
