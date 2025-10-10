local popup = require("plenary.popup")

local M = {}

-- Create a window
function M.create_window(title, namespace, width, height, padding)
  if padding == nil then
    padding = 5
  end
  local border_chars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  local bufnr = vim.api.nvim_create_buf(false, false)
  local win_id, win = popup.create(bufnr, {
    title = title,
    hightlight = namespace,
    line = vim.o.lines - height - padding,
    col = vim.o.columns - width - padding,
    minwidth = width,
    minheight = height,
    width = width,
    height = height,
    borderchars = border_chars,
  })
  vim.api.nvim_set_option_value(
    "winhl",
    "Normal:" .. namespace,
    { win = win.border.win_id }
  )
  vim.api.nvim_set_option_value(
    "filetype",
    namespace,
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

return M
