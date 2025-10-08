local str_utils = require("player.str")
local M = {}

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

-- Check if a given string has a certain ending.
function M.ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

-- Check for audio file endings we support.
local function file_endings(val)
  local normalized_val = string.lower(val)
  return M.ends_with(normalized_val, ".mp3") or M.ends_with(normalized_val, ".wav") or M.ends_with(normalized_val, ".flac")
end

-- Get the list of audio files in a directory.
--
-- @param dir The directory to search for audio files.
-- @param recursive Flag to search recursively.
-- @return List of audio files within a directory.
function M.get_files(dir, recursive)
  if dir == nil then
    return {}
  end
  local files = vim.fn.readdir(dir)
  local result = {}
  if files then
    for _, file in ipairs(files) do
      local full_path = str_utils.path_join(dir, file)
      if full_path == nil then
        goto continue
      end
      -- recursive path
      if recursive and vim.fn.isdirectory(full_path) == 1 then
        -- add all inner files to list
        local inner_files = M.get_files(full_path, recursive)
        for _, entry in ipairs(inner_files) do
          -- TODO maybe consider categorizing inner files to better group songs?
          if file_endings(entry) then
            table.insert(result, str_utils.path_join(full_path, entry))
          end
        end
      end
      if file_endings(file) then
        table.insert(result, file)
      end
      -- label to skip invalid file paths
      ::continue::
    end
  end
  return result
end

-- Safe gaurd against divide by zero
function M.safe_divide(value, div)
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
  local min = M.safe_divide(sec, 60)
  local hr = M.safe_divide(min, 60)
  local day = M.safe_divide(hr, 24)
  local week = M.safe_divide(day, 7)
  local yr = M.safe_divide(week, 52)
  return {
    sec = sec,
    min = min,
    hr = hr,
    day = day,
    week = week,
    yr = yr,
  }
end

return M
