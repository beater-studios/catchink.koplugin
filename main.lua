local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local PluginScreensaver = require("catchink/screensaver")

local PLUGIN_DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("(.*)/") or "."

PluginScreensaver.install(PLUGIN_DIR, "catchink")
require("catchink/awake").install("catchink")

local OPEN_FAILED = "CatchInk could not open. Try restarting KOReader."

-- The warning in the reader's language, from the plugin texts when they can still be read.
local function open_failed_text()
    local ok, text = pcall(function()
        local chunk = assert(loadfile(PLUGIN_DIR .. "/data/i18n.lua"))
        setfenv(chunk, {})
        local i18n = chunk()
        local code = (G_reader_settings and G_reader_settings:readSetting("language") or ""):sub(1, 2):lower()
        return (i18n[code] or i18n.en).open_failed
    end)
    return ok and type(text) == "string" and text or OPEN_FAILED
end

local CatchInk = WidgetContainer:extend{
    name = "catchink",
    is_doc_only = false,
}

function CatchInk:init()
    self.ui.menu:registerToMainMenu(self)
end

function CatchInk:addToMainMenu(menu_items)
    menu_items.catchink = {
        text = self.fullname,
        sorting_hint = "tools",
        callback = function()
            local ok, screen = pcall(function()
                return require("catchink/ui/screen"):new{ plugin_dir = PLUGIN_DIR }
            end)
            if ok then
                UIManager:show(screen)
            else
                logger.warn("catchink: could not open", screen)
                UIManager:show(InfoMessage:new{ text = open_failed_text() })
            end
        end,
    }
end

return CatchInk
