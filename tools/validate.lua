-- Checks the hand-written data: the games (catchink/games.lua) and the sprite sets (catchink/sprite_sets.lua).
-- The generated files in data/ are checked by the tests. Usage, from the plugin folder: luajit tools/validate.lua
package.path = "./?.lua;./tools/?.lua;" .. package.path
local DataCheck = require("data_check")
local Data = require("catchink/data")
local Games = require("catchink/games")
local SpriteSets = require("catchink/sprite_sets")

local c = DataCheck.new()
local data = Data.new("data")
local manifest = DataCheck.load("data/sprites.lua")

-- index is added by the module when it loads.
local GAME = DataCheck.set("id en es gen vg versions dex set region dlc_of alphas index")
local SET = DataCheck.set("id label game normal female shiny shiny_female gray icons index")

local games, set_uses, dlc_uses = {}, {}, {}
for i, game in ipairs(Games.LIST) do
    local where = "game " .. tostring(type(game) == "table" and game.id or i)
    if c:table(where, game, GAME) then
        c:text(where .. ".id", game.id, nil, true)
        if type(game.id) == "string" then
            if games[game.id] then
                c:error(where .. ": repeated id")
            end
            games[game.id] = game
        end
        c:text(where .. ".en", game.en, 40, true)
        c:text(where .. ".es", game.es, 40, true)
        c:text(where .. ".region", game.region, 20, true)
        c:integer(where .. ".gen", game.gen, 1, 9, true)
        c:integer(where .. ".vg", game.vg, 1, nil, true)
        for _, field in ipairs({ "versions", "dex" }) do
            local list = game[field]
            if type(list) ~= "table" or #list == 0 then
                c:error(where .. "." .. field .. ": should be a list with at least one id")
            else
                for j, id in ipairs(list) do
                    c:integer(where .. "." .. field .. "[" .. j .. "]", id, 1, nil, true)
                end
            end
        end
        for j, dex in ipairs(type(game.dex) == "table" and game.dex or {}) do
            if type(dex) == "number" and not data.dex[dex] then
                c:error(where .. ".dex[" .. j .. "]: Pokédex " .. dex .. " is not in data/index.lua")
            end
        end
        if game.alphas ~= nil and game.alphas ~= true then
            c:error(where .. ".alphas: should be true or left out")
        end
        c:text(where .. ".set", game.set, nil, true)
        if type(game.set) == "string" then
            set_uses[game.set] = where .. ".set"
        end
        if game.dlc_of ~= nil then
            c:text(where .. ".dlc_of", game.dlc_of, nil, true)
            if type(game.dlc_of) == "string" then
                dlc_uses[game.dlc_of] = where .. ".dlc_of"
            end
        end
    end
end

local sets, game_uses = {}, {}
local FOLDERS = { "normal", "female", "shiny", "shiny_female" }
for i, set in ipairs(SpriteSets.LIST) do
    local where = "sprite set " .. tostring(type(set) == "table" and set.id or i)
    if c:table(where, set, SET) then
        c:text(where .. ".id", set.id, nil, true)
        if type(set.id) == "string" then
            if sets[set.id] then
                c:error(where .. ": repeated id")
            end
            sets[set.id] = true
        end
        if set.id ~= "base" then
            c:text(where .. ".game", set.game, nil, true)
            if type(set.game) == "string" then
                game_uses[set.game] = where .. ".game"
            end
        end
        if type(set.normal) ~= "string" then
            c:error(where .. ".normal: the folder of the normal sprites is required")
        end
        for _, field in ipairs(FOLDERS) do
            local folder = set[field]
            if folder ~= nil then
                if type(folder) ~= "string" then
                    c:error(where .. "." .. field .. ": should be a folder name")
                elseif not (type(manifest.folders) == "table" and manifest.folders[folder]) then
                    c:error(where .. "." .. field .. ": folder " .. folder .. " is not in data/sprites.lua")
                end
            end
        end
        if set.shiny_female ~= nil and set.shiny == nil then
            c:error(where .. ".shiny_female: there is no shiny folder for it to go with")
        end
        for _, flag in ipairs({ "gray", "icons" }) do
            if set[flag] ~= nil and set[flag] ~= true then
                c:error(where .. "." .. flag .. ": should be true or left out")
            end
        end
        if set.label ~= nil then
            c:text(where .. ".label", set.label, 12)
        end
    end
end
if not sets.base then
    c:error("sprite sets: the base set is required, every missing file falls back on it")
end

c:references("sprite set", set_uses, sets)
c:references("game", game_uses, games)
c:references("game", dlc_uses, games)
-- A DLC is listed under its base game, so the base game is never a DLC itself.
for id, where in pairs(dlc_uses) do
    if games[id] and games[id].dlc_of then
        c:error(where .. ": " .. id .. " is itself a DLC")
    end
end
c:finish(#Games.LIST .. " games and " .. #SpriteSets.LIST .. " sprite sets")
