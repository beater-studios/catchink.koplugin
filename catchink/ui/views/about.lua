-- About: version, the notice that this is an unofficial project, and the credits.
local Draw = require("catchink/ui/draw")
local Look = require("catchink/ui/look")

local s = Draw.s
local About = {}
About.__index = About

function About.new(app)
    return setmetatable({ app = app }, About)
end

function About:draw(ctx)
    local app, t, bb, W = self.app, self.app.t, ctx.bb, ctx.w
    Look.header(ctx, t.about, { back = function() app:back() end })
    local y = s(Look.HEADER_H) + s(28)
    Draw.rect(bb, W / 2 - s(46), y, s(92), s(92), Draw.INK, s(18))
    Draw.icon(bb, "logo", W / 2, y + s(46), s(70), Draw.WHITE)
    y = y + s(104)
    Draw.text(bb, t.name, Draw.face("serif", s(28)), 0, y, W, s(40), "center")
    Draw.text(bb, string.format(t.version_line, app.meta.version or "?"), Draw.face("sans", s(14)), 0, y + s(40), W, s(22), "center", Draw.DARK)
    y = y + s(84)
    local face = Draw.face("sans", s(14))
    local line_h = s(20)
    local lines = Draw.wrap(t.disclaimer, face, W - s(64))
    local h = #lines * line_h + s(30)
    Look.card(bb, s(16), y, W - s(32), h, t.notice)
    Draw.paragraph(bb, t.disclaimer, face, s(32), y + s(16), W - s(64), line_h)
    y = y + h + s(28)
    local credits = { t.credit_data, t.credit_sprites, t.credit_translation }
    local total = s(30)
    for _, c in ipairs(credits) do
        total = total + #Draw.wrap(c, face, W - s(64)) * line_h + s(8)
    end
    Look.card(bb, s(16), y, W - s(32), total, t.credits)
    local cy = y + s(16)
    for _, c in ipairs(credits) do
        cy = cy + Draw.paragraph(bb, c, face, s(32), cy, W - s(64), line_h) + s(8)
    end
    y = y + total + s(24)
    Draw.text(bb, app.meta.homepage and app.meta.homepage:gsub("^https://", "") or "", Draw.face("sans", s(13)), 0, y, W, s(22), "center", Draw.DARK)
end

return About
