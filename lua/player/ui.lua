local popup = require("plenary.popup")

local M = {}

local tracker_win_id = nil
local tracker_bufnr = nil

local function create_window()
  local width = 60
  local height = 10
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

function M.format_time_info(result, info)
  local yr = math.floor(info.yr)
  local week = math.floor(info.week)
  local day = math.floor(info.day)
  local hr = math.floor(info.hr)
  local min = math.floor(info.min)
  local sec = math.floor(info.sec)
  if yr > 0 then
    table.insert(result, string.format("\tyr: %d", yr))
  end
  if week > 0 then
    table.insert(result, string.format("\tweek: %d", week % 52))
  end
  if day > 0 then
    table.insert(result, string.format("\tday: %d", day % 7))
  end
  if hr > 0 then
    table.insert(result, string.format("\thr: %d", hr % 24))
  end
  if min > 0 then
    table.insert(result, string.format("\tmin: %d", min % 60))
  end
  if sec > 0 then
    table.insert(result, string.format("\tsec: %d", sec % 60))
  end
  return result
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
  buf = buf .. string.format(" %f%%", range)
  return buf
end

function M.get_file_name(file_path)
  return string.match(file_path, "[^/\\%s]+$")
end

function M.format_contents(info)
  local contents = {}
  if info == nil then
    table.insert(contents, "--- No Song Selected ---")
    return contents
  end
  -- TODO get song name from full-path song name.
  table.insert(contents, string.format("Song: %s", M.get_file_name(info.song)))
  table.insert(contents, string.format("Volume: %d", info.volume))
  -- TODO need to format the time properly
  local run_time = M.extract_time_info(info.current_spot)
  table.insert(contents, string.format("Time: %d:%d:%d", run_time.hr, run_time.min, run_time.sec))
  local percent_played = 0
  if info.audio_length > 0 then
    percent_played = run_time / info.audio_length
  end
  table.insert(contents, M.progress_bar(percent_played))
  return contents
end

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
  -- TODO add more keybindings to pause/resume player
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ENTER>",
    "za",
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
