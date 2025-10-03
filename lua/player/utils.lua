local M = {}

-- Linux sleep function.
--
-- @param seconds Number of seconds to sleep.
function M.sleep_linux(seconds)
  os.execute("sleep " .. tonumber(seconds))
end

return M

