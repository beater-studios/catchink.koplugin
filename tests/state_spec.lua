-- Tests of what is saved and read back, run from the plugin folder with plain LuaJIT: luajit tests/state_spec.lua
package.path = "./?.lua;" .. package.path
local Games = require("catchink/games")
local Profiles = require("catchink/profiles")
local SavedState = require("catchink/saved_state")
local State = require("catchink/state")

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAILED: " .. name .. "\n  " .. tostring(err))
    end
end
local function eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%sexpected %s, got %s", label and (label .. ": ") or "", tostring(expected), tostring(actual)), 2)
    end
end

-- A settings file as a table, read the way the screen reads it.
local function reader(t)
    return function(key)
        return t[key]
    end
end

local function load_save(path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, {})
    return chunk()
end

local warnings = {}
local function warn(...)
    warnings[#warnings + 1] = table.concat({ ... }, " ")
end

test("profiles and captures come back the same", function()
    local p = Profiles.new("p3", "Living", { model = "living" }, 1000)
    p.sets["red-blue"] = "yellow"
    local saved = State.settings(reader({ lang = "pt", profiles = { SavedState.copy(p) }, banner_off = true, last_profile_id = 5 }), "en", warn)
    eq(saved.lang, "pt")
    eq(saved.banner_off, true)
    eq(saved.last_profile_id, 5)
    eq(#saved.profiles, 1)
    local back = saved.profiles[1]
    for _, field in ipairs({ "id", "name", "model", "gender", "forms", "shiny", "created" }) do
        eq(back[field], p[field], field)
    end
    eq(#back.games, #p.games)
    eq(back.sets["red-blue"], "yellow")
    local caps = Profiles.Captures.new()
    caps:apply("scarlet-violet", "25_m", "c", 10)
    caps:set_note("scarlet-violet", "25_m", "Paldea")
    caps:set("home", "150", "u", 11)
    local again = State.captures(SavedState.copy(caps:serialize()), warn)
    eq(again:state("scarlet-violet", "25_m"), "c")
    eq(again:record("scarlet-violet", "25_m").n, "Paldea")
    eq(again:state("home", "150"), "u")
end)

test("what left the content falls back or leaves, and the profile opens", function()
    local saved = State.settings(reader({
        lang = "fr",
        profiles = { {
            id = "p1", name = "Old", model = "retired-model", gender = "both",
            games = { "red-blue", "a-game-that-left", "emerald" },
            sets = { ["red-blue"] = "a-set-that-left", emerald = "emerald", ["a-game-that-left"] = "emerald", home = "base" },
        } },
    }), "es", warn)
    eq(saved.lang, "es", "unknown language")
    local p = saved.profiles[1]
    eq(p.model, "custom")
    eq(p.gender, "single")
    eq(table.concat(p.games, ","), "red-blue,emerald")
    eq(p.sets["red-blue"], nil)
    eq(p.sets.emerald, "emerald")
    eq(p.sets["a-game-that-left"], nil)
    eq(p.sets.home, "base")
end)

test("a broken save opens: bad profiles leave, the rest stays", function()
    local saved = State.settings(reader({
        lang = 3,
        profiles = { 5, { id = "p2", name = "Good" }, { name = "no id" }, { id = "p2", name = "Repeated" }, { id = "p7", games = "x", sets = 1, filters = "y" } },
        banner_off = "yes",
        last_profile_id = 0 / 0,
    }), "en", warn)
    eq(saved.lang, "en")
    eq(saved.banner_off, false)
    eq(#saved.profiles, 2)
    eq(saved.profiles[1].name, "Good")
    eq(saved.profiles[2].id, "p7")
    eq(#saved.profiles[2].games, #Games.LIST, "all games when the list is broken")
    eq(next(saved.profiles[2].sets), nil)
    eq(saved.profiles[2].filters, nil)
    eq(saved.last_profile_id, 7, "never below an id in use")
    local empty = State.settings(reader({ profiles = "not a list" }), "pt", warn)
    eq(#empty.profiles, 0)
    eq(empty.lang, "pt")
    local caps = State.captures({ ["red-blue"] = 5, emerald = { ["1"] = "c", ["4"] = { s = "x" }, ["7"] = { s = "c", t = "soon" } } }, warn)
    eq(caps:state("emerald", "1"), nil)
    eq(caps:state("emerald", "4"), nil)
    eq(caps:state("emerald", "7"), "c")
    eq(State.captures("garbage", warn):state("emerald", "7"), nil)
end)

test("a profile that breaks while read is left out with a warning", function()
    local real = Profiles.valid
    Profiles.valid = function(p)
        if p.id == "p1" then
            error("broken")
        end
        return real(p)
    end
    local before = #warnings
    local ok, saved = pcall(State.settings, reader({ profiles = { { id = "p1" }, { id = "p2" } } }), "en", warn)
    Profiles.valid = real
    assert(ok, saved)
    eq(#saved.profiles, 1)
    eq(saved.profiles[1].id, "p2")
    eq(#warnings, before + 1)
end)

test("the save of 0.1.0 opens with everything in it", function()
    local dir = "tests/saves/0.1.0/"
    local saved = State.settings(reader(load_save(dir .. "catchink.lua")), "en", warn)
    eq(saved.lang, "es")
    eq(saved.banner_off, true)
    eq(saved.last_profile_id, 4, "the deleted profile p4 keeps its id taken")
    eq(#saved.profiles, 3)
    local main, shiny, living = saved.profiles[1], saved.profiles[2], saved.profiles[3]
    eq(main.name, "Principal")
    eq(main.sets["red-blue"], "yellow")
    eq(main.filters["red-blue"].status, "caught")
    eq(shiny.shiny, true)
    eq(living.forms, true)
    eq(living.gender, "dimorphic")
    eq(#main.games, #Games.LIST)
    local caps = State.captures(load_save(dir .. "profile_p1.lua").captures, warn)
    eq(caps:state("red-blue", "25"), "c")
    eq(caps:record("red-blue", "25").n, "Viridian Forest")
    eq(caps:state("red-blue", "12"), "s")
    eq(caps:state("red-blue", "151"), "u")
    eq(caps:national_state(main, "150"), "c")
    local lcaps = State.captures(load_save(dir .. "profile_p3.lua").captures, warn)
    eq(lcaps:state("scarlet-violet", "25_m"), "c")
    eq(lcaps:state("scarlet-violet", "26:alola"), "c")
    eq(State.captures(load_save(dir .. "profile_p2.lua").captures, warn):state("legends-arceus", "399"), "c")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
