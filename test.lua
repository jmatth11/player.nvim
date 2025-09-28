-- for luajit 2.1.0
package.cpath = package.cpath .. ';./zig-out/lib/lib?.so'
local mylib = require('player_nvim')

print(mylib.version())
mylib.lib_print("from lua")
