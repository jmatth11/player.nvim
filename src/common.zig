const std = @import("std");

/// Shared Memory name.
pub const shm_name: [*:0]const u8 = "/jmatth11.player.nvim.player_exe.shm";
/// Semaphore name.
pub const sem_name: [*:0]const u8 = "/jmatth11.player.nvim.player_exe.sem";
/// Read and Write permissions.
pub const RDWR: comptime_int = 0o2;
/// Create permissions.
pub const CREAT: comptime_int = 0o100;
/// Flag for Exclusive.
pub const EXECL: comptime_int = 0o200;

/// Shared Memory structure between the plugin and the player process.
pub const SharedMem = struct {
    /// The playtime of the current audio in seconds.
    playtime: f64,
    /// The total length of the audio in seconds.
    length: u64,
    /// The volume of the player.
    volume: f32,
    /// Flag for if the audio is playing or not.
    is_playing: bool,
    /// Flag to signal the player process to stop.
    should_stop: bool,
};

