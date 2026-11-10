-- Pattern "data_checks". This file is copied unchanged into
-- every plugin that needs it, as tools/data_check.lua: change the pattern first, then copy it again.
--
-- Helpers for a validator of hand-written data tables (cards, items, formats), run with plain LuaJIT. They
-- reject what an engine would silently ignore: unknown keys, broken numbers, references to nothing and texts
-- longer than their room. Every problem is collected, so one run lists them all.
local DataCheck = {}
DataCheck.__index = DataCheck

function DataCheck.new()
    return setmetatable({ errors = {}, warnings = {} }, DataCheck)
end

function DataCheck:error(message)
    self.errors[#self.errors + 1] = message
end

function DataCheck:warn(message)
    self.warnings[#self.warnings + 1] = message
end

-- Loads a data file in an empty environment, as a plugin should: the file can only return a table. A file
-- that does not load, raises or returns something else is an error.
function DataCheck.load(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error(err, 0)
    end
    setfenv(chunk, {})
    local ok, result = pcall(chunk)
    if not ok then
        error(tostring(result), 0)
    end
    if type(result) ~= "table" then
        error(path .. ": should return a table, returned " .. type(result), 0)
    end
    return result
end

-- A set from "a b c" or { "a", "b", "c" }.
function DataCheck.set(list)
    local set = {}
    if type(list) == "string" then
        for word in list:gmatch("%S+") do
            set[word] = true
        end
    else
        for _, word in ipairs(list) do
            set[word] = true
        end
    end
    return set
end

-- Letters, not bytes: an accented letter takes two bytes in UTF-8.
function DataCheck.letters(text)
    return #text:gsub("[\128-\191]", "")
end

-- A table whose keys are all in `allowed` (a set). Returns false when it is not a table.
function DataCheck:table(where, value, allowed)
    if type(value) ~= "table" then
        self:error(where .. ": should be a table, found " .. type(value))
        return false
    end
    for key in pairs(value) do
        if not allowed[key] then
            self:error(where .. ": unknown key " .. tostring(key))
        end
    end
    return true
end

-- An integer from `min` (and up to `max`, if given). nil passes unless `required`.
function DataCheck:integer(where, value, min, max, required)
    if value == nil then
        if required then self:error(where .. ": missing") end
        return
    end
    if type(value) ~= "number" or value % 1 ~= 0 or (min and value < min) or (max and value > max) then
        local range = (min and (" from " .. min) or "") .. (max and (" up to " .. max) or "")
        self:error(where .. ": should be an integer" .. range .. ", found " .. tostring(value))
    end
end

-- A value from a closed set (meter names, triggers). nil passes unless `required`.
function DataCheck:one_of(where, value, allowed, required)
    if value == nil then
        if required then self:error(where .. ": missing") end
        return
    end
    if not allowed[value] then
        self:error(where .. ": unknown value " .. tostring(value))
    end
end

-- A text with something besides spaces, of at most `max` letters. nil passes unless `required`.
function DataCheck:text(where, value, max, required)
    if value == nil then
        if required then self:error(where .. ": missing") end
        return
    end
    if type(value) ~= "string" or not value:find("%S") then
        self:error(where .. ": should be a non-empty text")
    elseif max and DataCheck.letters(value) > max then
        self:error(string.format("%s: %d letters, the limit is %d", where, DataCheck.letters(value), max))
    end
end

-- A file that must exist, such as the image of a character. A folder with that name is not a file.
function DataCheck:file(where, path)
    local file = io.open(path, "rb")
    if not file then
        self:error(where .. ": file not found " .. path)
        return
    end
    local _, err = file:read(0)
    file:close()
    if err then
        self:error(where .. ": not a readable file " .. path .. " (" .. err .. ")")
    end
end

-- References in both directions. `uses` maps each referenced id to where it was used; `defined` is the set
-- of ids that exist. A use of something that does not exist is an error; with `unused_is_warning`, something
-- that exists and is never used is a warning.
function DataCheck:references(kind, uses, defined, unused_is_warning)
    local missing = {}
    for id, where in pairs(uses) do
        if not defined[id] then
            missing[#missing + 1] = string.format("%s: %s %s does not exist", where, kind, tostring(id))
        end
    end
    table.sort(missing)
    for _, message in ipairs(missing) do
        self:error(message)
    end
    if unused_is_warning then
        local unused = {}
        for id in pairs(defined) do
            if uses[id] == nil then
                unused[#unused + 1] = string.format("%s %s is never used", kind, tostring(id))
            end
        end
        table.sort(unused)
        for _, message in ipairs(unused) do
            self:warn(message)
        end
    end
end

-- Prints every warning and error and a summary. Returns true when there were no errors.
function DataCheck:report(summary)
    for _, message in ipairs(self.warnings) do
        print("warning: " .. message)
    end
    for _, message in ipairs(self.errors) do
        print("ERROR: " .. message)
    end
    print(string.format("%s%d errors, %d warnings", summary and (summary .. "; ") or "", #self.errors, #self.warnings))
    return #self.errors == 0
end

-- report, then ends the script with an error code when there were errors.
function DataCheck:finish(summary)
    os.exit(self:report(summary) and 0 or 1)
end

return DataCheck
