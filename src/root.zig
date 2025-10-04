const std = @import("std");

pub const c = @cImport({
    @cInclude("play.h");
    @cInclude("luaconf.h");
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

const LuaState = c.lua_State;
const FnReg = c.luaL_Reg;

var player: ?*c.player_t = null;

export fn setup(_: ?*LuaState) c_int {
    if (player == null) {
        player = c.player_create();
    }
    return 0;
}

export fn play(lua: ?*LuaState) c_int {
    if (player == null) {
        player = c.player_create();
    }
    const file_name: [*c]const u8 = c.lua_tolstring(lua, 1, null);
    if (!c.player_play(player, file_name)) {
        std.debug.print("failed to play file", .{});
        c.lua_pushboolean(lua, 0);
        return 1;
    }
    c.lua_pushboolean(lua, 1);
    return 1;
}

export fn get_volume(lua: ?*LuaState) c_int {
    const ret_val = c.player_get_volume(player);
    c.lua_pushnumber(lua, @floatCast(ret_val));
    return 1;
}
export fn set_volume(lua: ?*LuaState) c_int {
    const new_vol = c.lua_tonumber(lua, 1);
    c.player_set_volume(player, @floatCast(new_vol));
    return 0;
}

export fn deinit(_: ?*LuaState) c_int {
    c.player_destroy(&player);
    return 0;
}

export fn version(lua: ?*LuaState) c_int {
    // push string to be a return value
    c.lua_pushstring(lua, "0.0.1");
    // return the number of return values pushed back.
    return 1;
}

/// Create a function register.
const version_reg: FnReg = .{ .name = "version", .func = version };
const play_reg: FnReg = .{ .name = "play", .func = play };
const deinit_reg: FnReg = .{ .name = "deinit", .func = deinit };
const setup_reg: FnReg = .{ .name = "setup", .func = setup };
const get_vol_reg: FnReg = .{ .name = "get_volume", .func = get_volume };
const set_vol_reg: FnReg = .{ .name = "set_volume", .func = set_volume };

/// Complete list of functions to register.
/// Use an empty struct to signal the end of the list.
const lib_fn_reg = [_]FnReg{
    version_reg,
    setup_reg,
    play_reg,
    deinit_reg,
    get_vol_reg,
    set_vol_reg,
    FnReg{},
};

/// This is a special function to register functions.
/// Basically the entrypoint of the library.
export fn luaopen_player_nvim(lua: ?*LuaState) c_int {
    c.luaL_register(lua, "player_nvim", @ptrCast(&lib_fn_reg[0]));
    return 1;
}
