-- The type chart: attack in rows, defense in columns, in the chart of a generation. A tap on a type highlights its
-- row and column and offers its summary.
local Draw = require("catchink/ui/draw")
local Look = require("catchink/ui/look")

local s = Draw.s
local Chart = {}
Chart.__index = Chart

-- args: gen (the generation whose chart opens first; nil is the newest).
function Chart.new(app, args)
    local charts = app:type_charts()
    return setmetatable({ app = app, index = charts:chart_index(args.gen) }, Chart)
end

function Chart:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local charts = app:type_charts()
    local y = Look.header(ctx, t.types_chart, { back = function() app:back() end, sub = t.types_chart_sub })
    y = y + s(12)
    local labels = {}
    for i, chart in ipairs(charts.charts) do
        labels[i] = app.text:type_chart_gens(chart, charts.last_gen, true)
    end
    Look.segmented(ctx, s(16), y, W - s(32), labels, self.index, function(i)
        if i ~= self.index then
            self.index = i
            local list = charts:list(i)
            local found = false
            for _, id in ipairs(list) do
                found = found or id == self.selected
            end
            if not found then
                self.selected = nil
            end
            app:redraw()
        end
    end, s(34))
    y = y + s(48)
    local list = charts:list(self.index)
    local label_w = s(44)
    local cell = math.floor((W - s(16) - label_w) / #list)
    local x0 = math.floor((W - label_w - cell * #list) / 2) + label_w
    local value_face = Draw.face("bold", s(13))
    local sel
    for i, id in ipairs(list) do
        if id == self.selected then
            sel = i
        end
    end
    local function select(id)
        self.selected = self.selected ~= id and id or nil
        app:redraw()
    end
    for j, id in ipairs(list) do
        if sel == j then
            Draw.rect(bb, x0 + (j - 1) * cell, y, cell, cell, Draw.PALE, s(3))
        end
        Look.type_disc(bb, id, x0 + (j - 0.5) * cell, y + cell / 2, cell - s(5))
        ctx:hit(x0 + (j - 1) * cell, y, cell, cell, function() select(id) end)
    end
    y = y + cell + s(2)
    for i, a in ipairs(list) do
        local ry = y + (i - 1) * cell
        if sel == i then
            Draw.rect(bb, x0 - label_w, ry, label_w - s(2), cell, Draw.PALE, s(3))
        end
        Look.type_disc(bb, a, x0 - label_w / 2, ry + cell / 2, cell - s(5))
        ctx:hit(x0 - label_w, ry, label_w, cell, function() select(a) end)
        for j, d in ipairs(list) do
            local cx = x0 + (j - 1) * cell
            local m = charts:factor(self.index, a, d)
            local in_line = sel and (sel == i or sel == j)
            local fill = m == 200 and Draw.INK or (m == 50 and Draw.PALE or (m == 0 and Draw.MID or (in_line and Draw.PAPER or Draw.WHITE)))
            Draw.rect(bb, cx + s(1), ry + s(1), cell - s(2), cell - s(2), fill, s(2))
            local text = m == 200 and "2" or (m == 50 and "½" or (m == 0 and "0" or ""))
            if text ~= "" then
                Draw.text(bb, text, value_face, cx, ry, cell, cell, "center", m == 200 and Draw.WHITE or Draw.BLACK)
            end
        end
        ctx:hit(x0, ry, cell * #list, cell, function() select(a) end)
    end
    if sel then
        local thick = math.max(2, s(2.4))
        Draw.border(bb, x0, y + (sel - 1) * cell, cell * #list, cell, thick, Draw.BLACK, s(2))
        Draw.border(bb, x0 + (sel - 1) * cell, y, cell, cell * #list, thick, Draw.BLACK, s(2))
    end
    y = y + cell * #list + s(10)
    local lx = s(16)
    local legend = { { "2", Draw.INK, Draw.WHITE }, { "½", Draw.PALE, Draw.BLACK }, { "0", Draw.MID, Draw.BLACK } }
    for k, item in ipairs(legend) do
        Draw.rect(bb, lx, y, s(20), s(20), item[2], s(3))
        Draw.text(bb, item[1], Draw.face("bold", s(12)), lx, y, s(20), s(20), "center", item[3])
        local tw = Draw.text(bb, t.types_legend[k], Draw.face("sans", s(12.5)), lx + s(26), y, s(170), s(20), "left")
        lx = lx + s(26) + tw + s(22)
    end
    y = y + s(30)
    if sel then
        local bh = s(44)
        local by = math.max(y, H - bh - s(14))
        Look.button(bb, s(16), by, W - s(32), bh, string.format(t.types_summary_of, app.text:type_name(self.selected)), "primary")
        ctx:hit(s(16), by, W - s(32), bh, function()
            app:show("type_summary", { index = self.index, type = self.selected })
        end)
    else
        Draw.text(bb, t.types_hint, Draw.face("sans", s(12.5)), s(16), y, W - s(32), s(18), "left", Draw.DARK)
    end
end

return Chart
