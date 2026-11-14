-- The sprites on the device: where each set lives, what is already downloaded, which file shows an
-- entry, and what a download has to fetch. Files come from PokeAPI/sprites at a fixed commit.
local Games = require("catchink/games")
local SpriteSets = require("catchink/sprite_sets")

local Sprites = {}
Sprites.__index = Sprites

local BASE_URL = "https://raw.githubusercontent.com/PokeAPI/sprites/"
-- The only server the downloads may reach.
Sprites.HOSTS = { "raw.githubusercontent.com" }

local function quote(text)
    return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end

-- opts: dir (where the sets are kept), manifest (data/sprites.lua), data (catchink/data, to download only the
-- Pokédex of each game), bundled (folders that ship inside the plugin: { [folder] = dir }),
-- list_dir(path) -> names (for the tests).
function Sprites.new(opts)
    local self = setmetatable({ dir = opts.dir, manifest = opts.manifest or { folders = {} }, data = opts.data, bundled = opts.bundled or {}, list_dir = opts.list_dir, known = {}, wanted_cache = {} }, Sprites)
    return self
end

-- The folders that came inside the plugin, by package: none, the base set, or the base set with shiny.
local BUNDLED = { [""] = "base", female = "female", shiny = "shiny", ["shiny/female"] = "shiny_female" }
-- The folder of the sprites a package brings. Some packages bring none, so the path is built in two parts,
-- which the package check of tools/package_lib.sh does not take as a file every package must have.
local BUNDLED_DIR = "sprites"

function Sprites.bundled_in(plugin_dir, exists)
    exists = exists or function(path)
        local ok, lfs = pcall(require, "libs/libkoreader-lfs")
        return ok and lfs.attributes(path, "mode") == "directory"
    end
    local out = {}
    for folder, name in pairs(BUNDLED) do
        local dir = plugin_dir .. "/" .. BUNDLED_DIR .. "/" .. name
        if exists(dir) then
            out[folder] = dir
        end
    end
    return out
end

-- The base set (normal, and shiny in the larger package) can come inside the plugin.
function Sprites:is_bundled(set, variant)
    if set.id ~= "base" then
        return false
    end
    local folder = variant == "shiny" and set.shiny or set.normal
    return self.bundled[folder] ~= nil
end

-- The species a set is for: those in the Pokédex of every game that uses it. Nil means all (the base).
function Sprites:set_species(set)
    if set.id == "base" or not self.data then
        return nil
    end
    local species = {}
    for _, game in ipairs(Games.LIST) do
        if game.set == set.id then
            for _, e in ipairs(Games.dex_entries(game, self.data.dex)) do
                species[e.species] = true
            end
        end
    end
    return species
end

-- The files of a folder a set downloads: every file for the base, and for a game's set only the Pokémon of
-- its Pokédex with their forms (the folders of the newer games hold the whole national Pokédex).
function Sprites:wanted(set, folder)
    local key = set.id .. "|" .. folder
    local cached = self.wanted_cache[key]
    if cached then
        return cached
    end
    local info = self.manifest.folders[folder]
    local ids = info and info.ids or {}
    local species = self:set_species(set)
    local list
    if not species then
        list = ids
    else
        local owner = {}
        for sid, forms in pairs(self.data.forms or {}) do
            for _, f in ipairs(forms) do
                owner[f[2]] = sid
            end
        end
        list = {}
        for _, stem in ipairs(ids) do
            local sid = owner[stem] or tonumber(stem:match("^(%d+)"))
            if sid and sid >= 10000 then
                sid = owner[stem:match("^(%d+)")]
            end
            if sid and species[sid] then
                list[#list + 1] = stem
            end
        end
    end
    self.wanted_cache[key] = list
    return list
end

-- Files and approximate bytes an item downloads.
function Sprites:size(set, variant)
    local files, bytes = 0, 0
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        local info = folder and self.manifest.folders[folder]
        if info then
            local n = #self:wanted(set, folder)
            files = files + n
            bytes = bytes + n * info.avg
        end
    end
    return files, bytes
end

function Sprites:folder_dir(folder)
    return self.dir .. "/" .. (folder == "" and "base" or folder)
end

function Sprites:ext(folder)
    local info = self.manifest.folders[folder]
    return info and info.ext or "png"
end

local function list_files(path)
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok then
        return {}
    end
    local names = {}
    local okd, iter, dir_obj = pcall(lfs.dir, path)
    if not okd then
        return names
    end
    for name in iter, dir_obj do
        names[#names + 1] = name
    end
    return names
end

-- The stems already on disk in a folder, read once and kept until forgotten.
function Sprites:stems(folder)
    local known = self.known[folder]
    if known then
        return known
    end
    known = { count = 0, set = {}, where = {} }
    local ext = "." .. self:ext(folder)
    local dirs = { self:folder_dir(folder) }
    if self.bundled[folder] then
        table.insert(dirs, 1, self.bundled[folder])
    end
    for _, dir in ipairs(dirs) do
        for _, name in ipairs((self.list_dir or list_files)(dir)) do
            if name:sub(-#ext) == ext then
                local stem = name:sub(1, -#ext - 1)
                if not known.set[stem] then
                    known.set[stem] = true
                    known.where[stem] = dir
                    known.count = known.count + 1
                end
            end
        end
    end
    self.known[folder] = known
    return known
end

function Sprites:forget(folder)
    if folder then
        self.known[folder] = nil
    else
        self.known = {}
    end
end

function Sprites:has(folder, stem)
    return folder ~= nil and self:stems(folder).set[stem] == true
end

function Sprites:path(folder, stem)
    local known = self.known[folder]
    local dir = known and known.where[stem] or self:folder_dir(folder)
    return dir .. "/" .. stem .. "." .. self:ext(folder)
end

-- Where a download writes a file (never inside the plugin).
function Sprites:download_path(folder, stem)
    return self:folder_dir(folder) .. "/" .. stem .. "." .. self:ext(folder)
end

-- "done", "partial" or "none" for an item (set and variant).
function Sprites:item_state(set, variant)
    local have, want = 0, 0
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        if folder then
            local on_disk = self:stems(folder).set
            for _, stem in ipairs(self:wanted(set, folder)) do
                want = want + 1
                if on_disk[stem] then
                    have = have + 1
                end
            end
        end
    end
    if have == 0 then
        return "none"
    elseif have >= want then
        return "done"
    end
    return "partial", have, want
end

function Sprites:usable(set_id)
    local set = SpriteSets.get(set_id)
    return set ~= nil and self:item_state(set, "normal") ~= "none"
end

-- The set a game shows: the one chosen for it, else its own when downloaded, else the base.
-- Returns the set id and whether it is the game's own set (or a choice made for it).
function Sprites:set_for(game, chosen)
    if chosen and SpriteSets.get(chosen) then
        return chosen, true
    end
    if game and self:usable(game.set) then
        return game.set, true
    end
    return "base", game == nil
end

-- The file for a sprite: stem of the entry, female sprite wanted, shiny wanted, set to use.
-- Returns the path (or nil), and whether the picture is really shiny.
function Sprites:resolve(stem, female, shiny, set_id)
    local function try(set, variant)
        if not set or not SpriteSets.has_variant(set, variant) then
            return nil
        end
        local main = variant == "shiny" and set.shiny or set.normal
        local fem = variant == "shiny" and set.shiny_female or set.female
        if female and fem and self:has(fem, stem) then
            return self:path(fem, stem)
        end
        if self:has(main, stem) then
            return self:path(main, stem)
        end
        return nil
    end
    local set = SpriteSets.get(set_id or "base")
    local base = SpriteSets.get("base")
    if shiny then
        local p = try(set, "shiny") or try(base, "shiny")
        if p then
            return p, true
        end
    end
    local p = try(set, "normal") or try(base, "normal")
    return p, false
end

-- The files an item still has to download: { { url, path } }.
function Sprites:job_files(set, variant)
    local files = {}
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        local info = folder and self.manifest.folders[folder]
        if info then
            local have = self:stems(folder).set
            local remote = self.manifest.root .. (folder ~= "" and ("/" .. folder) or "")
            for _, stem in ipairs(self:wanted(set, folder)) do
                if not have[stem] then
                    files[#files + 1] = {
                        BASE_URL .. self.manifest.commit .. "/" .. remote .. "/" .. stem .. "." .. info.ext,
                        self:download_path(folder, stem),
                    }
                end
            end
        end
    end
    return files
end

function Sprites:make_dirs(set, variant)
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        if folder then
            os.execute("mkdir -p " .. quote(self:folder_dir(folder)))
        end
    end
end

-- Removes the files of an item (only the files: other variants may live in folders below).
function Sprites:delete(set, variant)
    for _, folder in ipairs(SpriteSets.folders(set, variant)) do
        if folder then
            local ext = "." .. self:ext(folder)
            for _, name in ipairs((self.list_dir or list_files)(self:folder_dir(folder))) do
                if name:sub(-#ext) == ext or name:sub(-5) == ".part" then
                    os.remove(self:folder_dir(folder) .. "/" .. name)
                end
            end
            self:forget(folder)
        end
    end
end

function Sprites.item_id(set, variant)
    return set.id .. "@" .. variant
end

return Sprites
