-- Makes the type icons of the plugin, assets/icons/type_<type>.png, from the SVG of tools/fetch_type_icons.sh: each
-- SVG is a circle in the type's color with a white symbol, and only the symbol is kept, as a mask (white on black)
-- like the other icons, which the plugin paints in any color.
-- Usage: ICONS_SVG=<folder>/icons KOREADER_DIR=<desktop KOReader> tools/koreader/run_headless.sh tools/koreader/make_type_icons.lua
local plugin_dir = assert(os.getenv("PLUGIN_DIR"))
local svg_dir = assert(os.getenv("ICONS_SVG"), "ICONS_SVG: the icons folder of tools/fetch_type_icons.sh")

require("setupkoenv")
local DataStorage = require("datastorage")
G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
local Blitbuffer = require("ffi/blitbuffer")
local RenderImage = require("ui/renderimage")

-- In the order of the type ids, as the plugin names them.
local TYPES = { "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost", "steel", "fire", "water", "grass", "electric", "psychic", "ice", "dragon", "dark", "fairy" }
local RENDER, SIZE = 384, 96
local STEP = RENDER / SIZE

local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

-- KOReader's NanoSVG ignores <style>, so each class becomes a fill attribute.
local function inline_fills(text)
    local fills = {}
    for class, color in text:gmatch("%.(cls%-%d+)%s*{%s*fill:%s*(#%x+)%s*;?%s*}") do
        fills[class] = color
    end
    text = text:gsub("<defs>.-</defs>", "")
    text = text:gsub('class="(cls%-%d+)"', function(class)
        return 'fill="' .. assert(fills[class], "no fill for " .. class) .. '"'
    end)
    assert(not text:find("class=", 1, true), "a class was left")
    return text
end

local work = DataStorage:getDataDir() .. "/type_icons"
os.execute("mkdir -p '" .. work .. "'")
for _, name in ipairs(TYPES) do
    local svg = work .. "/" .. name .. ".svg"
    local file = assert(io.open(svg, "wb"))
    file:write(inline_fills(read(svg_dir .. "/" .. name .. ".svg")))
    file:close()
    local bb = assert(RenderImage:renderSVGImageFile(svg, RENDER, RENDER), name)
    -- How white each pixel is, inside the circle: the symbol is white, the circle and its holes have the color.
    local white = {}
    for y = 0, RENDER - 1 do
        local line = {}
        for x = 0, RENDER - 1 do
            local c = bb:getPixel(x, y):getColorRGB32()
            line[x] = math.max(0, math.min(1, (math.min(c.r, c.g, c.b) - 190) / 60)) * c.alpha / 255
        end
        white[y] = line
    end
    bb:free()
    -- Down to the icon size by the average of each block, the same result every time.
    local mask = Blitbuffer.new(SIZE, SIZE, Blitbuffer.TYPE_BB8)
    for y = 0, SIZE - 1 do
        for x = 0, SIZE - 1 do
            local sum = 0
            for dy = 0, STEP - 1 do
                local line = white[y * STEP + dy]
                for dx = 0, STEP - 1 do
                    sum = sum + line[x * STEP + dx]
                end
            end
            mask:setPixel(x, y, Blitbuffer.Color8(math.floor(255 * sum / (STEP * STEP) + 0.5)))
        end
    end
    mask:writePNG(plugin_dir .. "/assets/icons/type_" .. name .. ".png")
    mask:free()
    print("type_" .. name .. ".png")
end
print(#TYPES .. " type icons in assets/icons")
