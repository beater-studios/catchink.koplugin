-- New profile, or the settings of one: name, model, sprites, genders, forms, games and a copy source.
local Draw = require("catchink/ui/draw")
local Games = require("catchink/games")
local Look = require("catchink/ui/look")
local Profiles = require("catchink/profiles")
local SpriteCache = require("catchink/ui/sprite_cache")

local s = Draw.s
local Form = {}
Form.__index = Form

local MODEL_SPRITES = { normal = 1, shiny = 906, alpha = 133, living = 25 }
local GENDERS = { "single", "dimorphic", "all" }

function Form.new(app, args)
    local self = setmetatable({ app = app, profile = args.profile }, Form)
    local p = args.profile
    if p then
        self.values = { name = p.name, model = p.model, shiny = p.shiny, gender = p.gender, forms = p.forms, games = { unpack(p.games) } }
    else
        local d = Profiles.model_defaults("normal")
        self.values = { name = "", model = "normal", shiny = d.shiny, gender = d.gender, forms = d.forms, games = d.games }
    end
    return self
end

function Form:apply_model(model)
    local d = Profiles.model_defaults(model)
    local v = self.values
    v.model = model
    if model ~= "custom" then
        v.shiny, v.gender, v.forms, v.games = d.shiny, d.gender, d.forms, d.games
    end
end

function Form:games_text()
    local t = self.app.t
    local n = #self.values.games
    if n == #Games.LIST then
        return string.format(t.all_games, n)
    elseif n <= 2 and n > 0 then
        local names = {}
        for i, id in ipairs(self.values.games) do
            names[i] = Games.name(Games.get(id), self.app.lang)
        end
        return table.concat(names, t.and_word)
    end
    return string.format(t.games_count, n)
end

function Form:submit()
    local app, t, v = self.app, self.app.t, self.values
    local name = v.name:match("^%s*(.-)%s*$")
    if name == "" then
        name = t.models[v.model] or t.new_profile
    end
    if #v.games == 0 then
        app:show_toast(t.pick_one_game)
        app:redraw()
        return
    end
    local settings = { model = v.model, shiny = v.shiny, gender = v.gender, forms = v.forms, games = v.games, copy_from = v.copy_from }
    if self.profile then
        self.profile.name = name
        app:update_profile(self.profile, settings)
        app:back()
    else
        local p = app:create_profile(name, settings)
        app:back()
        app:show("games", { profile = p })
    end
end

function Form:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local v = self.values
    Look.header(ctx, self.profile and t.edit_profile or t.new_profile, { close = function() app:back() end })
    local y = s(72)
    Look.label(bb, s(20), y, W - s(40), t.profile_name)
    y = y + s(18)
    Draw.rect(bb, s(16), y, W - s(32), s(44), Draw.BLACK, s(8))
    Draw.rect(bb, s(17.8), y + s(1.8), W - s(35.6), s(40.4), Draw.WHITE, s(7))
    local shown = v.name ~= "" and v.name or (t.models[v.model] or "")
    Draw.text(bb, shown, Draw.face("sans", s(17)), s(30), y, W - s(80), s(44), "left", v.name ~= "" and Draw.BLACK or Draw.MID)
    Draw.icon(bb, "pencil", W - s(40), y + s(22), s(18))
    ctx:hit(s(16), y, W - s(32), s(44), function()
        app:ask_text(t.profile_name, v.name, function(text)
            v.name = text or ""
            app:redraw()
        end)
    end)
    y = y + s(62)
    Look.label(bb, s(20), y, W - s(40), t.start_from_model)
    y = y + s(20)
    local bw = (W - s(32) - s(16)) / 3
    for i, model in ipairs(Profiles.MODELS) do
        local bx = s(16) + ((i - 1) % 3) * (bw + s(8))
        local by = y + math.floor((i - 1) / 3) * s(104)
        local on = v.model == model
        Draw.rect(bb, bx, by, bw, s(96), Draw.BLACK, s(8))
        Draw.rect(bb, bx + s(1.8), by + s(1.8), bw - s(3.6), s(92.4), on and Draw.INK or Draw.WHITE, s(7))
        local species = MODEL_SPRITES[model]
        if species then
            Draw.rect(bb, bx + bw / 2 - s(30), by + s(8), s(60), s(46), on and Draw.WHITE or Draw.PAPER, s(6))
            local path = app.sprites:resolve(tostring(species), false, model == "shiny", "base")
            if not SpriteCache.paint(bb, path, bx + bw / 2, by + s(31), s(56), s(44), "color") then
                Look.placeholder(bb, bx + bw / 2, by + s(31), s(56), s(44))
            end
        else
            Draw.icon(bb, "pencil", bx + bw / 2, by + s(31), s(28), on and Draw.WHITE or Draw.BLACK)
        end
        Draw.text(bb, t.models[model], Draw.face("bold", s(14)), bx + s(4), by + s(58), bw - s(8), s(20), "center", on and Draw.WHITE or Draw.BLACK)
        Draw.text(bb, t.model_hints[model], Draw.face("sans", s(11.5)), bx + s(4), by + s(76), bw - s(8), s(16), "center", on and Draw.PALE or Draw.DARK)
        ctx:hit(bx, by, bw, s(96), function()
            self:apply_model(model)
            app:redraw()
        end)
    end
    y = y + s(228)
    Look.section(bb, s(20), y, W - s(40), t.profile_settings)
    Draw.text(bb, v.model == "custom" and t.profile_settings_custom or t.profile_settings_hint, Draw.face("sans", s(12)), s(20), y + s(8), W - s(40), s(20), "left", Draw.DARK)
    y = y + s(64)
    local function row_label(label, hint)
        Draw.text(bb, label, Draw.face("bold", s(14)), s(20), y - s(12), s(230), s(22), "left")
        if hint then
            Draw.text(bb, hint, Draw.face("sans", s(11.5)), s(20), y + s(8), s(230), s(18), "left", Draw.DARK)
        end
    end
    row_label(t.sprites, nil)
    Look.segmented(ctx, s(250), y - s(17), W - s(266), { t.sprites_normal, t.sprites_shiny }, v.shiny and 2 or 1, function(i)
        v.shiny = i == 2
        if v.model == "normal" or v.model == "shiny" then
            v.model = v.shiny and "shiny" or "normal"
        end
        app:redraw()
    end)
    y = y + s(58)
    row_label(t.gender, t.gender_hint)
    local gi = 1
    for i, g in ipairs(GENDERS) do
        if v.gender == g then
            gi = i
        end
    end
    Look.segmented(ctx, s(250), y - s(17), W - s(266), { t.gender_modes.single, t.gender_modes.dimorphic, t.gender_modes.all }, gi, function(i)
        v.gender = GENDERS[i]
        app:redraw()
    end)
    y = y + s(58)
    row_label(t.count_forms, t.count_forms_hint)
    Look.toggle(bb, W - s(60), y - s(12), v.forms)
    ctx:hit(s(16), y - s(24), W - s(32), s(50), function()
        v.forms = not v.forms
        app:redraw()
    end)
    y = y + s(48)
    Draw.hline(bb, s(16), y - s(10), W - s(32), math.max(1, s(1.2)), Draw.PALE)
    Draw.text(bb, t.games, Draw.face("bold", s(14)), s(20), y, s(200), s(30), "left")
    Draw.text(bb, self:games_text(), Draw.face("sans", s(14)), s(150), y, W - s(194), s(30), "right")
    Draw.icon(bb, "chevron_right", W - s(26), y + s(15), s(16))
    ctx:hit(s(16), y - s(4), W - s(32), s(38), function()
        app:show("pick_games", { values = v })
    end)
    y = y + s(40)
    if not self.profile and #app.profiles > 0 then
        local src = v.copy_from and app:profile_by_id(v.copy_from)
        Draw.text(bb, t.copy_from, Draw.face("bold", s(14)), s(20), y, s(250), s(30), "left")
        Draw.text(bb, src and src.name or t.nobody, Draw.face("sans", s(14)), s(250), y, W - s(294), s(30), "right")
        Draw.icon(bb, "chevron_right", W - s(26), y + s(15), s(16))
        ctx:hit(s(16), y - s(4), W - s(32), s(38), function()
            local items = { { text = t.nobody, callback = function() v.copy_from = nil app:redraw() end } }
            for _, p in ipairs(app.profiles) do
                items[#items + 1] = { text = p.name, callback = function() v.copy_from = p.id app:redraw() end }
            end
            app:menu(t.copy_from, items)
        end)
    end
    local by = H - s(78)
    Look.button(bb, s(16), by, W - s(32), s(52), self.profile and t.save or t.create_profile, "primary", s(17))
    ctx:hit(s(16), by, W - s(32), s(52), function() self:submit() end)
    app:draw_toast(ctx, by - s(4))
end

return Form
