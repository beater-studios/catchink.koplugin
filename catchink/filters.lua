-- Filters, search and order of a list of entries.
-- filters: { gens = { [n] = true }, types = { id, id }, status = "all" | "caught" | "missing" | "seen" | "unavailable",
--            cats = { legendary = true, mythical = true, baby = true, forms = true }, order = "regional" | "national" | "name" }
local Data = require("catchink/data")
local Letters = require("catchink/letters")

local Filters = {}

function Filters.empty()
    return { gens = {}, types = {}, status = "all", cats = {}, order = "regional" }
end

function Filters.valid(f)
    if type(f) ~= "table" then
        return Filters.empty()
    end
    local out = Filters.empty()
    if type(f.gens) == "table" then
        for k, v in pairs(f.gens) do
            if v == true and tonumber(k) then
                out.gens[tonumber(k)] = true
            end
        end
    end
    if type(f.types) == "table" then
        for _, t in ipairs(f.types) do
            if tonumber(t) and #out.types < 2 then
                out.types[#out.types + 1] = tonumber(t)
            end
        end
    end
    local statuses = { all = true, caught = true, missing = true, seen = true, unavailable = true }
    out.status = statuses[f.status] and f.status or "all"
    if type(f.cats) == "table" then
        for _, c in ipairs({ "legendary", "mythical", "baby", "forms" }) do
            out.cats[c] = f.cats[c] == true or nil
        end
    end
    local orders = { regional = true, national = true, name = true }
    out.order = orders[f.order] and f.order or "regional"
    return out
end

-- A text that changes whenever the filters do, to know when a filtered list is still good.
function Filters.signature(f)
    local gens, cats = {}, {}
    for g in pairs(f.gens) do
        gens[#gens + 1] = g
    end
    table.sort(gens)
    for c in pairs(f.cats) do
        cats[#cats + 1] = c
    end
    table.sort(cats)
    return table.concat(gens, ",") .. "|" .. table.concat(f.types, ",") .. "|" .. f.status .. "|" .. table.concat(cats, ",") .. "|" .. f.order
end

-- How many filters are on (the order does not count).
function Filters.count(f)
    local n = 0
    if next(f.gens) then
        n = n + 1
    end
    n = n + #f.types
    if f.status ~= "all" then
        n = n + 1
    end
    for _ in pairs(f.cats) do
        n = n + 1
    end
    return n
end

-- A search text and a name compared the same way: composed letters, no accents, lowercase, a typographic
-- apostrophe as a plain one ("Farfetch’d"), no spaces around.
function Filters.normalize(text)
    text = Letters.lower(Letters.plain(Letters.nfc(text or ""))):gsub("\226\128\153", "'")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- entry_info(e) gives { name, types, gen, species, number, national }; state_of(key) the capture state.
function Filters.apply(entries, f, entry_info, state_of, data, query)
    local out = {}
    local q = query and Filters.normalize(query) or ""
    local qnum = tonumber(q)
    for _, e in ipairs(entries) do
        local info = entry_info(e)
        local ok = true
        if next(f.gens) and not f.gens[info.gen] then
            ok = false
        end
        if ok then
            for _, t in ipairs(f.types) do
                if info.types[1] ~= t and info.types[2] ~= t then
                    ok = false
                    break
                end
            end
        end
        if ok and f.status ~= "all" then
            local s = state_of(e.key)
            if f.status == "caught" then
                ok = s == "c"
            elseif f.status == "missing" then
                ok = s ~= "c" and s ~= "u"
            elseif f.status == "seen" then
                ok = s == "s"
            else
                ok = s == "u"
            end
        end
        if ok and next(f.cats) then
            local any = false
            if f.cats.legendary and data:has_flag(e.species, Data.LEGENDARY) then
                any = true
            end
            if f.cats.mythical and data:has_flag(e.species, Data.MYTHICAL) then
                any = true
            end
            if f.cats.baby and data:has_flag(e.species, Data.BABY) then
                any = true
            end
            if f.cats.forms and #data:species_forms(e.species) > 0 then
                any = true
            end
            ok = any
        end
        if ok and q ~= "" then
            if qnum then
                ok = e.number == qnum or e.national == qnum
            else
                ok = Filters.normalize(info.name):find(q, 1, true) ~= nil
            end
        end
        if ok then
            out[#out + 1] = e
        end
    end
    if f.order == "national" then
        table.sort(out, function(a, b)
            if a.national ~= b.national then
                return a.national < b.national
            end
            return a.key < b.key
        end)
    elseif f.order == "name" then
        local names = {}
        for _, e in ipairs(out) do
            names[e] = Filters.normalize(entry_info(e).name)
        end
        table.sort(out, function(a, b)
            if names[a] ~= names[b] then
                return names[a] < names[b]
            end
            return a.key < b.key
        end)
    end
    return out
end

return Filters
