local M = {}

-- Linux sleep function.
--
-- @param seconds Number of seconds to sleep.
function M.sleep_linux(seconds)
  os.execute("sleep " .. tonumber(seconds))
end

-- Log and notify the given message at INFO level.
function M.info(msg)
  vim.notify(msg, vim.log.levels.INFO)
  print(msg)
end

-- Log and notify the given message at ERROR level.
function M.error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
  print(msg)
end

-- Get padding to center the given text horizontally.
--
-- @param text The text to center.
-- @param width The width of the area to center it on.
-- @param symbol The symbol used for padding.
-- @return String of padding.
--
-- Example:
-- -- assuming this method exists in your code.
-- local width = get_screen_width()
-- local text = "test text"
-- local padding = M.get_center_padding(text, width, " ")
-- local final_string = padding .. text
--
function M.get_center_padding(text, width, symbol)
  if text == nil then
    text = " "
  end
  if width == nil then
    width = 2
  end
  if symbol == nil then
    symbol = " "
  end
  local offset = (width / 2.0) - (string.len(text) / 2)
  if offset < 0 then
    offset = 0
  end
  return string.rep(symbol, offset)
end

-- Get the base name from a filepath.
--
-- @param file_path The file path.
-- @return The base file name or an empty string if nil.
function M.get_basename(file_path)
  if file_path == nil then
    return ""
  end
  return string.match(file_path, "[^/\\%s]+$")
end

return M
