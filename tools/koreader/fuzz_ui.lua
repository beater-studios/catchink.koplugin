-- Random taps, holds and swipes through the real views, with the fuzz pattern (tools/koreader/fuzz.lua).
-- One run per view and language, each from nothing saved, with two profiles and some catches. Downloads are
-- switched off. Run with tools/koreader/run_headless.sh tools/koreader/fuzz_ui.lua (ACTIONS, SEED, ONLY).
local Fuzz = dofile(os.getenv("PLUGIN_DIR") .. "/tools/koreader/fuzz.lua")
local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local Screen = require("catchink/ui/screen")
-- main.lua does this when KOReader loads the plugin.
require("catchink/awake").install("catchink")

local settings_dir = DataStorage:getSettingsDir()
local home = DataStorage:getDataDir() .. "/catchink"

local screen

-- A new screen with nothing saved by the run before.
local function fresh(lang)
    if screen and UIManager:isWidgetShown(screen) then
        UIManager:close(screen)
    end
    os.execute("rm -f '" .. settings_dir .. "'/catchink*.lua*")
    os.execute("rm -rf '" .. home .. "'")
    screen = Screen:new{ plugin_dir = Fuzz.plugin_dir }
    screen.downloader.add = function() end
    screen:set_language(lang)
    local main = screen:create_profile("Fuzz", { model = "living" })
    screen:create_profile("Shiny", { model = "shiny" })
    local caps = screen:caps(main)
    for i = 1, 40, 3 do
        caps:set("red-blue", tostring(i), "c", 1762000000 + i)
    end
    caps:set("red-blue", "12", "s", 1762000000)
    screen:save_caps(main)
    return screen, main
end

-- Each run: where it starts, given the screen and the first profile.
local VIEWS = {
    { "home", function() end },
    { "games", function(s, p) s:show("games", { profile = p }) end },
    { "box", function(s, p) s:show("browse", { profile = p, game = "red-blue" }) end },
    { "list", function(s, p) s:show("browse", { profile = p, game = "scarlet-violet", mode = "list" }) end },
    { "national", function(s, p) s:show("browse", { profile = p, game = "home" }) end },
    { "card", function(s, p)
        local list = s:entries(p, "red-blue")
        s:show("card", { profile = p, game = "red-blue", list = list, index = 25 })
    end },
    { "filters", function(s, p)
        local view = s:show("browse", { profile = p, game = "red-blue" })
        s:show("filters", { profile = p, game = "red-blue", browse = view })
    end },
    { "profile form", function(s, p) s:show("profile_form", { profile = p }) end },
    { "progress", function(s, p) s:show("progress", { profile = p }) end },
    { "sprites", function(s, p) s:show("sprites", { profile = p }) end },
    { "about", function(s, p) s:show("about", { profile = p }) end },
    { "type chart", function(s) s:show("type_chart", {}) end },
    { "card types", function(s, p)
        local list = s:entries(p, "red-blue")
        s:show("card", { profile = p, game = "red-blue", list = list, index = 6, tab = 7 })
    end },
}

local first = fresh("en")
local fuzz = Fuzz.new{ screen = first }
for _, lang in ipairs({ "pt", "en", "es" }) do
    for _, view in ipairs(VIEWS) do
        -- The three languages for the views with the most text, English for the others.
        if lang == "en" or view[1] == "home" or view[1] == "box" or view[1] == "card" then
            local label = view[1] .. " " .. lang
            local depth, kind, errors
            fuzz:run{
                label = label,
                -- The first time, and after an error, from nothing saved; when the run only wandered off, back
                -- to its view on the same screen, keeping what the touches marked.
                setup = function(f)
                    if screen.fuzz_run == label and f.errors == errors and UIManager:isWidgetShown(screen) then
                        while #screen.stack > depth do
                            table.remove(screen.stack)
                        end
                        if screen:current().kind == kind then
                            screen:set_view(screen:current())
                            return screen
                        end
                    end
                    local s, p = fresh(lang)
                    UIManager:show(s)
                    view[2](s, p)
                    s.fuzz_run = label
                    depth, kind, errors = #s.stack, s:current().kind, f.errors
                    return s
                end,
                -- Out of the view where the run started, or now and then with a dialog left on top.
                again = function(f)
                    local current = screen:current()
                    if #screen.stack < depth or not current or current.kind ~= kind then
                        return true
                    end
                    local stack = UIManager._window_stack
                    return stack[#stack].widget ~= screen and f.random(1, 6) == 1
                end,
            }
        end
    end
end
fuzz:finish()
