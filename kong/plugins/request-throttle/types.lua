local re_match = ngx.re.match

local redis_sentinel_addresses = [[^([^:]+):(\d+)$]]

local _M = {}

--- Parses `host:port` string into a `{host: ..., port: ...}` table.
function _M.sentinel_addresses(string)
  local m = re_match(string, redis_sentinel_addresses, "jo")
  if not m then
    return nil, "invalid redis sentinel addresses value: " .. string
  end
  return { host = m[1], port = m[2] }
end

return _M
