-- Progress of a profile: the national total, the last days, by generation and by game.
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")

local s = Draw.s
local Progress = {}
Progress.__index = Progress

function Progress.new(app, args)
    return setmetatable({ app = app, profile = args.profile, page = 1 }, Progress)
end

-- Caught and total of the national entries by generation.
function Progress:by_generation()
    local app, p = self.app, self.profile
    local state_of = app:state_fn(p, Games.HOME)
    local gens = {}
    for _, e in ipairs(app:entries(p, Games.HOME)) do
        local g = app.data:generation(e.species)
        gens[g] = gens[g] or { caught = 0, total = 0 }
        local st = state_of(e.key)
        if st ~= "u" then
            gens[g].total = gens[g].total + 1
        end
        if st == "c" then
            gens[g].caught = gens[g].caught + 1
        end
    end
    return gens
end

local function ring(bb, cx, cy, r, width, frac)
    Draw.ring(bb, cx, cy, r, width, Draw.DARK)
    -- The caught part, drawn as dots along the circle (blitbuffers have no arcs).
    local steps = math.floor(360 * frac)
    for a = 0, steps, 2 do
        local rad = math.rad(a - 90)
        Draw.circle(bb, cx + math.cos(rad) * (r - width / 2), cy + math.sin(rad) * (r - width / 2), width / 2, Draw.WHITE)
    end
end

function Progress:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local p = self.profile
    Look.header(ctx, t.progress, { back = function() app:back() end, sub = string.format("%s · %s", p.name, t.models[p.model] or p.model) })
    local y = s(Look.HEADER_H) + s(16)
    local nat = app:progress(p, Games.HOME)
    local frac = nat.total > 0 and nat.caught / nat.total or 0
    Draw.rect(bb, s(16), y, W - s(32), s(122), Draw.INK, s(10))
    ring(bb, s(86), y + s(61), s(46), s(10), frac)
    Draw.text(bb, string.format("%d%%", math.floor(frac * 100 + 0.5)), Draw.face("serif", s(20)), s(40), y + s(46), s(92), s(30), "center", Draw.WHITE)
    Draw.text(bb, string.format(t.of_total, nat.caught, nat.total), Draw.face("serif", s(24)), s(156), y + s(20), W - s(190), s(34), "left", Draw.WHITE)
    Draw.text(bb, p.forms and t.national_entries or t.national_species, Draw.face("sans", s(13.5)), s(156), y + s(54), W - s(190), s(20), "left", Draw.PALE)
    local recent = app:caps(p):recent(os.time(), 7)
    Draw.text(bb, string.format(t.recent_seen, recent, nat.seen), Draw.face("bold", s(13)), s(156), y + s(80), W - s(190), s(22), "left", Draw.WHITE)
    y = y + s(142)
    Look.section(bb, s(20), y, W - s(40), t.by_generation)
    y = y + s(14)
    local gens = self:by_generation()
    for g = 1, 9 do
        local v = gens[g] or { caught = 0, total = 0 }
        Draw.text(bb, string.format(t.gen_short, g), Draw.face("sans", s(13.5)), s(20), y, s(70), s(20), "left")
        Look.progress(bb, s(90), y + s(4), s(380), v.total > 0 and v.caught / v.total or 0, s(12), Draw.DARK)
        Draw.text(bb, string.format("%d / %d", v.caught, v.total), Draw.face("bold", s(13)), W - s(130), y, s(110), s(20), "right")
        y = y + s(25)
    end
    y = y + s(12)
    Look.section(bb, s(20), y, W - s(40), t.by_game)
    y = y + s(14)
    local rows = {}
    for _, id in ipairs(p.games) do
        rows[#rows + 1] = Games.get(id)
    end
    local button_y = H - s(64)
    local per = math.max(1, math.floor((button_y - y - s(30)) / s(25)))
    local pages = math.max(1, math.ceil(#rows / per))
    self.pages = pages
    self.page = math.min(self.page, pages)
    local first = (self.page - 1) * per + 1
    for i = first, math.min(#rows, first + per - 1) do
        local g = rows[i]
        local pr = app:progress(p, g.id)
        Draw.text(bb, Games.name(g, app.lang), Draw.face("sans", s(13.5)), s(20), y, s(220), s(20), "left")
        Look.progress(bb, s(240), y + s(4), s(230), pr.total > 0 and pr.caught / pr.total or 0, s(12), Draw.DARK)
        Draw.text(bb, string.format("%d%%", pr.total > 0 and math.floor(pr.caught / pr.total * 100 + 0.5) or 0), Draw.face("bold", s(13)), W - s(110), y, s(90), s(20), "right")
        ctx:hit(0, y - s(2), W, s(25), function() app:show("browse", { profile = p, game = g.id }) end)
        y = y + s(25)
    end
    if pages > 1 then
        Draw.text(bb, string.format(t.page_of, self.page, pages), Draw.face("sans", s(12)), 0, y + s(2), W, s(24), "center", Draw.DARK)
        ctx:hit(0, y - s(4), W / 2, s(32), function() self:swipe("east") end)
        ctx:hit(W / 2, y - s(4), W / 2, s(32), function() self:swipe("west") end)
    end
    local half = (W - s(44)) / 2
    Look.button(bb, s(16), button_y, half, s(46), t.see_missing, "primary", s(15))
    ctx:hit(s(16), button_y, half, s(46), function()
        app:show("browse", { profile = p, game = Games.HOME, mode = "list", filters = { status = "missing" } })
    end)
    Look.button(bb, s(28) + half, button_y, half, s(46), t.all_games_button, "outline", s(15))
    ctx:hit(s(28) + half, button_y, half, s(46), function() app:back_to("games") end)
end

function Progress:swipe(direction)
    if direction == "west" and self.page < (self.pages or 1) then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.app:redraw()
end

return Progress
