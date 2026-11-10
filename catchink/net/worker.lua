-- Runs inside a child process: downloads a list of files one by one, so the screen never waits for the network.
-- The list has one "url<TAB>path" per line. After each file the progress file gets "done failed total".
-- A file named like the progress file plus ".stop" ends the work early. After STOP_AFTER failures in a row
-- (no Wi-Fi, the server down) it gives up and ends with "stopped", so it never waits on every file.
-- Each file is one request of the HTTPS pattern (Request.run), already inside this child: the name of the
-- server is checked on any KOReader version, with no proxy and no redirects.
local Request = require("catchink/https_request")

local Worker = {}

local HOSTS = { ["raw.githubusercontent.com"] = true }
local STOP_AFTER = 8

local function write_atomic(path, text)
    local tmp = path .. ".tmp"
    local file = io.open(tmp, "wb")
    if file then
        file:write(text)
        file:close()
        os.rename(tmp, path)
    end
end

local function exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

function Worker.allowed(url)
    local host = Request.host(url)
    return host ~= nil and HOSTS[host] == true
end

-- One file; true when it was saved. It arrives as <path>.part and gets its name only when complete.
function Worker.fetch(url, path, ca_file, user_agent, timeout)
    if not Worker.allowed(url) then
        return false
    end
    local spec = {
        url = url,
        headers = { ["user-agent"] = user_agent or "CatchInk" },
        ca_file = ca_file,
        timeout = timeout or 30,
        out_path = path .. ".part",
        code_path = path .. ".code",
    }
    local code = Request.run(spec)
    os.remove(spec.code_path)
    if code == 200 then
        os.rename(spec.out_path, path)
        return true
    end
    os.remove(spec.out_path)
    return false
end

function Worker.run(list_path, progress_path, ca_file, user_agent)
    local jobs = {}
    for line in io.lines(list_path) do
        local url, path = line:match("^([^\t]+)\t(.+)$")
        if url then
            jobs[#jobs + 1] = { url, path }
        end
    end
    local done, failed, in_a_row = 0, 0, 0
    local stopped = false
    local stop_path = progress_path .. ".stop"
    write_atomic(progress_path, string.format("%d %d %d", done, failed, #jobs))
    for _, job in ipairs(jobs) do
        if exists(stop_path) then
            break
        end
        if exists(job[2]) then
            done = done + 1
        else
            -- A second try covers a connection that dropped once.
            local ok = pcall(Worker.fetch, job[1], job[2], ca_file, user_agent)
            if not (ok and exists(job[2])) then
                ok = pcall(Worker.fetch, job[1], job[2], ca_file, user_agent)
            end
            if ok and exists(job[2]) then
                done = done + 1
                in_a_row = 0
            else
                failed = failed + 1
                in_a_row = in_a_row + 1
            end
        end
        write_atomic(progress_path, string.format("%d %d %d", done, failed, #jobs))
        if in_a_row >= STOP_AFTER then
            stopped = true
            break
        end
    end
    write_atomic(progress_path, string.format("%d %d %d end%s", done, failed, #jobs, stopped and " stopped" or ""))
end

return Worker
