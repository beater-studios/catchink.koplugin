-- Which games a profile follows: a checklist by generation, with all and none.
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")

local s = Draw.s
local Pick = {}
Pick.__index = Pick

local ROW_H = 40

function Pick.new(app, args)
    local self = setmetatable({ app = app, values = args.values, page = 1 }, Pick)
    self.selected = {}
    for _, id in ipairs(args.values.games) do
        self.selected[id] = true
    end
    return self
end

function Pick:commit()
    local list = {}
    for _, g in ipairs(Games.LIST) do
        if self.selected[g.id] then
            list[#list + 1] = g.id
        end
    end
    if table.concat(list, ",") ~= table.concat(self.values.games, ",") then
        self.values.model = "custom"
    end
    self.values.games = list
end

function Pick:rows_per_page(H)
    return math.floor((H - s(Look.HEADER_H) - s(140)) / s(ROW_H))
end

function Pick:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    Look.header(ctx, t.games, { back = function()
        self:commit()
        app:back()
    end })
    local y = s(Look.HEADER_H) + s(12)
    local half = (W - s(40)) / 2
    Look.button(bb, s(16), y, half, s(36), t.select_all, "outline", s(13))
    ctx:hit(s(16), y, half, s(36), function()
        for _, g in ipairs(Games.LIST) do
            self.selected[g.id] = true
        end
        app:redraw()
    end)
    Look.button(bb, s(24) + half, y, half, s(36), t.select_none, "outline", s(13))
    ctx:hit(s(24) + half, y, half, s(36), function()
        self.selected = {}
        app:redraw()
    end)
    y = y + s(48)
    local per = self:rows_per_page(H)
    self.pages = math.max(1, math.ceil(#Games.LIST / per))
    self.page = math.min(self.page, self.pages)
    local first = (self.page - 1) * per + 1
    for i = first, math.min(#Games.LIST, first + per - 1) do
        local g = Games.LIST[i]
        local on = self.selected[g.id]
        local indent = g.dlc_of and s(24) or 0
        Draw.rect(bb, s(20) + indent, y + s(8), s(24), s(24), Draw.BLACK, s(5))
        Draw.rect(bb, s(21.8) + indent, y + s(9.8), s(20.4), s(20.4), on and Draw.INK or Draw.WHITE, s(4))
        if on then
            Draw.icon(bb, "check", s(32) + indent, y + s(20), s(18), Draw.WHITE)
        end
        Draw.text(bb, Games.name(g, app.lang), Draw.face(on and "bold" or "sans", s(15)), s(56) + indent, y, W - s(140) - indent, s(ROW_H), "left")
        Draw.text(bb, string.format(t.gen_short, g.gen), Draw.face("sans", s(12)), W - s(90), y, s(72), s(ROW_H), "right", Draw.DARK)
        ctx:hit(0, y, W, s(ROW_H), function()
            self.selected[g.id] = not self.selected[g.id] or nil
            app:redraw()
        end)
        y = y + s(ROW_H)
    end
    if self.pages > 1 then
        local py = H - s(70)
        Draw.text(bb, string.format(t.page_of, self.page, self.pages), Draw.face("sans", s(13)), 0, py, W, s(40), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(40), py + s(20), s(24), self.page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(40), py + s(20), s(24), self.page < self.pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(0, py - s(10), s(140), s(60), function() self:swipe("east") end)
        ctx:hit(W - s(140), py - s(10), s(140), s(60), function() self:swipe("west") end)
    end
end

function Pick:swipe(direction)
    if direction == "west" and self.page < (self.pages or 1) then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.app:redraw()
end

return Pick
