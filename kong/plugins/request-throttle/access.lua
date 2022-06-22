local math_floor = math.floor
local tostring = tostring
local string_format = string.format
local pcall = pcall
local kong = kong
local ngx_now = ngx.now
local json = require "cjson"

local _M = {}

local function store_incr(counter_dict, key, delta, expiry)
    local new_value, err, forcible = ngx.shared[counter_dict]:incr(key, delta, 0, expiry)
    if err then
        return nil, err
    end
    if forcible then
        kong.log.warn("shared dictionary is full, removed valid key(s) to store the new one")
    end
    return new_value, nil
end

local function store_get(counter_dict, key)
    local value = ngx.shared[counter_dict]:get(key)
    if not value == nil then
        return nil, "not found"
    end
    return value, nil
end

local function window_started_at(window_size, now_ms)
    return now_ms - (now_ms % window_size)
end

local function get_id(time, window_size)
    return tostring(math_floor(time / window_size))
end

local function get_counter_key(limit_key, time, window_size)
    local id = get_id(time, window_size)
    return string_format("%s.%s.counter", limit_key, id)
end

local function last_sample_count(counter_dict, limit_key, window_size, now_ms)
    local a_window_ago_from_now = now_ms - window_size
    local last_counter_key = get_counter_key(limit_key, a_window_ago_from_now, window_size)
    return store_get(counter_dict, last_counter_key) or 0, last_counter_key
end

local function add_sample_and_estimate_total_count(counter_dict, limit_key, limit, window_size)
    local now_ms = ngx_now() * 1000
    local last_count, last_counter_key = last_sample_count(counter_dict, limit_key, window_size, now_ms)

    local last_rate = last_count / window_size
    local elapsed_time = now_ms - window_started_at(window_size, now_ms)
    local counter_key = get_counter_key(limit_key, now_ms, window_size)
    local count = store_get(counter_dict, counter_key) or 0
    local estimated_total_count = last_rate * (window_size - elapsed_time) + count + 1

    local should_throttle = estimated_total_count > limit
    if should_throttle then
        return should_throttle, counter_key, last_counter_key
    end
    local expiry = window_size * 2 / 1000
    store_incr(counter_dict, counter_key, 1, expiry)
    return false, counter_key, last_counter_key

end

local function keep_keys_under_plugin_instance(counter_dict, uuid, counter_key, last_counter_key, expiry)
    local keys_array = kong.table.new(2, 0)
    keys_array[1] = counter_key
    keys_array[2] = last_counter_key
    local keys_array_str, err = json.encode(keys_array)
    if err then
        kong.log.err("can't encode keys form array to string")
    end
    kong.table.clear(keys_array)
    ngx.shared[counter_dict]:set(uuid, keys_array_str)
    ngx.shared[counter_dict]:expire(uuid, expiry)
end

local function get_limit_key(conf)
    local identifier
    if conf.limit_by == "current_entity" then
        if conf.service_id then
            identifier = "service_id:" .. kong.router.get_service().id
        else
            identifier = "router_id:" .. kong.router.get_route().id
        end
    elseif conf.limit_by == "uri" then
        identifier = "request_uri:" .. kong.request.get_path()
    elseif conf.limit_by == "ip" then
        identifier = "client_ip:" .. kong.client.get_ip()
    end
    return identifier
end

local function get_kong_nodes_number(counter_dict)
    return ngx.shared[counter_dict]:get(kong.node.get_id())
end

function _M.execute(conf)
    local limit
    local status, kong_nodes_number = pcall(get_kong_nodes_number, conf.counter_dict)
    if status and kong_nodes_number then
        kong_nodes_number = tonumber(kong_nodes_number)
        limit = math_floor(conf.limit / kong_nodes_number)
    else
        kong.log.err("can't get kong nodes numbers, may set kong nodes shared dict name error, downgrade to stand-alone mode to limit traffic")
        limit = conf.limit
    end

    local limit_key = get_limit_key(conf)
    local status, should_throttle, counter_key, last_counter_key = pcall(add_sample_and_estimate_total_count, conf.counter_dict, limit_key, limit, conf.window_size_in_seconds * 1000)

    --限流执行出错，为了不影响调用，打日志直接退出，不影响正常请求
    if not status then
        kong.log.err("can't execute limit traffic, may set counters shared dict name error, no limit on traffic")
        return
    end

    if should_throttle then
        return kong.response.error(429, conf.message)
    end

    pcall(keep_keys_under_plugin_instance, conf.counter_dict, conf.uuid, counter_key, last_counter_key, conf.window_size_in_seconds)
end

return _M
