local utils = require("player.utils")
local player = require("player.player")
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
  if opts ~= nil and type(opts) == "table" then
    M.opts = vim.tbl_deep_extend('force', M.opts, opts)
  end
  vim.api.nvim_create_augroup(player_autogroup, { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = player_autogroup,
    callback = function()
      M.kill()
    end
  })
  player.setup()
end

-- Print the version of the plugin.
function M.version(silent)
  local v = "v" .. player.version()
  if silent == nil then
    utils.info(v)
  end
  return v
end

-- Play the give song file name.
function M.play(name)
  local file_name = str.path_join(M.opts.parent_dir, name)
  if file_name ~= nil then
    local msg = "playing: " .. file_name
    utils.info(msg)
    player.play(file_name)
  end
end

function M.get_volume()
  return player.get_volume()
end

function M.set_volume(vol)
  if vol ~= nil and vol >= 0 and vol <= 1 then
    player.set_volume(vol)
  end
end

-- Kill the current player process.
function M.kill()
  player.deinit()
end

return M
