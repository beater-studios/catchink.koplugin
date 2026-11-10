-- The sprite sets: what is on the device, what is downloading and what can be downloaded or removed.
local Draw = require("catchink/ui/draw")
local Look = require("catchink/ui/look")
local SpriteCache = require("catchink/ui/sprite_cache")
local SpriteSets = require("catchink/sprite_sets")
local Sprites = require("catchink/sprites")

local s = Draw.s
local SpritesView = {}
SpritesView.__index = SpritesView

local ROW_H = 76
local SAMPLE = { base = 1, ["red-blue"] = 1, yellow = 25, gold = 152, crystal = 155, ["ruby-sapphire"] = 252, emerald = 255,
    ["firered-leafgreen"] = 4, ["diamond-pearl"] = 387, platinum = 390, ["heartgold-soulsilver"] = 152, ["black-white"] = 495,
    ["x-y"] = 650, ["omega-ruby-alpha-sapphire"] = 252, ["gen7-icons"] = 722, ["lets-go"] = 25, ["sword-shield"] = 810,
    ["brilliant-diamond-shining-pearl"] = 387, ["legends-arceus"] = 722, ["scarlet-violet"] = 906, ["legends-za"] = 1 }

function SpritesView.new(app)
    return setmetatable({ app = app, page = 1 }, SpritesView)
end

function SpritesView:rows()
    local rows = {}
    for _, item in ipairs(SpriteSets.items()) do
        rows[#rows + 1] = item
    end
    return rows
end

function SpritesView:totals()
    local count, bytes = 0, 0
    for _, item in ipairs(SpriteSets.items()) do
        local state = self.app.sprites:item_state(item.set, item.variant)
        if state ~= "none" then
            count = count + 1
            local _, b = self.app.sprites:size(item.set, item.variant)
            bytes = bytes + b
        end
    end
    return count, bytes
end

function SpritesView:item_menu(item, state)
    local app, t = self.app, self.app.t
    local label = app:set_label(item.set, item.variant)
    local items = {}
    -- While a set downloads, the only choice is to stop it: deleting would race the download.
    if state == "busy" then
        app:menu(label, { { text = t.cancel_download, callback = function() app:cancel_download(item.set, item.variant) end } })
        return
    end
    if state ~= "done" then
        items[#items + 1] = { text = state == "partial" and t.resume_download or t.download, callback = function()
            app:download(item.set, item.variant)
            app:redraw()
        end }
    end
    if state ~= "none" then
        items[#items + 1] = { text = t.delete, callback = function()
            app:confirm(string.format(t.delete_set_confirm, label), t.delete, function()
                app.sprites:delete(item.set, item.variant)
                SpriteCache.forget()
                app:redraw()
            end)
        end }
    end
    if #items > 0 then
        app:menu(label, items)
    end
end

function SpritesView:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local count, bytes = self:totals()
    Look.header(ctx, t.sprites, { back = function() app:back() end, sub = string.format(count == 1 and t.sets_downloaded_one or t.sets_downloaded, count, app:size_text(bytes)) })
    local y = s(Look.HEADER_H) + s(10)
    Draw.text(bb, app.sprites:is_bundled(SpriteSets.get("base"), "normal") and t.sprites_hint or t.sprites_hint_download, Draw.face("sans", s(12)), s(20), y, W - s(40), s(20), "left", Draw.DARK)
    y = y + s(28)
    local rows = self:rows()
    local footer_h = s(78)
    local per = math.max(1, math.floor((H - y - footer_h - s(40)) / s(ROW_H)))
    local pages = math.max(1, math.ceil(#rows / per))
    self.pages = pages
    self.page = math.min(self.page, pages)
    local first = (self.page - 1) * per + 1
    for i = first, math.min(#rows, first + per - 1) do
        local item = rows[i]
        local id = Sprites.item_id(item.set, item.variant)
        local state, have, want = app.sprites:item_state(item.set, item.variant)
        local busy = app.downloader:busy_with(id)
        local files, size = app.sprites:size(item.set, item.variant)
        local x, w, h = s(16), W - s(32), s(ROW_H - 8)
        local strong = state == "done"
        Draw.rect(bb, x, y, w, h, strong and Draw.BLACK or Draw.LIGHT, s(8))
        Draw.rect(bb, x + s(1.5), y + s(1.5), w - s(3), h - s(3), Draw.WHITE, s(7))
        Draw.rect(bb, x + s(8), y + s(8), s(56), h - s(16), Draw.PAPER, s(6))
        local sample = tostring(SAMPLE[item.set.id] or 1)
        local main = item.variant == "shiny" and item.set.shiny or item.set.normal
        local path = app.sprites:has(main, sample) and app.sprites:path(main, sample) or nil
        if not SpriteCache.paint(bb, path, x + s(36), y + h / 2, s(48), h - s(20), "color") then
            Look.placeholder(bb, x + s(36), y + h / 2, s(48), h - s(20))
        end
        if item.variant == "shiny" then
            Draw.icon(bb, "sparkle", x + s(58), y + s(16), s(12), Draw.DARK)
        end
        Draw.text(bb, app:set_label(item.set, item.variant), Draw.face("bold", s(15)), x + s(76), y + s(6), w - s(240), s(24), "left")
        local detail = string.format(t.set_detail, app.text:thousands(files), app:size_text(size))
        if item.set.icons then
            detail = detail .. " · " .. t.box_icons
        elseif item.set.gray then
            detail = detail .. " · " .. t.in_gray
        end
        Draw.text(bb, detail, Draw.face("sans", s(12)), x + s(76), y + s(30), w - s(200), s(20), "left", Draw.DARK)
        if busy == "running" then
            local done, total = app.downloader:progress(id)
            local frac = total and total > 0 and done / total or 0
            Draw.text(bb, string.format("%d%%", math.floor(frac * 100)), Draw.face("bold", s(13)), W - s(150), y + s(8), s(118), s(20), "right")
            Look.progress(bb, W - s(150), y + s(34), s(118), frac, s(10))
            Draw.text(bb, t.cancel, Draw.face("sans", s(11.5)), W - s(150), y + s(46), s(118), s(18), "right", Draw.DARK)
            ctx:hit(W - s(170), y, s(154), h, function() app:cancel_download(item.set, item.variant) end)
        elseif busy == "queued" then
            Draw.text(bb, t.waiting, Draw.face("bold", s(13)), W - s(170), y, s(138), h, "right", Draw.DARK)
            ctx:hit(W - s(170), y, s(154), h, function() app:cancel_download(item.set, item.variant) end)
        elseif app.sprites:is_bundled(item.set, item.variant) then
            Look.stamp(bb, W - s(42), y + h / 2, s(12))
            Draw.text(bb, t.bundled, Draw.face("sans", s(11.5)), W - s(190), y, s(132), h, "right", Draw.DARK)
        elseif state == "done" then
            Look.stamp(bb, W - s(80), y + h / 2, s(12))
            Draw.icon(bb, "trash", W - s(42), y + h / 2, s(20), Draw.DARK)
            ctx:hit(W - s(66), y, s(50), h, function() self:item_menu(item, state) end)
        else
            local label = state == "partial" and string.format(t.partial, math.floor((have or 0) / math.max(1, want or 1) * 100)) or t.download
            local bw = s(110)
            Draw.rect(bb, W - s(28) - bw, y + h / 2 - s(16), bw, s(32), Draw.INK, s(7))
            Draw.icon(bb, "download", W - s(28) - bw + s(18), y + h / 2, s(16), Draw.WHITE)
            Draw.text(bb, label, Draw.face("bold", s(13)), W - s(28) - bw + s(28), y + h / 2 - s(16), bw - s(34), s(32), "center", Draw.WHITE)
            ctx:hit(W - s(40) - bw, y, bw + s(24), h, function()
                app:download(item.set, item.variant)
                app:redraw()
            end)
        end
        if not app.sprites:is_bundled(item.set, item.variant) then
            ctx:hit(x, y, W - s(190), h, function() self:item_menu(item, busy and "busy" or state) end)
        end
        y = y + s(ROW_H)
    end
    if pages > 1 then
        Draw.text(bb, string.format(t.page_of, self.page, pages), Draw.face("sans", s(13)), 0, y, W, s(30), "center", Draw.DARK)
        Draw.icon(bb, "chevron_left", s(40), y + s(15), s(22), self.page > 1 and Draw.BLACK or Draw.LIGHT)
        Draw.icon(bb, "chevron_right", W - s(40), y + s(15), s(22), self.page < pages and Draw.BLACK or Draw.LIGHT)
        ctx:hit(0, y - s(6), s(140), s(42), function() self:swipe("east") end)
        ctx:hit(W - s(140), y - s(6), s(140), s(42), function() self:swipe("west") end)
    end
    local fy = H - footer_h
    Draw.hline(bb, s(16), fy, W - s(32), math.max(1, s(1.2)), Draw.PALE)
    Draw.text(bb, t.banner_setting, Draw.face("bold", s(13.5)), s(20), fy + s(12), W - s(110), s(22), "left")
    Draw.text(bb, t.banner_setting_hint, Draw.face("sans", s(11.5)), s(20), fy + s(36), W - s(110), s(18), "left", Draw.DARK)
    Look.toggle(bb, W - s(60), fy + s(20), not app.banner_off)
    ctx:hit(0, fy, W, footer_h, function()
        app.banner_off = not app.banner_off
        app:save_settings()
        app:redraw()
    end)
    app:draw_toast(ctx, fy - s(4))
end

function SpritesView:swipe(direction)
    if direction == "west" and self.page < (self.pages or 1) then
        self.page = self.page + 1
    elseif direction == "east" and self.page > 1 then
        self.page = self.page - 1
    else
        return
    end
    self.app:redraw()
end

return SpritesView
