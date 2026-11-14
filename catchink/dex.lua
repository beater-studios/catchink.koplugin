-- The entries a profile shows for a game or for the national Pokédex. An entry is one thing to catch:
-- a species, one gender of it, or one form. Its key is what the captures are stored under:
-- "25" for the species, "25_m" and "25_f" for its genders, "25:alola" for a form.
local Data = require("catchink/data")
local Games = require("catchink/games")

local Dex = {}

-- Which genders a species is split into, by the profile's mode ("single", "dimorphic" or "all").
function Dex.genders(data, species, mode)
    if mode == "dimorphic" then
        if data:has_flag(species, Data.DIMORPHIC) then
            return { "m", "f" }
        end
    elseif mode == "all" then
        local rate = data:gender_rate(species)
        if rate > 0 and rate < 8 then
            return { "m", "f" }
        end
    end
    return { false }
end

local function species_entries(data, species, number, mode, out)
    for _, g in ipairs(Dex.genders(data, species, mode)) do
        out[#out + 1] = {
            key = g and (species .. "_" .. g) or tostring(species),
            species = species,
            gender = g or nil,
            number = number,
            national = species,
        }
    end
end

-- A game's Pokédex and, when the profile counts forms, the forms that game has, kept outside battle.
function Dex.game_entries(data, game, profile)
    local out = {}
    for _, e in ipairs(Games.dex_entries(game, data.dex)) do
        species_entries(data, e.species, e.number, profile.gender, out)
        if profile.forms then
            for _, key in ipairs(data:game_forms(game.id, e.species)) do
                local f = data:form(e.species, key)
                if f and f[3] == 0 then
                    out[#out + 1] = { key = e.species .. ":" .. key, species = e.species, form = key, number = e.number, national = e.species }
                end
            end
        end
    end
    return out
end

-- The species a profile follows: all of them when it has every game, else those in its games' Pokédex.
function Dex.profile_species(data, profile)
    if #profile.games >= #Games.LIST then
        return nil
    end
    local set = {}
    for _, id in ipairs(profile.games) do
        local game = Games.get(id)
        if game then
            for _, e in ipairs(Games.dex_entries(game, data.dex)) do
                set[e.species] = true
            end
        end
    end
    return set
end

-- The national Pokédex of a profile: every species its games have (all 1025 with every game) and, when
-- the profile counts forms, each form that can be kept (forms only seen in battle, like Mega Evolutions,
-- do not count).
function Dex.national_entries(data, profile)
    local out = {}
    local only = Dex.profile_species(data, profile)
    for species = 1, data.count do
        if not only or only[species] then
            species_entries(data, species, species, profile.gender, out)
            if profile.forms then
                for _, f in ipairs(data:species_forms(species)) do
                    if f[3] == 0 then
                        out[#out + 1] = { key = species .. ":" .. f[1], species = species, form = f[1], number = species, national = species }
                    end
                end
            end
        end
    end
    return out
end

-- Splits a key into species, gender and form.
function Dex.parse(key)
    local species, rest = key:match("^(%d+)(.*)$")
    species = tonumber(species)
    if not species then
        return nil
    end
    if rest:sub(1, 1) == "_" then
        return species, rest:sub(2), nil
    elseif rest:sub(1, 1) == ":" then
        return species, nil, rest:sub(2)
    end
    return species, nil, nil
end

function Dex.types(data, entry)
    if entry.form then
        local f = data:form(entry.species, entry.form)
        if f then
            return f[5] ~= 0 and { f[4], f[5] } or { f[4] }
        end
    end
    return data:types(entry.species)
end

-- The PokeAPI id of the Pokémon an entry shows: its species, or a form's own id (its sprite file name).
function Dex.pokemon_id(data, entry)
    if entry.form then
        local f = data:form(entry.species, entry.form)
        return f and tonumber(f[2]) or nil
    end
    return entry.species
end

-- The sprite file name (without extension) of an entry, and whether a female sprite is wanted.
function Dex.sprite_stem(data, entry)
    if entry.form then
        local f = data:form(entry.species, entry.form)
        return f and f[2] or tostring(entry.species), false
    end
    return tostring(entry.species), entry.gender == "f"
end

return Dex
