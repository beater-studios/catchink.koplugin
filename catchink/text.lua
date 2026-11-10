-- Turns data into the player's language: dates, heights, evolution conditions, places and moves.
local Text = {}
Text.__index = Text

local LANG_FIELD = { en = 1, es = 2 }

function Text.new(t, lang, data)
    return setmetatable({ t = t, lang = lang, data = data }, Text)
end

local function decimal(value, sep)
    local s = string.format("%.1f", value)
    return (s:gsub("%.", sep))
end

function Text:height(dm)
    return decimal(dm / 10, self.t.decimal) .. " m"
end

function Text:weight(hg)
    return decimal(hg / 10, self.t.decimal) .. " kg"
end

function Text:thousands(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1" .. self.t.thousands):reverse()
    return (out:gsub("^%" .. self.t.thousands, ""))
end

function Text:date(time)
    if not time then
        return ""
    end
    local d = os.date("*t", time)
    return string.format(self.t.date_long, d.day, self.t.months[d.month], d.year)
end

function Text:date_short(time)
    if not time then
        return ""
    end
    local d = os.date("*t", time)
    return string.format(self.t.date_short, d.day, d.month, d.year)
end

function Text:percent(value)
    if value == math.floor(value) then
        return string.format("%d%%", value)
    end
    return decimal(value, self.t.decimal) .. "%"
end

function Text:type_name(id)
    return self.t.types[id] or "?"
end

function Text:species(id)
    return self.data:name(id, self.lang)
end

-- English name for Portuguese and English, Spanish name for Spanish (moves, items and places).
local function pick(entry, lang)
    if not entry then
        return "?"
    end
    return entry[LANG_FIELD[lang] or 1] ~= "" and entry[LANG_FIELD[lang] or 1] or entry[1]
end

function Text:move(id)
    return pick(self.data:moves()[id], self.lang)
end

function Text:item(id)
    return pick(self.data:items()[id], self.lang)
end

function Text:area(id)
    return pick(self.data:places().areas and self.data:places().areas[id], self.lang)
end

function Text:location(id)
    return pick(self.data:places().locations and self.data:places().locations[id], self.lang)
end

function Text:ability(id)
    local a = self.data:abilities()[id]
    if not a then
        return "?", ""
    end
    local name = self.lang == "es" and a[2] or a[1]
    local text
    if self.lang == "pt" then
        text = a[5] ~= "" and a[5] or a[3]
    elseif self.lang == "es" then
        text = a[4]
    else
        text = a[3]
    end
    return name, text or ""
end

function Text:genus(detail)
    local g = detail.genus or {}
    return (g[self.lang] ~= nil and g[self.lang] ~= "") and g[self.lang] or g.en or ""
end

-- The Pokédex text for a game (its versions), or the latest one. Portuguese has one text per species.
function Text:flavor(detail, versions)
    local f = detail.flavor or {}
    if self.lang == "pt" and f.pt and f.pt ~= "" then
        return f.pt, nil
    end
    local texts = f[self.lang]
    if not texts or next(texts) == nil then
        texts = f.en or {}
    end
    for _, v in ipairs(versions or {}) do
        if texts[v] then
            return texts[v], v
        end
    end
    local best
    for v in pairs(texts) do
        if not best or v > best then
            best = v
        end
    end
    return best and texts[best] or "", nil
end

function Text:egg_group(id)
    return self.t.egg_groups[id] or id
end

function Text:growth(id)
    return self.t.growth[id] or id
end

function Text:method(id)
    return self.t.methods[id] or self.t.methods.other
end

-- One evolution condition as a short phrase: "Level 16", "Trade holding Metal Coat", "Use Water Stone".
function Text:condition(c)
    local E = self.t.evo
    local parts = {}
    local t = c.t
    if t == "level-up" then
        if c.lv then
            parts[#parts + 1] = string.format(E.level, c.lv)
        else
            parts[#parts + 1] = E.level_up
        end
    elseif t == "trade" then
        parts[#parts + 1] = E.trade
    elseif t == "use-item" then
        parts[#parts + 1] = string.format(E.use_item, c.item and self:item(c.item) or "?")
    elseif E[t] then
        parts[#parts + 1] = E[t]
    else
        parts[#parts + 1] = E.other
    end
    if t ~= "use-item" and c.item then
        parts[#parts + 1] = string.format(E.with_item, self:item(c.item))
    end
    if c.held then
        parts[#parts + 1] = string.format(E.holding, self:item(c.held))
    end
    if c.happy then
        parts[#parts + 1] = E.friendship
    end
    if c.affection then
        parts[#parts + 1] = E.affection
    end
    if c.beauty then
        parts[#parts + 1] = E.beauty
    end
    if c.time and E["time_" .. c.time] then
        parts[#parts + 1] = E["time_" .. c.time]
    end
    if c.gender then
        parts[#parts + 1] = c.gender == 1 and E.female or E.male
    end
    if c.move then
        parts[#parts + 1] = string.format(E.knowing, self:move(c.move))
    end
    if c.move_type then
        parts[#parts + 1] = string.format(E.knowing_type, self:type_name(c.move_type))
    end
    if c.used_move then
        if c.move_count then
            parts[#parts + 1] = string.format(E.using_times, self:move(c.used_move), c.move_count)
        else
            parts[#parts + 1] = string.format(E.using, self:move(c.used_move))
        end
    end
    if c.loc then
        parts[#parts + 1] = string.format(E.at, self:location(c.loc))
    end
    if c.party then
        parts[#parts + 1] = string.format(E.with_party, self:species(c.party))
    end
    if c.party_type then
        parts[#parts + 1] = string.format(E.with_party_type, self:type_name(c.party_type))
    end
    if c.trade_with then
        parts[#parts + 1] = string.format(E.for_species, self:species(c.trade_with))
    end
    if c.phys then
        parts[#parts + 1] = c.phys > 0 and E.atk_gt_def or (c.phys < 0 and E.atk_lt_def or E.atk_eq_def)
    end
    if c.rain then
        parts[#parts + 1] = E.rain
    end
    if c.upside_down then
        parts[#parts + 1] = E.upside_down
    end
    if c.steps then
        parts[#parts + 1] = string.format(E.steps, self:thousands(c.steps))
    end
    if c.damage then
        parts[#parts + 1] = string.format(E.damage, c.damage)
    end
    return table.concat(parts, ", ")
end

-- All conditions of an evolution, without repeats.
function Text:conditions(list)
    local seen, out = {}, {}
    for _, c in ipairs(list or {}) do
        local s = self:condition(c)
        if s ~= "" and not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return out
end

return Text
