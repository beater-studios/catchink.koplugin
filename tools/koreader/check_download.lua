-- Downloads sprite sets through the plugin's own downloader, as the device does, and checks the files.
-- Run with tools/koreader/run_headless.sh tools/koreader/check_download.lua. CATCHINK_HOME keeps the files
-- (default: a temporary folder); SETS is a list like "red-blue@normal base@normal" (default: red-blue@normal).
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))

require("setupkoenv")
package.path = plugin_dir .. "/?.lua;" .. package.path

local Data = require("catchink/data")
local Downloader = require("catchink/net/downloader")
local SpriteSets = require("catchink/sprite_sets")
local Sprites = require("catchink/sprites")
local ffiutil = require("ffi/util")

local home = os.getenv("CATCHINK_HOME") or (os.getenv("OUTPUT_DIR") .. "/home")
os.execute("mkdir -p '" .. home .. "'")
local data = Data.new(plugin_dir .. "/data")
local sprites = Sprites.new{ dir = home .. "/sprites", manifest = data:sprites(), data = data }
local downloader = Downloader.new{ work_dir = home .. "/work" }

local wanted = os.getenv("SETS") or "red-blue@normal"
local failures = 0
for item in wanted:gmatch("%S+") do
    local id, variant = item:match("^(.-)@(.+)$")
    local set = assert(SpriteSets.get(id), "unknown set " .. tostring(id))
    local files = sprites:job_files(set, variant)
    sprites:make_dirs(set, variant)
    local started = os.time()
    local result
    downloader:add{ id = item, files = files, on_done = function(done, failed, total)
        result = { done = done, failed = failed, total = total }
    end }
    while downloader:tick() do
        ffiutil.sleep(1)
    end
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        if folder then
            sprites:forget(folder)
        end
    end
    local state = sprites:item_state(set, variant)
    print(string.format("%s: %d of %d files, %d failed, %d s, state %s", item, result and result.done or 0, #files,
        result and result.failed or -1, os.time() - started, state))
    if state ~= "done" then
        failures = failures + 1
    end
end
-- A host outside the list is refused by the worker.
local Worker = require("catchink/net/worker")
assert(not Worker.allowed("https://example.com/x.png"), "only raw.githubusercontent.com is allowed")
assert(Worker.allowed("https://raw.githubusercontent.com/PokeAPI/sprites/x.png"))
print(failures == 0 and "downloads ok" or (failures .. " sets incomplete"))
os.exit(failures == 0 and 0 or 1)
