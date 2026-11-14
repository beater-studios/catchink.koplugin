-- Tests of the type charts, run from the plugin folder with plain LuaJIT: luajit tests/types_spec.lua
package.path = "./?.lua;" .. package.path
local Data = require("catchink/data")
local Dex = require("catchink/dex")
local Games = require("catchink/games")
local Text = require("catchink/text")
local Types = require("catchink/types")

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

local data = Data.new("data")
local types = Types.new(data:type_charts())
local i18n = Data.load_table("data/i18n.lua")

-- ids, as in types.csv
local NORMAL, FIGHTING, FLYING, POISON, GROUND, ROCK, BUG, GHOST, STEEL, FIRE, WATER, GRASS, ELECTRIC, PSYCHIC, ICE, DRAGON, DARK, FAIRY =
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18

local function group(groups, factor)
    for _, g in ipairs(groups) do
        if g.factor == factor then
            return table.concat(g.types, ",")
        end
    end
    return ""
end

test("three charts: the 1st generation, the 2nd to the 5th and the 6th on", function()
    eq(#types.charts, 3)
    eq(types:chart_index(1), 1)
    for gen = 2, 5 do
        eq(types:chart_index(gen), 2, "gen " .. gen)
    end
    for gen = 6, types.last_gen do
        eq(types:chart_index(gen), 3, "gen " .. gen)
    end
    eq(types:chart_index(nil), 3, "the national view uses the newest")
    eq(#types:list(1), 15, "no Steel, Dark or Fairy in the 1st")
    eq(#types:list(2), 17, "no Fairy before the 6th")
    eq(#types:list(3), 18)
end)

test("every game has a chart", function()
    for _, game in ipairs(Games.LIST) do
        assert(types:chart(types:chart_index(game.gen)), game.id)
    end
end)

test("the chart of today", function()
    eq(types:factor(3, FIRE, GRASS), 200)
    eq(types:factor(3, WATER, FIRE), 200)
    eq(types:factor(3, NORMAL, GHOST), 0)
    eq(types:factor(3, DRAGON, FAIRY), 0)
    eq(types:factor(3, GHOST, STEEL), 100, "Steel stopped resisting Ghost in the 6th")
    eq(types:factor(3, NORMAL, NORMAL), 100)
end)

test("what changed in older generations", function()
    eq(types:factor(1, BUG, POISON), 200)
    eq(types:factor(1, POISON, BUG), 200)
    eq(types:factor(1, GHOST, PSYCHIC), 0)
    eq(types:factor(1, ICE, FIRE), 100)
    eq(types:factor(2, GHOST, STEEL), 50)
    eq(types:factor(2, DARK, STEEL), 50)
    eq(types:factor(2, BUG, POISON), 50)
end)

test("Charizard takes four times from Rock and nothing from Ground", function()
    local d = types:defense(3, { FIRE, FLYING })
    eq(group(d, 400), tostring(ROCK))
    eq(group(d, 200), WATER .. "," .. ELECTRIC)
    eq(group(d, 50), FIGHTING .. "," .. STEEL .. "," .. FIRE .. "," .. FAIRY)
    eq(group(d, 25), BUG .. "," .. GRASS)
    eq(group(d, 0), tostring(GROUND))
    eq(d[1].factor, 400, "the biggest first")
end)

test("the moves of a type", function()
    local o = types:offense(3, FIRE)
    eq(group(o, 200), BUG .. "," .. STEEL .. "," .. GRASS .. "," .. ICE)
    eq(group(o, 50), ROCK .. "," .. FIRE .. "," .. WATER .. "," .. DRAGON)
    eq(group(o, 0), "")
    eq(group(types:offense(1, GHOST), 0), NORMAL .. "," .. PSYCHIC, "Ghost did nothing to Psychic in the 1st")
end)

test("the types a Pokémon had in a game", function()
    local function in_game(species, game)
        local entry = { species = species, key = tostring(species) }
        local gen = Games.get(game).gen
        return table.concat(types:of_pokemon(Dex.pokemon_id(data, entry), gen, Dex.types(data, entry)), ",")
    end
    eq(in_game(35, "red-blue"), tostring(NORMAL), "Clefairy was Normal")
    eq(in_game(35, "black-white"), tostring(NORMAL))
    eq(in_game(35, "x-y"), tostring(FAIRY))
    eq(in_game(81, "red-blue"), tostring(ELECTRIC), "Magnemite was only Electric")
    eq(in_game(81, "gold-silver"), ELECTRIC .. "," .. STEEL)
    eq(in_game(6, "red-blue"), FIRE .. "," .. FLYING)
    eq(table.concat(types:of_pokemon(35, nil, { FAIRY }), ","), tostring(FAIRY), "the national view keeps today's")
    local wash = { species = 479, form = "wash", key = "479:wash" }
    eq(table.concat(types:of_pokemon(Dex.pokemon_id(data, wash), 4, Dex.types(data, wash)), ","), ELECTRIC .. "," .. GHOST, "Rotom's forms were Electric and Ghost in the 4th")
end)

test("every type has an icon and a name in each language", function()
    for id = 1, 18 do
        local file = io.open("assets/icons/" .. Types.icon(id) .. ".png", "rb")
        assert(file, Types.icon(id))
        file:close()
    end
    for _, lang in ipairs({ "pt", "en", "es" }) do
        eq(#i18n[lang].types, 18, lang)
        eq(#i18n[lang].card_tabs, 7, lang)
    end
end)

test("a note for each older chart, and the names of the charts", function()
    for _, lang in ipairs({ "pt", "en", "es" }) do
        eq(#i18n[lang].types_notes, #types.charts - 1, lang)
    end
    local text = Text.new(i18n.en, "en", data)
    eq(text:type_chart_gens(types:chart(1), types.last_gen), "Generation 1")
    eq(text:type_chart_gens(types:chart(2), types.last_gen), "Generations 2 to 5")
    eq(text:type_chart_gens(types:chart(3), types.last_gen), "Generation 6 onwards")
    eq(text:type_chart_gens(types:chart(3), types.last_gen, true), "Gen 6 onwards")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
