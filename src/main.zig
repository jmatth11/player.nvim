const std = @import("std");

const shm_name: [*:0]const u8 = "jmatth11.player.nvim.player_exe.shared_memory";
const RDWR: comptime_int = 0o2;
const CREAT: comptime_int = 0o100;
const EXECL: comptime_int = 0o200;

const SharedMem = struct {
    is_playing: bool,
};

pub fn main() !void {
    const shm_fd = std.c.shm_open(
        shm_name,
        RDWR | CREAT | EXECL,
        std.c.S.IRUSR | std.c.S.IWUSR,
    );
    const res: c_int = std.c.ftruncate(shm_fd, @sizeOf(SharedMem));
    if (res != 0) {
        std.log.err("ftruncate failed. code({})\n", .{std.posix.errno(-1)});
        return;
    }
    const mapping: std.c.MAP = .{
        .TYPE = .SHARED,
    };
    var mem = std.c.mmap(
        null,
        @sizeOf(SharedMem),
        std.c.PROT.READ | std.c.PROT.WRITE,
        mapping,
        shm_fd,
        0,
    );
    // TODO finish fleshing out player executable
}
