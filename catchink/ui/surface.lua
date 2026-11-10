-- The whole screen as one drawing: the current view paints into the screen buffer and marks its touch
-- areas. Taps, holds and swipes go to those areas or to the view.
-- A view is a table with draw(view, ctx) and optionally swipe(view, direction); ctx.bb is the buffer,
-- ctx.w and ctx.h its size, and ctx:hit(x, y, w, h, tap, hold) marks a touch area. A view that fails to
-- draw leaves the screen to paint_failed, so the rest of the plugin still works.
local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local logger = require("logger")

local Draw = require("catchink/ui/draw")
local Refresh = require("catchink/refresh")
local Sleep = require("catchink/sleep")

local Screen = Device.screen

-- stop_events_propagation: every gesture stops here, so none reaches what is under the plugin (the file
-- browser, PlainUI's tabs).
local Surface = InputContainer:extend{
    name = "catchink_surface",
    covers_fullscreen = true,
    stop_events_propagation = true,
}

-- Every view has the same layout (header, body, bottom bar), so all of them are one kind for the refresh
-- counter: a change inside a view and a move to another view are updates without a flash, and the one after
-- REFRESH_LIMIT of them is full, which clears the ghosting of e-ink.
local REFRESH_LIMIT = 8
local REFRESH_KIND = "view"

local Context = {}
Context.__index = Context

function Context:hit(x, y, w, h, tap, hold)
    self.hits[#self.hits + 1] = { x = x, y = y, w = w, h = h, tap = tap, hold = hold }
end

function Surface:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.hits = {}
    self.refresh = Refresh.new(REFRESH_LIMIT)
    Sleep.watch(self)
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
end

function Surface:getSize()
    return self.dimen
end

function Surface:set_view(view, mode)
    self.view = view
    self:redraw(mode)
end

-- Redraws the view. mode "full" flashes now, whatever the count. While the device sleeps nothing is drawn
-- (Sleep.dirty): a timer running on a wakeup of the system would paint the plugin over the sleep screen,
-- and the device would look awake with the touch blocked. The window is repainted when it wakes up.
function Surface:redraw(mode)
    if mode == "full" then
        self.refresh:reset()
    end
    local refresh = self.refresh:mode(REFRESH_KIND)
    Sleep.dirty(self, function()
        return refresh, self.dimen
    end)
end

-- Redraws what changes on its own, like the progress of a download: without a flash and outside the count.
function Surface:redraw_progress()
    Sleep.dirty(self, function()
        return "ui", self.dimen
    end)
end

-- For a view that failed to draw: ctx is cleared to white, with no touch areas. The screen draws its message.
function Surface:paint_failed(ctx)
end

function Surface:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Draw.WHITE)
    local ctx = setmetatable({ bb = bb, w = self.dimen.w, h = self.dimen.h, hits = {} }, Context)
    if self.view then
        local ok, err = pcall(self.view.draw, self.view, ctx)
        if not ok then
            logger.warn("catchink: could not draw", self.view.kind, err)
            bb:paintRect(x, y, self.dimen.w, self.dimen.h, Draw.WHITE)
            ctx.hits = {}
            pcall(self.paint_failed, self, ctx)
        end
    end
    self.hits = ctx.hits
end

function Surface:find(gx, gy)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if gx >= h.x and gy >= h.y and gx < h.x + h.w and gy < h.y + h.h then
            return h, gx - h.x, gy - h.y
        end
    end
    return nil
end

function Surface:dispatch(ges, kind)
    local gx, gy = ges.pos.x - self.dimen.x, ges.pos.y - self.dimen.y
    local hit, lx, ly = self:find(gx, gy)
    if hit then
        local action = hit[kind] or (kind == "hold" and hit.tap)
        if action then
            action(lx, ly)
        end
    end
    return true
end

function Surface:onTap(_, ges)
    return self:dispatch(ges, "tap")
end

function Surface:onHold(_, ges)
    return self:dispatch(ges, "hold")
end

function Surface:onSwipe(_, ges)
    if self.view and self.view.swipe and ges.direction then
        self.view:swipe(ges.direction)
    end
    return true
end

return Surface
