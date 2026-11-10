-- Profiles and their captures. A profile is a Pokédex of its own (normal, shiny, alphas...). Its captures
-- are kept per game, and "home" holds what is marked straight on the national view.
-- A capture record: { s = "c" (caught), "s" (seen) or "u" (unavailable), t = time it was set, n = note }.
local Games = require("catchink/games")
local SavedState = require("catchink/saved_state")
local SpriteSets = require("catchink/sprite_sets")

local Profiles = {}

Profiles.MODELS = { "normal", "shiny", "alpha", "living", "custom" }

local DAY = 86400

-- The settings a model starts with.
function Profiles.model_defaults(model)
    local p = { model = model, shiny = false, gender = "single", forms = false, games = Games.all_ids() }
    if model == "shiny" then
        p.shiny = true
    elseif model == "alpha" then
        p.games = Games.alpha_ids()
    elseif model == "living" then
        p.forms = true
        p.gender = "dimorphic"
    end
    return p
end

function Profiles.new(id, name, settings, now)
    local p = Profiles.model_defaults(settings.model or "normal")
    for k, v in pairs(settings) do
        p[k] = v
    end
    p.id = id
    p.name = name
    p.created = now
    p.games = Games.ordered(p.games)
    p.sets = p.sets or {}
    return p
end

-- A profile read from disk, fixed field by field: values that no longer exist (a model, a game, a sprite
-- set) fall back or leave. nil when it is not a profile at all.
function Profiles.valid(p)
    if type(p) ~= "table" or type(p.id) ~= "string" or p.id == "" then
        return nil
    end
    p.name = type(p.name) == "string" and p.name or "?"
    p.model = SavedState.one_of(p.model, Profiles.MODELS, "custom")
    p.gender = SavedState.one_of(p.gender, { "single", "dimorphic", "all" }, "single")
    p.forms = p.forms == true
    p.shiny = p.shiny == true
    p.created = tonumber(p.created)
    p.games = Games.ordered(type(p.games) == "table" and SavedState.list(p.games, nil, "") or Games.all_ids())
    local sets = {}
    if type(p.sets) == "table" then
        for game, set in pairs(p.sets) do
            if (game == Games.HOME or Games.get(game)) and type(set) == "string" and SpriteSets.get(set) then
                sets[game] = set
            end
        end
    end
    p.sets = sets
    if p.filters ~= nil and type(p.filters) ~= "table" then
        p.filters = nil
    end
    return p
end

-- A new id, above every id ever used (last_used), so a deleted profile's id never comes back.
function Profiles.next_id(profiles, last_used)
    local top = tonumber(last_used) or 0
    for _, p in ipairs(profiles) do
        local n = tonumber(p.id:match("%d+")) or 0
        if n > top then
            top = n
        end
    end
    return "p" .. (top + 1)
end

---------------------------------------------------------------------------
-- Captures of one profile.
---------------------------------------------------------------------------

local Captures = {}
Captures.__index = Captures
Profiles.Captures = Captures

function Captures.new(data)
    local caps = {}
    if type(data) == "table" then
        for game, records in pairs(data) do
            if type(records) == "table" then
                local clean = {}
                for key, r in pairs(records) do
                    if type(key) == "string" and type(r) == "table" and (r.s == "c" or r.s == "s" or r.s == "u" or r.n) then
                        clean[key] = { s = r.s, t = tonumber(r.t), n = type(r.n) == "string" and r.n or nil }
                    end
                end
                caps[game] = clean
            end
        end
    end
    return setmetatable({ caps = caps }, Captures)
end

function Captures:serialize()
    return self.caps
end

function Captures:record(game, key)
    local g = self.caps[game]
    return g and g[key]
end

local function base_key(key)
    return key:match("^(%d+)_[mf]$")
end

-- The state of a key in one game: "c", "s", "u" or nil. A gendered key falls back on its species, and a
-- species counts as caught when both its genders are, so changing the gender mode keeps the progress.
function Captures:state(game, key)
    local g = self.caps[game]
    if not g then
        return nil
    end
    local r = g[key]
    if r and r.s then
        return r.s
    end
    local base = base_key(key)
    if base then
        local b = g[base]
        return b and b.s or nil
    end
    if not key:find(":", 1, true) then
        local m, f = g[key .. "_m"], g[key .. "_f"]
        local ms, fs = m and m.s, f and f.s
        if ms == "c" and fs == "c" then
            return "c"
        elseif ms or fs then
            if ms == "c" or fs == "c" or ms == "s" or fs == "s" then
                return "s"
            end
        end
    end
    return nil
end

-- The state on the national view: caught or seen in any game of the profile, or marked there.
function Captures:national_state(profile, key)
    local best = self:state(Games.HOME, key)
    if best == "c" then
        return "c", Games.HOME
    end
    local seen, where = best == "s", nil
    for _, game in ipairs(profile.games) do
        local s = self:state(game, key)
        if s == "c" then
            return "c", game
        elseif s == "s" then
            seen = true
        end
    end
    if seen then
        return "s"
    end
    if best == "u" then
        return "u"
    end
    return nil, where
end

-- Sets the state of a key (nil clears it, keeping the note), and nothing else. Returns the record as it was.
function Captures:set(game, key, state, now)
    self.caps[game] = self.caps[game] or {}
    local g = self.caps[game]
    local old = g[key]
    local before = old and { s = old.s, t = old.t, n = old.n } or false
    if state then
        local t = (old and old.s == state and old.t) or now
        g[key] = { s = state, t = t, n = old and old.n or nil }
    elseif old and old.n then
        g[key] = { n = old.n }
    else
        g[key] = nil
    end
    return before
end

-- Sets what an entry shows, whatever the gender mode its state came from: a gender caught through its
-- species splits the species into its two genders first (so the other gender keeps its state), and a
-- species shown through its genders replaces them. Returns { key = record as it was or false } for undo.
function Captures:apply(game, key, state, now)
    self.caps[game] = self.caps[game] or {}
    local g = self.caps[game]
    local before = {}
    local function put(k, s, t)
        if before[k] == nil then
            local r = g[k]
            before[k] = r and { s = r.s, t = r.t, n = r.n } or false
        end
        local old = g[k]
        if s then
            g[k] = { s = s, t = (old and old.s == s and old.t) or t or now, n = old and old.n or nil }
        elseif old and old.n then
            g[k] = { n = old.n }
        else
            g[k] = nil
        end
    end
    local species = base_key(key)
    if species then
        local own = g[key]
        local b = g[species]
        if not (own and own.s) and b and b.s then
            local sibling = species .. (key:sub(-1) == "m" and "_f" or "_m")
            local sib = g[sibling]
            if not (sib and sib.s) then
                put(sibling, b.s, b.t)
            end
            put(species, nil)
        end
    elseif not key:find(":", 1, true) then
        for _, k in ipairs({ key .. "_m", key .. "_f" }) do
            local r = g[k]
            if r and r.s then
                put(k, nil)
            end
        end
    end
    put(key, state)
    return before
end

-- Puts back what apply() changed.
function Captures:restore(game, before)
    self.caps[game] = self.caps[game] or {}
    for k, r in pairs(before) do
        self.caps[game][k] = r or nil
    end
end

function Captures:set_note(game, key, note)
    self.caps[game] = self.caps[game] or {}
    local g = self.caps[game]
    local r = g[key] or {}
    r.n = (note and note ~= "") and note or nil
    if not r.s and not r.n then
        g[key] = nil
    else
        g[key] = r
    end
end

function Captures:set_time(game, key, time)
    local r = self:record(game, key)
    if r and r.s then
        r.t = time
    end
end

-- Toggles a tap: anything but caught becomes caught, caught is cleared. Returns the undo and the new state.
function Captures:toggle(game, key, now)
    if self:state(game, key) == "c" then
        return self:apply(game, key, nil, now), nil
    end
    return self:apply(game, key, "c", now), "c"
end

-- Progress of a list of entries: caught, seen, unavailable and the total that counts.
function Captures:progress(entries, state_of)
    local caught, seen, unavailable = 0, 0, 0
    for _, e in ipairs(entries) do
        local s = state_of(e.key)
        if s == "c" then
            caught = caught + 1
        elseif s == "s" then
            seen = seen + 1
        elseif s == "u" then
            unavailable = unavailable + 1
        end
    end
    return { caught = caught, seen = seen, unavailable = unavailable, total = #entries - unavailable }
end

-- Keys caught since a time, in any game, each counted once.
function Captures:caught_since(time)
    local keys = {}
    local count = 0
    for _, records in pairs(self.caps) do
        for key, r in pairs(records) do
            if r.s == "c" and r.t and r.t >= time and not keys[key] then
                keys[key] = true
                count = count + 1
            end
        end
    end
    return count
end

function Captures:recent(now, days)
    return self:caught_since(now - (days or 7) * DAY)
end

-- A copy, for duplicating a profile.
function Captures:copy()
    local data = {}
    for game, records in pairs(self.caps) do
        data[game] = {}
        for key, r in pairs(records) do
            data[game][key] = { s = r.s, t = r.t, n = r.n }
        end
    end
    return Captures.new(data)
end

return Profiles
