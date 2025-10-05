local state = require("player.state")
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
  state.setup(M.opts)
end

-- Print the version of the plugin.
function M.version(silent)
  return state.version(silent)
end

-- Play the give song file name.
function M.play(name)
  state.play(name)
end

function M.get_volume()
  return state.volume()
end

function M.set_volume(vol)
  state.volume(vol)
end

function M.pause()
  state.pause()
end

function M.resume()
  state.resume()
end

function M.stop()
  state.stop()
end

-- Kill the current player process.
function M.kill()
  state.kill()
end

return M
