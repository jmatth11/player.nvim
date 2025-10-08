local state = require("player.state")
local utils = require("player.utils")
local ui = require("player.ui")
-- defaults
local M = {
  opts = {
    parent_dir = vim.env.HOME,
    volume_scale = 5,
    live_update = true,
  }
}

-- autogroup
local player_autogroup = "player.nvim.autogroup"

-- Setup the plugin.
--
-- @param opts Table of options.
--      parent_dir - The parent directory to look for the song files.
function M.setup(opts)
  if opts ~= nil and type(opts) == "table" then
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)
  end
  vim.api.nvim_create_augroup(player_autogroup, { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = player_autogroup,
    callback = function()
      M.kill()
    end
  })
  local result = state.setup(M.opts)
  if result ~= 0 then
    utils.error("player setup failed: code(" .. result .. ")")
  end
end

-- Toggle the player info window.
function M.player_info()
  ui.toggle_window(state)
end

-- Print the version of the plugin.
--
-- @param silent Flag to silence the print and just return the version.
-- @return The version string.
function M.version(silent)
  return state.version(silent)
end

-- Play the give song file name.
--
-- @param name The song file name.
function M.play(name)
  state.play(name)
end

-- Get the current volume.
function M.get_volume()
  return state.volume()
end

-- Set the volume of the player.
function M.set_volume(vol)
  state.volume(vol)
  ui.draw_player(state.get_player_info())
end

-- Increase the volume of the player by the configured volume_scale value.
function M.volume_up()
  local vol = M.get_volume()
  if vol == 100 then
    return
  end
  vol = vol + M.opts.volume_scale
  if vol > 100 then
    vol = 100
  end
  M.set_volume(vol)
end

-- Decrease the volume of the player by the configured volume_scale value.
function M.volume_down()
  local vol = M.get_volume()
  if vol == 0 then
    return
  end
  vol = vol - M.opts.volume_scale
  if vol < 0 then
    vol = 0
  end
  M.set_volume(vol)
end

-- Toggle playing/pausing the audio.
function M.toggle_play()
  local flag = state.is_playing()
  if flag == 1 then
    M.pause()
  else
    M.resume()
  end
end

-- Pause the player.
function M.pause()
  state.pause()
  ui.draw_player(state.get_player_info())
end

-- Resume the player.
function M.resume()
  state.resume()
  ui.draw_player(state.get_player_info())
end

-- Stop the player.
-- This function clears out the song.
function M.stop()
  state.stop()
  ui.close()
end

-- Kill the current player process.
function M.kill()
  state.kill()
  ui.close()
end

return M
