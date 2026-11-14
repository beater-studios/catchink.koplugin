-- The summary of a type in a chart: what its moves do and what it takes.
local Draw = require("catchink/ui/draw")
local Look = require("catchink/ui/look")

local s = Draw.s
local Summary = {}
Summary.__index = Summary

local STYLE = { [200] = "filled", [50] = "outline", [0] = "light" }

-- args: index (of the chart), type (its id).
function Summary.new(app, args)
    return setmetatable({ app = app, index = args.index, type = args.type }, Summary)
end

function Summary:draw(ctx)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    local charts = app:type_charts()
    local name = app.text:type_name(self.type)
    local sub = t.types_chart .. " · " .. app.text:type_chart_gens(charts:chart(self.index), charts.last_gen)
    local y = Look.header(ctx, name, { back = function() app:back() end, sub = sub })
    y = y + s(24)
    local blocks = {
        { string.format(t.types_attacks, name), charts:offense(self.index, self.type), { [200] = t.types_super, [50] = t.types_weak, [0] = t.types_none } },
        { string.format(t.types_defends, name), charts:defense(self.index, { self.type }), { [200] = t.types_weak_to, [50] = t.types_resists, [0] = t.types_immune } },
    }
    for _, block in ipairs(blocks) do
        local h = s(24)
        for _, g in ipairs(block[2]) do
            h = h + s(18) + s(30) * Look.type_pill_lines(g.types, app.text, W - s(64))
        end
        Look.card(bb, s(16), y, W - s(32), h, block[1])
        local yy = y + s(18)
        for _, g in ipairs(block[2]) do
            Look.label(bb, s(32), yy, W - s(64), block[3][g.factor])
            yy = Look.type_pill_rows(bb, g.types, app.text, STYLE[g.factor], s(32), yy + s(18), W - s(64), s(30))
        end
        y = y + h + s(22)
    end
end

return Summary
