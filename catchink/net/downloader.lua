-- Downloads sprite sets in the background, one child process at a time, and reports the progress.
local Downloader = {}
Downloader.__index = Downloader

local PLUGIN_DIR = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/catchink/net/downloader%.lua$", "")

local function quote(text)
    return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local data = file:read("*a")
    file:close()
    return data
end

local function is_macos()
    return jit and jit.os == "OSX"
end

-- opts: work_dir (private folder for the list and progress files), ca_file, user_agent, and for the tests
-- spawn(list, progress), is_done(pid), kill(pid).
function Downloader.new(opts)
    return setmetatable({
        work_dir = opts.work_dir,
        -- KOReader's own list of trusted certificates, relative to its folder (Request.CA_FILE).
        ca_file = opts.ca_file or "data/ca-bundle.crt",
        user_agent = opts.user_agent or "CatchInk",
        spawn = opts.spawn,
        is_done = opts.is_done,
        kill = opts.kill,
        queue = {},
        current = nil,
    }, Downloader)
end

-- When the screen opens: the work folder, private to the user, without the lists and progress files that a
-- crash during a download may have left. The files downloaded so far are elsewhere and stay.
function Downloader:reset_work_dir()
    os.execute("rm -rf " .. quote(self.work_dir) .. " && mkdir -p " .. quote(self.work_dir) .. " && chmod 700 " .. quote(self.work_dir))
end

function Downloader:spawn_process(list_path, progress_path)
    if self.spawn then
        return self.spawn(list_path, progress_path)
    end
    if is_macos() then
        local pid_path = progress_path .. ".pid"
        os.execute(string.format("./luajit %s %s %s %s %s %s >/dev/null 2>&1 & echo $! > %s",
            quote(PLUGIN_DIR .. "/catchink/net/worker_main.lua"), quote(PLUGIN_DIR), quote(list_path), quote(progress_path),
            quote(self.ca_file), quote(self.user_agent), quote(pid_path)))
        local pid = tonumber(read_file(pid_path) or "")
        os.remove(pid_path)
        return pid
    end
    local util = require("ffi/util")
    local Worker = require("catchink/net/worker")
    local ca_file, user_agent = self.ca_file, self.user_agent
    return util.runInSubProcess(function()
        Worker.run(list_path, progress_path, ca_file, user_agent)
    end)
end

-- Whether a child ended; on the device this also collects it (waitpid), so it does not stay as a zombie.
function Downloader:process_done(pid, wait)
    if self.is_done then
        return self.is_done(pid, wait)
    end
    if is_macos() then
        local result = os.execute(string.format("kill -0 %d 2>/dev/null", pid))
        return not (result == 0 or result == true)
    end
    return require("ffi/util").isSubProcessDone(pid, wait)
end

-- Children that ended or were killed still have to be collected; the ones not collected yet wait here.
function Downloader:collect(pid)
    if pid and not self:process_done(pid) then
        self.unreaped = self.unreaped or {}
        self.unreaped[#self.unreaped + 1] = pid
    end
end

function Downloader:reap()
    for i = #(self.unreaped or {}), 1, -1 do
        if self:process_done(self.unreaped[i]) then
            table.remove(self.unreaped, i)
        end
    end
end

function Downloader:kill_process(pid)
    if self.kill then
        return self.kill(pid)
    end
    if is_macos() then
        os.execute(string.format("kill -9 %d 2>/dev/null", pid))
        return
    end
    require("ffi/util").terminateSubProcess(pid)
end

-- job: { id, files = { { url, path } }, on_done(done, failed, total) }. Jobs run one after the other.
function Downloader:add(job)
    for _, j in ipairs(self.queue) do
        if j.id == job.id then
            return
        end
    end
    if self.current and self.current.id == job.id then
        return
    end
    self.queue[#self.queue + 1] = job
end

function Downloader:busy_with(id)
    if self.current and self.current.id == id then
        return "running"
    end
    for _, j in ipairs(self.queue) do
        if j.id == id then
            return "queued"
        end
    end
    return nil
end

function Downloader:active()
    return self.current ~= nil or #self.queue > 0
end

-- Whether the screen should keep ticking: a download runs, or a child still waits to be collected.
function Downloader:busy()
    return self:active() or #(self.unreaped or {}) > 0
end

-- Each job is split among a few child processes: the time goes into opening connections, not into the CPU.
local PARTS = 3

function Downloader:launch(job)
    os.execute("mkdir -p " .. quote(self.work_dir) .. " && chmod 700 " .. quote(self.work_dir))
    local base = self.work_dir .. "/" .. job.id:gsub("[^%w%-]", "_")
    local count = math.max(1, math.min(PARTS, #job.files))
    job.parts = {}
    for p = 1, count do
        local part = { list_path = base .. "." .. p .. ".list", progress_path = base .. "." .. p .. ".progress" }
        os.remove(part.progress_path)
        os.remove(part.progress_path .. ".stop")
        local file = io.open(part.list_path, "wb")
        if not file then
            return false
        end
        for i = p, #job.files, count do
            local f = job.files[i]
            file:write(f[1], "\t", f[2], "\n")
        end
        file:close()
        part.pid = self:spawn_process(part.list_path, part.progress_path)
        job.parts[p] = part
    end
    job.done, job.failed, job.total = 0, 0, #job.files
    for _, part in ipairs(job.parts) do
        if not part.pid then
            return false
        end
    end
    return true
end

-- Sums the progress of the parts. Returns true when every part says it ended.
function Downloader:read_progress(job)
    local done, failed, ended = 0, 0, true
    for _, part in ipairs(job.parts or {}) do
        local text = read_file(part.progress_path) or ""
        local d, f = text:match("^(%d+) (%d+) %d+")
        if d then
            part.done, part.failed = tonumber(d), tonumber(f)
        end
        done = done + (part.done or 0)
        failed = failed + (part.failed or 0)
        part.ended = text:find("end", 1, true) ~= nil
        if text:find("stopped", 1, true) then
            job.stopped = true
        end
        if not part.ended then
            ended = false
        end
    end
    job.done, job.failed = done, failed
    return ended
end

function Downloader:finish(job)
    self.current = nil
    for _, part in ipairs(job.parts or {}) do
        self:collect(part.pid)
        os.remove(part.list_path)
        os.remove(part.progress_path)
        os.remove(part.progress_path .. ".stop")
    end
    if job.on_done then
        job.on_done(job.done or 0, job.failed or 0, job.total or #job.files, job.cancelled, job.stopped)
    end
end

-- Called now and then by the screen. Returns true while something runs.
function Downloader:tick()
    self:reap()
    local job = self.current
    if job then
        local ended = self:read_progress(job)
        local alive = false
        for _, part in ipairs(job.parts or {}) do
            if part.pid and not part.ended and not self:process_done(part.pid) then
                alive = true
            end
        end
        if ended or not alive then
            self:read_progress(job)
            self:finish(job)
        end
    end
    if not self.current and #self.queue > 0 then
        local next_job = table.remove(self.queue, 1)
        self.current = next_job
        if not self:launch(next_job) then
            for _, part in ipairs(next_job.parts or {}) do
                if part.pid then
                    self:kill_process(part.pid)
                end
            end
            next_job.failed = #next_job.files
            self:finish(next_job)
        end
    end
    return self:busy()
end

function Downloader:progress(id)
    local job = self.current
    if job and job.id == id then
        return job.done or 0, job.total or #job.files, job.failed or 0
    end
    return nil
end

-- Stops a job: one in the queue leaves it, the running one is asked to stop and then killed.
function Downloader:cancel(id)
    for i, j in ipairs(self.queue) do
        if j.id == id then
            table.remove(self.queue, i)
            return
        end
    end
    local job = self.current
    if job and job.id == id then
        job.cancelled = true
        for _, part in ipairs(job.parts or {}) do
            local stop = io.open(part.progress_path .. ".stop", "wb")
            if stop then
                stop:close()
            end
            if part.pid then
                self:kill_process(part.pid)
            end
        end
        self:read_progress(job)
        self:finish(job)
    end
end

function Downloader:stop()
    self.queue = {}
    if self.current then
        self:cancel(self.current.id)
    end
    -- Killed children end at once: wait for each, so none is left behind when the plugin closes.
    for _, pid in ipairs(self.unreaped or {}) do
        self:process_done(pid, true)
    end
    self.unreaped = {}
end

return Downloader
