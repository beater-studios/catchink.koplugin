-- Cases of tools/koreader/check_sleep.lua for this plugin: the timers are the toast that closes by itself and
-- the tick of a sprite download.
local function open(plugin_dir)
    -- main.lua does this when KOReader loads the plugin.
    require("catchink/awake").install("catchink")
    local Screen = require("catchink/ui/screen")
    local screen = Screen:new{ plugin_dir = plugin_dir }
    if #screen.profiles == 0 then
        screen:create_profile("Sleep", { model = "normal" })
    end
    return screen
end

return {
    ["catchink/ui/surface"] = "base class of the screen, never opened by itself",
    ["box with a toast"] = function(plugin_dir)
        local screen = open(plugin_dir)
        local profile = screen.profiles[1]
        screen:show("browse", { profile = profile, game = profile.games[1] })
        screen:toggle(profile, profile.games[1], screen:entries(profile, profile.games[1])[1])
        return screen
    end,
    ["sprites screen with a download running"] = function(plugin_dir)
        local screen = open(plugin_dir)
        -- A child that never ends and never writes, so the check needs no network.
        screen.downloader.spawn = function() return 1 end
        screen.downloader.is_done = function() return false end
        screen.downloader.kill = function() end
        screen:show("sprites", { profile = screen.profiles[1] })
        screen:download(require("catchink/sprite_sets").get("red-blue"), "normal")
        return screen
    end,
}
