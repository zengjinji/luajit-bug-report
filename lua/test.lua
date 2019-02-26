local _M = {_VERSION = '0.1.1'};

local shm = ngx.shared["common_shm"];

local key = "aaaaa";

function _M.shm_set(self)
    local str = string.rep("aaaaaaaaaa",520);
    shm:set(key, str);
    ngx.say("ok")
end


function _M.shm_get(self)
    local str = shm:get(key);
    ngx.say(#str)
end


return _M;
