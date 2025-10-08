const std = @import("std");
const common = @import("common.zig");

const alloc = std.heap.smp_allocator;

/// State object of the plugin.
const State = struct {
    /// The semaphore.
    sem_lock: ?*std.c.sem_t,
    /// The shared memory file descriptor.
    shm_fd: ?c_int,
    /// The shared memory.
    mem: ?*common.SharedMem,
    /// The child process of the player.
    proc: ?std.process.Child,
    /// The player_cli executable path.
    exe_path: []const u8,
    /// The Log File.
    log_file: std.fs.File,
    /// The log file path name.
    log_file_name: []const u8,
};

/// The plugin state instance.
var state: State = .{
    .sem_lock = null,
    .shm_fd = null,
    .mem = null,
    .proc = null,
    .exe_path = undefined,
    .log_file = undefined,
    .log_file_name = undefined,
};

/// Convenience function to log a message to a file.
fn log_to_file(comptime fmt: []const u8, args: anytype) void {
    const buf = std.fmt.allocPrint(alloc, fmt, args) catch unreachable;
    _ = state.log_file.write(buf) catch unreachable;
}

/// Setup the player plugin.
///
/// @param root_dir The root directory of the plugin.
/// @return 0 for success, Less than 0 for any error.
export fn setup(root_dir: [*:0]const u8) c_int {
    const root: []const u8 = std.mem.span(root_dir);
    const log_file = std.fs.path.join(alloc, &.{
        root,
        "../../player.log",
    }) catch |err| {
        std.log.err("failed to join path for executable. {any}\n", .{err});
        return -1;
    };
    state.log_file_name = log_file;
    // TODO test switching to openFile variant so we don't overwrite the file everytime
    state.log_file = std.fs.createFileAbsolute(log_file, .{
        .truncate = false,
    }) catch |err| {
        std.log.err("failed to create log file: {any}.\n", .{err});
        return -2;
    };
    const exe = std.fs.path.join(alloc, &.{
        root,
        "../../zig-out/bin/player_cli",
    }) catch |err| {
        log_to_file("failed to create exe path: {any}", .{err});
        return -3;
    };
    state.exe_path = exe;
    const shm_fd = std.c.shm_open(
        common.shm_name,
        common.RDWR | common.CREAT,
        std.c.S.IRUSR | std.c.S.IWUSR,
    );
    if (shm_fd == -1) {
        log_to_file("shm_open failed. code({})\n", .{std.posix.errno(-1)});
        return -4;
    }
    const res: c_int = std.c.ftruncate(shm_fd, @sizeOf(common.SharedMem));
    if (res != 0) {
        log_to_file("ftruncate failed. code({})\n", .{std.posix.errno(-1)});
        return -5;
    }
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
        log_to_file("shared memory was null.\n", .{});
        return -6;
    }
    var mem: *common.SharedMem = @ptrCast(@alignCast(mem_op.?));
    const sem_lock: ?*std.c.sem_t = std.c.sem_open(
        common.sem_name,
        common.CREAT,
        std.c.S.IRUSR | std.c.S.IWUSR,
        0,
    );
    if (sem_lock == null) {
        log_to_file("sem_open failed. code({})\n", .{std.posix.errno(-1)});
        return -7;
    }
    mem.length = 0;
    mem.is_playing = false;
    mem.should_stop = false;
    mem.volume = 0.75;
    mem.playtime = 0;
    state.mem = mem;
    state.shm_fd = shm_fd;
    state.sem_lock = sem_lock;
    return 0;
}

/// Play the given audio file.
///
/// @param file_name The audio filename.
/// @return 0 for success, Less than 0 for failure.
export fn play(file_name: [*:0]const u8) c_int {
    if (state.proc) |*proc| {
        stop();
        _ = proc.*.kill() catch |err| {
            log_to_file("failed to kill proc: {any}.\n", .{err});
        };
    }
    const args: []const []const u8 = &.{
        state.exe_path,
        std.mem.span(file_name),
        state.log_file_name,
    };
    log_to_file("exe({s}); song({s})\n", .{ args[0], args[1] });
    state.mem.?.is_playing = true;
    state.proc = std.process.Child.init(args, alloc);
    state.proc.?.spawn() catch |err| {
        log_to_file("spawn failed: {any}\n", .{err});
        state.mem.?.is_playing = false;
        return -1;
    };
    return 0;
}

/// Set the volume of the player.
///
/// @param vol The volume. Value must be between 0 - 1.
export fn set_volume(vol: f32) void {
    if (state.proc == null) {
        return;
    }
    if (state.mem) |mem| {
        mem.volume = vol;
        if (state.sem_lock) |sem_lock| {
            _ = std.c.sem_post(sem_lock);
        }
    }
}

/// Pause the player.
export fn pause() void {
    if (state.proc == null) {
        return;
    }
    if (state.mem) |mem| {
        mem.is_playing = false;
        if (state.sem_lock) |sem_lock| {
            _ = std.c.sem_post(sem_lock);
        }
    }
}

/// Resume the player.
export fn @"resume"() void {
    if (state.proc == null) {
        return;
    }
    if (state.mem) |mem| {
        mem.is_playing = true;
        if (state.sem_lock) |sem_lock| {
            _ = std.c.sem_post(sem_lock);
        }
    }
}

/// Stop the player.
/// This function will clear the song from the player.
export fn stop() void {
    if (state.proc == null) {
        return;
    }
    if (state.mem) |mem| {
        mem.should_stop = true;
        if (state.sem_lock) |sem_lock| {
            _ = std.c.sem_post(sem_lock);
        }
    }
}

/// Get the current playtime of the running audio in seconds.
export fn get_playtime() f64 {
    if (state.proc == null) {
        return 0;
    }
    if (state.mem) |mem| {
        return mem.playtime;
    }
    return 0;
}

/// Get the total audio length in seconds.
export fn get_audio_length() u64 {
    if (state.proc == null) {
        return 0;
    }
    if (state.mem) |mem| {
        return mem.length;
    }
    return 0;
}

/// Get the is-playing flag.
///
/// @return 1 for true, 0 for false.
export fn is_playing() c_int {
    if (state.proc == null) {
        return 0;
    }
    if (state.mem) |mem| {
        return @intFromBool(mem.is_playing);
    }
    return 0;
}

/// Get the in-progress flag.
/// This function is to check if the player has an audio file queued up
/// whether it's playing or paused.
///
/// @return 1 for true, 0 for false.
export fn in_progress() c_int {
    if (state.proc == null) {
        return 0;
    }
    // sending 0 to id with kill just checks to see if the process exists
    // and we have permission to kill it. We don't need to worry about permissions
    if (std.c.kill(state.proc.?.id, 0) == 0) {
        return 1;
    }
    return 0;
}

/// Deinitialize the player plugin.
export fn deinit() void {
    alloc.free(state.log_file_name);
    alloc.free(state.exe_path);
    if (state.proc) |*proc| {
        _ = proc.*.kill() catch |err| {
            log_to_file("failed to kill proc: {any}.\n", .{err});
        };
    }
    if (state.sem_lock) |sem_lock| {
        _ = std.c.sem_close(sem_lock);
        _ = std.c.sem_destroy(sem_lock);
    }
    if (state.mem) |mem| {
        const result = std.c.munmap(@ptrCast(@alignCast(mem)), @sizeOf(common.SharedMem));
        if (result != 0) {
            log_to_file("munmap failed: code({})\n", .{result});
        }
    }
    if (state.shm_fd) |shm_fd| {
        _ = std.c.shm_unlink(common.shm_name);
        _ = std.c.close(shm_fd);
    }
    state.log_file.close();
}
