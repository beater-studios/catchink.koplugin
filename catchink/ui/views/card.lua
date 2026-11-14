-- The card of a Pokémon, in seven pages: overview, stats, evolution, forms, in the game, in the profile and types.
-- Swipes and the arrows in the header move along the list it was opened from.
local Dex = require("catchink/dex")
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")
local SpriteCache = require("catchink/ui/sprite_cache")

local s = Draw.s
local Card = {}
Card.__index = Card

local STATES = { false, "s", "c", "u" }

function Card.new(app, args)
    local self = setmetatable({ app = app, profile = args.profile, game = args.game, list = args.list, index = args.index or 1, tab = args.tab or 1, sub_page = 1 }, Card)
    self:load()
    return self
end

function Card:load()
    self.entry = self.list[self.index]
    self.species = self.entry.species
    self.detail = self.app.data:detail(self.species) or {}
    self.sub_page = 1
    self.move_game = nil
end

function Card:refresh()
    self:load()
end

function Card:in_game()
    return self.game ~= Games.HOME
end

-- The game used by the "in the game" page: the card's game, or a chosen one from the national view.
function Card:page_game()
    if self:in_game() then
        return Games.get(self.game)
    end
    if self.move_game then
        return Games.get(self.move_game)
    end
    for i = #self.profile.games, 1, -1 do
        local g = Games.get(self.profile.games[i])
        if self.detail.moves and self.detail.moves[g.vg] then
            return g
        end
    end
    return Games.get(self.profile.games[#self.profile.games] or "red-blue")
end

function Card:state()
    local caps = self.app:caps(self.profile)
    if self:in_game() then
        return caps:state(self.game, self.entry.key)
    end
    return (caps:national_state(self.profile, self.entry.key))
end

function Card:record_game()
    return self:in_game() and self.game or Games.HOME
end

function Card:move(delta)
    local index = self.index + delta
    if index < 1 or index > #self.list then
        return
    end
    self.index = index
    self:load()
    self.app.notice = nil
    self.app:redraw()
end

function Card:swipe(direction)
    if direction == "west" then
        self:move(1)
    elseif direction == "east" then
        self:move(-1)
    end
end

function Card:header(ctx)
    local app, t = self.app, self.app.t
    local e = self.entry
    local sub
    if self:in_game() then
        local g = Games.get(self.game)
        sub = string.format("%s · %s #%03d", Games.name(g, app.lang), g.region, e.number)
    else
        sub = string.format("%s · %s #%03d", self.profile.name, t.national_short, e.national)
    end
    Look.header(ctx, string.format("#%03d  %s", e.national, app:entry_name(e)), {
        back = function() app:back() end,
        sub = sub,
        right = {
            { icon = "chevron_left", size = 20, tap = function() self:move(-1) end },
            { icon = "chevron_right", size = 20, tap = function() self:move(1) end },
        },
    })
end

function Card:sprite(bb, entry, cx, cy, w, h, mode, shiny)
    local app = self.app
    local set_id = app:set_for(self.profile, self.game)
    local stem, female = Dex.sprite_stem(app.data, entry)
    local path = app.sprites:resolve(stem, female, shiny == nil and self.profile.shiny or shiny, set_id)
    if not SpriteCache.paint(bb, path, cx, cy, w, h, mode or "color") then
        Look.placeholder(bb, cx, cy, w, h, "#" .. entry.species)
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- 1. Overview.
---------------------------------------------------------------------------

function Card:page_overview(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local e, d = self.entry, self.detail
    local y = top + s(16)
    Draw.rect(bb, s(16), y, s(220), s(200), Draw.BLACK, s(8))
    Draw.rect(bb, s(17.6), y + s(1.6), s(216.8), s(196.8), Draw.PAPER, s(7))
    local state = self:state()
    self:sprite(bb, e, s(126), y + s(100), s(190), s(180), state == "c" and "color" or (state == "s" and "seen" or "color"))
    if self.profile.shiny then
        Draw.icon(bb, "sparkle", s(212), y + s(22), s(18))
    end
    if self.profile.model == "alpha" then
        Draw.icon(bb, "alpha", s(40), y + s(24), s(22))
    end
    local x = s(254)
    local name_face = Draw.face("serif", s(24))
    Draw.text(bb, app:entry_name(e), name_face, x, y + s(4), W - x - s(16), s(34), "left")
    Draw.text(bb, app.text:genus(d), Draw.face("italic", s(15)), x, y + s(38), W - x - s(16), s(22), "left", Draw.DARK)
    Look.type_pills(bb, x, y + s(66), app:entry_types(e, self.game), app.text, s(13), s(24))
    if e.gender then
        Draw.icon(bb, e.gender == "f" and "female" or "male", W - s(34), y + s(78), s(20))
    end
    local facts = {
        { t.height, d.h and app.text:height(d.h) or "?" },
        { t.weight, d.w and app.text:weight(d.w) or "?" },
        { t.national_number, string.format("#%03d", e.national) },
        { t.generation_label, tostring(app.data:generation(e.species)) },
    }
    for i, f in ipairs(facts) do
        local fx = x + ((i - 1) % 2) * s(168)
        local fy = y + s(104) + math.floor((i - 1) / 2) * s(46)
        Look.label(bb, fx, fy, s(160), f[1])
        Draw.text(bb, f[2], Draw.face("bold", s(17)), fx, fy + s(16), s(160), s(24), "left")
    end
    y = y + s(226)
    local game = self:in_game() and Games.get(self.game) or nil
    local text, version = app.text:flavor(d, game and game.versions)
    local title = t.description
    if version and game then
        title = string.format(t.description_of, Games.name(game, app.lang))
    end
    local face = Draw.face("serif_regular", s(15.5))
    local lines = Draw.wrap(text ~= "" and text or t.no_description, face, W - s(64))
    local box_h = math.max(s(70), #lines * s(22) + s(30))
    Look.card(bb, s(16), y, W - s(32), box_h, title)
    for i, line in ipairs(lines) do
        Draw.text(bb, line, face, s(32), y + s(14) + (i - 1) * s(22), W - s(64), s(22), "left")
    end
    y = y + box_h + s(26)
    local card_h = bottom - y - s(12)
    Look.card(bb, s(16), y, W - s(32), card_h, self:in_game() and t.in_this_game or t.on_national)
    local active = 1
    for i, st in ipairs(STATES) do
        if (st or nil) == state then
            active = i
        end
    end
    Look.segmented(ctx, s(30), y + s(20), W - s(60), { t.state_none, t.state_seen, t.state_caught, t.state_unavailable }, active, function(i)
        local game_id = self:record_game()
        if not self:in_game() then
            local _, where = app:caps(self.profile):national_state(self.profile, e.key)
            if where and where ~= Games.HOME and STATES[i] ~= "c" then
                app:show_toast(string.format(t.caught_in_game, Games.name(Games.get(where), app.lang)))
                return app:redraw()
            end
        end
        app:set_state(self.profile, game_id, e.key, STATES[i] or nil)
    end, s(40), s(13))
    local record = app:caps(self.profile):record(self:record_game(), e.key)
    local ry = y + s(78)
    if state == "c" and record and record.t then
        Look.label(bb, s(32), ry, s(300), t.caught_on)
        Draw.text(bb, app.text:date(record.t), Draw.face("sans", s(15.5)), s(32), ry + s(14), W - s(110), s(26), "left")
        Draw.icon(bb, "pencil", W - s(44), ry + s(20), s(18))
        ctx:hit(s(30), ry - s(6), W - s(60), s(50), function() app:edit_date(self.profile, self:record_game(), e.key) end)
        ry = ry + s(54)
        Draw.hline(bb, s(30), ry - s(8), W - s(60), math.max(1, s(1.2)), Draw.PALE)
    elseif state == "c" then
        local _, where = app:caps(self.profile):national_state(self.profile, e.key)
        if where and where ~= Games.HOME then
            Draw.text(bb, string.format(t.caught_in_game, Games.name(Games.get(where), app.lang)), Draw.face("sans", s(14)), s(32), ry, W - s(64), s(26), "left", Draw.DARK)
            ry = ry + s(40)
        end
    end
    if ry + s(40) < y + card_h then
        Look.label(bb, s(32), ry, s(300), t.note)
        local note = record and record.n
        Draw.text(bb, note or t.add_note, Draw.face("sans", s(15)), s(32), ry + s(14), W - s(110), s(26), "left", note and Draw.BLACK or Draw.MID)
        Draw.icon(bb, "pencil", W - s(44), ry + s(20), s(18))
        ctx:hit(s(30), ry - s(6), W - s(60), s(50), function() app:edit_note(self.profile, self:record_game(), e.key) end)
    end
end

---------------------------------------------------------------------------
-- 2. Stats.
---------------------------------------------------------------------------

function Card:page_stats(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local d = self.detail
    local y = top + s(24)
    Look.card(bb, s(16), y, W - s(32), s(252), t.base_stats)
    local total = 0
    for i, v in ipairs(d.st or {}) do
        local sy = y + s(20) + (i - 1) * s(32)
        Draw.text(bb, t.stats[i], Draw.face("sans", s(14)), s(32), sy, s(120), s(18), "left")
        Draw.text(bb, tostring(v), Draw.face("bold", s(14)), s(120), sy, s(50), s(18), "right")
        Look.progress(bb, s(184), sy + s(2), W - s(216), math.min(1, v / 160), s(14), Draw.DARK)
        total = total + v
    end
    Draw.hline(bb, s(30), y + s(214), W - s(60), math.max(1, s(1.2)), Draw.PALE)
    Draw.text(bb, t.total, Draw.face("bold", s(15)), s(32), y + s(222), s(120), s(22), "left")
    Draw.text(bb, tostring(total), Draw.face("serif", s(17)), s(100), y + s(222), s(70), s(22), "right")
    y = y + s(276)
    local abilities = d.ab or {}
    local face_text = Draw.face("sans", s(13.5))
    local blocks, needed = {}, s(24)
    for _, a in ipairs(abilities) do
        local name, text = app.text:ability(a[1])
        local lines = Draw.wrap(text, face_text, W - s(64))
        blocks[#blocks + 1] = { name = name, lines = lines, hidden = a[2] == 1 }
        needed = needed + s(26) + #lines * s(19) + s(8)
    end
    local ab_h = math.min(needed, s(200))
    Look.card(bb, s(16), y, W - s(32), ab_h, t.abilities)
    local ay = y + s(16)
    for _, b in ipairs(blocks) do
        if ay + s(26) > y + ab_h then
            break
        end
        local nw = Draw.text(bb, b.name, Draw.face("bold", s(16)), s(32), ay, W - s(150), s(24), "left")
        if b.hidden then
            Look.pill(bb, s(40) + nw, ay + s(2), t.hidden, "outline", s(11), s(20), s(8))
        end
        ay = ay + s(26)
        for _, line in ipairs(b.lines) do
            if ay + s(19) > y + ab_h - s(4) then
                break
            end
            Draw.text(bb, line, face_text, s(32), ay, W - s(64), s(19), "left", Draw.DARK)
            ay = ay + s(19)
        end
        ay = ay + s(8)
    end
    y = y + ab_h + s(24)
    local card_h = bottom - y - s(10)
    Look.card(bb, s(16), y, W - s(32), card_h, t.capture_breeding)
    local egg = {}
    for i, g in ipairs(d.eg or {}) do
        egg[i] = app.text:egg_group(g)
    end
    local items = {
        { t.capture_rate, tostring(d.cr or "?") },
        { t.hatch_steps, d.hc and app.text:thousands(d.hc * 256) or "?" },
        { t.egg_groups_label, #egg > 0 and table.concat(egg, ", ") or "?" },
        { t.growth_rate, app.text:growth(d.gr or "") },
    }
    for i, it in ipairs(items) do
        local fx = s(32) + ((i - 1) % 2) * s(280)
        local fy = y + s(18) + math.floor((i - 1) / 2) * s(48)
        if fy + s(40) < y + card_h then
            Look.label(bb, fx, fy, s(260), it[1])
            Draw.text(bb, it[2], Draw.face("bold", s(15)), fx, fy + s(16), s(260), s(22), "left")
        end
    end
    local gy = y + s(118)
    if gy + s(40) < y + card_h then
        Look.label(bb, s(32), gy, s(300), t.gender_ratio)
        local rate = app.data:gender_rate(self.species)
        local bx, bw, bh = s(32), W - s(64), s(18)
        if rate < 0 then
            Draw.text(bb, t.genderless, Draw.face("bold", s(14)), bx, gy + s(16), bw, s(22), "left")
        else
            local female = rate / 8
            Draw.rect(bb, bx, gy + s(18), bw, bh, Draw.BLACK, bh / 2)
            Draw.rect(bb, bx + s(1.4), gy + s(19.4), bw - s(2.8), bh - s(2.8), Draw.WHITE, bh / 2)
            if female < 1 then
                Draw.rect(bb, bx + s(2), gy + s(20), math.max(bh, (bw - s(4)) * (1 - female)), bh - s(4), Draw.DARK, (bh - s(4)) / 2)
            end
            local ly = gy + s(38)
            Draw.icon(bb, "male", bx + s(7), ly + s(9), s(14))
            Draw.text(bb, app.text:percent((1 - female) * 100), Draw.face("bold", s(12)), bx + s(18), ly, s(100), s(18), "left")
            local fw = Draw.text_width(app.text:percent(female * 100), Draw.face("bold", s(12)))
            Draw.text(bb, app.text:percent(female * 100), Draw.face("bold", s(12)), bx + bw - s(100), ly, s(100), s(18), "right")
            Draw.icon(bb, "female", bx + bw - fw - s(10), ly + s(9), s(14))
        end
    end
end

---------------------------------------------------------------------------
-- 3. Evolution.
---------------------------------------------------------------------------

function Card:evo_stages()
    local nodes = self.detail.evo or {}
    local depth, by_parent = {}, {}
    for _, n in ipairs(nodes) do
        depth[n.s] = n.from and ((depth[n.from] or 0) + 1) or 0
        if n.from then
            by_parent[n.from] = by_parent[n.from] or {}
            table.insert(by_parent[n.from], n)
        end
    end
    local stages = {}
    for _, n in ipairs(nodes) do
        local dpt = depth[n.s] or 0
        stages[dpt + 1] = stages[dpt + 1] or {}
        table.insert(stages[dpt + 1], n)
    end
    return stages
end

function Card:node_state(species)
    local caps = self.app:caps(self.profile)
    local key = tostring(species)
    if self:in_game() then
        return caps:state(self.game, key)
    end
    return (caps:national_state(self.profile, key))
end

function Card:page_evolution(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local y = top + s(10)
    Draw.text(bb, t.evolution_chain, Draw.face("serif", s(19)), s(20), y, W - s(40), s(28), "left")
    Draw.text(bb, t.evolution_hint, Draw.face("sans", s(12.5)), s(20), y + s(26), W - s(40), s(20), "left", Draw.DARK)
    y = y + s(54)
    local stages = self:evo_stages()
    local count = #(self.detail.evo or {})
    if count <= 1 then
        Draw.text(bb, t.no_evolution, Draw.face("sans", s(15)), s(20), y + s(20), W - s(40), s(30), "center", Draw.DARK)
        return
    end
    local area_bottom = bottom - s(150)
    local rows = 0
    for _, nodes in ipairs(stages) do
        rows = rows + math.ceil(#nodes / 3)
    end
    local gap = s(30)
    local row_gap = s(8)
    local card_h = math.min(s(150), math.floor((area_bottom - y - gap * (#stages - 1) - row_gap * (rows - #stages)) / rows))
    local face_cond = Draw.face("bold", s(11))
    for si, nodes in ipairs(stages) do
        local per_row = math.min(3, #nodes)
        local cw = math.min(s(180), (W - s(32) - (per_row - 1) * s(10)) / per_row)
        for ni, n in ipairs(nodes) do
            local col = (ni - 1) % 3
            local row_in_stage = math.floor((ni - 1) / 3)
            local in_row = math.min(3, #nodes - row_in_stage * 3)
            local row_w = in_row * cw + (in_row - 1) * s(10)
            local x = (W - row_w) / 2 + col * (cw + s(10))
            local cy = y + row_in_stage * (card_h + row_gap)
            local current = n.s == self.species
            Draw.rect(bb, x, cy, cw, card_h, Draw.BLACK, s(8))
            Draw.rect(bb, x + (current and s(2.4) or s(1.5)), cy + (current and s(2.4) or s(1.5)), cw - (current and s(4.8) or s(3)), card_h - (current and s(4.8) or s(3)), Draw.WHITE, s(7))
            if current then
                Draw.border(bb, x + s(5), cy + s(5), cw - s(10), card_h - s(10), math.max(1, s(1)), Draw.BLACK, s(5))
            end
            local st = self:node_state(n.s)
            local mode = st == "c" and "color" or (st == "s" and "seen" or "silhouette")
            local cond_h = (n.c and si > 1) and s(18) or 0
            local sprite_h = card_h - s(40) - cond_h
            self:sprite(bb, { species = n.s, key = tostring(n.s) }, x + cw / 2, cy + s(8) + cond_h + sprite_h / 2, cw - s(24), sprite_h - s(4), mode)
            Draw.text(bb, app.data:name(n.s, app.lang), Draw.face("bold", s(13.5)), x + s(4), cy + card_h - s(28), cw - s(8), s(22), "center")
            if n.c and si > 1 then
                local conds = app.text:conditions(n.c)
                local label = conds[1] or ""
                if #conds > 1 then
                    label = label .. " +" .. (#conds - 1)
                end
                Draw.rect(bb, x + s(6), cy + s(6), cw - s(12), s(18), Draw.PAPER, s(9))
                Draw.text(bb, label, face_cond, x + s(10), cy + s(6), cw - s(20), s(18), "center")
            end
            Look.mark_for(self.profile, bb, st, x + cw - s(16), cy + card_h - s(44), s(9))
            ctx:hit(x, cy, cw, card_h, function()
                if n.s ~= self.species then
                    self:open_species(n.s)
                end
            end)
        end
        y = y + math.ceil(#nodes / 3) * (card_h + row_gap) - row_gap + (si < #stages and gap or 0)
        if si < #stages then
            Draw.icon(bb, "chevron_down", W / 2, y - gap / 2, s(18), Draw.DARK)
        end
    end
    -- How this one evolves, written out in full.
    local by = area_bottom + s(14)
    local own
    for _, n in ipairs(self.detail.evo or {}) do
        if n.s == self.species then
            own = n
        end
    end
    local game_id = self:record_game()
    local entries = {}
    local members = {}
    for _, n in ipairs(self.detail.evo or {}) do
        members[n.s] = true
    end
    for _, e in ipairs(app:entries(self.profile, game_id)) do
        if members[e.species] and not e.form then
            entries[#entries + 1] = e
        end
    end
    local caught = 0
    local state_of = app:state_fn(self.profile, game_id)
    for _, e in ipairs(entries) do
        if state_of(e.key) == "c" then
            caught = caught + 1
        end
    end
    Look.card(bb, s(16), by, W - s(32), s(70), self:in_game() and t.in_this_game or t.on_national)
    if own and own.from then
        local conds = app.text:conditions(own.c)
        local text = string.format(t.evolves_from, app.data:name(own.from, app.lang), table.concat(conds, t.or_word))
        Draw.text(bb, text, Draw.face("sans", s(12.5)), s(30), by + s(10), W - s(60), s(20), "left", Draw.DARK)
    end
    Draw.text(bb, string.format(t.line_progress, caught, #entries), Draw.face("bold", s(15)), s(30), by + s(32), W - s(60), s(24), "left")
    local bby = by + s(82)
    Look.button(bb, s(16), bby, W - s(32), s(48), t.mark_line, caught < #entries and "outline" or "disabled", s(15))
    if caught < #entries then
        ctx:hit(s(16), bby, W - s(32), s(48), function() app:mark_line(self.profile, game_id, self.species) end)
    end
end

function Card:open_species(species)
    for i, e in ipairs(self.list) do
        if e.species == species and not e.form then
            self.index = i
            self:load()
            self.app:redraw()
            return
        end
    end
    -- Not in this list (another game's Pokédex): open it from the national view of the profile.
    local list = self.app:entries(self.profile, Games.HOME)
    for i, e in ipairs(list) do
        if e.species == species and not e.form then
            self.app:show("card", { profile = self.profile, game = Games.HOME, list = list, index = i, tab = 3 })
            return
        end
    end
end

---------------------------------------------------------------------------
-- 4. Forms.
---------------------------------------------------------------------------

function Card:page_forms(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local y = top + s(10)
    Draw.text(bb, t.forms_title, Draw.face("serif", s(19)), s(20), y, W - s(40), s(28), "left")
    local hint = self.profile.forms and t.forms_counted or t.forms_not_counted
    Draw.text(bb, hint, Draw.face("sans", s(12.5)), s(20), y + s(26), W - s(40), s(20), "left", Draw.DARK)
    y = y + s(58)
    local forms = { { key = nil, name = app.data:name(self.species, app.lang), kind = t.default_form } }
    for _, f in ipairs(app.data:species_forms(self.species)) do
        forms[#forms + 1] = { key = f[1], form = f, name = app.data:form_name(f, app.lang), battle = f[3] == 1 }
    end
    local row_h = s(160)
    local per = math.max(1, math.floor((bottom - y - s(50)) / (row_h + s(12))))
    local pages = math.max(1, math.ceil(#forms / per))
    self.sub_page = math.min(self.sub_page, pages)
    Draw.text(bb, Look.upper(t.sprites_normal), Draw.face("bold", s(11)), s(264), y - s(20), s(132), s(16), "center", Draw.DARK)
    Draw.text(bb, Look.upper(t.sprites_shiny), Draw.face("bold", s(11)), s(414), y - s(20), s(132), s(16), "center", Draw.DARK)
    local caps = app:caps(self.profile)
    local first = (self.sub_page - 1) * per + 1
    for i = first, math.min(#forms, first + per - 1) do
        local f = forms[i]
        Look.card(bb, s(16), y, W - s(32), row_h)
        Draw.text(bb, f.name, Draw.face("bold", s(16)), s(32), y + s(16), s(220), s(24), "left")
        local kind = f.kind or (f.battle and t.battle_only or t.other_form)
        Draw.text(bb, kind, Draw.face("sans", s(13)), s(32), y + s(42), s(220), s(20), "left", Draw.DARK)
        local entry = { species = self.species, key = f.key and (self.species .. ":" .. f.key) or tostring(self.species), form = f.key }
        local in_game = self:in_game()
        local absent = in_game and f.key and not app.data:game_has_form(self.game, self.species, f.key)
        local countable = f.key and self.profile.forms and not f.battle and not absent
        local st
        if countable then
            if in_game then
                st = caps:state(self.game, entry.key)
            else
                st = (caps:national_state(self.profile, entry.key))
            end
        elseif not f.key then
            st = self:node_state(self.species)
        end
        for col, shiny in ipairs({ false, true }) do
            local cx = s(330) + (col - 1) * s(150)
            Draw.rect(bb, cx - s(66), y + s(12), s(132), row_h - s(24), Draw.PAPER, s(6))
            local mode = (st == "c" or not countable) and "color" or "silhouette"
            if not f.key then
                mode = "color"
            end
            local stem = Dex.sprite_stem(app.data, entry)
            local path, really = app.sprites:resolve(stem, false, shiny, "base")
            if (shiny and not really) or not SpriteCache.paint(bb, path, cx, y + row_h / 2, s(120), row_h - s(36), mode) then
                Look.placeholder(bb, cx, y + row_h / 2, s(120), row_h - s(36))
            end
            if shiny then
                Draw.icon(bb, "sparkle", cx - s(50), y + s(28), s(14), Draw.DARK)
            end
        end
        if countable then
            if st then
                Look.state_mark(bb, st, s(40), y + row_h - s(30), s(11))
                Draw.text(bb, t.statuses_short[st], Draw.face("sans", s(12)), s(58), y + row_h - s(40), s(190), s(20), "left", Draw.DARK)
            else
                Look.empty_mark(bb, s(40), y + row_h - s(30), s(11))
                Draw.text(bb, t.tap_to_mark, Draw.face("sans", s(12)), s(58), y + row_h - s(40), s(190), s(20), "left", Draw.MID)
            end
            ctx:hit(s(16), y, W - s(32), row_h, function()
                app:toggle(self.profile, in_game and self.game or Games.HOME, entry)
            end)
        elseif absent and not f.battle then
            Draw.text(bb, t.not_in_game, Draw.face("sans_italic", s(11.5)), s(32), y + row_h - s(40), s(220), s(20), "left", Draw.MID)
        elseif f.key and f.battle then
            Draw.text(bb, t.not_counted_battle, Draw.face("sans_italic", s(11.5)), s(32), y + row_h - s(40), s(220), s(20), "left", Draw.MID)
        end
        y = y + row_h + s(12)
    end
    if pages > 1 then
        local py = bottom - s(44)
        Draw.text(bb, string.format(t.page_of, self.sub_page, pages), Draw.face("sans", s(13)), 0, py, W, s(36), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(40), py + s(18), s(22), self.sub_page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(40), py + s(18), s(22), self.sub_page < pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(0, py - s(6), s(140), s(48), function()
            if self.sub_page > 1 then
                self.sub_page = self.sub_page - 1
                app:redraw()
            end
        end)
        ctx:hit(W - s(140), py - s(6), s(140), s(48), function()
            if self.sub_page < pages then
                self.sub_page = self.sub_page + 1
                app:redraw()
            end
        end)
    end
end

---------------------------------------------------------------------------
-- 5. In the game: where to find it and its level-up moves.
---------------------------------------------------------------------------

function Card:moves_for(game)
    local moves = self.detail.moves or {}
    if moves[game.vg] then
        return moves[game.vg], game, false
    end
    local base = game.dlc_of and Games.get(game.dlc_of)
    if base and moves[base.vg] then
        return moves[base.vg], base, false
    end
    -- The newest data of a game before this one.
    for i = game.index - 1, 1, -1 do
        local g = Games.LIST[i]
        if moves[g.vg] then
            return moves[g.vg], g, true
        end
    end
    return nil
end

function Card:page_in_game(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local game = self:page_game()
    local y = top + s(10)
    if not self:in_game() then
        local label = Games.name(game, app.lang)
        Draw.text(bb, t.game_label, Draw.face("bold", s(12)), s(20), y, s(80), s(32), "left", Draw.DARK)
        local px = Look.pill(bb, s(80), y + s(3), label .. "     ", "outline", s(13), s(26), s(12))
        Draw.icon(bb, "chevron_down", px - s(18), y + s(16), s(12))
        ctx:hit(s(76), y, px - s(70), s(34), function()
            local items = {}
            for _, id in ipairs(self.profile.games) do
                local g = Games.get(id)
                items[#items + 1] = { text = Games.name(g, app.lang), callback = function()
                    self.move_game = id
                    app:redraw()
                end }
            end
            app:menu(t.game_label, items)
        end)
        y = y + s(44)
    end
    y = y + s(14)
    -- Encounters of the game's versions, merged by place and method.
    local places, order = {}, {}
    for vi, version in ipairs(game.versions) do
        local flat = (self.detail.enc or {})[version]
        if flat then
            for i = 1, #flat, 5 do
                local key = flat[i] .. ":" .. flat[i + 1]
                local p = places[key]
                if not p then
                    p = { area = flat[i], method = flat[i + 1], lo = flat[i + 2], hi = flat[i + 3], chance = flat[i + 4], versions = {} }
                    places[key] = p
                    order[#order + 1] = p
                else
                    p.lo = math.min(p.lo, flat[i + 2])
                    p.hi = math.max(p.hi, flat[i + 3])
                    p.chance = math.max(p.chance or 0, flat[i + 4] or 0)
                end
                p.versions[vi] = true
            end
        end
    end
    local enc_lines = math.min(#order, 4)
    local enc_h = #order == 0 and s(66) or (s(24) + enc_lines * s(26) + (#order > enc_lines and s(22) or 0))
    Look.card(bb, s(16), y, W - s(32), enc_h, string.format(t.where_in, Games.name(game, app.lang)))
    local ey = y + s(14)
    if #order == 0 then
        Draw.text(bb, t.no_encounters, Draw.face("sans", s(13)), s(32), ey, W - s(64), s(40), "left", Draw.DARK)
    else
        for i = 1, enc_lines do
            local p = order[i]
            local level = p.lo == p.hi and string.format(t.level_short, p.lo) or string.format(t.levels_short, p.lo, p.hi)
            local only = ""
            if #game.versions > 1 and not (p.versions[1] and p.versions[2]) then
                local version_names = Games.name(game, app.lang)
                local which = p.versions[1] and 1 or 2
                local parts = {}
                for part in version_names:gmatch("[^/]+") do
                    parts[#parts + 1] = part:match("^%s*(.-)%s*$")
                end
                if parts[which] then
                    only = " · " .. string.format(t.only_in, parts[which])
                end
            end
            -- Gifts and fixed encounters always happen: a chance there says nothing.
            local fixed = p.method == 18 or p.method == 19 or p.method == 20
            local chance = (not fixed and p.chance and p.chance > 0) and (" · " .. p.chance .. "%") or ""
            Draw.text(bb, app.text:area(p.area), Draw.face("bold", s(14)), s(32), ey, s(270), s(24), "left")
            Draw.text(bb, app.text:method(p.method) .. " · " .. level .. chance .. only, Draw.face("sans", s(12)), s(270), ey, W - s(302), s(24), "right", Draw.DARK)
            ey = ey + s(26)
        end
        if #order > enc_lines then
            Draw.text(bb, string.format(t.more_places, #order - enc_lines), Draw.face("sans_italic", s(12)), s(32), ey, W - s(64), s(20), "left", Draw.MID)
        end
    end
    y = y + enc_h + s(26)
    local moves, source, older = self:moves_for(game)
    local title = string.format(t.moves_in, Games.name(source or game, app.lang))
    local mh = bottom - y - s(10)
    Look.card(bb, s(16), y, W - s(32), mh, title)
    if not moves then
        Draw.text(bb, t.no_moves, Draw.face("sans", s(13)), s(32), y + s(18), W - s(64), s(24), "left", Draw.DARK)
        return
    end
    local my = y + s(14)
    if older then
        Draw.text(bb, t.moves_older, Draw.face("sans_italic", s(11.5)), s(32), my, W - s(64), s(18), "left", Draw.MID)
        my = my + s(20)
    end
    Look.label(bb, s(32), my, s(60), t.level_col)
    Look.label(bb, s(100), my, s(200), t.move_col)
    Draw.text(bb, Look.upper(t.type_col), Draw.face("bold", s(10.5)), W - s(132), my, s(100), s(16), "right", Draw.DARK)
    my = my + s(20)
    local row = s(34)
    local per = math.max(1, math.floor((y + mh - my - s(36)) / row))
    local count = #moves / 2
    local pages = math.max(1, math.ceil(count / per))
    self.sub_page = math.min(self.sub_page, pages)
    local first = (self.sub_page - 1) * per
    local data_moves = app.data:moves()
    for i = 1, per do
        local k = first + i
        if k > count then
            break
        end
        local lv, mid = moves[k * 2 - 1], moves[k * 2]
        Draw.hline(bb, s(30), my, W - s(60), 1, Draw.PALE)
        Draw.text(bb, lv == 0 and t.evolve_level or tostring(lv), Draw.face("serif", s(15)), s(30), my, s(50), row, "center")
        Draw.text(bb, app.text:move(mid), Draw.face("sans", s(15)), s(100), my, W - s(240), row, "left")
        local mt = data_moves[mid] and data_moves[mid][3]
        if mt and mt > 0 then
            Look.type_pill(bb, W - s(32), my + s(6), mt, app.text:type_name(mt), "filled", s(11.5), s(22), s(9), "right")
        end
        my = my + row
    end
    if pages > 1 then
        local py = y + mh - s(36)
        Draw.text(bb, string.format(t.page_of, self.sub_page, pages), Draw.face("sans", s(12)), s(16), py, W - s(32), s(30), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(50), py + s(15), s(18), self.sub_page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(50), py + s(15), s(18), self.sub_page < pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(s(16), py - s(6), s(140), s(40), function()
            if self.sub_page > 1 then
                self.sub_page = self.sub_page - 1
                app:redraw()
            end
        end)
        ctx:hit(W - s(156), py - s(6), s(140), s(40), function()
            if self.sub_page < pages then
                self.sub_page = self.sub_page + 1
                app:redraw()
            end
        end)
    end
end

---------------------------------------------------------------------------
-- 6. In the profile: which games already have it.
---------------------------------------------------------------------------

function Card:page_profile(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local caps = app:caps(self.profile)
    -- The entry's own key: a form or a gender shows its own marks, not the species'.
    local key = self.entry.key
    local form = self.entry.form
    local rows = {}
    local caught_games, present = 0, 0
    for _, id in ipairs(self.profile.games) do
        local g = Games.get(id)
        local number
        for _, e in ipairs(Games.dex_entries(g, app.data.dex)) do
            if e.species == self.species then
                number = e.number
                break
            end
        end
        local form_absent = false
        if number and form and not app.data:game_has_form(id, self.species, form) then
            number, form_absent = nil, true
        end
        local st = number and caps:state(id, key)
        local r = caps:record(id, key)
        if number then
            present = present + 1
            if st == "c" then
                caught_games = caught_games + 1
            end
        end
        rows[#rows + 1] = { game = g, number = number, state = st, time = r and r.t, form_absent = form_absent }
    end
    local home = caps:state(Games.HOME, key)
    local hr = caps:record(Games.HOME, key)
    rows[#rows + 1] = { home = true, state = home, time = hr and hr.t }
    local y = top + s(16)
    Draw.rect(bb, s(16), y, W - s(32), s(80), Draw.INK, s(8))
    Draw.rect(bb, s(26), y + s(8), s(76), s(64), Draw.PAPER, s(6))
    self:sprite(bb, self.entry, s(64), y + s(40), s(70), s(58), "color")
    Draw.text(bb, string.format(t.caught_in_n, caught_games), Draw.face("serif", s(19)), s(110), y + s(12), W - s(140), s(28), "left", Draw.WHITE)
    Draw.text(bb, string.format(t.of_present, present), Draw.face("sans", s(13)), s(110), y + s(42), W - s(140), s(20), "left", Draw.PALE)
    y = y + s(96)
    local row_h = s(56)
    local per = math.max(1, math.floor((bottom - y - s(44)) / row_h))
    local pages = math.max(1, math.ceil(#rows / per))
    self.sub_page = math.min(self.sub_page, pages)
    local first = (self.sub_page - 1) * per + 1
    for i = first, math.min(#rows, first + per - 1) do
        local r = rows[i]
        local out = not r.home and not r.number
        local name = r.home and t.home_label or Games.name(r.game, app.lang)
        local sub
        if r.home then
            sub = t.home_hint
        elseif r.number then
            sub = string.format("%s #%03d", r.game.region, r.number)
        else
            sub = r.form_absent and t.not_in_game or string.format(t.not_in_dex, r.game.region)
        end
        Draw.hline(bb, s(16), y + row_h - 1, W - s(32), 1, Draw.PALE)
        Draw.text(bb, name, Draw.face("bold", s(15)), s(30), y + s(6), W - s(200), s(24), "left", out and Draw.MID or Draw.BLACK)
        Draw.text(bb, sub, Draw.face("sans", s(12.5)), s(30), y + s(30), W - s(200), s(20), "left", out and Draw.MID or Draw.DARK)
        if r.state == "c" and r.time then
            Draw.text(bb, app.text:date_short(r.time), Draw.face("sans", s(13)), W - s(180), y, s(120), row_h, "right", Draw.DARK)
        end
        if r.state then
            Look.mark_for(self.profile, bb, r.state, W - s(36), y + row_h / 2, s(13))
        elseif not out then
            Look.empty_mark(bb, W - s(36), y + row_h / 2, s(13))
        end
        y = y + row_h
    end
    if pages > 1 then
        local py = bottom - s(42)
        Draw.text(bb, string.format(t.page_of, self.sub_page, pages), Draw.face("sans", s(13)), 0, py, W, s(36), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(40), py + s(18), s(22), self.sub_page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(40), py + s(18), s(22), self.sub_page < pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(0, py - s(6), s(140), s(48), function()
            if self.sub_page > 1 then
                self.sub_page = self.sub_page - 1
                app:redraw()
            end
        end)
        ctx:hit(W - s(140), py - s(6), s(140), s(48), function()
            if self.sub_page < pages then
                self.sub_page = self.sub_page + 1
                app:redraw()
            end
        end)
    end
end

---------------------------------------------------------------------------
-- 7. Types.
---------------------------------------------------------------------------

local STYLE = { [400] = "filled", [200] = "filled", [50] = "outline", [25] = "outline", [0] = "light" }
local FACTOR = { [400] = "×4", [200] = "×2", [50] = "×½", [25] = "×¼", [0] = "×0" }

-- What the Pokémon takes from each type and what the moves of its types do, in the chart of the card's game (the
-- newest from the national view), with the types it had in that game.
function Card:page_types(ctx, top, bottom)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local charts = app:type_charts()
    local index = charts:chart_index(app:game_gen(self.game))
    local chart = charts:chart(index)
    local types = app:entry_types(self.entry, self.game)
    local place = self:in_game() and Games.name(Games.get(self.game), app.lang) or t.national
    local y = top + s(14)
    Draw.text(bb, string.format(t.types_chart_of, place, app.text:type_chart_gens(chart, charts.last_gen)), Draw.face("sans", s(13)), s(20), y, W - s(40), s(18), "left", Draw.DARK)
    y = y + s(30)
    local inner_w = W - s(32) - s(96)
    local groups = charts:defense(index, types)
    local height = s(50)
    for _, g in ipairs(groups) do
        height = height + Look.type_pill_lines(g.types, app.text, inner_w) * s(30)
    end
    Look.card(bb, s(16), y, W - s(32), height, t.types_defense)
    local yy = y + s(20)
    for _, g in ipairs(groups) do
        Draw.text(bb, FACTOR[g.factor], Draw.face("bold", s(17)), s(32), yy, s(60), s(22), "left")
        yy = Look.type_pill_rows(bb, g.types, app.text, STYLE[g.factor], s(32) + s(64), yy, inner_w, s(30))
    end
    Draw.text(bb, t.types_neutral, Draw.face("sans", s(12.5)), s(32), yy + s(2), W - s(64), s(18), "left", Draw.DARK)
    y = y + height + s(22)
    local labels = { [200] = t.types_super, [50] = t.types_weak, [0] = t.types_none }
    local blocks, off_h = {}, s(20)
    for _, ty in ipairs(types) do
        local o = charts:offense(index, ty)
        blocks[#blocks + 1] = { type = ty, groups = o }
        off_h = off_h + s(40)
        for _, g in ipairs(o) do
            off_h = off_h + s(18) + Look.type_pill_lines(g.types, app.text, W - s(64)) * s(28)
        end
    end
    Look.card(bb, s(16), y, W - s(32), off_h, t.types_offense)
    local oy = y + s(18)
    for _, b in ipairs(blocks) do
        Look.type_pills(bb, s(32), oy, { b.type }, app.text, s(13), s(24))
        oy = oy + s(34)
        for _, g in ipairs(b.groups) do
            Look.label(bb, s(32), oy, W - s(64), labels[g.factor])
            oy = Look.type_pill_rows(bb, g.types, app.text, STYLE[g.factor], s(32), oy + s(18), W - s(64), s(28))
        end
        oy = oy + s(6)
    end
    y = y + off_h + s(16)
    local note = index < #charts.charts and t.types_notes[index]
    if note then
        y = y + Draw.paragraph(bb, note, Draw.face("sans", s(12.5)), s(20), y, W - s(40), s(17), Draw.DARK) + s(10)
    end
    local bh = s(44)
    local by = math.max(y, bottom - bh - s(14))
    Look.button(bb, s(16), by, W - s(32), bh, t.types_full_chart, "outline")
    ctx:hit(s(16), by, W - s(32), bh, function()
        app:show("type_chart", { gen = app:game_gen(self.game) })
    end)
end

local PAGES = { "page_overview", "page_stats", "page_evolution", "page_forms", "page_in_game", "page_profile", "page_types" }

function Card:draw(ctx)
    local app, t = self.app, self.app.t
    self:header(ctx)
    local tabs_y = ctx.h - Draw.s(Look.TABS_H)
    self[PAGES[self.tab]](self, ctx, Draw.s(Look.HEADER_H), tabs_y)
    Look.tabs(ctx, t.card_tabs, self.tab, function(i)
        if i ~= self.tab then
            self.tab = i
            self.sub_page = 1
            app.notice = nil
            app:redraw()
        end
    end)
    app:draw_toast(ctx, tabs_y - Draw.s(4))
end

return Card
