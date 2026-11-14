-- Logic tests, run from the plugin folder with plain LuaJIT: luajit tests/catchink_spec.lua
package.path = "./?.lua;" .. package.path
local Data = require("catchink/data")
local Dex = require("catchink/dex")
local Downloader = require("catchink/download")
local Filters = require("catchink/filters")
local Games = require("catchink/games")
local Profiles = require("catchink/profiles")
local SpriteSets = require("catchink/sprite_sets")
local Sprites = require("catchink/sprites")
local Text = require("catchink/text")
local Worker = require("catchink/download_worker")

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAILED: " .. name .. "\n  " .. tostring(err))
    end
end
local function eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%sexpected %s, got %s", label and (label .. ": ") or "", tostring(expected), tostring(actual)), 2)
    end
end

local data = Data.new("data")
local i18n = Data.load_table("data/i18n.lua")

local function profile(settings)
    return Profiles.new("p1", "Test", settings or {}, 1000)
end

test("index has every species and the national dex", function()
    eq(data.count, 1025)
    eq(data:name(25, "en"), "Pikachu")
    eq(data:name(772, "es"), "Código Cero")
    eq(#data.dex[1], 1025)
end)

test("every game has a Pokédex with entries", function()
    for _, g in ipairs(Games.LIST) do
        local entries = Games.dex_entries(g, data.dex)
        assert(#entries > 50, g.id .. " has " .. #entries .. " entries")
        local seen = {}
        for _, e in ipairs(entries) do
            assert(not seen[e.species], g.id .. " repeats species " .. e.species)
            seen[e.species] = true
        end
    end
    eq(#Games.dex_entries(Games.get("red-blue"), data.dex), 151)
    eq(#Games.dex_entries(Games.get("scarlet-violet"), data.dex), 400)
end)

test("Kalos joins its three Pokédex lists with growing numbers", function()
    local entries = Games.dex_entries(Games.get("x-y"), data.dex)
    assert(#entries > 400, "Kalos has " .. #entries)
    for i = 2, #entries do
        assert(entries[i].number > entries[i - 1].number, "numbers grow")
    end
end)

test("every game has a sprite set and a version group", function()
    for _, g in ipairs(Games.LIST) do
        assert(SpriteSets.get(g.set), g.id .. " has no set")
        assert(g.vg and #g.versions > 0, g.id)
    end
    for _, set in ipairs(SpriteSets.LIST) do
        assert(data:sprites().folders[set.normal], "manifest has " .. set.id)
    end
end)

test("gender modes split species", function()
    local simple = Dex.game_entries(data, Games.get("red-blue"), profile())
    eq(#simple, 151)
    local dimorphic = Dex.game_entries(data, Games.get("diamond-pearl"), profile{ gender = "dimorphic" })
    local plain = Dex.game_entries(data, Games.get("diamond-pearl"), profile())
    assert(#dimorphic > #plain, "dimorphic adds entries")
    local all = Dex.game_entries(data, Games.get("red-blue"), profile{ gender = "all" })
    assert(#all > #simple, "complete adds entries")
    -- Nidoran is one sex only, Magnemite has none: both stay single.
    local keys = {}
    for _, e in ipairs(all) do
        keys[e.key] = true
    end
    assert(keys["29"] and not keys["29_m"], "Nidoran female stays single")
    assert(keys["81"] and not keys["81_m"], "Magnemite stays single")
    assert(keys["1_m"] and keys["1_f"], "Bulbasaur splits")
end)

test("national with forms adds only forms kept outside battle", function()
    local p = profile{ forms = true }
    local entries = Dex.national_entries(data, p)
    local keys = {}
    for _, e in ipairs(entries) do
        keys[e.key] = true
    end
    assert(keys["37:alola"], "Alolan Vulpix counts")
    assert(not keys["3:mega"], "Mega Venusaur does not count")
    assert(not keys["3:gmax"], "Gigantamax does not count")
    eq(#Dex.national_entries(data, profile()), 1025)
    local alpha = Dex.national_entries(data, Profiles.new("p2", "A", { model = "alpha" }, 0))
    assert(#alpha < 700 and #alpha > 200, "an alpha profile follows only the Legends games: " .. #alpha)
end)

test("forms count in the games that have them", function()
    local p = profile{ forms = true }
    local function keys(game)
        local out = {}
        for _, e in ipairs(Dex.game_entries(data, Games.get(game), p)) do
            out[e.key] = true
        end
        return out
    end
    assert(keys("sun-moon")["37:alola"], "Alolan Vulpix in Sun and Moon")
    assert(keys("sword-shield")["37:alola"], "Alolan Vulpix in Sword and Shield (PKHeX)")
    assert(not keys("red-blue")["37:alola"], "no Alolan Vulpix in Red and Blue")
    assert(keys("gold-silver")["201:b"], "Unown B in Gold and Silver")
    assert(keys("legends-arceus")["58:hisui"], "Hisuian Growlithe in Legends: Arceus")
    assert(not keys("sword-shield")["58:hisui"], "no Hisuian Growlithe in Sword and Shield")
    assert(keys("brilliant-diamond-shining-pearl")["422:east"], "East Sea Shellos in BDSP")
    assert(not keys("sun-moon")["3:mega"], "Mega Evolutions never count")
    local plain = 0
    for _ in pairs(keys("red-blue")) do
        plain = plain + 1
    end
    eq(plain, 151, "Red and Blue have no forms")
    assert(data:game_has_form("scarlet-violet", 194, "paldea"), "Paldean Wooper in Scarlet and Violet")
end)

test("the newer games have encounters from PKHeX", function()
    local function versions(species)
        local enc = data:detail(species).enc or {}
        local out = {}
        for v in pairs(enc) do
            out[v] = true
        end
        return out
    end
    local eevee = versions(133)
    for _, v in ipairs({ 37, 38, 39, 40, 41, 47, 48 }) do
        assert(eevee[v], "Eevee in version " .. v)
    end
    assert(versions(906)[40], "Sprigatito as a gift in Scarlet")
    assert(versions(1017)[42], "Ogerpon in the Teal Mask")
    local text = Text.new(i18n.pt, "pt", data)
    local enc = data:detail(906).enc[40]
    eq(text:area(enc[1]), "Cabo Poco")
    eq(text:method(enc[2]), "Presente")
    eq(text:method(68), "Alfa")
    -- Bidoof on Route 201 in Brilliant Diamond: 50% (Serebii).
    local found
    local bidoof = data:detail(399).enc[37]
    for i = 1, #bidoof, 5 do
        if text:area(bidoof[i]) == "Route 201" and bidoof[i + 1] == 1 then
            found = bidoof[i + 4]
        end
    end
    eq(found, 50, "chance of Bidoof on Route 201")
    -- Pidgey on Route 1 in Red: its slots in one place add up, but times of day never do.
    local pidgey = data:detail(16).enc[1]
    for i = 1, #pidgey, 5 do
        assert(pidgey[i + 4] <= 100, "a chance above 100%")
    end
end)

test("keys parse back", function()
    eq(select(1, Dex.parse("25")), 25)
    eq(select(2, Dex.parse("25_f")), "f")
    eq(select(3, Dex.parse("37:alola")), "alola")
end)

test("captures toggle, undo and fall back across gender modes", function()
    local caps = Profiles.Captures.new()
    local before, state = caps:toggle("red-blue", "1", 10)
    eq(state, "c")
    eq(caps:state("red-blue", "1"), "c")
    eq(caps:state("red-blue", "1_f"), "c", "a gendered key falls back on the species")
    caps:restore("red-blue", before)
    eq(caps:state("red-blue", "1"), nil, "undo clears")
    caps:set("red-blue", "4_m", "c", 10)
    eq(caps:state("red-blue", "4"), "s", "one gender caught is not the species")
    caps:set("red-blue", "4_f", "c", 10)
    eq(caps:state("red-blue", "4"), "c", "both genders make the species")
    local b = caps:toggle("red-blue", "4", 11)
    eq(caps:state("red-blue", "4"), nil, "clearing a species clears both genders")
    eq(caps:state("red-blue", "4_m"), nil)
    caps:restore("red-blue", b)
    eq(caps:state("red-blue", "4"), "c", "undo brings both back")
end)

test("a gender caught through its species changes alone", function()
    local caps = Profiles.Captures.new()
    caps:set("red-blue", "3", "c", 10)
    local b = caps:toggle("red-blue", "3_m", 11)
    eq(caps:state("red-blue", "3_m"), nil, "the male is cleared")
    eq(caps:state("red-blue", "3_f"), "c", "the female stays caught")
    eq(caps:record("red-blue", "3_f").t, 10, "with the time of the species")
    caps:restore("red-blue", b)
    eq(caps:state("red-blue", "3_m"), "c", "undo")
    eq(caps:record("red-blue", "3_f"), nil, "undo removes the split")
    caps:apply("red-blue", "3_m", "u", 12)
    eq(caps:state("red-blue", "3_m"), "u", "the card can set a gender caught through its species")
    eq(caps:state("red-blue", "3_f"), "c")
    caps:apply("red-blue", "3", nil, 13)
    eq(caps:state("red-blue", "3"), nil, "the card can clear a species shown through its genders")
    eq(caps:state("red-blue", "3_f"), nil)
end)

test("notes stay when the state is cleared", function()
    local caps = Profiles.Captures.new()
    caps:set("home", "25", "c", 5)
    caps:set_note("home", "25", "Shiny from an egg")
    caps:set("home", "25", nil, 6)
    eq(caps:record("home", "25").n, "Shiny from an egg")
    eq(caps:state("home", "25"), nil)
end)

test("national state joins the games", function()
    local p = profile{ games = { "red-blue", "yellow" } }
    local caps = Profiles.Captures.new()
    caps:set("yellow", "25", "c", 5)
    local state, where = caps:national_state(p, "25")
    eq(state, "c")
    eq(where, "yellow")
    caps:set("red-blue", "26", "s", 5)
    eq((caps:national_state(p, "26")), "s")
    caps:set("home", "27", "u", 5)
    eq((caps:national_state(p, "27")), "u")
    local pr = caps:progress({ { key = "25" }, { key = "26" }, { key = "27" } }, function(k) return (caps:national_state(p, k)) end)
    eq(pr.caught, 1)
    eq(pr.total, 2, "unavailable leaves the total")
end)

test("recent catches count each key once", function()
    local caps = Profiles.Captures.new()
    caps:set("red-blue", "1", "c", 100)
    caps:set("yellow", "1", "c", 100)
    caps:set("yellow", "2", "c", 1)
    eq(caps:caught_since(50), 1)
end)

test("captures from disk are cleaned", function()
    local caps = Profiles.Captures.new({ ["red-blue"] = { ["1"] = { s = "c", t = 5 }, ["2"] = { s = "x" }, [3] = { s = "c" } }, bad = 4 })
    eq(caps:state("red-blue", "1"), "c")
    eq(caps:record("red-blue", "2"), nil)
end)

test("models set their defaults", function()
    eq(Profiles.model_defaults("shiny").shiny, true)
    eq(#Profiles.model_defaults("alpha").games, 3)
    eq(Profiles.model_defaults("living").forms, true)
    eq(#Profiles.model_defaults("normal").games, #Games.LIST)
    eq(Profiles.next_id({ { id = "p1" }, { id = "p7" } }), "p8")
    eq(Profiles.next_id({ { id = "p1" } }, 7), "p8", "a deleted id is never handed out again")
end)

test("filters by type, generation, status and search", function()
    local p = profile()
    local entries = Dex.national_entries(data, p)
    local function info(e)
        return { name = data:name(e.species, "en"), types = data:types(e.species), gen = data:generation(e.species) }
    end
    local f = Filters.empty()
    f.types = { 10 }
    f.gens[1] = true
    local fire = Filters.apply(entries, f, info, function() return nil end, data)
    eq(#fire, 12, "fire types of generation 1")
    f = Filters.empty()
    local found = Filters.apply(entries, f, info, function() return nil end, data, "char")
    eq(found[1].species, 4)
    local by_number = Filters.apply(entries, f, info, function() return nil end, data, "150")
    eq(#by_number, 1)
    f.status = "caught"
    local caught = Filters.apply(entries, f, info, function(k) return k == "25" and "c" or nil end, data)
    eq(#caught, 1)
    f = Filters.empty()
    f.cats.legendary = true
    f.gens[1] = true
    eq(#Filters.apply(entries, f, info, function() return nil end, data), 4, "Articuno, Zapdos, Moltres, Mewtwo")
    f = Filters.empty()
    f.order = "name"
    local sorted = Filters.apply(entries, f, info, function() return nil end, data)
    eq(sorted[1].species, 460, "Abomasnow comes first")
end)

test("search ignores accents and case", function()
    eq(Filters.normalize("  Flabébé "), "flabebe")
    eq(Filters.normalize("ÉLÉCTRICO"), "electrico")
    eq(Filters.normalize("Farfetch’d"), "farfetch'd")
    eq(Filters.normalize("ÄÈËÌÎÏÒÖÙÛÑ"), "aeeiiioouun")
end)

test("filters from disk are cleaned", function()
    local f = Filters.valid({ gens = { [1] = true, x = true }, types = { 1, 2, 3 }, status = "bad", order = "name" })
    eq(#f.types, 2)
    eq(f.status, "all")
    eq(f.order, "name")
    eq(Filters.count(f), 3)
end)

test("species details load and every one has texts in three languages", function()
    for id = 1, data.count do
        local d = data:detail(id)
        assert(d, "detail " .. id)
        assert(d.genus.en ~= "" and d.genus.es ~= "" and d.genus.pt ~= "", "genus of " .. id)
        assert(d.flavor.pt ~= "", "Portuguese text of " .. id)
        assert(next(d.flavor.es) ~= nil, "Spanish text of " .. id)
        assert(#d.st == 6, "stats of " .. id)
    end
end)

test("texts in Portuguese have no dashes", function()
    for id = 1, data.count do
        local d = data:detail(id)
        assert(not d.flavor.pt:find("—") and not d.flavor.pt:find("–"), "dash in " .. id)
    end
end)

test("what is in Portuguese is also in Spanish", function()
    for id, a in pairs(data:abilities()) do
        assert(a[5] ~= "", "Portuguese text of ability " .. id)
        assert(a[4] ~= "" and a[4] ~= a[3], "Spanish text of ability " .. id .. " (" .. a[1] .. ")")
    end
    for species, forms in pairs(data.forms) do
        for _, f in ipairs(forms) do
            if f[8] ~= f[6] then
                assert(f[7] ~= f[6], "Spanish name of form " .. f[6])
            end
        end
    end
end)

test("evolution conditions read well", function()
    local text = Text.new(i18n.pt, "pt", data)
    local eevee = data:detail(133)
    local by_species = {}
    for _, n in ipairs(eevee.evo) do
        by_species[n.s] = n
    end
    eq(text:conditions(by_species[134].c)[1], "Usar Water Stone")
    eq(text:conditions(by_species[197].c)[1], "Subir de nível, amizade alta, à noite")
    local en = Text.new(i18n.en, "en", data)
    eq(en:conditions(data:detail(2).evo[2].c)[1], "Level 16")
    local es = Text.new(i18n.es, "es", data)
    eq(es:conditions(by_species[134].c)[1], "Usar Piedra Agua")
end)

test("flavor picks the game's text, Portuguese has one", function()
    local en = Text.new(i18n.en, "en", data)
    local d = data:detail(1)
    local text, version = en:flavor(d, { 1, 2 })
    eq(version, 1)
    assert(text:find("strange seed"), text)
    local pt = Text.new(i18n.pt, "pt", data)
    assert(pt:flavor(d, { 1 }):find("semente"))
end)

test("numbers and dates follow the language", function()
    local pt = Text.new(i18n.pt, "pt", data)
    eq(pt:height(7), "0,7 m")
    eq(pt:weight(69), "6,9 kg")
    eq(pt:thousands(5120), "5.120")
    eq(pt:percent(87.5), "87,5%")
    local en = Text.new(i18n.en, "en", data)
    eq(en:thousands(1234567), "1,234,567")
    eq(pt:date(os.time{ year = 2026, month = 3, day = 12, hour = 12 }), "12 de março de 2026")
end)

test("moves, abilities and places keep official names in Portuguese", function()
    local pt = Text.new(i18n.pt, "pt", data)
    eq(pt:move(33), "Tackle")
    local name, text = pt:ability(65)
    eq(name, "Overgrow")
    assert(text ~= "" and not text:find("Powers"), "Portuguese ability text")
    local es = Text.new(i18n.es, "es", data)
    eq(es:move(33), "Placaje")
end)

test("sprites resolve to the chosen set, then the base, and report shiny", function()
    local files = {
        ["/s/base"] = { "1.png", "25.png" },
        ["/s/shiny"] = { "25.png" },
        ["/s/female"] = { "25.png" },
        ["/s/versions/generation-i/red-blue/transparent/gray"] = { "1.png" },
    }
    local sprites = Sprites.new{ dir = "/s", manifest = data:sprites(), list_dir = function(path) return files[path] or {} end }
    eq(sprites:resolve("1", false, false, "red-blue"), "/s/versions/generation-i/red-blue/transparent/gray/1.png")
    eq(sprites:resolve("25", false, false, "red-blue"), "/s/base/25.png", "falls back on the base")
    local path, shiny = sprites:resolve("25", false, true, "red-blue")
    eq(path, "/s/shiny/25.png")
    eq(shiny, true)
    local p2, s2 = sprites:resolve("1", false, true, "red-blue")
    eq(p2, "/s/versions/generation-i/red-blue/transparent/gray/1.png")
    eq(s2, false, "no shiny anywhere: the normal one, not marked shiny")
    eq(sprites:resolve("25", true, false, "base"), "/s/female/25.png")
    eq(sprites:resolve("999", false, false, "base"), nil)
    eq(sprites:item_state(SpriteSets.get("red-blue"), "normal"), "partial")
    eq(select(1, sprites:set_for(Games.get("red-blue"), nil)), "red-blue")
    eq(select(1, sprites:set_for(Games.get("platinum"), nil)), "base")
    eq(select(2, sprites:set_for(Games.get("platinum"), nil)), false, "the base is not the game's own")
    eq(select(2, sprites:set_for(Games.get("platinum"), "base")), true, "a chosen set counts as the game's")
end)

test("the base set inside the plugin counts as downloaded", function()
    local files = { ["/plugin/sprites/base"] = { "1.png", "25.png" }, ["/s/versions/generation-i/red-blue/transparent/gray"] = { "1.png" } }
    local sprites = Sprites.new{ dir = "/s", manifest = data:sprites(), data = data,
        bundled = { [""] = "/plugin/sprites/base" }, list_dir = function(path) return files[path] or {} end }
    eq(sprites:resolve("25", false, false, "base"), "/plugin/sprites/base/25.png")
    eq(sprites:resolve("1", false, false, "red-blue"), "/s/versions/generation-i/red-blue/transparent/gray/1.png")
    assert(sprites:is_bundled(SpriteSets.get("base"), "normal"))
    assert(not sprites:is_bundled(SpriteSets.get("base"), "shiny"))
    for _, f in ipairs(sprites:job_files(SpriteSets.get("base"), "normal")) do
        assert(not f[2]:find("/plugin/", 1, true), "downloads never write inside the plugin")
    end
end)

test("each package says which sprites came inside it", function()
    local function bundled(dirs)
        return Sprites.bundled_in("/p", function(path) return dirs[path] == true end)
    end
    local none = bundled({})
    eq(next(none), nil, "the package without sprites brings none")
    local base = Sprites.new{ dir = "/s", manifest = data:sprites(), bundled = bundled({ ["/p/sprites/base"] = true, ["/p/sprites/female"] = true }), list_dir = function() return {} end }
    assert(base:is_bundled(SpriteSets.get("base"), "normal"))
    assert(not base:is_bundled(SpriteSets.get("base"), "shiny"), "shiny is a download in the base package")
    local all = bundled({ ["/p/sprites/base"] = true, ["/p/sprites/female"] = true, ["/p/sprites/shiny"] = true, ["/p/sprites/shiny_female"] = true })
    eq(all.shiny, "/p/sprites/shiny")
end)

test("a download job lists only missing files, at the fixed commit", function()
    local sprites = Sprites.new{ dir = "/s", manifest = data:sprites(), list_dir = function(path)
        return path == "/s/versions/generation-i/red-blue/transparent/gray" and { "1.png" } or {}
    end }
    local files = sprites:job_files(SpriteSets.get("red-blue"), "normal")
    eq(#files, 150)
    assert(files[1][1]:find("^https://raw%.githubusercontent%.com/PokeAPI/sprites/" .. data:sprites().commit .. "/sprites/pokemon/versions/generation%-i/red%-blue/transparent/gray/"), files[1][1])
    for _, f in ipairs(files) do
        assert(Worker.allowed(f[1], Sprites.HOSTS), f[1])
    end
end)

test("a game's set downloads only its Pokédex and their forms", function()
    local sprites = Sprites.new{ dir = "/s", manifest = data:sprites(), data = data, list_dir = function() return {} end }
    local bw = SpriteSets.get("black-white")
    local folder_total = #data:sprites().folders[bw.normal].ids
    local files = sprites:size(bw, "normal")
    assert(files < folder_total / 2, string.format("%d of %d files", files, folder_total))
    local wanted = {}
    for _, stem in ipairs(sprites:wanted(bw, bw.normal)) do
        wanted[stem] = true
    end
    assert(wanted["495"] and wanted["649"], "Unova species are in")
    assert(not wanted["1"], "Bulbasaur is not in Unova")
    local sv = SpriteSets.get("scarlet-violet")
    local sv_wanted = {}
    for _, stem in ipairs(sprites:wanted(sv, sv.normal)) do
        sv_wanted[stem] = true
    end
    assert(sv_wanted["906"] and sv_wanted["1"], "the set of Scarlet and Violet also covers Kitakami and Blueberry")
    eq(#sprites:wanted(SpriteSets.get("base"), ""), #data:sprites().folders[""].ids, "the base takes everything")
    local rb = sprites:size(SpriteSets.get("red-blue"), "normal")
    eq(rb, 151)
end)

test("the downloader runs jobs in order and reports them", function()
    local tmp = os.tmpname()
    os.remove(tmp)
    local spawned, done, reaped = {}, {}, {}
    local downloader = Downloader.new{
        work_dir = tmp,
        hosts = Sprites.HOSTS,
        spawn = function(list, progress)
            spawned[#spawned + 1] = list
            local count = 0
            for _ in io.lines(list) do
                count = count + 1
            end
            local f = io.open(progress, "wb")
            f:write(string.format("%d 0 %d end", count, count))
            f:close()
            return #spawned
        end,
        is_done = function(pid)
            reaped[pid] = true
            return true
        end,
        kill = function() end,
    }
    downloader:add{ id = "a", files = { { "u1", "p1" }, { "u2", "p2" } }, on_done = function(d, f, t) done[#done + 1] = d .. "/" .. t end }
    downloader:add{ id = "b", files = { { "u3", "p3" } }, on_done = function(d) done[#done + 1] = "b" .. d end }
    downloader:add{ id = "a", files = {} }
    eq(downloader:busy_with("b"), "queued")
    while downloader:tick() do end
    eq(#spawned, 3, "two parts for the first job, one for the second")
    for pid = 1, 3 do
        assert(reaped[pid], "child " .. pid .. " was collected")
    end
    eq(done[1], "2/2")
    eq(done[2], "b1")
    os.execute("rm -rf '" .. tmp .. "'")
end)

test("the worker gives up after many failures in a row", function()
    local tmp = os.tmpname()
    local list = tmp .. ".list"
    local f = io.open(list, "wb")
    for i = 1, 20 do
        f:write("https://example.invalid/" .. i .. ".png\t" .. tmp .. "_" .. i .. ".png\n")
    end
    f:close()
    Worker.run({ list = list, progress = tmp .. ".progress", ca_file = "none", hosts = Sprites.HOSTS })
    local p = io.open(tmp .. ".progress", "rb")
    local text = p:read("*a")
    p:close()
    assert(text:find("stopped", 1, true), "it stops: " .. text)
    eq(text:match("^%d+ (%d+)"), "8", "after 8 failures, not 20")
    os.remove(list)
    os.remove(tmp .. ".progress")
    os.remove(tmp)
end)

test("the worker refuses other hosts", function()
    assert(not Worker.allowed("http://raw.githubusercontent.com/a.png", Sprites.HOSTS))
    assert(not Worker.allowed("https://raw.githubusercontent.com.evil.com/a.png", Sprites.HOSTS))
    assert(Worker.allowed("https://raw.githubusercontent.com/a.png", Sprites.HOSTS))
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
