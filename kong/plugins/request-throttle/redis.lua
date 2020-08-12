local redis_connector = require "resty.redis.connector"
local floor = math.floor
local modf = math.modf

local _M = {}

function _M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end
--初使化redis信息
function _M:init(conf)
    local redis_conf = {
        host = conf.redis.host,
        port = conf.redis.port,
        password = conf.redis.password,
        db = conf.redis.database,
        read_timeout = conf.redis.timeout,
        keepalive_timeout = conf.redis.max_idle_timeout,
        keepalive_poolsize = conf.redis.pool_size
    }
    local sentinel_master_name = conf.redis.sentinel_master
    if sentinel_master_name ~= nil and string.len(sentinel_master_name) > 0 then
        redis_conf.master_name = sentinel_master_name
        redis_conf.role = conf.redis.sentinel_role
        local sentinels = conf.redis.sentinel_addresses
        if sentinels then
            redis_conf.sentinels = {}
            for _, sentinel in ipairs(sentinels) do
                local sentinel_host, sentinel_port = string.match(sentinel, "(.*)[:](%d*)")
                redis_conf.sentinels[#redis_conf.sentinels + 1] = {
                    host = sentinel_host,
                    port = sentinel_port
                }
            end
        end
    end
    self.connector = redis_connector.new(redis_conf)
end
--连接redis
function _M:connect()
    local red, err = self.connector:connect()
    if red == nil then
        kong.log.err("failed to connect to Redis: " .. err)
        return false
    end
    self.red = red
    return true
end
--关闭redis
function _M:close()
    local ok, err = self.connector:set_keepalive(self.red)
    if not ok then
        kong.log.err("failed to set keepalive: " .. err)
        return false
    end
    return true
end

function sum(t)
    local sum = 0
    for k, v in pairs(t) do
        sum = sum + v
    end
    return sum
end

local function get_global_value(key, redis)
    local global_value_array, err = redis:hvals(key)
    if err then
        kong.log.err("failed to hvals cache: ", err)
        return nil, err
    end
    return sum(global_value_array)
end

function _M:sync_redis_with_shm(keys_array, counter_dict, expire_time)
    local connected = self:connect()
    if not connected then
        return
    end

    for i = 1, #keys_array do
        local key = keys_array[i]
        local value = ngx.shared[counter_dict]:get(key)
        if value then
            self.red:hset(key, kong.node.get_id(), value)
            self.red:expire(key, expire_time)

            local global_value = get_global_value(key, self.red)
            local kong_nodes_number = ngx.shared[counter_dict]:get(kong.node.get_id())
            if not kong_nodes_number then
                return
            end

            --四舍五入，算当前节点的限流值
            local limit, _ = modf(floor(global_value / kong_nodes_number + 0.5))
            --同步redis数据到shm
            local ttl, err = ngx.shared[counter_dict]:ttl(key)
            if err or ttl <= 0 then
                break
            end
            ngx.shared[counter_dict]:set(key, limit, ttl)
        end
    end

    kong.table.clear(keys_array)
    self:close()
end

--zadd数据(单条)
function _M:zadd(key, score, member)
    local connected = self:connect()
    if not connected then
        return
    end
    local ok, err = self.red:zadd(key, score, member)
    if not ok then
        kong.log.err("failed to zadd cache: ", err)
        return
    end
    self:close()
end

--zcount数据
function _M:zcount(key, min, max)
    local connected = self:connect()
    if not connected then
        return nil
    end
    local cached_value, err = self.red:zcount(key, min, max)
    if err then
        kong.log.err("failed to zcount cache: ", err)
        return nil, err
    end
    self:close()
    return cached_value
end

return _M