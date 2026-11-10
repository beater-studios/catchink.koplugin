-- Home: the profiles, each with its national progress, and a button for a new one.
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")
local SpriteCache = require("catchink/ui/sprite_cache")

local s = Draw.s
local Home = {}
Home.__index = Home

local PER_PAGE = 4
local COVER = { normal = 1, shiny = 906, alpha = 133, living = 25, custom = 4 }

function Home.new(app)
    return setmetatable({ app = app, page = 1 }, Home)
end

function Home:pages()
    return math.max(1, math.ceil(#self.app.profiles / PER_PAGE))
end

-- The species of a profile's latest catch, or one that fits the model. Catches in the same second (a whole
-- evolution line marked at once) go to the lowest number, so the picture does not change between openings.
local function latest_catch(app, profile)
    local best, when = nil, -1
    for _, records in pairs(app:caps(profile).caps) do
        for key, r in pairs(records) do
            if r.s == "c" and r.t and r.t >= when then
                local species = tonumber(key:match("^(%d+)"))
                if species and app.data.species[species] and (r.t > when or species < best) then
                    best, when = species, r.t
                end
            end
        end
    end
    return best or COVER[profile.model] or 1
end

-- The species shown on a profile's card, kept until the profile's captures change.
local covers = setmetatable({}, { __mode = "k" })

local function cover_species(app, profile)
    local version = app:caps_version(profile)
    local cached = covers[profile]
    if not cached or cached.version ~= version then
        cached = { version = version, species = latest_catch(app, profile) }
        covers[profile] = cached
    end
    return cached.species
end

function Home:scope_text(profile)
    local t = self.app.t
    if #profile.games <= 2 and #profile.games > 0 then
        local names = {}
        for i, id in ipairs(profile.games) do
            names[i] = Games.name(Games.get(id), self.app.lang)
        end
        return table.concat(names, t.and_word)
    end
    return string.format(t.games_count, #profile.games)
end

function Home:profile_menu(profile)
    local app, t = self.app, self.app.t
    app:menu(profile.name, {
        { text = t.open, callback = function() app:show("games", { profile = profile }) end },
        { text = t.edit_profile, callback = function() app:show("profile_form", { profile = profile }) end },
        { text = t.rename, callback = function()
            app:ask_text(t.rename, profile.name, function(name)
                if name and name:match("%S") then
                    profile.name = name
                    app:save_settings()
                    app:redraw()
                end
            end)
        end },
        { text = t.duplicate, callback = function()
            app:duplicate_profile(profile)
            app:redraw()
        end },
        { text = t.delete, callback = function()
            app:confirm(string.format(t.delete_confirm, profile.name), t.delete, function()
                app:delete_profile(profile)
                self.page = math.min(self.page, self:pages())
                app:redraw()
            end)
        end },
    })
end

function Home:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local y = Look.header(ctx, t.name, {
        logo = true,
        right = { { icon = "dots", tap = function()
            app:menu(t.name, {
                { text = t.sprites, callback = function() app:show("sprites") end },
                { text = t.language, callback = function() app:choose_language() end },
                { text = t.about, callback = function() app:show("about") end },
                { text = t.exit_app, callback = function() app:close() end },
            })
        end } },
    })
    Draw.text(bb, t.your_profiles, Draw.face("serif", s(20)), s(20), y + s(12), W - s(40), s(28), "left")
    Draw.text(bb, t.profiles_hint, Draw.face("sans", s(13)), s(20), y + s(38), W - s(40), s(20), "left", Draw.DARK)
    y = y + s(70)
    local first = (self.page - 1) * PER_PAGE + 1
    local card_h = s(118)
    for i = first, math.min(#app.profiles, first + PER_PAGE - 1) do
        local p = app.profiles[i]
        local x, w = s(16), W - s(32)
        Look.card(bb, x, y, w, card_h)
        Draw.rect(bb, x + s(12), y + s(12), s(94), s(94), Draw.PAPER, s(6))
        local species = cover_species(app, p)
        local path = app:species_sprite(p, Games.HOME, species)
        if not SpriteCache.paint(bb, path, x + s(59), y + s(59), s(84), s(84), "color") then
            Look.placeholder(bb, x + s(59), y + s(59), s(84), s(84), "#" .. species)
        end
        if p.shiny then
            Draw.icon(bb, "sparkle", x + s(96), y + s(24), s(16), Draw.BLACK)
        end
        if p.model == "alpha" then
            Draw.icon(bb, "alpha", x + s(96), y + s(26), s(20), Draw.BLACK)
        end
        local model = t.models[p.model] or p.model
        local pw = Look.pill_width(model, s(11.5), s(9))
        Look.pill(bb, x + w - s(14), y + s(16), model, "outline", s(11.5), s(22), s(9), "right")
        Draw.text(bb, p.name, Draw.face("serif", s(19)), x + s(122), y + s(14), w - s(140) - pw, s(30), "left")
        Draw.text(bb, self:scope_text(p), Draw.face("sans", s(13)), x + s(122), y + s(42), w - s(140), s(20), "left", Draw.DARK)
        local pr = app:progress(p, Games.HOME)
        local pct = pr.total > 0 and pr.caught / pr.total or 0
        Draw.text(bb, string.format(t.of_total, pr.caught, pr.total), Draw.face("bold", s(15)), x + s(122), y + s(68), w - s(200), s(22), "left")
        Draw.text(bb, string.format("%d%%", math.floor(pct * 100 + 0.5)), Draw.face("bold", s(15)), x + w - s(80), y + s(68), s(66), s(22), "right")
        Look.progress(bb, x + s(122), y + s(92), w - s(136), pct, s(10))
        ctx:hit(x, y, w, card_h, function() app:show("games", { profile = p }) end, function() self:profile_menu(p) end)
        y = y + card_h + s(14)
    end
    local last_page = self.page == self:pages()
    if last_page then
        local x, w, h = s(16), W - s(32), s(62)
        Draw.rect(bb, x, y, w, h, Draw.MID, s(8))
        Draw.rect(bb, x + s(1.6), y + s(1.6), w - s(3.2), h - s(3.2), Draw.WHITE, s(7))
        Draw.icon(bb, "plus", W / 2 - s(70), y + h / 2, s(18), Draw.BLACK)
        Draw.text(bb, t.new_profile, Draw.face("bold", s(16)), W / 2 - s(56), y, s(200), h, "left")
        ctx:hit(x, y, w, h, function() app:show("profile_form", {}) end)
    end
    if self:pages() > 1 then
        local py = H - s(64)
        Draw.text(bb, string.format(t.page_of, self.page, self:pages()), Draw.face("sans", s(13)), 0, py, W, s(30), "center", Draw.DARK)
        if self.page > 1 then
            Draw.icon(bb, "chevron_left", s(40), py + s(15), s(24))
            ctx:hit(0, py - s(10), s(120), s(50), function() self:swipe("east") end)
        end
        if self.page < self:pages() then
            Draw.icon(bb, "chevron_right", W - s(40), py + s(15), s(24))
            ctx:hit(W - s(120), py - s(10), s(120), s(50), function() self:swipe("west") end)
        end
    end
    Draw.text(bb, t.profiles_footer, Draw.face("sans", s(11.5)), s(10), H - s(30), W - s(20), s(24), "center", Draw.MID)
    app:draw_toast(ctx, H - s(40))
end

function Home:swipe(direction)
    if direction == "west" and self.page < self:pages() then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.app:redraw()
end

return Home
