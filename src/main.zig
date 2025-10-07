const std = @import("std");
const player = @import("ffi.zig");
const common = @import("common.zig");

const Error = error {
    missing_param,
    sem_open_failed,
    sem_wait_failed,
};

const alloc = std.heap.smp_allocator;
var log_file: ?std.fs.File = null;
var sem_lock: ?*std.c.sem_t = null;

export fn playback_end() void {
    if (sem_lock) |sl| {
        const result: c_int = std.c.sem_post(sl);
        if (result != 0) {
            log_to_file("playback_cli: sem_post on playback end failed: code({})\n", .{std.posix.errno(-1)});
        }
    }
}

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
    const file_name: ?[:0]const u8 = args.next();
    if (file_name == null) {
        std.log.err("A filename of the song to play is a required parameter.\n", .{});
        return Error.missing_param;
    }

    const log_file_name: ?[:0]const u8 = args.next();
    if (log_file_name) |log_fn| {
        log_file = try std.fs.openFileAbsoluteZ(log_fn, .{.mode = .read_write});
    }

    // get our shared memory file descriptor
    const shm_fd = std.c.shm_open(
        common.shm_name,
        common.RDWR | common.CREAT,
        std.c.S.IRUSR | std.c.S.IWUSR,
    );
    const mapping: std.c.MAP = .{
        .TYPE = .SHARED,
    };
    // grab the shared memory
    const mem_op: *anyopaque = std.c.mmap(
        null,
        @sizeOf(common.SharedMem),
        std.c.PROT.READ | std.c.PROT.WRITE,
        mapping,
        shm_fd,
        0,
    );
    const mem: *common.SharedMem = @ptrCast(@alignCast(mem_op));
    //defer std.c.munmap(mem, @sizeOf(common.SharedMem));
    // local memory copy
    var local_mem: common.SharedMem = .{
        .is_playing = mem.is_playing,
        .volume = mem.volume,
        .should_stop = mem.should_stop,
        .sem_lock = mem.sem_lock,
        .length = 0,
    };
    // acquire the shared semaphore
    sem_lock = std.c.sem_open(common.sem_name, 0, 0, 0);
    if (sem_lock == null) {
        log_to_file("sem_open failed: code({})\n", .{std.posix.errno(-1)});
        return  Error.sem_open_failed;
    }
    defer _ = std.c.sem_close(sem_lock.?);
    // setup player
    player.setup(playback_end);
    defer player.deinit();
    // play the song.
    if (player.play(file_name.?) == 0) {
        log_to_file("failed to play song.\n", .{});
        return;
    }
    // set the volume to whatever is set.
    player.set_volume(local_mem.volume);
    // set audio length.
    mem.length = player.get_audio_length();
    local_mem.length = mem.length;

    while (player.has_stopped() != 1) {
        // block until controller sends an update.
        if (sem_lock) |sl| {
            // TODO rework ffi.zig to allow for a notify function which can call std.c.sem_post
            // to allow this to unblock if we've encountered an AT_END error.
            const wait_res: c_int = std.c.sem_wait(sl);
            if (wait_res != 0) {
                log_to_file("failed to sem_wait: {any}\n", .{std.posix.errno(-1)});
                return Error.sem_wait_failed;
            }
        }

        if (mem.is_playing != local_mem.is_playing) {
            local_mem.is_playing = mem.is_playing;
            if (local_mem.is_playing) {
                player.@"resume"();
            } else {
                player.pause();
            }
        }
        if (mem.volume != local_mem.volume) {
            local_mem.volume = mem.volume;
            player.set_volume(local_mem.volume);
        }
        if (mem.should_stop) {
            _ = player.stop();
            break;
        }
    }
}
