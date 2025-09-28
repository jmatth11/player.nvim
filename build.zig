const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("player_nvim", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    mod.addIncludePath(.{
        .cwd_relative = "/usr/include/luajit-2.1",
    });
    mod.addIncludePath(b.path("./audio/"));
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "player_nvim",
        .root_module = mod,
    });
    lib.linkSystemLibrary("luajit-5.1");
    lib.linkSystemLibrary("m");
    lib.linkSystemLibrary("pthread");
    lib.linkSystemLibrary("atomic");
    b.installArtifact(lib);
}
