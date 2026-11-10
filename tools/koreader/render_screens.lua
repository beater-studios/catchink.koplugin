-- Opens the real plugin screens in a headless KOReader and saves each one as a PNG, for review.
-- Run with tools/koreader/run_headless.sh tools/koreader/render_screens.lua (OUTPUT_DIR keeps the files).
-- CATCHINK_HOME points to a folder with downloaded sprites (see check_download.lua); LANG_CODE picks the language.
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local out = assert(os.getenv("OUTPUT_DIR"))
local lang = os.getenv("LANG_CODE") or "pt"

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
G_reader_settings:saveSetting("language", lang)
package.path = plugin_dir .. "/?.lua;" .. package.path

local Device = require("device")
require("document/canvascontext"):init(Device)
local UIManager = require("ui/uimanager")
UIManager:init()
local Geom = require("ui/geometry")
local Games = require("catchink/games")
local Screen = require("catchink/ui/screen")

local home = os.getenv("CATCHINK_HOME")
local work_home = out .. "/home"
os.execute("rm -rf '" .. work_home .. "' && mkdir -p '" .. work_home .. "'")
if home then
    os.execute("ln -s '" .. home .. "/sprites' '" .. work_home .. "/sprites'")
end

local screen = Screen:new{ plugin_dir = plugin_dir, home_dir = work_home }
UIManager:show(screen)
local shots = 0

local function shot(name)
    UIManager:forceRePaint()
    Device.screen.bb:writePNG(out .. "/" .. name .. ".png")
    shots = shots + 1
end

local function tap(x, y)
    screen:onTap(nil, { pos = Geom:new{ x = x, y = y } })
    UIManager:forceRePaint()
end

local function close_popups()
    while #UIManager._window_stack > 0 and UIManager._window_stack[#UIManager._window_stack].widget ~= screen do
        UIManager:close(UIManager._window_stack[#UIManager._window_stack].widget)
    end
end

local DAY = 86400
local now = os.time()

shot("01_home_empty")
screen:show("profile_form", {})
shot("02_new_profile")
screen:back()

local main = screen:create_profile("Principal", { model = "normal" })
local shiny = screen:create_profile(lang == "pt" and "Caça shiny" or "Shiny hunt", { model = "shiny" })
local alpha = screen:create_profile(lang == "pt" and "Alfas" or "Alphas", { model = "alpha" })
local living = screen:create_profile("Living Dex", { model = "living" })

-- Some catches, spread over time.
local caps = screen:caps(main)
local caught_rb = { 1, 2, 4, 5, 7, 10, 11, 13, 14, 16, 17, 19, 20, 21, 23, 25, 27, 29, 133, 134 }
for i, id in ipairs(caught_rb) do
    caps:set("red-blue", tostring(id), "c", now - i * DAY)
end
caps:set("red-blue", "12", "s", now)
caps:set("red-blue", "26", "s", now)
caps:set("red-blue", "136", "s", now)
caps:set_note("red-blue", "1", lang == "pt" and "Inicial. Apelido Broto, nível 5 em Pallet." or "Starter, nicknamed Sprout.")
for id = 1, 151 do
    if id % 3 ~= 0 then
        caps:set("firered-leafgreen", tostring(id), "c", now - 40 * DAY)
    end
end
for _, id in ipairs({ 906, 909, 912, 915, 916, 187, 921, 922, 734 }) do
    caps:set("scarlet-violet", tostring(id), "c", now - 2 * DAY)
end
caps:set("scarlet-violet", "917", "s", now)
for _, id in ipairs({ 4, 5, 37, 58, 77, 78, 136 }) do
    caps:set("home", tostring(id), "c", now - 3 * DAY)
end
caps:set("home", "38", "s", now)
screen:save_caps(main)
local lcaps = screen:caps(living)
lcaps:set("home", "3", "c", now)
lcaps:set("home", "37:alola", "c", now)
screen:save_caps(living)
local scaps = screen:caps(shiny)
for _, id in ipairs({ 906, 25, 133, 1, 4 }) do
    scaps:set("home", tostring(id), "c", now - DAY)
end
screen:save_caps(shiny)
local acaps = screen:caps(alpha)
for _, id in ipairs({ 133, 399, 403, 25, 54 }) do
    acaps:set("legends-arceus", tostring(id), "c", now - DAY)
end
screen:save_caps(alpha)
screen:redraw()
shot("03_home_profiles")

screen:show("games", { profile = main })
main.last_game = "red-blue"
shot("04_games")
screen:current():swipe("west")
shot("04_games_page2")

local rb = screen:show("browse", { profile = main, game = "red-blue" })
shot("05_box_red_blue")
-- Asleep, a mark (or a timer) must not draw over the sleep screen; waking up draws what changed.
local Event = require("ui/event")
UIManager:broadcastEvent(Event:new("Suspend"))
assert(screen.sleeping, "the screen knows the device sleeps")
screen:redraw()
assert(screen.redraw_pending, "nothing is drawn while asleep")
UIManager:broadcastEvent(Event:new("Resume"))
assert(not screen.sleeping and not screen.redraw_pending, "waking up draws again")
local cell = rb.list[27]
screen:toggle(main, "red-blue", cell)
shot("05_box_red_blue_toast")
screen:back()

local plat = screen:show("browse", { profile = main, game = "platinum" })
shot("06_box_platinum")
screen:back()
local sv = screen:show("browse", { profile = main, game = "scarlet-violet" })
shot("07_box_scarlet_violet_banner")
sv:swipe("west")
shot("07_box_scarlet_violet_page2")
screen:back()

local nat = screen:show("browse", { profile = main, game = Games.HOME, mode = "list" })
local f = screen:filters_of(main, Games.HOME)
f.types = { 10 }
f.gens[1] = true
nat.page = 1
screen:redraw()
shot("08_list_fire_gen1")
screen:show("filters", { profile = main, game = Games.HOME, browse = nat })
shot("09_filters")
screen:back()
f.types = {}
f.gens = {}
nat.query = "char"
screen:redraw()
shot("10_search_char")
nat.query = nil
screen:back()

local rb_entries = screen:entries(main, "red-blue")
local card = screen:show("card", { profile = main, game = "red-blue", list = rb_entries, index = 1 })
for tab = 1, 6 do
    card.tab = tab
    screen:redraw()
    shot(string.format("11_card_%d", tab))
end
card.index = 133
card:load()
card.tab = 3
screen:redraw()
shot("12_card_eevee_evolution")
screen:back()

local nat_living = screen:entries(living, Games.HOME)
local index
for i, e in ipairs(nat_living) do
    if e.key == "3" then
        index = i
    end
end
local lcard = screen:show("card", { profile = living, game = Games.HOME, list = nat_living, index = index, tab = 4 })
shot("13_card_forms_living")
lcard.tab = 5
screen:redraw()
shot("13_card_in_game_national")
screen:back()

for i, e in ipairs(nat_living) do
    if e.key == "37:alola" then
        index = i
    end
end
screen:show("card", { profile = living, game = Games.HOME, list = nat_living, index = index, tab = 1 })
shot("14_card_form_entry")
screen:back()

screen:show("browse", { profile = living, game = Games.HOME })
shot("15_box_living_national")
screen:back()

local sv_entries = screen:entries(main, "scarlet-violet")
for i, e in ipairs(sv_entries) do
    if e.species == 133 then
        index = i
    end
end
screen:show("card", { profile = main, game = "scarlet-violet", list = sv_entries, index = index, tab = 5 })
shot("21_card_eevee_in_scarlet_violet")
screen:back()
local la_living = screen:entries(living, "legends-arceus")
for i, e in ipairs(la_living) do
    if e.species == 58 then
        index = i
    end
end
screen:show("card", { profile = living, game = "legends-arceus", list = la_living, index = index, tab = 4 })
shot("22_card_growlithe_forms_legends_arceus")
screen:back()
screen:show("browse", { profile = alpha, game = "legends-arceus" })
shot("24_box_alpha_legends_arceus")
screen:back()
screen:show("browse", { profile = living, game = "gold-silver" })
screen:current().page = 7
screen:redraw()
shot("23_box_gold_silver_unown")
screen:back()

screen:show("progress", { profile = main })
shot("16_progress")
screen:back()

screen:show("sprites")
shot("17_sprites")
screen:back()

screen:show("about")
shot("18_about")
screen:back()

screen:show("profile_form", { profile = alpha })
shot("19_edit_profile")
screen:show("pick_games", { values = screen:current().values })
shot("20_pick_games")
close_popups()

print(string.format("%d screens saved in %s", shots, out))
screen:close()
