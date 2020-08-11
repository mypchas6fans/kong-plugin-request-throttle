local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.request-throttle.access"
local sync = require "kong.plugins.request-throttle.sync"

local RequestThrottleHandler = BasePlugin:extend()

RequestThrottleHandler.VERSION = "0.0.1"
RequestThrottleHandler.PRIORITY = 902

function RequestThrottleHandler:init_worker()
    local worker_id = ngx.worker.id()
    kong.log.info("request throttle sync counters to redis started on worker ", worker_id)
    ngx.timer.every(1, sync.sync_request_counter)
end

function RequestThrottleHandler:new()
    RequestThrottleHandler.super.new(self, "request-throttle")

end

function RequestThrottleHandler:access(conf)
    RequestThrottleHandler.super.access(self)
    access.execute(conf)
end

return RequestThrottleHandler