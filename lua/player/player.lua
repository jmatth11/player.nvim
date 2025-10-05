local ffi = require("ffi")

ffi.cdef [[
void setup();
int play(const char* file_name);
void pause();
void resume();
int stop();
float get_volume();
void set_volume(float vol);
void deinit();
const char* version();
]]

local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/player.lua') * -1)
local library_path = dirname .. '../../zig-out/lib/libplayer_nvim.so'
local lib = ffi.load(library_path)
return lib
