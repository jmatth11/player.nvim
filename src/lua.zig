const std = @import("std");
const common = @import("common.zig");

const alloc = std.heap.smp_allocator;

const State = struct {
    sem_lock: ?*std.c.sem_t,
    shm_fd: ?c_int,
    mem: ?*common.SharedMem,
    proc: ?std.process.Child,
};

var state: State = .{
    .sem_lock = null,
    .shm_fd = null,
    .mem = null,
    .proc = null,
};

export fn setup() c_int {
    const shm_fd = std.c.shm_open(
        common.shm_name,
        common.RDWR | common.CREAT | common.EXECL,
        std.c.S.IRUSR | std.c.S.IWUSR,
    );
    const res: c_int = std.c.ftruncate(shm_fd, @sizeOf(common.SharedMem));
    if (res != 0) {
        std.log.err("ftruncate failed. code({})\n", .{std.posix.errno(-1)});
        return 0;
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
    const mem: *common.SharedMem = @ptrCast(@alignCast(mem_op));
    const sem_lock: *std.c.sem_t = std.c.sem_open(
        common.sem_name,
        common.CREAT | common.EXECL,
        std.c.S.IRUSR | std.c.S.IWUSR,
        1,
    );
    state.mem = mem;
    state.shm_fd = shm_fd;
    state.sem_lock = sem_lock;
    return 1;
}

export fn play(file_name: [*:0]const u8) c_int {
    if (state.proc) |*proc| {
        stop();
        _ = proc.*.kill() catch |err| {
            std.log.err("failed to kill proc: {any}.\n", .{err});
        };
    }
    const args: []const []const u8 = &.{
        std.mem.span(file_name),
    };
    state.proc = std.process.Child.init(args, alloc);
    state.proc.?.spawn() catch |err| {
        std.log.err("spawn failed: {any}\n", .{err});
        return 0;
    };
    return 1;
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

export fn deinit() void {
    if (state.proc) |*proc| {
        _ = proc.*.kill() catch |err| {
            std.log.err("failed to kill proc: {any}.\n", .{err});
        };
    }
    if (state.sem_lock) |sem_lock| {
        _ = std.c.sem_close(sem_lock);
        _ = std.c.sem_destroy(sem_lock);
    }
    if (state.mem) |mem| {
        const result = std.c.munmap(@ptrCast(@alignCast(mem)), @sizeOf(common.SharedMem));
        if (result != -1) {
            std.log.err("munmap failed: code({})\n", .{result});
        }
    }
    if (state.shm_fd) |shm_fd| {
        _ = std.c.shm_unlink(common.shm_name);
        _ = std.c.close(shm_fd);
    }
}
