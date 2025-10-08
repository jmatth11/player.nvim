local utils = require("player.utils")
local ui = require("player.ui")

local M = {}

-- window specifics
local tracker_win_id = nil
local tracker_bufnr = nil
local width = 65
local height = 4

-- live update.
-- 1 second
local timer_delay = 1000

-- timer function to update the player if it is displayed
local function timer_fn(state)
  return function ()
    if tracker_bufnr == nil then
      return
    end
    M.draw_player(state.get_player_info())
    vim.defer_fn(timer_fn(state), timer_delay)
  end
end

-- Add play state text to the given table.
--
-- @param contents The table of text to populate.
-- @param flag The flag for is_playing.
function M.get_play_state(contents, flag)
  local play_button = "▶"
  local status_text = "'<ENTER>' to play"
  if flag ~= 0 then
    play_button = "⏸"
    status_text = "'<ENTER>' to pause"
  end
  status_text = status_text .. "; <leader>u/d for volume; <leader>s to stop"
  table.insert(contents, utils.get_center_padding(play_button, width, " ") .. play_button)
  table.insert(contents, utils.get_center_padding(status_text, width, " ") .. status_text)
end

-- Generate a table of formatted content to display in the player window.
--
-- @param info The table of info to display. Expects the format:
--    {
--      song: String         - The song name.
--      volume: Number       - The volume of the player.
--      is_playing: Number   - The playing state. 1 for true, 0 for false.
--      playtime: Number     - The current playtime.
--      audio_length: Number - The full length of the audio.
--    }
-- @return The table of formatted text.
function M.format_contents(info)
  local contents = {}
  local text = "--- No Song Selected ---"
  if info == nil then
    table.insert(contents, "")
    table.insert(contents, utils.get_center_padding(text, width, " ") .. text)
    return contents
  end
  local song_name = string.format("Song: %s", utils.get_basename(info.song))
  local run_time = utils.extract_time_info(info.playtime)
  local percent_played = 0
  if info.audio_length > 0 then
    percent_played = info.playtime / info.audio_length
  end
  local prog_bar = ui.progress_bar(percent_played)
  local song_info = string.format("Volume: %d | Time: %d:%d:%d | %s", info.volume, run_time.hr, run_time.min, run_time.sec, prog_bar)
  table.insert(contents, utils.get_center_padding(song_name, width, " ") .. song_name)
  table.insert(contents, utils.get_center_padding(song_info, width, " ") .. song_info)
  M.get_play_state(contents, info.is_playing)
  return contents
end

-- Draw the player window's content.
--
-- @param info The table of info to display. Expects the format:
--    {
--      song: String         - The song name.
--      volume: Number       - The volume of the player.
--      is_playing: Number   - The playing state. 1 for true, 0 for false.
--      playtime: Number     - The current playtime.
--      audio_length: Number - The full length of the audio.
--    }
function M.draw_player(info)
  if tracker_bufnr ~= nil then
    local contents = M.format_contents(info)
    if contents == nil then
      contents = {}
    end
    vim.api.nvim_set_option_value(
      "readonly",
      false,
      { buf = tracker_bufnr }
    )
    vim.api.nvim_buf_set_lines(tracker_bufnr, 0, #contents, false, contents)
    vim.api.nvim_set_option_value(
      "readonly",
      true,
      { buf = tracker_bufnr }
    )
  end
end

-- Close the window if it exists.
function M.close()
  if tracker_win_id ~= nil then
    vim.api.nvim_win_close(tracker_win_id, true)
    tracker_win_id = nil
    tracker_bufnr = nil
  end
end

-- Toggle the player info window on or off.
--
-- @param state The player state object.
-- @param live_update Flag to redraw the player info every second.
function M.toggle_window(state, live_update)
  if tracker_win_id ~= nil then
    vim.api.nvim_win_close(tracker_win_id, true)
    tracker_win_id = nil
    tracker_bufnr = nil
    return
  end
  local window = ui.create_window("Player", "player_info_viewer.nvim.window", width, height)
  local contents = M.format_contents(state.get_player_info())
  if contents == nil then
    contents = {}
  end
  tracker_win_id = window.win_id
  tracker_bufnr = window.bufnr
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "q",
    "<Cmd>lua require('player').player_info()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ESC>",
    "<Cmd>lua require('player').player_info()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ENTER>",
    "<Cmd>lua require('player').toggle_play()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<leader>u",
    "<Cmd>lua require('player').volume_up()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<leader>d",
    "<Cmd>lua require('player').volume_down()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<leader>s",
    "<Cmd>lua require('player').stop()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_lines(tracker_bufnr, 0, #contents, false, contents)
  vim.api.nvim_set_option_value(
    "readonly",
    true,
    { buf = tracker_bufnr }
  )
  if live_update then
    vim.defer_fn(timer_fn(state), timer_delay)
  end
end

return M
