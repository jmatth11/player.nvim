const std = @import("std");

pub const c = @cImport({
    @cDefine("MINIAUDIO_IMPLEMENTATION", "1");
    @cInclude("miniaudio.h");
    @cInclude("luaconf.h");
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

const LuaState = c.lua_State;
const FnReg = c.luaL_Reg;

const State = struct {
    playing: bool,
    device: c.ma_device,
    decoder: c.ma_decoder,
    config: c.ma_device_config,
};

var global_state: State = .{
    .playing = false,
    .device = undefined,
    .decoder = undefined,
    .config = undefined,
};

export fn data_callback(pDevice: ?*c.ma_device, pOutput: ?*anyopaque, _: ?*const anyopaque, frameCount: c.ma_uint32) void {
    if (pDevice) |dev| {
        const pDecoder: ?*c.ma_decoder = @ptrCast(@alignCast(dev.pUserData));
        if (pDecoder) |dec| {
            _ = c.ma_decoder_read_pcm_frames(dec, pOutput, frameCount, null);
        }
    }
}

export fn play(lua: ?*LuaState) c_int {
    if (global_state.playing) {
        _ = c.ma_device_uninit(&global_state.device);
        _ = c.ma_decoder_uninit(&global_state.decoder);
        global_state.playing = false;
    }
    const file_name: [*c]const u8 = c.lua_tolstring(lua, 1, null);
    var result = c.ma_decoder_init_file(file_name, null, &global_state.decoder);
    if (result != c.MA_SUCCESS) {
        std.debug.print("failed to init decoder file: code({})", .{result});
        c.lua_pushboolean(lua, 0);
        return 1;
    }
    var device_config = c.ma_device_config_init(c.ma_device_type_playback);
    device_config.playback.format = global_state.decoder.outputFormat;
    device_config.playback.channels = global_state.decoder.outputChannels;
    device_config.sampleRate        = global_state.decoder.outputSampleRate;
    device_config.dataCallback      = data_callback;
    device_config.pUserData         = &global_state.decoder;
    global_state.config = device_config;
    var ctx: c.ma_context = .{};
    result = c.ma_device_init(&ctx, &global_state.config, &global_state.device);
    if (result != c.MA_SUCCESS) {
        _ = c.ma_decoder_uninit(&global_state.decoder);
        std.debug.print("failed to init device: code({})", .{result});
        c.lua_pushboolean(lua, 0);
        return 1;
    }
    result = c.ma_device_start(&global_state.device);
    if (result != c.MA_SUCCESS) {
        _ = c.ma_device_uninit(&global_state.device);
        _ = c.ma_decoder_uninit(&global_state.decoder);
        std.debug.print("failed to start device: code({})", .{result});
        c.lua_pushboolean(lua, 0);
        return 1;
    }
    global_state.playing = true;
    c.lua_pushboolean(lua, 1);
    return 1;
}

export fn version(lua: ?*LuaState) c_int {
    // push string to be a return value
    c.lua_pushstring(lua, "0.0.1");
    // return the number of return values pushed back.
    return 1;
}

export fn lib_print(lua: ?*LuaState) c_int {
    // it's important to have [*c] type.
    // also to pull argument passed in from lua, you use index position.
    const arg: [*c]const u8 = c.lua_tolstring(lua, 1, null);
    std.debug.print("from zig: {s}\n", .{arg});
    return 0;
}

/// Create a function register.
const version_reg: FnReg = .{ .name = "version", .func = version };
const lib_print_reg: FnReg = .{ .name = "lib_print", .func = lib_print };
const play_reg: FnReg = .{.name = "play", .func = play };

/// Complete list of functions to register.
/// Use an empty struct to signal the end of the list.
const lib_fn_reg = [_]FnReg{ version_reg, lib_print_reg, play_reg, FnReg{} };

/// This is a special function to register functions.
/// Basically the entrypoint of the library.
export fn luaopen_player_nvim(lua: ?*LuaState) c_int {
    c.luaL_register(lua, "player_nvim", @ptrCast(&lib_fn_reg[0]));
    return 1;
}
