-- Reads the data files in data/: the index stays in memory, the rest is loaded when first needed.
local Data = {}
Data.__index = Data

local function load_table(path)
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, err
    end
    setfenv(chunk, {})
    local ok, value = pcall(chunk)
    if not ok then
        return nil, value
    end
    return value
end
Data.load_table = load_table

local DETAIL_CACHE = 12

function Data.new(dir)
    local self = setmetatable({ dir = dir, details = {}, detail_order = {} }, Data)
    self.index = assert(load_table(dir .. "/index.lua"))
    self.species = self.index.species
    self.forms = self.index.forms
    self.dex = self.index.dex
    self.names_es = self.index.names_es or {}
    self.count = #self.species
    return self
end

local function lazy(self, field, file)
    if self[field] == nil then
        self[field] = load_table(self.dir .. "/" .. file) or false
    end
    return self[field] or {}
end

function Data:moves()
    return lazy(self, "_moves", "moves.lua")
end

function Data:abilities()
    return lazy(self, "_abilities", "abilities.lua")
end

function Data:items()
    return lazy(self, "_items", "items.lua")
end

function Data:places()
    return lazy(self, "_places", "places.lua")
end

function Data:sprites()
    return lazy(self, "_sprites", "sprites.lua")
end

-- Species fields: name, generation, type 1, type 2 (0 when none), flags, gender rate, chain.
Data.LEGENDARY, Data.MYTHICAL, Data.BABY, Data.DIMORPHIC = 1, 2, 4, 8

function Data:name(id, lang)
    local s = self.species[id]
    if not s then
        return "?"
    end
    if lang == "es" and self.names_es[id] then
        return self.names_es[id]
    end
    return s[1]
end

function Data:generation(id)
    return self.species[id] and self.species[id][2] or 0
end

function Data:types(id)
    local s = self.species[id]
    if not s then
        return {}
    end
    if s[4] and s[4] ~= 0 then
        return { s[3], s[4] }
    end
    return { s[3] }
end

function Data:flags(id)
    return self.species[id] and self.species[id][5] or 0
end

function Data:has_flag(id, flag)
    return math.floor(self:flags(id) / flag) % 2 == 1
end

function Data:gender_rate(id)
    return self.species[id] and self.species[id][6] or -1
end

function Data:chain(id)
    return self.species[id] and self.species[id][7] or 0
end

-- Forms of a species: { key, sprite, battle only (1/0), type 1, type 2, name en, name es, name pt }.
function Data:species_forms(id)
    return self.forms[id] or {}
end

function Data:form(id, key)
    for _, f in ipairs(self:species_forms(id)) do
        if f[1] == key then
            return f
        end
    end
    return nil
end

-- The forms a game has for a species (keys), from PKHeX's tables or the game a form came in.
function Data:game_forms(game_id, species)
    local per_game = self.index.game_forms and self.index.game_forms[game_id]
    return per_game and per_game[species] or {}
end

function Data:game_has_form(game_id, species, key)
    for _, k in ipairs(self:game_forms(game_id, species)) do
        if k == key then
            return true
        end
    end
    return false
end

function Data:form_name(form, lang)
    if lang == "es" then
        return form[7]
    elseif lang == "pt" then
        return form[8]
    end
    return form[6]
end

-- The detail of a species, from data/species/<id>.lua, with a small cache.
function Data:detail(id)
    local cached = self.details[id]
    if cached then
        return cached
    end
    local detail = load_table(self.dir .. "/species/" .. id .. ".lua")
    if not detail then
        return nil
    end
    self.details[id] = detail
    table.insert(self.detail_order, id)
    if #self.detail_order > DETAIL_CACHE then
        local old = table.remove(self.detail_order, 1)
        self.details[old] = nil
    end
    return detail
end

-- Members of an evolution chain, from any species of it.
function Data:chain_members(id)
    local detail = self:detail(id)
    local members = {}
    for _, node in ipairs(detail and detail.evo or {}) do
        members[#members + 1] = node.s
    end
    return members
end

-- The type charts (data/types.lua), loaded when first needed.
function Data:type_charts()
    if not self.type_table then
        self.type_table = assert(load_table(self.dir .. "/types.lua"))
    end
    return self.type_table
end

return Data
