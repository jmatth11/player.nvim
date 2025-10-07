local ffi = require("ffi")

ffi.cdef [[
int setup(const char *root_dir);
int play(const char *file_name);
int is_playing();
int in_progress();
void set_volume(float vol);
long int get_audio_length();
void pause();
void resume();
void stop();
void deinit();
]]

local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/player.lua') * -1)
local library_path = dirname .. '../../zig-out/lib/libplayer_nvim.so'
local lib = ffi.load(library_path)
return lib
