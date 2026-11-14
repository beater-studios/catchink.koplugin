-- A game (or the national view) as boxes of 30, like in the games, or as a list. A tap marks or
-- clears a Pokémon, a hold opens its card. Filters and the search narrow what is shown.
local Data = require("catchink/data")
local Draw = require("catchink/ui/draw")
local Filters = require("catchink/filters")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")
local SpriteCache = require("catchink/ui/sprite_cache")
local SpriteSets = require("catchink/sprite_sets")
local Sprites = require("catchink/sprites")

local s = Draw.s
local Browse = {}
Browse.__index = Browse

local BOX = 30
local COLS = 6
local LIST_ROW = 52

function Browse.new(app, args)
    local self = setmetatable({ app = app, profile = args.profile, game = args.game, mode = args.mode or "box", page = 1, query = args.query }, Browse)
    if args.filters then
        local f = app:filters_of(self.profile, self.game)
        for k, v in pairs(args.filters) do
            f[k] = v
        end
    end
    local _, own = app:set_for(self.profile, self.game)
    self.banner = self.game ~= Games.HOME and not own and not app.banner_off
    return self
end

function Browse:refresh()
    self.list = nil
end

function Browse:filters()
    return self.app:filters_of(self.profile, self.game)
end

-- The list shown, kept until the filters, the search, the language or (for a status filter) the captures
-- change: filtering and sorting 1,500 entries on every redraw is slow on the device.
function Browse:entries()
    local app = self.app
    local all = app:entries(self.profile, self.game)
    local f = self:filters()
    if Filters.count(f) == 0 and (not self.query or self.query == "") and f.order == "regional" then
        return all
    end
    local signature = table.concat({ Filters.signature(f), self.query or "", app.lang, tostring(#all),
        f.status ~= "all" and tostring(app:caps_version(self.profile)) or "" }, "#")
    if self.cached_signature ~= signature or self.cached_all ~= all then
        self.cached_list = Filters.apply(all, f, function(e) return app:entry_info(e, self.game) end, app:state_fn(self.profile, self.game), app.data, self.query)
        self.cached_signature, self.cached_all = signature, all
    end
    return self.cached_list
end

function Browse:title()
    if self.game == Games.HOME then
        return self.app.t.national
    end
    return Games.name(Games.get(self.game), self.app.lang)
end

function Browse:subtitle(count)
    local t = self.app.t
    if self.query or Filters.count(self:filters()) > 0 then
        return string.format(t.results, self.profile.name, count)
    end
    if self.game == Games.HOME then
        return string.format(t.dex_of, self.profile.name, t.national_short)
    end
    return string.format(t.dex_of, self.profile.name, Games.get(self.game).region)
end

function Browse:open_card(list, index)
    self.app:show("card", { profile = self.profile, game = self.game, list = list, index = index })
end

function Browse:choose_set()
    local app, t = self.app, self.app.t
    local items = { { text = t.set_auto, callback = function()
        self.profile.sets[self.game] = nil
        app:save_settings()
        SpriteCache.forget()
        app:redraw()
    end } }
    for _, set in ipairs(SpriteSets.LIST) do
        if app.sprites:usable(set.id) then
            local current = self.profile.sets[self.game] == set.id
            items[#items + 1] = { text = (current and "✓ " or "") .. app:set_label(set, "normal"), callback = function()
                self.profile.sets[self.game] = set.id
                self.banner = false
                app:save_settings()
                app:redraw()
            end }
        end
    end
    items[#items + 1] = { text = t.manage_sprites, callback = function() app:show("sprites") end }
    app:menu(t.choose_set, items)
end

function Browse:download_game_set()
    local app = self.app
    local game = Games.get(self.game)
    local set = SpriteSets.get(game.set)
    app:download(set, "normal")
    if self.profile.shiny and set.shiny then
        app:download(set, "shiny")
    end
    self.watch_downloads = true
    app:show_toast(string.format(app.t.downloading, app:set_label(set, "normal")))
    app:redraw()
end

-- The chips of what narrows the view, each removable with a tap.
function Browse:chips()
    local t, f = self.app.t, self:filters()
    local chips = {}
    if self.query and self.query ~= "" then
        chips[#chips + 1] = { text = "“" .. self.query .. "”", remove = function() self.query = nil end }
    end
    local gens = {}
    for g in pairs(f.gens) do
        gens[#gens + 1] = g
    end
    table.sort(gens)
    for _, g in ipairs(gens) do
        chips[#chips + 1] = { text = string.format(t.generation, g), remove = function() f.gens[g] = nil end }
    end
    for i, ty in ipairs(f.types) do
        chips[#chips + 1] = { text = self.app.text:type_name(ty), type_id = ty, remove = function() table.remove(f.types, i) end }
    end
    if f.status ~= "all" then
        chips[#chips + 1] = { text = t.statuses[f.status], remove = function() f.status = "all" end }
    end
    for c in pairs(f.cats) do
        chips[#chips + 1] = { text = t.categories[c], remove = function() f.cats[c] = nil end }
    end
    return chips
end

function Browse:draw_chips(ctx, y)
    local app, bb, W = self.app, ctx.bb, ctx.w
    local chips = self:chips()
    if #chips == 0 then
        return y
    end
    Draw.rect(bb, 0, y, W, s(42), Draw.PAPER)
    Draw.hline(bb, 0, y + s(42), W, math.max(1, s(1.4)), Draw.BLACK)
    local x = s(14)
    local clear_w = s(80)
    for _, c in ipairs(chips) do
        local label = c.text .. "  ×"
        local w = c.type_id and Look.type_pill_width(label, s(12.5), s(10)) or Look.pill_width(label, s(12.5), s(10))
        if x + w > W - clear_w then
            break
        end
        if c.type_id then
            Look.type_pill(bb, x, y + s(9), c.type_id, label, "filled", s(12.5), s(24), s(10))
        else
            Look.pill(bb, x, y + s(9), label, "filled", s(12.5), s(24), s(10))
        end
        ctx:hit(x, y, w, s(42), function()
            c.remove()
            self.page = 1
            app:save_settings()
            app:redraw()
        end)
        x = x + w + s(6)
    end
    Draw.text(bb, app.t.clear, Draw.face("bold", s(13)), W - clear_w, y, clear_w - s(14), s(42), "right")
    ctx:hit(W - clear_w, y, clear_w, s(42), function()
        self.query = nil
        local f = self:filters()
        local order = f.order
        for k, v in pairs(Filters.empty()) do
            f[k] = v
        end
        f.order = order
        self.page = 1
        app:save_settings()
        app:redraw()
    end)
    return y + s(43)
end

function Browse:draw_banner(ctx, y)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local game = Games.get(self.game)
    local set = SpriteSets.get(game.set)
    local x, w, h = s(10), W - s(20), s(86)
    y = y + s(6)
    Draw.rect(bb, x, y, w, h, Draw.BLACK, s(8))
    Draw.rect(bb, x + s(2), y + s(2), w - s(4), h - s(4), Draw.WHITE, s(7))
    Draw.rect(bb, x, y, s(8), h, Draw.INK, s(4))
    Draw.icon(bb, "info", x + s(28), y + s(22), s(20))
    Draw.text(bb, t.banner_title, Draw.face("bold", s(14)), x + s(46), y + s(6), w - s(100), s(20), "left")
    Draw.text(bb, t.banner_text, Draw.face("sans", s(12)), x + s(46), y + s(26), w - s(60), s(18), "left", Draw.DARK)
    local state = app.downloader:busy_with(Sprites.item_id(set, "normal"))
    local px = Look.pill(bb, x + s(46), y + s(52), t.change_set, "outline", s(12.5), s(26), s(12))
    ctx:hit(x + s(40), y + s(46), px - x - s(34), s(38), function() self:choose_set() end)
    local _, bytes = app.sprites:size(set, "normal")
    local label
    if state then
        local done, total = app.downloader:progress(Sprites.item_id(set, "normal"))
        label = done and string.format(t.downloading_count, done, total) or t.waiting
    else
        label = string.format(t.download_set, Games.name(game, app.lang), app:size_text(bytes))
    end
    local px2 = Look.pill(bb, px + s(8), y + s(52), label, "filled", s(12.5), s(26), s(12))
    if not state then
        ctx:hit(px + s(4), y + s(46), px2 - px, s(38), function() self:download_game_set() end)
    end
    Draw.icon(bb, "x", x + w - s(22), y + s(20), s(14))
    ctx:hit(x + w - s(48), y, s(48), s(44), function()
        app.banner_off = true
        app:save_settings()
        self.banner = false
        app:redraw()
    end)
    return y + h + s(4)
end

function Browse:draw_box_bar(ctx, y, list, pages)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local h = s(48)
    Draw.rect(bb, 0, y, W, h, Draw.PAPER)
    Draw.hline(bb, 0, y + h, W, math.max(1, s(1.4)), Draw.BLACK)
    Draw.icon(bb, "chevron_left", s(24), y + h / 2, s(20), self.page > 1 and Draw.BLACK or Draw.LIGHT)
    Draw.icon(bb, "chevron_right", s(216), y + h / 2, s(20), self.page < pages and Draw.BLACK or Draw.LIGHT)
    ctx:hit(0, y, s(70), h, function() self:swipe("east") end)
    ctx:hit(s(170), y, s(70), h, function() self:swipe("west") end)
    local label = self.mode == "box" and t.box or t.page
    Draw.text(bb, string.format(label, self.page, pages), Draw.face("bold", s(15)), s(50), y + s(4), s(140), s(22), "center")
    local per = self.mode == "box" and BOX or self.per_page
    local first = list[(self.page - 1) * per + 1]
    local last = list[math.min(#list, self.page * per)]
    if first and last then
        Draw.text(bb, string.format(t.range, first.number, last.number), Draw.face("sans", s(11.5)), s(50), y + s(26), s(140), s(18), "center", Draw.DARK)
    end
    local pr = app:progress(self.profile, self.game)
    Draw.text(bb, string.format("%d / %d", pr.caught, pr.total), Draw.face("bold", s(15)), s(260), y + s(4), W - s(276), s(22), "right")
    Look.progress(bb, s(300), y + s(30), W - s(316), pr.total > 0 and pr.caught / pr.total or 0, s(9))
    return y + h + s(2)
end

function Browse:cell(ctx, e, x, y, cw, ch, list, index, state_of)
    local app, bb = self.app, ctx.bb
    local state = state_of(e.key)
    local caught = state == "c"
    Draw.rect(bb, x + s(3), y + s(3), cw - s(6), ch - s(6), caught and Draw.BLACK or Draw.LIGHT, s(7))
    Draw.rect(bb, x + s(3) + (caught and s(1.6) or s(1.2)), y + s(3) + (caught and s(1.6) or s(1.2)), cw - s(6) - (caught and s(3.2) or s(2.4)), ch - s(6) - (caught and s(3.2) or s(2.4)), Draw.WHITE, s(6))
    if app.data:has_flag(e.species, Data.LEGENDARY) or app.data:has_flag(e.species, Data.MYTHICAL) then
        Draw.border(bb, x + s(7), y + s(7), cw - s(14), ch - s(14), math.max(1, s(1)), Draw.BLACK, s(5))
    end
    local mode = caught and "color" or (state == "s" and "seen" or (state == "u" and "unavailable" or "silhouette"))
    local path = app:sprite_path(self.profile, self.game, e)
    local cy = y + ch / 2 - s(8)
    if not SpriteCache.paint(bb, path, x + cw / 2, cy, cw - s(22), ch - s(50), mode) then
        Look.placeholder(bb, x + cw / 2, cy, cw - s(22), ch - s(50))
    end
    local missing = state == nil
    Draw.text(bb, string.format("#%03d", e.number), Draw.face("bold", s(11)), x + s(10), y + s(6), cw - s(36), s(18), "left", missing and Draw.MID or Draw.DARK)
    local name = app:entry_name(e)
    local name_x, name_w = x + s(6), cw - s(12)
    if e.gender then
        Draw.icon(bb, e.gender == "f" and "female" or "male", x + s(14), y + ch - s(16), s(13), missing and Draw.MID or Draw.BLACK)
        name_x, name_w = x + s(22), cw - s(28)
    end
    Draw.text(bb, name, Draw.face(caught and "bold" or "sans", s(11.5)), name_x, y + ch - s(26), name_w, s(20), "center", missing and Draw.MID or Draw.BLACK)
    Look.mark_for(self.profile, bb, state, x + cw - s(16), y + s(16), s(9))
    ctx:hit(x, y, cw, ch, function() app:toggle(self.profile, self.game, e) end, function() self:open_card(list, index) end)
end

function Browse:draw_row(ctx, e, y, W, list, index, state_of)
    local app, bb = self.app, ctx.bb
    local rh = s(LIST_ROW)
    local state = state_of(e.key)
    Draw.hline(bb, s(16), y + rh - 1, W - s(32), 1, Draw.PALE)
    Draw.rect(bb, s(16), y + s(4), s(56), rh - s(8), Draw.PAPER, s(6))
    local mode = state == "c" and "color" or (state == "s" and "seen" or (state == "u" and "unavailable" or "silhouette"))
    if not SpriteCache.paint(bb, app:sprite_path(self.profile, self.game, e), s(44), y + rh / 2, s(50), rh - s(10), mode) then
        Look.placeholder(bb, s(44), y + rh / 2, s(50), rh - s(10))
    end
    Draw.text(bb, string.format("#%03d", e.number), Draw.face("sans", s(11.5)), s(84), y + s(4), s(80), s(18), "left", Draw.DARK)
    local name = app:entry_name(e)
    local face = Draw.face(state == "c" and "bold" or "sans", s(16))
    local nx = s(84)
    if e.gender then
        Draw.icon(bb, e.gender == "f" and "female" or "male", nx + s(7), y + s(35), s(14))
        nx = nx + s(18)
    end
    local nw = Draw.text(bb, name, face, nx, y + s(22), s(180), s(26), "left", state == nil and Draw.DARK or Draw.BLACK)
    if app.data:has_flag(e.species, Data.LEGENDARY) or app.data:has_flag(e.species, Data.MYTHICAL) then
        Draw.icon(bb, "star", nx + nw + s(12), y + s(35), s(13))
    end
    Look.type_pills(bb, s(285), y + s(16), app:entry_info(e, self.game).types, app.text)
    Look.mark_for(self.profile, bb, state, W - s(34), y + rh / 2, s(12), true)
    ctx:hit(0, y, W, rh, function() app:toggle(self.profile, self.game, e) end, function() self:open_card(list, index) end)
end

function Browse:nav(ctx)
    local app, t = self.app, self.app.t
    local nf = Filters.count(self:filters())
    return Look.bottom_nav(ctx, {
        { label = t.nav_boxes, icon = "grid", active = self.mode == "box", tap = function()
            if self.mode ~= "box" then
                self.mode, self.page = "box", 1
                app:redraw()
            end
        end },
        { label = t.nav_list, icon = "list", active = self.mode == "list", tap = function()
            if self.mode ~= "list" then
                self.mode, self.page = "list", 1
                app:redraw()
            end
        end },
        { label = nf > 0 and string.format(t.nav_filters_n, nf) or t.nav_filters, icon = "filter", tap = function()
            app:show("filters", { profile = self.profile, game = self.game, browse = self })
        end },
        { label = t.nav_search, icon = "search", tap = function()
            app:ask_text(t.search_title, self.query or "", function(text)
                self.query = (text and text:match("%S")) and text or nil
                self.page = 1
                if self.query then
                    self.mode = "list"
                end
                app:redraw()
            end)
        end },
        { label = t.nav_progress, icon = "chart", tap = function() app:show("progress", { profile = self.profile }) end },
    })
end

function Browse:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local list = self:entries()
    self.list = list
    Look.header(ctx, self:title(), { back = function() app:back() end, sub = self:subtitle(#list), right = {
        { icon = "image", tap = function() self:choose_set() end },
    } })
    local y = s(Look.HEADER_H)
    y = self:draw_chips(ctx, y)
    local nav_y = H - s(Look.NAV_H)
    local state_of = app:state_fn(self.profile, self.game)
    -- The banner shows on the first box of the visit, until the page changes, it is closed or the
    -- game's own set arrives.
    if self.banner and self.game ~= Games.HOME and app.sprites:usable(Games.get(self.game).set) then
        self.banner = false
    end
    local banner_room = self.banner and self.page == 1 and self.mode == "box"
    local pages
    if self.mode == "box" then
        pages = math.max(1, math.ceil(#list / BOX))
    else
        local top = y + s(50)
        self.per_page = math.max(1, math.floor((nav_y - top) / s(LIST_ROW)))
        pages = math.max(1, math.ceil(#list / self.per_page))
    end
    self.pages = pages
    self.page = math.min(self.page, pages)
    y = self:draw_box_bar(ctx, y, list, pages)
    if banner_room then
        y = self:draw_banner(ctx, y)
    end
    if #list == 0 then
        Draw.text(bb, t.nothing_here, Draw.face("sans", s(15)), s(20), y + s(40), W - s(40), s(30), "center", Draw.DARK)
    elseif self.mode == "box" then
        local first = (self.page - 1) * BOX
        local cw = (W - s(12)) / COLS
        local ch = (nav_y - y - s(4)) / 5
        for i = 1, BOX do
            local e = list[first + i]
            if not e then
                break
            end
            local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
            self:cell(ctx, e, s(6) + col * cw, y + row * ch, cw, ch, list, first + i, state_of)
        end
    else
        local first = (self.page - 1) * self.per_page
        for i = 1, self.per_page do
            local e = list[first + i]
            if not e then
                break
            end
            self:draw_row(ctx, e, y, W, list, first + i, state_of)
            y = y + s(LIST_ROW)
        end
    end
    self:nav(ctx)
    app:draw_toast(ctx, nav_y - s(4))
end

function Browse:swipe(direction)
    if direction == "west" and self.page < (self.pages or 1) then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.banner = false
    self.app.notice = nil
    self.app:redraw()
end

return Browse
