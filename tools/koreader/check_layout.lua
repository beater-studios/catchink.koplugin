-- Opens every view in the three languages and checks the layout: no view fails to draw, no text or touch area
-- leaves the screen, and no text of the interface is cut for being wider than its box (names, places and
-- other data may be cut on purpose; they are only counted). Also checks the version on the About view, the
-- profiles and catches read again by a new screen, a save of a build from before the first release opened by the screen, the refresh modes,
-- the Back key and a view that fails to draw.
-- Run with tools/koreader/check_all_sizes.sh (four screen sizes) or tools/koreader/run_headless.sh.
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local out_dir = assert(os.getenv("OUTPUT_DIR"))

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
package.path = plugin_dir .. "/?.lua;" .. package.path

local Device = require("device")
local DeviceScreen = Device.screen
require("document/canvascontext"):init(Device)
local UIManager = require("ui/uimanager")
UIManager:init()
local Event = require("ui/event")
local Geom = require("ui/geometry")
local lfs = require("libs/libkoreader-lfs")

local Draw = require("catchink/ui/draw")
local Look = require("catchink/ui/look")
local Screen = require("catchink/ui/screen")
-- main.lua does this when KOReader loads the plugin.
require("catchink/awake").install("catchink")

local meta = dofile(plugin_dir .. "/_meta.lua")
local settings_dir = DataStorage:getSettingsDir()
local home_dir = DataStorage:getDataDir() .. "/catchink"
local W, H = DeviceScreen:getWidth(), DeviceScreen:getHeight()

local problems = 0
local function problem(text)
    problems = problems + 1
    print("PROBLEM: " .. text)
end

local function shot(name)
    UIManager:forceRePaint()
    DeviceScreen.bb:writePNG(out_dir .. "/" .. name .. ".png")
end

-- Every text drawn, with its box, so a cut one or one off the screen can be told.
local drawn = {}
local real_text = Draw.text
Draw.text = function(bb, text, face, x, y, w, h, align, color)
    if text and text ~= "" then
        drawn[#drawn + 1] = { text = text, x = x, y = y, w = w, h = h, cut = Draw.text_width(text, face) > math.floor(w) + 1 }
    end
    return real_text(bb, text, face, x, y, w, h, align, color)
end

local failed_paints = 0
local real_failed = Screen.paint_failed
Screen.paint_failed = function(self, ctx)
    failed_paints = failed_paints + 1
    return real_failed(self, ctx)
end

local function interface_texts(t, out)
    out = out or {}
    for _, v in pairs(t) do
        if type(v) == "string" then
            -- Labels are drawn in capitals.
            out[v] = true
            out[Look.upper(v)] = true
        elseif type(v) == "table" then
            interface_texts(v, out)
        end
    end
    return out
end

local data_cut, views_checked = 0, 0
local function check_view(screen, name)
    drawn = {}
    local before = failed_paints
    shot(name)
    views_checked = views_checked + 1
    if failed_paints > before then
        problem(name .. ": the view failed to draw")
    end
    local own = interface_texts(screen.t)
    for _, d in ipairs(drawn) do
        if d.y < -1 or d.y + d.h > H + 1 or d.x < -1 or d.x + d.w > W + 1 then
            problem(string.format("%s: text off the screen (%d,%d %dx%d): %s", name, d.x, d.y, d.w, d.h, d.text))
        elseif d.cut then
            if own[d.text] then
                problem(name .. ": interface text cut: " .. d.text)
            else
                data_cut = data_cut + 1
            end
        end
    end
    for _, h in ipairs(screen.hits) do
        if h.x < 0 or h.y < 0 or h.x + h.w > W + 1 or h.y + h.h > H + 1 then
            problem(string.format("%s: touch area off the screen (%d,%d %dx%d)", name, h.x, h.y, h.w, h.h))
        end
    end
end

local function close_above(screen)
    local stack = UIManager._window_stack
    while #stack > 0 and stack[#stack].widget ~= screen do
        UIManager:close(stack[#stack].widget)
    end
end

local function clean()
    os.execute("rm -f '" .. settings_dir .. "'/catchink*.lua*")
    os.execute("rm -rf '" .. home_dir .. "'")
end

local function open()
    local screen = Screen:new{ plugin_dir = plugin_dir }
    screen.downloader.add = function() end
    UIManager:show(screen)
    return screen
end

local function sample(screen)
    local main = screen:create_profile("Principal", { model = "normal" })
    screen:create_profile("Living Dex com um nome comprido de perfil", { model = "living" })
    local caps = screen:caps(main)
    for i = 1, 60, 2 do
        caps:set("red-blue", tostring(i), "c", 1762000000 + i * 3600)
    end
    caps:set("red-blue", "12", "s", 1762000000)
    caps:set("red-blue", "151", "u", 1762000000)
    caps:set_note("red-blue", "25", "Floresta de Viridian, perto da entrada sul, na grama alta")
    screen:save_caps(main)
    return main
end

-- Every view, in every language.
clean()
local screen = open()
local main = sample(screen)
local CARDS = { { "red-blue", 25 }, { "scarlet-violet", 1 }, { "home", 133 }, { "legends-arceus", 1 } }
for _, lang in ipairs({ "en", "pt", "es" }) do
    screen:set_language(lang)
    local function view(name, kind, args)
        screen:show(kind, args)
        check_view(screen, name .. "_" .. lang)
        screen:back_to("home")
    end
    screen:back_to("home")
    check_view(screen, "home_" .. lang)
    view("profile_new", "profile_form", {})
    view("profile_edit", "profile_form", { profile = main })
    local form = screen:show("profile_form", { profile = main })
    screen:show("pick_games", { values = form.values })
    check_view(screen, "pick_games_" .. lang)
    screen:back_to("home")
    view("games", "games", { profile = main })
    view("box", "browse", { profile = main, game = "red-blue" })
    view("box_national", "browse", { profile = main, game = "home" })
    view("list", "browse", { profile = main, game = "scarlet-violet", mode = "list" })
    local browse = screen:show("browse", { profile = main, game = "red-blue" })
    screen:show("filters", { profile = main, game = "red-blue", browse = browse })
    check_view(screen, "filters_" .. lang)
    screen:back_to("home")
    for _, c in ipairs(CARDS) do
        local list = screen:entries(main, c[1])
        local index = 1
        for i, e in ipairs(list) do
            if e.species == c[2] then
                index = i
                break
            end
        end
        for tab = 1, 6 do
            view(string.format("card_%s_%d_tab%d", c[1], c[2], tab), "card", { profile = main, game = c[1], list = list, index = index, tab = tab })
        end
    end
    view("progress", "progress", { profile = main })
    view("sprites", "sprites", { profile = main })
    view("about", "about", { profile = main })
    -- A toast over a box, as after a tap that marks.
    screen:show("browse", { profile = main, game = "red-blue" })
    screen:toggle(main, "red-blue", screen:entries(main, "red-blue")[2])
    check_view(screen, "box_toast_" .. lang)
    close_above(screen)
    screen:back_to("home")
end

-- The version on the About view.
screen:show("about", { profile = main })
drawn = {}
UIManager:setDirty(screen, "ui")
UIManager:forceRePaint()
local version_shown = false
for _, d in ipairs(drawn) do
    if d.text:find(meta.version, 1, true) then
        version_shown = true
    end
end
if not version_shown then
    problem("the About view does not show the version " .. meta.version)
end
screen:back_to("home")

-- The Back key: one view back, and from the first view the plugin closes.
screen:show("games", { profile = main })
screen:show("browse", { profile = main, game = "red-blue" })
screen:handleEvent(Event:new("Back"))
if screen:current().kind ~= "games" then
    problem("Back did not go back one view")
end
screen:handleEvent(Event:new("Back"))
screen:handleEvent(Event:new("Back"))
if UIManager:isWidgetShown(screen) then
    problem("Back on the first view did not close the plugin")
end

-- Profiles and catches read again by a new screen.
local reopened = open()
local p = reopened:profile_by_id(main.id)
if #reopened.profiles ~= 2 or not p then
    problem("the profiles were not read again: " .. #reopened.profiles)
elseif reopened:caps(p):state("red-blue", "25") ~= "c" or reopened:caps(p):record("red-blue", "25").n == nil then
    problem("the catches were not read again")
end
UIManager:close(reopened)

-- A save of a build from before the first release (tests/saves/0.1.0), with the catches where it kept them:
-- they move to the settings folder.
clean()
os.execute("mkdir -p '" .. home_dir .. "'")
os.execute("cp '" .. plugin_dir .. "/tests/saves/0.1.0/catchink.lua' '" .. settings_dir .. "/catchink.lua'")
os.execute("cp '" .. plugin_dir .. "/tests/saves/0.1.0/'profile_p*.lua '" .. home_dir .. "/'")
local old = open()
if #old.profiles ~= 3 or old.lang ~= "es" then
    problem("the older save did not open with its three profiles in Spanish")
else
    local p1 = old.profiles[1]
    if old:caps(p1):record("red-blue", "25").n ~= "Viridian Forest" then
        problem("the older catches were not read")
    end
    if lfs.attributes(home_dir .. "/profile_p1.lua", "mode") or not lfs.attributes(settings_dir .. "/catchink_profile_p1.lua", "mode") then
        problem("the older catches did not move to the settings folder")
    end
    old:show("browse", { profile = p1, game = "red-blue" })
    check_view(old, "older_save_box")
end
UIManager:close(old)

-- Refresh modes: the opening flashes, changes do not until the ninth, the download progress is outside the
-- count, and waking up flashes.
clean()
local modes = {}
local real_set_dirty = UIManager.setDirty
UIManager.setDirty = function(manager, widget, refresh, ...)
    if widget and widget.name == "catchink_screen" and refresh then
        modes[#modes + 1] = type(refresh) == "function" and (refresh()) or refresh
    end
    return real_set_dirty(manager, widget, refresh, ...)
end
local r = open()
local rp = r:create_profile("R", { model = "normal" })
r:show("browse", { profile = rp, game = "red-blue" })
r:redraw_progress()
for _ = 1, 7 do
    r:redraw()
end
r:redraw()
r:handleEvent(Event:new("Suspend"))
r:handleEvent(Event:new("Resume"))
UIManager.setDirty = real_set_dirty
local expected = "full,ui,ui,ui,ui,ui,ui,ui,ui,ui,full,full"
if table.concat(modes, ",") ~= expected then
    problem("refresh modes " .. table.concat(modes, ",") .. ", expected " .. expected)
end

-- A view that fails to draw: a message, and a tap goes back to the first view.
r:show("about", { profile = rp })
r:current().draw = function()
    error("planted")
end
local before = failed_paints
UIManager:setDirty(r, "ui")
UIManager:forceRePaint()
if failed_paints ~= before + 1 then
    problem("a view that fails to draw did not get the message")
end
r:handleEvent(Event:new("Gesture", { ges = "tap", pos = Geom:new{ x = math.floor(W / 2), y = math.floor(H / 2), w = 0, h = 0 }, time = require("ui/time").now() }))
UIManager:forceRePaint()
if r:current().kind ~= "home" then
    problem("the tap on a view that failed did not go back to the first view")
end
UIManager:close(r)

print(string.format("%d views at %dx%d, %d data texts cut on purpose, %d problems", views_checked, W, H, data_cut, problems))
os.exit(problems == 0 and 0 or 1)
