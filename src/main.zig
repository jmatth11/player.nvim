const std = @import("std");
const player = @import("ffi.zig");
const common = @import("common.zig");

/// Error values.
const Error = error {
    /// Missing the param for the CLI
    missing_param,
    /// Shared Memory acquire failed.
    shm_failed,
    /// Semaphore open failed.
    sem_open_failed,
    /// Semaphore wait failed.
    sem_wait_failed,
};

const alloc = std.heap.smp_allocator;
/// log file
var log_file: ?std.fs.File = null;
/// The shared memory object.
var mem: ?*common.SharedMem = null;
/// The semaphore value.
var sem_lock: ?*std.c.sem_t = null;

/// Playback callback
export fn playback_cb(elapsed_time: f64, ended: bool) void {
    if (ended) {
        if (sem_lock) |sl| {
            // unblock our main thread if the audio has ended.
            const result: c_int = std.c.sem_post(sl);
            if (result != 0) {
                log_to_file("playback_cli: sem_post on playback end failed: code({})\n", .{std.posix.errno(-1)});
            }
        }
    } else {
        if (mem) |m| {
            m.playtime += elapsed_time;
        }
    }
}

/// Convenience function to log messages to a file.
fn log_to_file(comptime fmt: []const u8, args: anytype) void {
    if (log_file) |lf| {
        const buf = std.fmt.allocPrint(alloc, fmt, args) catch unreachable;
        defer alloc.free(buf);
        _ = lf.write(buf) catch unreachable;
    }
    std.log.info(fmt, args);
}

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();
    if (!args.skip()) {
        std.log.err("A filename of the song to play is a required parameter.\n", .{});
        return Error.missing_param;
    }
    // song file name
    const file_name: ?[:0]const u8 = args.next();
    if (file_name == null) {
        std.log.err("A filename of the song to play is a required parameter.\n", .{});
        return Error.missing_param;
    }

    // optional log file
    const log_file_name: ?[:0]const u8 = args.next();
    if (log_file_name) |log_fn| {
        log_file = try std.fs.openFileAbsoluteZ(log_fn, .{.mode = .read_write});
    }

    // get our shared memory file descriptor
    const shm_fd = std.c.shm_open(
        common.shm_name,
        common.RDWR, // read/write
        std.c.S.IRUSR | std.c.S.IWUSR,
    );
    const mapping: std.c.MAP = .{
        .TYPE = .SHARED,
    };
    // grab the shared memory
    const mem_op: ?*anyopaque = std.c.mmap(
        null,
        @sizeOf(common.SharedMem),
        std.c.PROT.READ | std.c.PROT.WRITE,
        mapping,
        shm_fd,
        0,
    );
    if (mem_op == null) {
        log_to_file("player_cli: shared memory was null\n", .{});
        return Error.shm_failed;
    }
    mem = @ptrCast(@alignCast(mem_op.?));
    // local memory copy
    var local_mem: common.SharedMem = undefined;
    if (mem) |m| {
        local_mem = .{
            .is_playing = m.is_playing,
            .volume = m.volume,
            .should_stop = m.should_stop,
            .sem_lock = m.sem_lock,
            .length = 0,
            .playtime = 0,
        };
        // reset playtime
        m.playtime = 0;
    }
    // acquire the shared semaphore
    sem_lock = std.c.sem_open(common.sem_name, 0, 0, 0);
    if (sem_lock == null) {
        log_to_file("sem_open failed: code({})\n", .{std.posix.errno(-1)});
        return  Error.sem_open_failed;
    }
    defer _ = std.c.sem_close(sem_lock.?);
    // setup player
    player.setup(playback_cb);
    defer player.deinit();
    // play the song.
    if (player.play(file_name.?) == 0) {
        log_to_file("failed to play song.\n", .{});
        return;
    }
    if (mem) |m| {
        // set the volume to whatever is set.
        player.set_volume(local_mem.volume);
        // set audio length.
        m.length = player.get_audio_length();
        local_mem.length = m.length;
    }

    // main loop
    while (player.has_stopped() != 1) {
        // block until controller sends an update.
        if (sem_lock) |sl| {
            // wait for semaphore update
            const wait_res: c_int = std.c.sem_wait(sl);
            if (wait_res != 0) {
                log_to_file("failed to sem_wait: {any}\n", .{std.posix.errno(-1)});
                return Error.sem_wait_failed;
            }
        }

        if (mem) |m| {
            // check for updated states and apply them
            if (m.is_playing != local_mem.is_playing) {
                local_mem.is_playing = m.is_playing;
                if (local_mem.is_playing) {
                    player.@"resume"();
                } else {
                    player.pause();
                }
            }
            if (m.volume != local_mem.volume) {
                local_mem.volume = m.volume;
                player.set_volume(local_mem.volume);
            }
            if (m.should_stop) {
                _ = player.stop();
                break;
            }
        }
    }
}
