local ui = require("player.ui")
local utils = require("player.utils")

local M = {
  -- file select options
  options = nil
}

-- window specifics
local tracker_win_id = nil
local tracker_bufnr = nil
local width = 50
local height = 50

-- Grab the selected file and play the song.
function M.select_file()
  local idx = vim.fn.line(".")
  -- first entry is instructions
  if idx == 1 then
    return
  end
  if M.options ~= nil then
    -- minus 1 to account for the offset with the instructions
    local info = M.options[idx - 1]
    require("player").play(info.full_path)
  end
end

-- Format the list of audio files.
function M.format_contents(dir, recursive)
  M.options = {}
  local content = {}
  -- TODO maybe categorize songs in nice format?
  local files = utils.get_files(dir, recursive)

  local error_text = "--- No Audio Files Found ---"
  if vim.tbl_isempty(files) then
    table.insert(content, " ")
    table.insert(content, utils.get_center_padding(error_text, width, " ") .. error_text)
    return content
  end

  local instruction_text = "<ENTER> to play file"
  table.insert(content, utils.get_center_padding(instruction_text, width, " ") .. instruction_text)

  for _, file in ipairs(files) do
    local info = {
      full_path = file,
      name = utils.get_basename(file),
    }
    table.insert(M.options, info)
    table.insert(content, info.name)
  end

  return content
end

-- Close the window if it exists.
function M.close()
  if tracker_win_id ~= nil then
    vim.api.nvim_win_close(tracker_win_id, true)
    tracker_win_id = nil
    tracker_bufnr = nil
  end
end

-- Toggle the player file select window on or off.
function M.toggle_window(opts)
  if tracker_win_id ~= nil then
    vim.api.nvim_win_close(tracker_win_id, true)
    tracker_win_id = nil
    tracker_bufnr = nil
    return
  end
  local win_height = vim.api.nvim_get_option_value("lines", {}) - 5
  if (height > win_height) then
    height = win_height
  end
  local window = ui.create_window("File Select", "player_file_viewer.nvim.window", width, height, 1)
  local contents = M.format_contents(opts.parent_dir, opts.recursive)
  if contents == nil then
    contents = {}
  end
  tracker_win_id = window.win_id
  tracker_bufnr = window.bufnr
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "q",
    "<Cmd>lua require('player').file_select()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ESC>",
    "<Cmd>lua require('player').file_select()<CR>",
    { silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    tracker_bufnr,
    "n",
    "<ENTER>",
    "<Cmd>lua require('player.file_ui').select_file()<CR>",
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
