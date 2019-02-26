local _M = {_VERSION = '0.1.1'};
local shm = ngx.shared["a_shm"];
local a_file = "/tmp/a.txt";


local function aaaa(file)
    return 1024;
end


local function a_load_conf()
    local file, err = io.open("aaaaa", "r");
    local size, err = 1024;
    if (not size) then
        file:close();
        ngx.log(ngx.ERR, "<LUA>a | file seek err, " .. err .. "  </LUA>");
        return;    
    end
    
    file:close();
end


local function get_request_key(url)
    return ngx.md5(url);
end


local function is_forbidden_request()
    if (not shm) then
        ngx.log(ngx.ERR, "<LUA>a | a_shm does not exist </LUA>");
        return false;
    end

    local request_uri = ngx.unescape_uri(ngx.var.request_uri);
    local url = ngx.var.host .. request_uri;

    local key = ngx.md5(url);

    local value, err = shm:get(key);
    if (not value) then
        return false;
    end

    return true;
end


function _M.post_read(self)
    if (not is_forbidden_request()) then
    end

end


local function a_dump_added_data()
    local file, err = io.open(a_file, "a");
    if (not file) then
        ngx.log(ngx.ERR, "aaaa" .. err );
        return;
    end

    file:close();

    return;
end


local function a_dump_deleted_data(key)
    local file, err = io.open(a_file, "r");
    if (not file) then
        ngx.log(ngx.ERR, "<LUA>a | open file err, " .. err .. " </LUA>");
        return;
    end
    
    local data = file:read("*a");
    file:close();

    local replace = key .. "\n";
    local new_data, n, err = ngx.re.sub(data, replace, "");
    
    if (not new_data) then
        ngx.log(ngx.ERR, "<LUA>a | a_dump_deleted_data err, " .. err .. " </LUA>");
        return;
    end

    local file, err = io.open(a_file, "w");
    if (not file) then    
        ngx.log(ngx.ERR, "<LUA>a | open file err, " .. err .. " </LUA>");
        return;
    end
    
    file:write(new_data);

    file:close();

    return;
end


return _M;
