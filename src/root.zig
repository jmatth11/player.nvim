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
