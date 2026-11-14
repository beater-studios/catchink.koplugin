-- The look of CatchInk: header band, bottom bar, pills, cards, marks, bars, toggles and buttons.
-- Measures are designed for a 600 x 800 screen and scaled with Draw.s.
local Draw = require("catchink/ui/draw")
local Letters = require("catchink/letters")
local Types = require("catchink/types")

local s = Draw.s
local Look = {}

-- Upper case that also turns accented letters (Lua's own only knows ASCII).
function Look.upper(text)
    return Letters.upper(text)
end

Look.HEADER_H = 58
Look.NAV_H = 66
Look.TABS_H = 54

function Look.header(ctx, title, opts)
    opts = opts or {}
    local bb, W = ctx.bb, ctx.w
    local h = s(Look.HEADER_H)
    Draw.rect(bb, 0, 0, W, h, Draw.INK)
    local left = s(52)
    if opts.back then
        Draw.icon(bb, "chevron_left", s(26), h / 2, s(26), Draw.WHITE)
        ctx:hit(0, 0, s(52), h, opts.back)
    elseif opts.logo then
        Draw.icon(bb, "logo", s(28), h / 2, s(36), Draw.WHITE)
    elseif opts.close then
        Draw.icon(bb, "x", s(26), h / 2, s(20), Draw.WHITE)
        ctx:hit(0, 0, s(52), h, opts.close)
    else
        left = s(18)
    end
    local right_w = 0
    if opts.right then
        right_w = s(52) * #opts.right
        for i, item in ipairs(opts.right) do
            local cx = W - s(52) * (#opts.right - i) - s(26)
            Draw.icon(bb, item.icon, cx, h / 2, s(item.size or 24), Draw.WHITE)
            ctx:hit(cx - s(26), 0, s(52), h, item.tap)
        end
    end
    local tw = W - left - right_w - s(8)
    if opts.sub then
        Draw.text(bb, title, Draw.face("serif", s(21)), left, s(6), tw, s(30), "left", Draw.WHITE)
        Draw.text(bb, opts.sub, Draw.face("sans", s(12.5)), left, s(34), tw, s(18), "left", Draw.PALE)
    else
        Draw.text(bb, title, Draw.face("serif", s(21)), left, 0, tw, h, "left", Draw.WHITE)
    end
    return h
end

-- items: { { label, icon, tap, active } }
function Look.bottom_nav(ctx, items)
    local bb, W, H = ctx.bb, ctx.w, ctx.h
    local y0 = H - s(Look.NAV_H)
    Draw.rect(bb, 0, y0, W, H - y0, Draw.WHITE)
    Draw.hline(bb, 0, y0, W, s(2), Draw.BLACK)
    local cw = W / #items
    for i, it in ipairs(items) do
        local x = cw * (i - 1)
        local color = it.active and Draw.WHITE or Draw.BLACK
        if it.active then
            Draw.rect(bb, x + s(10), y0 + s(6), cw - s(20), H - y0 - s(12), Draw.INK, s(8))
        end
        Draw.icon(bb, it.icon, x + cw / 2, y0 + s(24), s(24), color)
        Draw.text(bb, it.label, Draw.face(it.active and "bold" or "sans", s(12.5)), x, y0 + s(39), cw, s(22), "center", color)
        ctx:hit(x, y0, cw, H - y0, it.tap)
    end
    return y0
end

function Look.tabs(ctx, labels, active, on_tap)
    local bb, W, H = ctx.bb, ctx.w, ctx.h
    local y0 = H - s(Look.TABS_H)
    Draw.rect(bb, 0, y0, W, H - y0, Draw.WHITE)
    Draw.hline(bb, 0, y0, W, s(2), Draw.BLACK)
    local tw = W / #labels
    for i, label in ipairs(labels) do
        local x = tw * (i - 1)
        local on = i == active
        if on then
            Draw.rect(bb, x + s(4), y0 + s(6), tw - s(8), H - y0 - s(12), Draw.INK, s(7))
        end
        Draw.text(bb, label, Draw.face(on and "bold" or "sans", s(12.5)), x + s(2), y0, tw - s(4), H - y0, "center", on and Draw.WHITE or Draw.BLACK)
        ctx:hit(x, y0, tw, H - y0, function() on_tap(i) end)
    end
    return y0
end

-- A rounded label. Returns its right edge. style: "filled" (dark), "outline" or "light".
function Look.pill(bb, x, y, text, style, px, h, pad, anchor)
    px, h, pad = px or s(12.5), h or s(22), pad or s(10)
    local face = Draw.face("bold", px)
    local w = Draw.text_width(text, face) + pad * 2
    if anchor == "right" then
        x = x - w
    end
    if style == "outline" then
        Draw.rect(bb, x, y, w, h, Draw.WHITE, h / 2)
        Draw.border(bb, x, y, w, h, math.max(1, s(1.5)), Draw.BLACK, h / 2)
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.BLACK)
    elseif style == "light" then
        Draw.rect(bb, x, y, w, h, Draw.PAPER, h / 2)
        Draw.border(bb, x, y, w, h, math.max(1, s(1.2)), Draw.MID, h / 2)
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.BLACK)
    else
        Draw.rect(bb, x, y, w, h, Draw.DARK, h / 2)
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.WHITE)
    end
    return x + w, x
end

function Look.pill_width(text, px, pad)
    return Draw.text_width(text, Draw.face("bold", px or s(12.5))) + (pad or s(10)) * 2
end

-- The icon of a type inside a label, a little larger than the letters.
local function type_icon_size(px)
    return math.floor(px * 1.2 + 0.5)
end

function Look.type_pill_width(text, px, pad)
    px = px or s(12.5)
    return Look.pill_width(text, px, pad) + type_icon_size(px) + s(4)
end

-- A label of a type: its icon before the text, in the color of the text. style as Look.pill. Returns its right edge.
function Look.type_pill(bb, x, y, type_id, text, style, px, h, pad, anchor)
    px, h, pad = px or s(12.5), h or s(22), pad or s(10)
    local size = type_icon_size(px)
    local w = Look.type_pill_width(text, px, pad)
    if anchor == "right" then
        x = x - w
    end
    local fg = Draw.WHITE
    if style == "outline" then
        Draw.rect(bb, x, y, w, h, Draw.WHITE, h / 2)
        Draw.border(bb, x, y, w, h, math.max(1, s(1.5)), Draw.BLACK, h / 2)
        fg = Draw.BLACK
    elseif style == "light" then
        Draw.rect(bb, x, y, w, h, Draw.PAPER, h / 2)
        Draw.border(bb, x, y, w, h, math.max(1, s(1.2)), Draw.MID, h / 2)
        fg = Draw.BLACK
    else
        Draw.rect(bb, x, y, w, h, Draw.DARK, h / 2)
    end
    Draw.icon(bb, Types.icon(type_id), x + pad - s(2) + size / 2, y + h / 2, size, fg)
    Draw.text(bb, text, Draw.face("bold", px), x + pad + size + s(2), y, w - pad * 2 - size - s(2), h, "left", fg)
    return x + w, x
end

-- The labels of a Pokémon's types, side by side. text: the Text of the screen, for the names.
function Look.type_pills(bb, x, y, types, text, px, h)
    for _, id in ipairs(types) do
        x = Look.type_pill(bb, x, y, id, text:type_name(id), "filled", px or s(12), h or s(20), s(8)) + s(5)
    end
    return x
end

-- Labels of types that wrap inside a width. Returns the y below them.
function Look.type_pill_rows(bb, types, text, style, x, y, w, line_h)
    local px, h, pad = s(12.5), s(22), s(9)
    local cx = x
    for _, id in ipairs(types) do
        local name = text:type_name(id)
        local pw = Look.type_pill_width(name, px, pad)
        if cx + pw > x + w and cx > x then
            cx, y = x, y + line_h
        end
        cx = Look.type_pill(bb, cx, y, id, name, style, px, h, pad) + s(6)
    end
    return y + line_h
end

-- How many lines type_pill_rows takes.
function Look.type_pill_lines(types, text, w)
    local n, cx = 1, 0
    for _, id in ipairs(types) do
        local pw = Look.type_pill_width(text:type_name(id), s(12.5), s(9)) + s(6)
        if cx + pw > w and cx > 0 then
            n, cx = n + 1, 0
        end
        cx = cx + pw
    end
    return n
end

-- A type as a dark disc with its white icon, as on the games' own labels.
function Look.type_disc(bb, type_id, cx, cy, d)
    Draw.circle(bb, cx, cy, d / 2, Draw.INK)
    Draw.icon(bb, Types.icon(type_id), cx, cy, math.floor(d * 0.62 + 0.5), Draw.WHITE)
end

function Look.progress(bb, x, y, w, frac, h, fill)
    h = h or s(10)
    Draw.rect(bb, x, y, w, h, Draw.WHITE, h / 2)
    Draw.border(bb, x, y, w, h, math.max(1, s(1.4)), Draw.BLACK, h / 2)
    frac = math.max(0, math.min(1, frac or 0))
    if frac > 0 then
        local inner = math.max(h - s(4), (w - s(4)) * frac)
        Draw.rect(bb, x + s(2), y + s(2), inner, h - s(4), fill or Draw.INK, (h - s(4)) / 2)
    end
end

function Look.stamp(bb, cx, cy, r)
    Draw.circle(bb, cx, cy, r, Draw.INK)
    Draw.icon(bb, "check", cx, cy + 1, r * 1.3, Draw.WHITE)
end

function Look.seen_mark(bb, cx, cy, r)
    Draw.circle(bb, cx, cy, r, Draw.WHITE)
    Draw.ring(bb, cx, cy, r, math.max(1, s(1.4)), Draw.BLACK)
    Draw.icon(bb, "eye", cx, cy, r * 1.35, Draw.BLACK)
end

function Look.unavailable_mark(bb, cx, cy, r)
    Draw.circle(bb, cx, cy, r, Draw.WHITE)
    Draw.ring(bb, cx, cy, r, math.max(1, s(1.4)), Draw.MID)
    Draw.icon(bb, "minus", cx, cy, r * 1.2, Draw.MID)
end

function Look.empty_mark(bb, cx, cy, r)
    Draw.ring(bb, cx, cy, r, math.max(1, s(1.6)), Draw.LIGHT)
end

-- The mark of an alpha profile: the Alpha symbol, solid on a dark circle once caught, faint while missing.
function Look.alpha_mark(bb, state, cx, cy, r)
    if state == "c" then
        Draw.circle(bb, cx, cy, r, Draw.INK)
        Draw.icon(bb, "alpha", cx, cy, r * 1.45, Draw.WHITE)
    elseif state == "s" then
        Look.seen_mark(bb, cx, cy, r)
    elseif state == "u" then
        Look.unavailable_mark(bb, cx, cy, r)
    else
        Draw.icon(bb, "alpha", cx, cy, r * 1.7, Draw.MID)
    end
end

-- The mark of an entry for a profile: the Alpha symbol in alpha profiles, the usual marks otherwise.
function Look.mark_for(profile, bb, state, cx, cy, r, empty)
    if profile and profile.model == "alpha" then
        return Look.alpha_mark(bb, state, cx, cy, r)
    end
    if state then
        Look.state_mark(bb, state, cx, cy, r)
    elseif empty then
        Look.empty_mark(bb, cx, cy, r)
    end
end

function Look.state_mark(bb, state, cx, cy, r)
    if state == "c" then
        Look.stamp(bb, cx, cy, r)
    elseif state == "s" then
        Look.seen_mark(bb, cx, cy, r)
    elseif state == "u" then
        Look.unavailable_mark(bb, cx, cy, r)
    end
end

-- A framed card with an optional title cut into the top border.
function Look.card(bb, x, y, w, h, title, fill)
    Draw.rect(bb, x, y, w, h, Draw.BLACK, s(8))
    Draw.rect(bb, x + s(1.6), y + s(1.6), w - s(3.2), h - s(3.2), fill or Draw.WHITE, s(7))
    if title then
        local face = Draw.face("bold", s(12))
        local text = Look.upper(title)
        local tw = Draw.text_width(text, face)
        Draw.rect(bb, x + s(10), y - s(9), tw + s(12), s(18), Draw.WHITE)
        Draw.text(bb, text, face, x + s(16), y - s(9), tw + s(4), s(18), "left", Draw.DARK)
    end
end

function Look.label(bb, x, y, w, text)
    Draw.text(bb, Look.upper(text), Draw.face("bold", s(10.5)), x, y, w, s(16), "left", Draw.DARK)
end

function Look.section(bb, x, y, w, text)
    local face = Draw.face("bold", s(11.5))
    local t = Look.upper(text)
    local tw = Draw.text_width(t, face)
    Draw.text(bb, t, face, x, y - s(9), w, s(18), "left", Draw.DARK)
    if tw + s(10) < w then
        Draw.hline(bb, x + tw + s(10), y, w - tw - s(10), math.max(1, s(1.2)), Draw.PALE)
    end
end

function Look.toggle(bb, x, y, on)
    local w, h = s(44), s(24)
    Draw.rect(bb, x, y, w, h, Draw.BLACK, h / 2)
    Draw.rect(bb, x + s(1.6), y + s(1.6), w - s(3.2), h - s(3.2), on and Draw.INK or Draw.WHITE, h / 2)
    Draw.circle(bb, x + (on and s(32) or s(12)), y + h / 2, s(8), on and Draw.WHITE or Draw.INK)
end

-- style: "primary", "outline" or "disabled".
function Look.button(bb, x, y, w, h, text, style, px)
    local face = Draw.face("bold", px or s(15))
    if style == "primary" then
        Draw.rect(bb, x, y, w, h, Draw.INK, s(8))
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.WHITE)
    elseif style == "disabled" then
        Draw.rect(bb, x, y, w, h, Draw.PALE, s(8))
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.MID)
    else
        Draw.rect(bb, x, y, w, h, Draw.BLACK, s(8))
        Draw.rect(bb, x + s(1.8), y + s(1.8), w - s(3.6), h - s(3.6), Draw.WHITE, s(7))
        Draw.text(bb, text, face, x, y, w, h, "center", Draw.BLACK)
    end
end

function Look.segmented(ctx, x, y, w, labels, active, on_tap, h, px)
    local bb = ctx.bb
    h = h or s(34)
    Draw.rect(bb, x, y, w, h, Draw.BLACK, s(8))
    Draw.rect(bb, x + s(1.6), y + s(1.6), w - s(3.2), h - s(3.2), Draw.WHITE, s(7))
    local seg = w / #labels
    for i, label in ipairs(labels) do
        local sx = x + seg * (i - 1)
        local on = i == active
        if on then
            Draw.rect(bb, sx + s(3), y + s(3), seg - s(6), h - s(6), Draw.INK, s(6))
        elseif i > 1 and i ~= active + 1 then
            Draw.rect(bb, sx, y + s(7), math.max(1, s(1.2)), h - s(14), Draw.LIGHT)
        end
        Draw.text(bb, label, Draw.face(on and "bold" or "sans", px or s(12.5)), sx + s(4), y, seg - s(8), h, "center", on and Draw.WHITE or Draw.BLACK)
        if on_tap then
            ctx:hit(sx, y, seg, h, function() on_tap(i) end)
        end
    end
end

-- A grid of chips. on: set of labels or indexes that are selected. Returns the y below it.
-- icons: optional, the icon of each label, drawn before it.
function Look.chips(ctx, x, y, w, labels, is_on, cols, on_tap, h, icons)
    local bb = ctx.bb
    h = h or s(32)
    local gap = s(6)
    local cw = (w - (cols - 1) * gap) / cols
    for i, label in ipairs(labels) do
        local cx = x + ((i - 1) % cols) * (cw + gap)
        local cy = y + math.floor((i - 1) / cols) * (h + gap)
        local on = is_on(i)
        Draw.rect(bb, cx, cy, cw, h, on and Draw.INK or Draw.LIGHT, s(7))
        if not on then
            Draw.rect(bb, cx + s(1.5), cy + s(1.5), cw - s(3), h - s(3), Draw.WHITE, s(6))
        end
        local face = Draw.face(on and "bold" or "sans", s(12.5))
        local color = on and Draw.WHITE or Draw.BLACK
        if icons and icons[i] then
            local size = s(15)
            local tw = math.min(Draw.text_width(label, face), cw - size - s(12))
            local left = cx + (cw - size - s(5) - tw) / 2
            Draw.icon(bb, icons[i], left + size / 2, cy + h / 2, size, color)
            Draw.text(bb, label, face, left + size + s(5), cy, tw + s(2), h, "left", color)
        else
            Draw.text(bb, label, face, cx + s(2), cy, cw - s(4), h, "center", color)
        end
        ctx:hit(cx, cy, cw, h, function() on_tap(i) end)
    end
    return y + math.ceil(#labels / cols) * (h + gap)
end

function Look.toast(ctx, text, action, on_action, bottom)
    local bb, W = ctx.bb, ctx.w
    local h = s(46)
    local y = bottom - h - s(12)
    local x, w = s(40), W - s(80)
    Draw.rect(bb, x, y, w, h, Draw.INK, s(8))
    local aw = 0
    if action then
        local face = Draw.face("bold", s(14))
        aw = Draw.text_width(action, face) + s(24)
        Draw.text(bb, action, face, x + w - aw, y, aw - s(12), h, "right", Draw.WHITE)
        ctx:hit(x + w - aw - s(10), y, aw + s(10), h, on_action)
    end
    Draw.text(bb, text, Draw.face("sans", s(14)), x + s(20), y, w - aw - s(30), h, "left", Draw.WHITE)
    ctx:hit(x, y, w - aw - s(10), h, function() end)
end

-- A placeholder when there is no sprite on the device: a dashed outline with the number.
function Look.placeholder(bb, cx, cy, w, h, text)
    local bw, bh = math.min(w, s(60)), math.min(h, s(52))
    local x, y = cx - bw / 2, cy - bh / 2
    local dash = s(5)
    for px = x, x + bw - dash, dash * 2 do
        Draw.rect(bb, px, y, dash, math.max(1, s(1.4)), Draw.LIGHT)
        Draw.rect(bb, px, y + bh - s(1.4), dash, math.max(1, s(1.4)), Draw.LIGHT)
    end
    for py = y, y + bh - dash, dash * 2 do
        Draw.rect(bb, x, py, math.max(1, s(1.4)), dash, Draw.LIGHT)
        Draw.rect(bb, x + bw - s(1.4), py, math.max(1, s(1.4)), dash, Draw.LIGHT)
    end
    if text then
        Draw.text(bb, text, Draw.face("bold", s(12)), x, y, bw, bh, "center", Draw.MID)
    end
end

return Look
