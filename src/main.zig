const std = @import("std");
const player = @import("ffi.zig");
const common = @import("common.zig");

const Error = error {
    missing_param,
};

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();
    if (!args.skip()) {
        std.log.err("A filename of the song to play is a required parameter.\n", .{});
        return Error.missing_param;
    }
    const file_name: ?[:0]const u8 = args.next();
    if (file_name != null) {
        std.log.err("A filename of the song to play is a required parameter.\n", .{});
        return Error.missing_param;
    }

    // get our shared memory file descriptor
    const shm_fd = std.c.shm_open(
        common.shm_name,
        common.RDWR, // read only
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
    // local memory copy
    var local_mem: common.SharedMem = .{
        .is_playing = mem.is_playing,
        .volume = mem.volume,
        .should_stop = mem.should_stop,
    };
    // setup player
    player.setup();
    defer player.deinit();
    // play the song.
    if (player.play(file_name.?) == 0) {
        std.log.err("failed to play song.\n", .{});
        return;
    }
    // set the volume to whatever is set.
    player.set_volume(local_mem.volume);

    // acquire the shared semaphore
    const sem_lock = std.c.sem_open(common.sem_name, 0, 0, 0);
    defer _ = std.c.sem_close(sem_lock);
    while (player.has_stopped() != 1) {
        // block until controller sends an update.
        _ = std.c.sem_wait(sem_lock);

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
