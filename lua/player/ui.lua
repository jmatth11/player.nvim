local popup = require("plenary.popup")
local utils = require("player.utils")

local M = {}

-- window specifics
local tracker_win_id = nil
local tracker_bufnr = nil
local width = 60
local height = 5

-- Create a window
local function create_window()
  local border_chars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  local bufnr = vim.api.nvim_create_buf(false, false)
  local win_id, win = popup.create(bufnr, {
    title = "Player",
    hightlight = "player.nvim.window",
    line = vim.o.lines - height - 5,
    col = vim.o.columns - width - 5,
    minwidth = width,
    minheight = height,
    borderchars = border_chars,
  })
  vim.api.nvim_set_option_value(
    "winhl",
    "Normal:player.nvim.window",
    { win = win.border.win_id }
  )
  vim.api.nvim_set_option_value(
    "filetype",
    "player.nvim",
    { buf = bufnr }
  )
  vim.api.nvim_set_option_value(
    "bufhidden",
    "delete",
    { buf = bufnr }
  )
  vim.api.nvim_set_option_value(
    "buftype",
    "nofile",
    { buf = bufnr }
  )
  return {
    bufnr = bufnr,
    win_id = win_id
  }
end

-- Safe gaurd against divide by zero
local function safe_divide(value, div)
  if value >= 1 then
    return value / div
  end
  return 0
end

-- Convert time elapsed into useful time info.
-- @params Time elapsed in seconds
-- @returns Table
--      {
--          sec,
--          min,
--          hr,
--          day,
--          week,
--          yr
--      }
function M.extract_time_info(t)
  local sec = t
  local min = safe_divide(sec, 60)
  local hr = safe_divide(min, 60)
  local day = safe_divide(hr, 24)
  local week = safe_divide(day, 7)
  local yr = safe_divide(week, 52)
  return {
    sec = sec,
    min = min,
    hr = hr,
    day = day,
    week = week,
    yr = yr,
  }
end

-- Generate a progress bar given the percentage value.
--
-- @param percent The percentage, value between 0 - 1.
-- @return String of the progress bar.
function M.progress_bar(percent)
  local range = math.floor(10 * percent)
  if range < 0 then
    range = 0
  elseif range > 10 then
    range = 10
  end
  local buf = ""
  local index = 0
  while index < 10 do
    local mark = "_"
    if index < range then
      mark = "█"
    elseif index == range then
      mark = "▄"
    end
    buf = buf .. mark
    index = index + 1
  end
  buf = buf .. string.format(" %d%%", 100 * percent)
  return buf
end

-- Add play state text to the given table.
--
-- @param contents The table of text to populate.
-- @param flag The flag for is_playing.
function M.get_play_state(contents, flag)
  local play_button = "▶️"
  local status_text = "'<ENTER>' to play"
  if flag ~= 0 then
    play_button = "⏸"
    status_text = "'<ENTER>' to pause"
  end
  status_text = status_text .. "; <leader>u/d for volume"
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
  local run_time = M.extract_time_info(info.playtime)
  local song_info = string.format("Volume: %d | Time: %d:%d:%d", info.volume, run_time.hr, run_time.min, run_time.sec)
  table.insert(contents, utils.get_center_padding(song_name, width, " ") .. song_name)
  table.insert(contents, utils.get_center_padding(song_info, width, " ") .. song_info)
  local percent_played = 0
  if info.audio_length > 0 then
    percent_played = info.playtime / info.audio_length
  end
  local prog_bar = M.progress_bar(percent_played)
  table.insert(contents, utils.get_center_padding(prog_bar, width, " ") .. prog_bar)
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
    vim.api.nvim_buf_set_lines(tracker_bufnr, 0, #contents, false, contents)
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
-- @param info The table of info to display. Expects the format:
--    {
--      song: String         - The song name.
--      volume: Number       - The volume of the player.
--      is_playing: Number   - The playing state. 1 for true, 0 for false.
--      playtime: Number     - The current playtime.
--      audio_length: Number - The full length of the audio.
--    }
function M.toggle_window(info)
  if tracker_win_id ~= nil then
    vim.api.nvim_win_close(tracker_win_id, true)
    tracker_win_id = nil
    tracker_bufnr = nil
    return
  end
  local window = create_window()
  local contents = M.format_contents(info)
  if contents == nil then
    contents = {}
  end
  tracker_win_id = window.win_id
  tracker_bufnr = window.bufnr
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "q",
    "<Cmd>lua require('player').toggle_player()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ESC>",
    "<Cmd>lua require('player').toggle_player()<CR>",
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
  vim.api.nvim_buf_set_lines(tracker_bufnr, 0, #contents, false, contents)
  vim.api.nvim_set_option_value(
    "readonly",
    true,
    { buf = tracker_bufnr }
  )
end

return M
