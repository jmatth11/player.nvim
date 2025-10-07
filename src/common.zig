const std = @import("std");
pub const shm_name: [*:0]const u8 = "/jmatth11.player.nvim.player_exe.shm";
pub const sem_name: [*:0]const u8 = "/jmatth11.player.nvim.player_exe.sem";
pub const RDWR: comptime_int = 0o2;
pub const CREAT: comptime_int = 0o100;
pub const EXECL: comptime_int = 0o200;

pub const SharedMem = struct {
    sem_lock: *std.c.sem_t,
    length: u64,
    volume: f32,
    is_playing: bool,
    should_stop: bool,
};

