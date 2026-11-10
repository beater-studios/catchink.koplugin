-- Turns sprite files into gray pictures with transparency, fitted to a box: trimmed to the drawing,
-- enlarged by whole steps without smoothing (pixel art stays sharp) or reduced smoothly when too big.
-- Modes: "color", "silhouette" (what is missing), "seen" (lighter) and "unavailable" (faint).
local Blitbuffer = require("ffi/blitbuffer")
local ffi = require("ffi")
local RenderImage = require("ui/renderimage")

local SpriteCache = {}

local MAX_ITEMS = 120
local cache, order = {}, {}

local SILHOUETTE = 0xBB
local FAINT = 0xDD

local function shade(mode, v)
    if mode == "silhouette" then
        return SILHOUETTE
    elseif mode == "unavailable" then
        return FAINT
    elseif mode == "seen" then
        return math.floor(v * 0.45 + 255 * 0.55)
    end
    -- A little more contrast: the sprites are drawn for color screens.
    local c = math.floor((v - 128) * 1.15 + 128)
    return c < 0 and 0 or (c > 255 and 255 or c)
end

-- A reader of gray and alpha for each pixel, straight from the buffer's memory: no object per pixel, so
-- the garbage collector stays quiet on the device.
local function reader(bb)
    local t = bb:getType()
    if t == Blitbuffer.TYPE_BBRGB32 then
        return function(x, y)
            local p = bb:getPixelP(x, y)
            return math.floor((p.r * 77 + p.g * 150 + p.b * 29) / 256), p.alpha
        end
    elseif t == Blitbuffer.TYPE_BB8A then
        return function(x, y)
            local p = bb:getPixelP(x, y)
            return p.a, p.alpha
        end
    elseif t == Blitbuffer.TYPE_BB8 then
        return function(x, y)
            return bb:getPixelP(x, y).a, 255
        end
    elseif t == Blitbuffer.TYPE_BBRGB24 then
        return function(x, y)
            local p = bb:getPixelP(x, y)
            return math.floor((p.r * 77 + p.g * 150 + p.b * 29) / 256), 255
        end
    end
    return function(x, y)
        local c = bb:getPixel(x, y):getColor8A()
        return c.a, c.alpha
    end
end

-- Sprites are decoded with lodepng, which keeps their transparency on every KOReader version (the image
-- renderer of the stable release on the device returned them over white).
local function decode(path)
    local ok_png, Png = pcall(require, "ffi/png")
    if not ok_png then
        return nil
    end
    local ok, img = Png.decodeFromFile(path, 4)
    if not ok or not img then
        return nil
    end
    return img
end

local function free_data(img)
    pcall(ffi.cdef, "void free(void *ptr);")
    ffi.C.free(img.data)
end

local function rgba_reader(img)
    local data, w = img.data, img.width
    return function(x, y)
        local i = (y * w + x) * 4
        return math.floor((data[i] * 77 + data[i + 1] * 150 + data[i + 2] * 29) / 256), data[i + 3]
    end
end

-- A transparent buffer. Blitbuffer's fill() turns any color into an opaque one (it drops the alpha), which
-- gave every sprite a white box, so the memory is zeroed instead: gray 0, alpha 0.
local function clear(bb)
    ffi.fill(bb.data, bb.stride * bb.h, 0)
end

-- Builds the picture from raw pixels: trimmed, then enlarged by whole steps or reduced by averaging.
local function from_pixels(read, w, h, box_w, box_h, mode)
    local x0, y0, x1, y1 = w, h, -1, -1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, alpha = read(x, y)
            if alpha > 24 then
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y < y0 then y0 = y end
                if y > y1 then y1 = y end
            end
        end
    end
    if x1 < 0 then
        x0, y0, x1, y1 = 0, 0, w - 1, h - 1
    end
    local tw, th = x1 - x0 + 1, y1 - y0 + 1
    local k = math.floor(math.min(box_w / tw, box_h / th))
    local solid = mode ~= "color" and mode ~= "seen"
    local out
    if k >= 1 then
        k = math.min(k, 8)
        out = Blitbuffer.new(tw * k, th * k, Blitbuffer.TYPE_BB8A)
        clear(out)
        for y = 0, th - 1 do
            for x = 0, tw - 1 do
                local v, alpha = read(x0 + x, y0 + y)
                if alpha > 24 then
                    local g = shade(mode, v)
                    local a = solid and 0xFF or alpha
                    for dy = 0, k - 1 do
                        for dx = 0, k - 1 do
                            local p = out:getPixelP(x * k + dx, y * k + dy)
                            p.a = g
                            p.alpha = a
                        end
                    end
                end
            end
        end
    else
        local scale = math.min(box_w / tw, box_h / th)
        local ow, oh = math.max(1, math.floor(tw * scale)), math.max(1, math.floor(th * scale))
        out = Blitbuffer.new(ow, oh, Blitbuffer.TYPE_BB8A)
        clear(out)
        for y = 0, oh - 1 do
            local sy0, sy1 = math.floor(y * th / oh), math.max(math.floor(y * th / oh), math.floor((y + 1) * th / oh) - 1)
            for x = 0, ow - 1 do
                local sx0, sx1 = math.floor(x * tw / ow), math.max(math.floor(x * tw / ow), math.floor((x + 1) * tw / ow) - 1)
                local sum_a, sum_g, n = 0, 0, 0
                for sy = sy0, sy1 do
                    for sx = sx0, sx1 do
                        local v, alpha = read(x0 + sx, y0 + sy)
                        sum_a = sum_a + alpha
                        sum_g = sum_g + v * alpha
                        n = n + 1
                    end
                end
                local alpha = math.floor(sum_a / n)
                if alpha > 24 then
                    local p = out:getPixelP(x, y)
                    p.a = shade(mode, math.floor(sum_g / sum_a))
                    p.alpha = solid and 0xFF or alpha
                end
            end
        end
    end
    return out
end

local function build(path, box_w, box_h, mode)
    local img = decode(path)
    if img then
        local ok, result = pcall(from_pixels, rgba_reader(img), img.width, img.height, box_w, box_h, mode)
        free_data(img)
        return ok and result or nil
    end
    -- Not a PNG lodepng can read: KOReader's image renderer.
    local ok, image = pcall(RenderImage.renderImageFile, RenderImage, path, false)
    if not ok or not image then
        return nil
    end
    local read = reader(image)
    local result = from_pixels(read, image:getWidth(), image:getHeight(), box_w, box_h, mode)
    image:free()
    return result
end

function SpriteCache.get(path, box_w, box_h, mode)
    box_w, box_h = math.floor(box_w), math.floor(box_h)
    local key = path .. "|" .. box_w .. "x" .. box_h .. "|" .. mode
    local item = cache[key]
    if item == nil then
        item = build(path, box_w, box_h, mode) or false
        cache[key] = item
        order[#order + 1] = key
        if #order > MAX_ITEMS then
            local old = table.remove(order, 1)
            if cache[old] then
                cache[old]:free()
            end
            cache[old] = nil
        end
    end
    return item or nil
end

-- Paints a sprite centered on (cx, cy). Returns false when the file could not be read.
function SpriteCache.paint(bb, path, cx, cy, box_w, box_h, mode)
    local s = path and SpriteCache.get(path, box_w, box_h, mode or "color")
    if not s then
        return false
    end
    local w, h = s:getWidth(), s:getHeight()
    bb:alphablitFrom(s, math.floor(cx - w / 2), math.floor(cy - h / 2), 0, 0, w, h)
    return true
end

function SpriteCache.forget(prefix)
    for i = #order, 1, -1 do
        local key = order[i]
        if not prefix or key:sub(1, #prefix) == prefix then
            if cache[key] then
                cache[key]:free()
            end
            cache[key] = nil
            table.remove(order, i)
        end
    end
end

return SpriteCache
