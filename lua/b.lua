
local _M = {_VERSION = '0.0.1'};

local cjson = require("cjson.safe");
local shm = ngx.shared["b_shm"];
local b_file = "/tmp/b.txt";
local b_file_max = 1*1024*1024;


local function lines(str, c)
    local t = {};
    local function helper(line) table.insert(t, line) return "" end
    helper((str:gsub("(.-)" .. c, helper)))
    return t;
end


local function is_empty_table(t)
    if (next(t)) then
        return false;
    end

    return true;
end


local function file_get_size(file)
    local size, err = file:seek("end");
    if (err) then
        return false, err;
    end
    
    local start, err = file:seek("set");
    if (err) then
        return false, err;
    end

    return size, nil;
end


local function file_get_contents(file, max_size)
    local file, err = io.open(file, "r");
    if (not file) then
        return nil, err;
    end

    local size, err = file_get_size(file);
    if (not size) then
        file:close();
        return nil, err;
    end

    if (size > max_size) then
        file:close();
        return nil, "file size:" .. size .. "> max_size:" .. max_size;
    end

    local contents = file:read("*a");
    file:close();

    return contents, nil;
end


local function file_put_contents(file, contents)
    local file, err = io.open(file, "w");
    if (not file) then
        return false, err;
    end

    file:write(contents);
    file:close();

    return true, nil;
end


local function file_get_json_contents()
    local data, err = file_get_contents(b_file, b_file_max);
    if (not data) then
        return nil, err;
    end

    local conf = cjson.decode(data);
    if (not conf) then
        return nil, "file no json";
    end

    return conf, nil;
end


local function file_put_json_contents(conf)
    local str = cjson.encode(conf);

    if (#str > b_file_max) then
        return false, "str is " .. #str .. " more len file max " .. b_file_max;
    end

    local suc, err = file_put_contents(b_file, str);
    if (not suc) then
        return false, err;
    end

    return true, nil;
end


local function get_ip_conf_key(domain)
    local key = domain .. ";conf";
    return key;
end


local function get_ip_key(domain, ip)
    local key = domain .. ";" .. ip;
    return key;
end


local function is_legal_ip(ip)
    local pattern = "(^\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3}$)";
    local m, err = ngx.re.match(ip, pattern, "jo");
    if (not m) then
        return false;
    end
    
    if (not ((tonumber(m[1]) <= 255) and (tonumber(m[2]) <= 255) 
        and (tonumber(m[3]) <= 255) and (tonumber(m[4]) <= 255))) then
        return false;
    end

    return true;
end


local function refresh_domain_conf(ip_conf)
    if (type(ip_conf) ~= "table") then
        return nil;
    end

    local now = ngx.time();

    for ip, expired in pairs(ip_conf) do
        expired = tonumber(expired);

        if (not (expired and expired > now and is_legal_ip(ip))) then
            ip_conf[ip] = nil;
        end
    end

    if (is_empty_table(ip_conf)) then
        ip_conf = nil;
    end

    return ip_conf;
end


local function refresh_conf(conf)
    for domain, domain_conf in pairs(conf) do
        if (type(domain_conf) ~= "table"
            or is_empty_table(domain_conf)) then
            return {};
        end

        for k, v in pairs(domain_conf) do
            if (k ~= "ip") then
                return {};
            end
        end

        if (domain_conf["ip"]) then
            domain_conf["ip"] = refresh_domain_conf(domain_conf["ip"]);
        end

        if (is_empty_table(domain_conf)) then
            domain_conf = nil;
        end

        conf[domain] = domain_conf;
    end

    return conf;
end


local function shm_update_domain_conf(domain, new_ip_conf)
    local now = ngx.time();
    local ip_conf_key = get_ip_conf_key(domain);
    local str = shm:get(ip_conf_key);

    local ip_conf = {};
    if (str) then
        ip_conf = cjson.decode(str);
    end

    -- flush ip_connf in memory
    for ip, expired in pairs(ip_conf) do
        if (expired <= now) then
            ip_conf[ip] = nil;
        end
    end

    -- ip_conf add new_ip_conf
    for ip, expired in pairs(new_ip_conf) do
        expired = tonumber(expired);
        local ip_key = get_ip_key(domain, ip);

        if (expired == 0) then
            ip_conf[ip] = nil;
            shm:delete(ip_key);

        else
            ip_conf[ip] = expired;
            local ttl = expired - now;
            shm:set(ip_key, 1, ttl);
        end
    end

    if (is_empty_table(ip_conf)) then
        shm:delete(domain);
        shm:delete(ip_conf_key);

    else
        shm:set(domain, 1);
        str = cjson.encode(ip_conf);
        shm:set(ip_conf_key, str);
    end
end


local function shm_update_conf(conf)
    for domain, domain_conf in pairs(conf) do
        local ip_conf = domain_conf["ip"];
        if (ip_conf) then
           shm_update_domain_conf(domain, ip_conf)
        end
    end
end


function _M.init_work(self)
    if (not shm) then
        ngx.log(ngx.ERR, "<LUA>b does not exist </LUA>");
        return;
    end

    local suc, err = shm:add("b_loaded", "1");
    if (err) then
        return;
    end
end


local function is_forbidden_ip()
    local key = get_ip_key(ngx.var.host, ngx.var.remote_addr);
    local value = shm:get(key);
    if (not value) then
        return false;
    end

    return true;
end


local function is_forbidden_request()
    if (not shm) then
        ngx.log(ngx.ERR, "<LUA>b does not exist </LUA>");
        return false;
    end

    local value = shm:get(ngx.var.host);
    if (not value) then
        return false;
    end

    if (is_forbidden_ip()) then
        return true;
    end

    return false;
end


local function get_forbidden_html()
    local host = "host";

    local str = "";
    str = str .. "<html><head><title>ERROR: ACCESS DENIED</title></head><body><center><h1>ERROR: ACCESS DENIED</h1></center><hr>\n";
    str = str .. "<center>403/" .. host .. "</center></BODY></HTML>";
    
    return str;
end


local function sent_forbidden_html()
    local status = ngx.HTTP_FORBIDDEN;

    ngx.status = status;
    ngx.header['Content-Type'] = "text/html";

    local data = get_forbidden_html();
    ngx.say(data);

    ngx.exit(status);
end


function _M.access(self)
    if (ngx.var.http_x_ae) then
        return;
    end

    if (not is_forbidden_request()) then
        return;
    end

    sent_forbidden_html();
end


local function get_domain_conf(domain_line)
    local now = ngx.time();
    local ip_conf = {};

    local t = lines(domain_line, ",");

    for _, pair in ipairs(t) do
        local pos = string.find(pair, ";");
        if (not pos) then
            return false;
        end
        
        local ip = string.sub(pair, 1, pos-1);
        local ttl = tonumber(string.sub(pair, pos+1));

        if (not (ttl and ttl >= 0 and is_legal_ip(ip))) then
            return false;
        end

        local expired = 0;
        if (ttl > 0) then
            expired = ttl + now;
        end
        
        ip_conf[ip] = expired;
    end

    if (is_empty_table(ip_conf)) then
        return false;
    end

    return {["ip"] = ip_conf};
end


local function get_post_rule()
    ngx.req.read_body();
    local data = ngx.req.get_body_data();
    if (not data) then
        return nil, "no recv data";
    end

    local conf = {};
    local items = lines(data, "\n");

    for _, line in pairs(items) do
        local pos = string.find(line, " ");
        if (not pos) then
            return nil, "not find spacing";
        end

        local domain = string.sub(line, 1, pos-1);
        local domain_line = string.sub(line, pos+1);

        local domain_conf = get_domain_conf(domain_line);
        if (not domain_conf) then
            return nil, "format err";
        end

        conf[domain] = domain_conf;
    end

    return conf;
end


function _M.set(self)
    local new_conf, err = get_post_rule();
    if (not new_conf) then
        return 403, err;
    end

    shm_update_conf(new_conf);

    return 200, "ok";
end



return _M;

