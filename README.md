# Release Notes

Adapt to the 2.0.x version of Kong.



# Kong-Plugin-Request-Throttle

Kong distributed traffic limit plugin.



# Know More

https://juejin.im/post/6862723818352279565/



# Status

Experimental



# Supported Kong Releases

Kong >= 2.0.x



# Installation

You can install it according to the kong custom plugin installation method

https://docs.konghq.com/2.0.x/plugin-development/distribution/



# Implementation details

This plugin makes use of [lua-resty-redis-connector](https://github.com/ledgetech/lua-resty-redis-connector) under the hood.



# Quickstart

I suggest the easiest way to install and use this plugin.

1. Copy the plugin directory `request-throttle` to the runtime directory of kong plugin.
   If you install kong on centos7 system, the runtime directory of kong plugin is 

   `/usr/local/share/lua/5.1/kong/plugins`.

2. Copy the resty directory `redis` to the runtime directory of the resty library used by kong.
   If you install kong on centos7 system, the runtime directory of kong plugin is `/usr/local/share/lua/5.1/resty`.

3. . Create a new `extend.conf` file, define lua_shared_dict

   ```
   lua_shared_dict request_throttle_counter 60m;
   ```

   Note that the variable name `request_throttle_counter` defined here must be consistent with value of the parameter `config.counter_dict` configured during use.

4. Modify kong.conf, enable plug-ins, and include `extend.conf` 

   ```
   plugins = bundled, request-throttle
   nginx_http_include = /path/to/your/extend.conf
   ```



## Configuration

Here's a list of all the parameters which can be used in this plugin's configuration:

| Form Parameter                           | default                  | description                                                  |      |
| ---------------------------------------- | ------------------------ | ------------------------------------------------------------ | ---- |
| `name`                                   |                          | The name of the plugin to use, in this case `request-throttle` |      |
| `service.id`                             |                          | The ID of the Service the plugin targets.                    |      |
| `route.id`                               |                          | The ID of the Route the plugin targets.                      |      |
| `config.limit`                           |                          | One or more requests-per-window limits to apply.             |      |
| `config.window_size_in_seconds`          |                          | One or more window sizes to apply a limit to (defined in seconds). |      |
| `config.limit_by`                        |                          | How to define the rate limit key. Can be `ip`, `uri`, `route`, `service`. |      |
| `config.sync_rate` Optional              | 1                        | How often to sync counter data to the central data store     |      |
| `config.strategy` Optional               | redis                    | he sync strategy to use; `redis` and `redis-sentinel` are supported. |      |
| `config.counter_dict` Optional           | request_throttle_counter | The shared dictionary where counters will be stored until the next sync cycle. |      |
| `config.uuid` Optional                   | uuid                     | The instance id  to use for this plugin. Counter data and sync configuration is shared in a namespace. |      |
| `config.redis.host` Optional             |                          | Host to use for Redis connection when the `redis` strategy is defined. |      |
| `config.redis.port` Optional             | 6379                     | Port to use for Redis connection when the `redis` strategy is defined. |      |
| `config.redis.timeout` Optional          | 2000                     | Connection timeout (in milliseconds) to use for Redis connection. |      |
| `config.redis.password`                  |                          | Password to use for Redis connection. If undefined, no AUTH commands are sent to Redis. |      |
| `config.redis.database`                  |                          | Database to use for Redis connection when the `redis` strategy is defined. |      |
| `config.redis.sentinel_master`           |                          | Sentinel master to use for Redis connection when the `redis-sentinel` strategy is defined. Defining this value implies using Redis Sentinel. |      |
| `config.redis.sentinel_role`             | master                   | Sentinel role to use for Redis connection when the `redis-sentinel` strategy is defined. `master` and `slave` are supported. |      |
| `config.redis.sentinel_address`          |                          | Sentinel addresses to use for Redis connection when the `redis-sentinel` strategy is defined. Defining this value implies using Redis Sentinel. |      |
| `config.redis.max_idle_timeout` Optional | 30000                    | Maximum idle time of redis connection                        |      |
| `config.redis.pool_size` Optional        | 3                        | Redis connection pool size                                   |      |




## Maintainers

[tzssangglass](https://github.com/tzssangglass)

## Acknowledgements

[lua-resty-global-throttle](https://github.com/ElvinEfendi/lua-resty-global-throttle) 

[lua-resty-redis-connector](
