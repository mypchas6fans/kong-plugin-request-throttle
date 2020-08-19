local _redis = require "kong.plugins.request-throttle.redis"
local json = require "cjson"
local resty_lock = require "resty.lock"

local function sync_counter_to_redis(conf, redis)
    local keys_array_str = ngx.shared[conf.counter_dict]:get(conf.uuid)
    if keys_array_str == nil or keys_array_str == '' then
        return
    end

    local keys_array = kong.table.new(2, 0)
    keys_array = json.decode(keys_array_str)
    ngx.timer.at(0, function(premature)
        if premature then
            return
        end
        redis:sync_redis_with_shm(keys_array, conf.counter_dict, conf.window_size_in_seconds, conf.limit)
    end)

end

local function fetch_kong_node_from_redis(redis, sync_rate)
    local now = ngx.time()
    redis:zadd("kong_nodes", now, kong.node.get_id())
    return redis:zcount("kong_nodes", now - sync_rate, now + sync_rate)
end

local function sync_kong_node(counter_dict, redis, sync_rate)
    --由于有多个插件实例存在
    --用lock来控制向redis同步kong节点数量的频率
    local lock, _ = resty_lock:new(counter_dict)
    if not lock then
        return
    end

    local elapsed, _ = lock:lock(ngx.time())
    lock:expire(3)
    if not elapsed then
        return
    end

    local kong_nodes_number = fetch_kong_node_from_redis(redis, sync_rate)
    if not kong_nodes_number then
        ngx.shared[counter_dict]:set(kong.node.get_id(), 1)
        return
    end
    ngx.shared[counter_dict]:set(kong.node.get_id(), kong_nodes_number)
end

local function sync_request_counter(premature)
    if premature then
        return
    end
    if ngx.worker.id() == 0 then
        for plugin, err in kong.db.plugins:each(1000,
                { cache_key = "request-throttle", }) do
            if err then
                kong.log.warn("error fetching plugin: ", err)
            end

            if plugin.name ~= "request-throttle" then
                goto plugin_iterator_continue
            end

            if plugin.enabled then
                --同步 kong 节点信息
                local redis = _redis:new()
                redis:init(plugin.config)
                sync_kong_node(plugin.config.counter_dict, redis, plugin.config.sync_rate)

                --根据时间间隔进行触发
                local trigger = ngx.time() % plugin.config.sync_rate == 0
                if trigger then
                    sync_counter_to_redis(plugin.config, redis)
                end

            end

            :: plugin_iterator_continue ::
        end
    end
end

return {
    sync_request_counter = sync_request_counter,
}