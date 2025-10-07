local player = require("player.player")
local utils = require("player.utils")
local str = require("player.str");

local dirname = string.sub(debug.getinfo(1).source, 2, string.len('/state.lua') * -1)

local M = {
  _song = nil,
  _volume = 100,
  _started = nil,
  opts = {
    parent_dir = vim.env.HOME,
  }
}

-- Initial setup of the player.
function M.setup(opts)
  M.opts = opts
  return player.setup(dirname)
end

-- Get the version of the library.
--
-- @param silent Flag to not print the version, just to return it.
function M.version(silent)
  local v = "v0.0.1"
  if silent == nil then
    utils.info(v)
  end
  return v
end

-- Volume function with scale of 0-100.
-- This function is both the getter and setter of the volume.
--
-- @param vol The volume to set, if nil then this function returns the current
--  volume.
function M.volume(vol)
  if vol ~= nil then
    if vol > 100 then
      vol = 100
    elseif vol < 0 then
      vol = 0
    end
    M._volume = vol
    player.set_volume(vol / 100)
  else
    return M._volume
  end
end

-- Set the song name.
-- If param is nil, return the song name.
function M.song(name)
  if name ~= nil then
    local file_name = str.path_join(M.opts.parent_dir, name)
    if file_name ~= nil then
      M._song = file_name
    end
  else
    return M._song
  end
end

-- Play the given song.
function M.play(name)
  M.song(name)
  if M._song ~= nil then
    local msg = "playing: " .. M._song
    utils.info(msg)
    if player.play(M._song) ~= 0 then
      utils.error("failed to play song")
    end
  end
end

-- Get the audio length in seconds.
function M.audio_length()
  return tonumber(player.get_audio_length())
end

function M.is_playing()
  return player.is_playing()
end

function M.in_progress()
  return player.in_progress()
end

-- Get the current playtime in seconds.
function M.get_playtime()
  return tonumber(player.get_playtime())
end

function M.get_player_info()
  if M.in_progress() == 0 then
    return nil
  end
  return {
    song = M.song(),
    volume = M.volume(),
    playtime = M.get_playtime(),
    audio_length = M.audio_length(),
    is_playing = M.is_playing(),
  }
end

-- Pause the player.
function M.pause()
  player.pause()
end

-- Resume the player.
function M.resume()
  player.resume()
end

function M.stop()
  player.stop()
end

-- Kill the player.
function M.kill()
  player.deinit()
end

return M
