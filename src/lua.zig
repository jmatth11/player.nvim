const std = @import("std");
const common = @import("common.zig");

const alloc = std.heap.smp_allocator;

const State = struct {
    sem_lock: ?*std.c.sem_t,
    shm_fd: ?c_int,
    mem: ?*common.SharedMem,
    proc: ?std.process.Child,
    exe_path: []const u8,
    log_file: std.fs.File,
    log_file_name: []const u8,
};

var state: State = .{
    .sem_lock = null,
    .shm_fd = null,
    .mem = null,
    .proc = null,
    .exe_path = undefined,
    .log_file = undefined,
    .log_file_name = undefined,
};

fn log_to_file(comptime fmt: []const u8, args: anytype) void {
    const buf = std.fmt.allocPrint(alloc, fmt, args) catch unreachable;
    _ = state.log_file.write(buf) catch unreachable;
}

export fn setup(root_dir: [*:0]const u8) c_int {
    const log_file = std.fs.path.join(alloc, &.{
        std.mem.span(root_dir),
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
        std.mem.span(root_dir),
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
    const mem_op: *anyopaque = std.c.mmap(
        null,
        @sizeOf(common.SharedMem),
        std.c.PROT.READ | std.c.PROT.WRITE,
        mapping,
        shm_fd,
        0,
    );
    var mem: *common.SharedMem = @ptrCast(@alignCast(mem_op));
    const sem_lock: ?*std.c.sem_t = std.c.sem_open(
        common.sem_name,
        common.CREAT,
        std.c.S.IRUSR | std.c.S.IWUSR,
        0,
    );
    if (sem_lock == null) {
        log_to_file("sem_open failed. code({})\n", .{std.posix.errno(-1)});
        return -6;
    }
    mem.length = 0;
    mem.is_playing = false;
    mem.should_stop = false;
    mem.volume = 0.75;
    state.mem = mem;
    state.shm_fd = shm_fd;
    state.sem_lock = sem_lock;
    return 0;
}

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
export fn get_audio_length() u64 {
    if (state.proc == null) {
        return 0;
    }
    if (state.mem) |mem| {
        return mem.length;
    }
    return 0;
}
export fn is_playing() c_int {
    if (state.proc == null) {
        return 0;
    }
    if (state.mem) |mem| {
        return @intFromBool(mem.is_playing);
    }
    return 0;
}
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
