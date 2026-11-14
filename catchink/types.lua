-- Type matchups, from data/types.lua: the chart of each generation, what a Pokémon takes and what the moves of a
-- type do. Factors are in percent (400, 200, 100, 50, 25, 0). Plain Lua, so the tests can use it.
local Types = {}
Types.__index = Types

-- The icon of each type id (assets/icons/type_<key>.png).
Types.KEYS = { "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy" }

-- The order the groups are shown in.
Types.DEFENSE = { 400, 200, 50, 25, 0 }
Types.OFFENSE = { 200, 50, 0 }

-- data: the table of data/types.lua ({ charts, by_gen, past }).
function Types.new(data)
    local last = 0
    for gen in pairs(data.by_gen) do
        last = math.max(last, gen)
    end
    return setmetatable({ charts = data.charts, by_gen = data.by_gen, past = data.past or {}, last_gen = last }, Types)
end

function Types.icon(id)
    return "type_" .. (Types.KEYS[id] or "normal")
end

-- The chart of a generation, by its index; nil (the national view) is the newest.
function Types:chart_index(gen)
    return gen and self.by_gen[gen] or #self.charts
end

function Types:chart(index)
    return self.charts[index]
end

-- The type ids a chart has, in id order.
function Types:list(index)
    return self.charts[index].types
end

function Types:factor(index, attack, defense)
    local row = self.charts[index].factors[attack]
    return row and row[defense] or 100
end

-- What a Pokémon with these types takes from each type of the chart: { { factor, { type ids } } } for the factors
-- other than 100, in the order of Types.DEFENSE, without empty groups.
function Types:defense(index, types)
    local groups = {}
    for _, attack in ipairs(self:list(index)) do
        local m = 100
        for _, t in ipairs(types) do
            m = m * self:factor(index, attack, t) / 100
        end
        m = math.floor(m + 0.5)
        if m ~= 100 then
            groups[m] = groups[m] or {}
            table.insert(groups[m], attack)
        end
    end
    local out = {}
    for _, f in ipairs(Types.DEFENSE) do
        if groups[f] then
            out[#out + 1] = { factor = f, types = groups[f] }
        end
    end
    return out
end

-- What the moves of a type do to each type of the chart, as defense() does.
function Types:offense(index, attack)
    local groups = {}
    for _, d in ipairs(self:list(index)) do
        local m = self:factor(index, attack, d)
        if m ~= 100 then
            groups[m] = groups[m] or {}
            table.insert(groups[m], d)
        end
    end
    local out = {}
    for _, f in ipairs(Types.OFFENSE) do
        if groups[f] then
            out[#out + 1] = { factor = f, types = groups[f] }
        end
    end
    return out
end

-- The types a Pokémon had in a generation: the past entry of the closest generation at or after it, else its types of
-- today (Clefairy was Normal up to the 5th). pokemon_id is the PokeAPI id (the species, or a form's own id).
function Types:of_pokemon(pokemon_id, gen, current)
    local past = gen and pokemon_id and self.past[pokemon_id]
    if past then
        local best
        for g in pairs(past) do
            if gen <= g and (not best or g < best) then
                best = g
            end
        end
        if best then
            return past[best]
        end
    end
    return current
end

return Types
