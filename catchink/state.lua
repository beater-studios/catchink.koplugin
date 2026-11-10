-- Reading back what an older version saved, in plain Lua so the tests can use it. Two kinds of file:
--   koreader/settings/catchink.lua               language, profiles, the sprite notice and the last profile id
--   koreader/settings/catchink_profile_<id>.lua  the captures of one profile
-- Fields added later get their defaults, values that no longer exist fall back or leave, and a profile that
-- cannot be read is left out without taking the others with it.
local Profiles = require("catchink/profiles")
local SavedState = require("catchink/saved_state")

local State = {}

-- The format of both files. It only goes up when a field changes meaning; a file without it is version 1.
State.VERSION = 1
State.LANGUAGES = { pt = true, en = true, es = true }

-- read(key) gives what the settings file holds for key. default_lang is used when the saved one is not
-- known. warn gets the error of a profile that could not be read.
function State.settings(read, default_lang, warn)
    local out = {
        lang = SavedState.one_of(read("lang"), State.LANGUAGES, default_lang),
        profiles = {},
        banner_off = read("banner_off") == true,
    }
    local ids = {}
    local saved = read("profiles")
    for _, p in ipairs(SavedState.list(type(saved) == "table" and saved or {}, nil, {})) do
        local valid = SavedState.restore(Profiles.valid, SavedState.copy(p), warn)
        if valid and not ids[valid.id] then
            ids[valid.id] = true
            out.profiles[#out.profiles + 1] = valid
        end
    end
    -- Ids are never handed out again, so the last one is kept above every profile that is still there.
    local last = tonumber(read("last_profile_id"))
    last = (last and last == last and last >= 0 and last < math.huge) and math.floor(last) or 0
    for _, p in ipairs(out.profiles) do
        local n = tonumber(p.id:match("%d+"))
        if n and n > last and n < math.huge then
            last = n
        end
    end
    out.last_profile_id = last
    return out
end

-- The captures of a profile from what its file holds; empty when they cannot be read.
function State.captures(saved, warn)
    return SavedState.restore(Profiles.Captures.new, saved, warn) or Profiles.Captures.new()
end

return State
