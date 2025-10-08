local M = {}

-- Get the native separator for file paths.
local function native_separator()
    if vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1 then
        return "\\"
    end
    return "/"
end

-- Native path separator.
M.path_sep = native_separator()

-- Naive path joining function.
--
-- @param base The base path.
-- @param item The item to join.
-- @return The concatenated strings or nil if one/both were nil.
function M.path_join(base, item)
  if base ~= nil and item ~= nil then
    return base .. M.path_sep .. item
  end
  return nil
end
return M
