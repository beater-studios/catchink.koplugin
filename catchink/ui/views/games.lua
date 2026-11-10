-- The games of a profile, by generation, with the national view on top.
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")

local s = Draw.s
local GamesView = {}
GamesView.__index = GamesView

local ROW_H = 48
local HEAD_H = 26

function GamesView.new(app, args)
    return setmetatable({ app = app, profile = args.profile, page = 1 }, GamesView)
end

-- Rows: generation headings and games, split into pages that fit the screen.
function GamesView:layout(avail)
    local rows = {}
    local last_gen
    for _, id in ipairs(self.profile.games) do
        local g = Games.get(id)
        if g.gen ~= last_gen then
            rows[#rows + 1] = { heading = g.gen }
            last_gen = g.gen
        end
        rows[#rows + 1] = { game = g }
    end
    local pages, page, used = {}, {}, 0
    for _, r in ipairs(rows) do
        local h = r.heading and s(HEAD_H) or s(ROW_H)
        if used + h > avail and #page > 0 then
            if page[#page].heading then
                local heading = table.remove(page)
                pages[#pages + 1] = page
                page, used = { heading }, s(HEAD_H)
            else
                pages[#pages + 1] = page
                page, used = {}, 0
            end
        end
        page[#page + 1] = r
        used = used + h
    end
    if #page > 0 then
        pages[#pages + 1] = page
    end
    return pages
end

function GamesView:open_menu()
    local app, t, p = self.app, self.app.t, self.profile
    app:menu(p.name, {
        { text = t.progress, callback = function() app:show("progress", { profile = p }) end },
        { text = t.edit_profile, callback = function() app:show("profile_form", { profile = p }) end },
        { text = t.sprites, callback = function() app:show("sprites") end },
    })
end

function GamesView:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local p = self.profile
    local sub = string.format(t.profile_sub, t.models[p.model] or p.model, #p.games)
    Look.header(ctx, p.name, { back = function() app:back() end, sub = sub, right = {
        { icon = "chart", tap = function() app:show("progress", { profile = p }) end },
        { icon = "dots", tap = function() self:open_menu() end },
    } })
    local y = s(Look.HEADER_H) + s(18)
    local x, w = s(16), W - s(32)
    Look.card(bb, x, y, w, s(86))
    Draw.rect(bb, x + s(10), y + s(10), s(80), s(66), Draw.INK, s(6))
    local nat = app:progress(p, Games.HOME)
    Draw.text(bb, tostring(#app:entries(p, Games.HOME)), Draw.face("serif", s(19)), x + s(10), y + s(16), s(80), s(28), "center", Draw.WHITE)
    Draw.text(bb, p.forms and t.entries_word or t.species_word, Draw.face("sans", s(11)), x + s(10), y + s(46), s(80), s(18), "center", Draw.PALE)
    Draw.text(bb, t.national_dex, Draw.face("serif", s(18)), x + s(106), y + s(12), w - s(190), s(26), "left")
    Draw.text(bb, t.national_hint, Draw.face("sans", s(12.5)), x + s(106), y + s(38), w - s(120), s(20), "left", Draw.DARK)
    Draw.text(bb, tostring(nat.caught), Draw.face("bold", s(18)), x + w - s(90), y + s(12), s(76), s(26), "right")
    Look.progress(bb, x + s(106), y + s(64), w - s(120), nat.total > 0 and nat.caught / nat.total or 0, s(10))
    ctx:hit(x, y, w, s(86), function() app:show("browse", { profile = p, game = Games.HOME }) end)
    y = y + s(104)
    local avail = H - y - s(56)
    local pages = self:layout(avail)
    self.pages = #pages
    self.page = math.max(1, math.min(self.page, #pages))
    for _, r in ipairs(pages[self.page] or {}) do
        if r.heading then
            Look.section(bb, s(20), y + s(12), W - s(36), string.format(t.generation, r.heading))
            y = y + s(HEAD_H)
        else
            local g = r.game
            local indent = g.dlc_of and s(18) or 0
            local last = p.last_game == g.id
            local pr = app:progress(p, g.id)
            if last then
                Draw.rect(bb, s(16) + indent, y + s(2), W - s(32) - indent, s(ROW_H - 4), Draw.BLACK, s(6))
                Draw.rect(bb, s(17.4) + indent, y + s(3.4), W - s(34.8) - indent, s(ROW_H - 6.8), Draw.PAPER, s(5))
            end
            local name = Games.name(g, app.lang)
            Draw.text(bb, name, Draw.face("bold", s(14.5)), s(28) + indent, y + s(5), s(330) - indent, s(22), "left", pr.caught > 0 and Draw.BLACK or Draw.DARK)
            local sub_text = g.region .. (last and (" · " .. t.last_opened) or "")
            Draw.text(bb, sub_text, Draw.face("sans", s(11.5)), s(28) + indent, y + s(26), s(330) - indent, s(18), "left", Draw.DARK)
            if pr.caught > 0 then
                Draw.text(bb, string.format("%d / %d", pr.caught, pr.total), Draw.face("bold", s(13)), W - s(170), y + s(5), s(140), s(20), "right")
                Look.progress(bb, s(380), y + s(29), W - s(410), pr.total > 0 and pr.caught / pr.total or 0, s(8))
            else
                Draw.text(bb, string.format("0 / %d", pr.total), Draw.face("sans", s(13)), W - s(170), y, s(140), s(ROW_H), "right", Draw.MID)
            end
            ctx:hit(0, y, W, s(ROW_H), function()
                p.last_game = g.id
                app:save_settings()
                app:show("browse", { profile = p, game = g.id })
            end)
            y = y + s(ROW_H)
        end
    end
    if self.pages > 1 then
        local py = H - s(50)
        Draw.text(bb, string.format(t.page_of, self.page, self.pages), Draw.face("sans", s(13)), 0, py, W, s(40), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(40), py + s(20), s(24), self.page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(40), py + s(20), s(24), self.page < self.pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(0, py - s(10), s(140), s(60), function() self:swipe("east") end)
        ctx:hit(W - s(140), py - s(10), s(140), s(60), function() self:swipe("west") end)
    end
    app:draw_toast(ctx, H - s(56))
end

function GamesView:swipe(direction)
    if direction == "west" and self.page < (self.pages or 1) then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.app:redraw()
end

return GamesView
