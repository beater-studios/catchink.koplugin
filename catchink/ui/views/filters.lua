-- Filters of a game or of the national view: generation, up to two types, situation, category and order.
local Draw = require("catchink/ui/draw")
local Filters = require("catchink/filters")
local Look = require("catchink/ui/look")
local Types = require("catchink/types")

local s = Draw.s
local FiltersView = {}
FiltersView.__index = FiltersView

local TYPE_ORDER = { 1, 10, 11, 12, 13, 15, 2, 4, 5, 3, 14, 7, 6, 8, 16, 17, 9, 18 }
local STATUSES = { "all", "caught", "missing", "seen", "unavailable" }
local CATEGORIES = { "legendary", "mythical", "baby", "forms" }
local ORDERS = { "regional", "national", "name" }

function FiltersView.new(app, args)
    local self = setmetatable({ app = app, profile = args.profile, game = args.game, browse = args.browse }, FiltersView)
    self.f = app:filters_of(self.profile, self.game)
    return self
end

function FiltersView:count()
    local browse = self.browse
    if not browse then
        return 0
    end
    return #browse:entries()
end

function FiltersView:draw(ctx)
    local app, t, bb, W, H = self.app, self.app.t, ctx.bb, ctx.w, ctx.h
    local f = self.f
    Look.header(ctx, t.filters, { close = function() app:back() end, right = { { icon = "trash", size = 20, tap = function()
        local order = f.order
        for k, v in pairs(Filters.empty()) do
            f[k] = v
        end
        f.order = order
        app:save_settings()
        app:redraw()
    end } } })
    local y = s(Look.HEADER_H) + s(22)
    local x, w = s(16), W - s(32)
    local function changed()
        if self.browse then
            self.browse.page = 1
        end
        app:save_settings()
        app:redraw()
    end
    Look.label(bb, s(20), y - s(8), w, t.filter_generation)
    local gens = {}
    for i = 1, 9 do
        gens[i] = tostring(i)
    end
    y = Look.chips(ctx, x, y + s(12), w, gens, function(i) return f.gens[i] == true end, 9, function(i)
        f.gens[i] = not f.gens[i] or nil
        changed()
    end) + s(14)
    Look.label(bb, s(20), y - s(8), w, t.filter_type)
    local type_names, type_icons = {}, {}
    for i, id in ipairs(TYPE_ORDER) do
        type_names[i] = app.text:type_name(id)
        type_icons[i] = Types.icon(id)
    end
    y = Look.chips(ctx, x, y + s(12), w, type_names, function(i)
        local id = TYPE_ORDER[i]
        return f.types[1] == id or f.types[2] == id
    end, 6, function(i)
        local id = TYPE_ORDER[i]
        for k, ty in ipairs(f.types) do
            if ty == id then
                table.remove(f.types, k)
                return changed()
            end
        end
        if #f.types >= 2 then
            table.remove(f.types, 1)
        end
        f.types[#f.types + 1] = id
        changed()
    end, nil, type_icons) + s(14)
    Look.label(bb, s(20), y - s(8), w, t.filter_status)
    local status_names = {}
    for i, st in ipairs(STATUSES) do
        status_names[i] = t.statuses[st]
    end
    y = Look.chips(ctx, x, y + s(12), w, status_names, function(i) return f.status == STATUSES[i] end, 5, function(i)
        f.status = STATUSES[i]
        changed()
    end) + s(14)
    Look.label(bb, s(20), y - s(8), w, t.filter_category)
    local cat_names = {}
    for i, c in ipairs(CATEGORIES) do
        cat_names[i] = t.categories[c]
    end
    y = Look.chips(ctx, x, y + s(12), w, cat_names, function(i) return f.cats[CATEGORIES[i]] == true end, 4, function(i)
        local c = CATEGORIES[i]
        f.cats[c] = not f.cats[c] or nil
        changed()
    end) + s(14)
    Look.label(bb, s(20), y - s(8), w, t.filter_order)
    local active = 1
    for i, o in ipairs(ORDERS) do
        if f.order == o then
            active = i
        end
    end
    Look.segmented(ctx, x, y + s(12), w, { t.orders.regional, t.orders.national, t.orders.name }, active, function(i)
        f.order = ORDERS[i]
        changed()
    end)
    local by = H - s(74)
    Look.button(bb, x, by, w, s(52), string.format(t.see_results, self:count()), "primary", s(17))
    ctx:hit(x, by, w, s(52), function() app:back() end)
end

return FiltersView
