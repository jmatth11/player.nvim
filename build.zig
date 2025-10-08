const std = @import("std");

fn build_audio_lib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const files: []const []const u8 = &.{
        "audio/play.c",
    };
    const flags: []const []const u8 = &.{
        "-Wall",
        "-std=c11",
    };
    const audio_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    audio_mod.addIncludePath(b.path("./audio/"));
    audio_mod.addCSourceFiles(.{
        .files = files,
        .language = .c,
        .flags = flags,
    });
    // required system libraries for miniaudio
    audio_mod.linkSystemLibrary("m", .{ .needed = true });
    audio_mod.linkSystemLibrary("pthread", .{ .needed = true });
    audio_mod.linkSystemLibrary("atomic", .{ .needed = true });
    return audio_mod;
}
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("player", .{
        .root_source_file = b.path("src/ffi.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    mod.addIncludePath(b.path("./audio/"));
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "player",
        .root_module = mod,
    });
    // build and include audio lib
    const audio_mod = build_audio_lib(b, target, optimize);
    const audio_lib = b.addLibrary(.{
        .name = "audio",
        .root_module = audio_mod,
        .linkage = .static
    });
    lib.addIncludePath(b.path("./audio/"));
    lib.linkLibrary(audio_lib);
    b.installArtifact(lib);

    // construct lua plugin.
    const lua_mod = b.addModule("player_nvim", .{
        .root_source_file = b.path("src/lua.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .link_libc = true,
    });
    lua_mod.addIncludePath(b.path("./audio/"));
    const lua_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "player_nvim",
        .root_module = lua_mod,
    });
    lua_lib.addIncludePath(b.path("./audio/"));
    lua_lib.linkLibrary(audio_lib);
    b.installArtifact(lua_lib);

    // create player_cli executable.
    const exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    exe_mod.linkLibrary(audio_lib);
    exe_mod.addIncludePath(b.path("./audio/"));

    const exe = b.addExecutable(.{
        .name = "player_cli",
        .root_module = exe_mod,
    });
    exe.linkLibC();
    b.installArtifact(exe);
}
