local M = {
  _song = nil,
  _volume = 100,
}

-- Volume function with scale of 0-100.
-- This function is both the getter and setter of the volume.
--
-- @param vol The volume to set, if nil then this function returns the current
--  volume.
function M.volume(vol)
  if vol ~= nil then
    if vol > 100 then
      vol = 100
    elseif vol < 0 then
      vol = 0
    end
    M.volume = vol
  else
    return M.volume
  end
end



return M
