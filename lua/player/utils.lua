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

return M

