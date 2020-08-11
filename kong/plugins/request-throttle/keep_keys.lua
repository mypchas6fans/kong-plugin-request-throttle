local json = require "cjson"
local re_match = ngx.re.match

local _M = {}
local mt = { __index = _M }

function _M.new ()
    return setmetatable({}, mt)
end

local function insert(keys_array, pos, key)
    local contain = false
    for i = 1, #keys_array do
        if key == keys_array[i] then
            contain = true
        end
    end

    if contain == false then
        if pos then
            table.insert(keys_array, pos, key)
        else
            table.insert(keys_array, key)
        end
    end
end

local function remove_expired_keys(keys_array, last_counter_key)
    local err
    last_counter_key, err = re_match(last_counter_key, [[(?<=\.).*(?=.counter)]], "jo")
    if err then
        kong.log.err("error get key from last counter key by regex", err)
        return
    end

    last_counter_key = tonumber(last_counter_key[0])
    for i = #keys_array, 1, -1 do
        local key, err = re_match(keys_array[i], [[(?<=\.).*(?=.counter)]], "jo")
        if err then
            kong.log.notice("error get key from keys array by regex", err)
            return
        end
        if last_counter_key > 0 and next(key) ~= nil then
            local key_number = tonumber(key[0])
            if key_number < last_counter_key then
                table.remove(keys_array, i)
            end
        end
    end
end

function _M.copy_key_under_namespace(self, counter_dict, uuid, key, last_counter_key)
    local keys_array_str = ngx.shared[counter_dict]:get(uuid)
    local keys_array = {}
    setmetatable(keys_array, json.empty_array_mt)

    if keys_array_str then
        keys_array = json.decode(keys_array_str)
        insert(keys_array, nil, key)
    else
        insert(keys_array, 1, key)
    end
    remove_expired_keys(keys_array, last_counter_key)
    local err
    keys_array_str, err = json.encode(keys_array)
    if not keys_array_str then
        return nil, "could not encode keys array: " .. err
    end
    ngx.shared[counter_dict]:set(uuid, keys_array_str)
end

return _M