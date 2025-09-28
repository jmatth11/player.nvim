const std = @import("std");

pub const c = @cImport({
    @cInclude("luaconf.h");
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

const LuaState = c.lua_State;
const FnReg = c.luaL_Reg;

export fn version(lua: ?*LuaState) c_int {
    // push string to be a return value
    c.lua_pushstring(lua, "0.0.1");
    // return the number of return values pushed back.
    return 1;
}

export fn lib_print(lua: ?*LuaState) c_int {
    // to pull full string we need to pass null to the last param
    // but it's registering wrong. so we make our own null.
    const n: usize = 0;
    // it's important to have [*c] type.
    // also to pull argument passed in from lua, you use index position.
    const arg: [*c]const u8 = c.lua_tolstring(lua, 1, @constCast(&n));
    std.debug.print("from zig: {s}\n", .{arg});
    return 0;
}

/// Create a function register.
const version_reg: FnReg = .{ .name = "version", .func = version };
const lib_print_reg: FnReg = .{ .name = "lib_print", .func = lib_print };

/// Complete list of functions to register.
/// Use an empty struct to signal the end of the list.
const lib_fn_reg = [_]FnReg{ version_reg, lib_print_reg, FnReg{} };

/// This is a special function to register functions.
/// Basically the entrypoint of the library.
export fn luaopen_player_nvim(lua: ?*LuaState) c_int {
    c.luaL_register(lua, "player_nvim", @ptrCast(&lib_fn_reg[0]));
    return 1;
}
