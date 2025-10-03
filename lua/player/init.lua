-- for luajit 2.1.0
-- load in zig audio library
local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/init.lua') * -1)
local library_path = dirname .. '../../zig-out/lib/lib?.so'
package.cpath = package.cpath .. ';' .. library_path
local ok, player = pcall(require, 'player_nvim')
if not ok then
  vim.notify("player.nvim zig library could not be loaded.", vim.log.levels.ERROR)
  return {}
end

-- init

local str = require("player.str");
local M = {
  opts = {
    parent_dir = vim.env.HOME
  }
}

local player_autogroup = "player.nvim.autogroup"

-- Setup the plugin.
--
-- @param opts Table of options.
--      parent_dir - The parent directory to look for the song files.
function M.setup(opts)
  M.opts = opts
  vim.api.nvim_create_augroup(player_autogroup, { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = player_autogroup,
    callback = function()
      M.kill()
    end
  })
end

-- Print the version of the plugin.
function M.version()
  print(player.version())
end

-- Play the give song file name.
function M.play(name)
  local file_name = str.path_join(M.parent_dir, name)
  if file_name ~= nil then
    player.play(file_name)
  end
end

-- Kill the current player process.
function M.kill()
  player.deinit()
end

return M
