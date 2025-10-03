-- for luajit 2.1.0
package.cpath = package.cpath .. ';./zig-out/lib/lib?.so'
local mylib = require('player_nvim')

  local function sleep_linux(seconds)
      os.execute("sleep " .. tonumber(seconds))
  end

print(mylib.version())
mylib.lib_print("from lua")
mylib.play("test/cascade.mp3")
sleep_linux(10)
mylib.deinit()
