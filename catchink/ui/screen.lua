-- The CatchInk screen: holds the profiles, their captures, the sprites and the downloads, and moves
-- between the views. Each view lives in catchink/ui/views and draws through Surface.
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Awake = require("catchink/awake")
local Data = require("catchink/data")
local Dex = require("catchink/dex")
local Downloader = require("catchink/download")
local Draw = require("catchink/ui/draw")
local Filters = require("catchink/filters")
local Games = require("catchink/games")
local Portrait = require("catchink/portrait")
local Profiles = require("catchink/profiles")
local SavedState = require("catchink/saved_state")
local Sleep = require("catchink/sleep")
local SpriteCache = require("catchink/ui/sprite_cache")
local SpriteSets = require("catchink/sprite_sets")
local Sprites = require("catchink/sprites")
local State = require("catchink/state")
local Surface = require("catchink/ui/surface")
local Text = require("catchink/text")
local Types = require("catchink/types")

local LANGUAGES = { { "pt", "Português" }, { "en", "English" }, { "es", "Español" } }
local TOAST_SECONDS = 5
local DOWNLOAD_TICK = 1.5
local SAVE_VERSION = State.VERSION

local function default_language()
    local code = G_reader_settings and G_reader_settings:readSetting("language") or ""
    local prefix = code:sub(1, 2):lower()
    return State.LANGUAGES[prefix] and prefix or "en"
end

local function is_file(path)
    return lfs.attributes(path, "mode") == "file"
end

local Screen = Surface:extend{
    name = "catchink_screen",
    plugin_dir = ".",
}

Screen.LANGUAGES = LANGUAGES
Screen.SAVE_VERSION = SAVE_VERSION

function Screen:init()
    Portrait.open(self, self.setup_screen)
end

-- Everything the opening does, protected by Portrait.open: if it fails, the rotation is given back.
function Screen:setup_screen()
    Surface.init(self)
    Draw.init(self.plugin_dir)
    if Device:hasKeys() then
        self.key_events.Back = { { Device.input.group.Back } }
    end
    self.meta = Data.load_table(self.plugin_dir .. "/_meta.lua") or { version = "?" }
    self.i18n = assert(Data.load_table(self.plugin_dir .. "/data/i18n.lua"))
    self.data = Data.new(self.plugin_dir .. "/data")
    self.home_dir = self.home_dir or (DataStorage:getDataDir() .. "/catchink")
    self.settings_dir = self.settings_dir or DataStorage:getSettingsDir()
    os.execute("mkdir -p '" .. self.home_dir:gsub("'", "'\\''") .. "'")
    self:load_settings()
    self.captures = {}
    self.entries_cache = {}
    self.progress_cache = {}
    self.caps_versions = {}
    self.sprites = Sprites.new{
        -- In KOReader's data folder, not in the plugin: built in two parts for the package check.
        dir = self.home_dir .. "/" .. "sprites",
        manifest = self.data:sprites(),
        data = self.data,
        bundled = Sprites.bundled_in(self.plugin_dir),
    }
    self.downloader = Downloader.new{
        work_dir = self.home_dir .. "/work",
        hosts = Sprites.HOSTS,
        user_agent = "CatchInk/" .. tostring(self.meta.version),
    }
    self.downloader:reset_work_dir()
    self.stack = {}
    self.tick_cb = function()
        self:tick()
    end
    self.toast_cb = function()
        self.notice = nil
        self:redraw()
    end
    self:show("home")
end

-- The settings file: language, the list of profiles and a few choices, read by State (catchink/state.lua).
function Screen:load_settings()
    self.settings = LuaSettings:open(self.settings_dir .. "/catchink.lua")
    local saved = State.settings(function(key)
        return self.settings:readSetting(key)
    end, default_language(), logger.warn)
    self:set_language(self.i18n[saved.lang] and saved.lang or "en")
    self.profiles = saved.profiles
    self.banner_off = saved.banner_off
    self.last_profile_id = saved.last_profile_id
    for _, p in ipairs(self.profiles) do
        self:move_legacy_captures(p.id)
    end
end

function Screen:set_language(lang)
    self.lang = lang
    self.t = self.i18n[lang]
    self.text = Text.new(self.t, lang, self.data)
end

function Screen:save_settings()
    local list = {}
    for i, p in ipairs(self.profiles) do
        list[i] = p
    end
    self.settings:saveSetting("version", SAVE_VERSION)
    self.settings:saveSetting("lang", self.lang)
    self.settings:saveSetting("profiles", list)
    self.settings:saveSetting("banner_off", self.banner_off or nil)
    self.settings:saveSetting("last_profile_id", self.last_profile_id)
    self.settings:flush()
end

---------------------------------------------------------------------------
-- Navigation.
---------------------------------------------------------------------------

local VIEWS = {
    home = "catchink/ui/views/home",
    profile_form = "catchink/ui/views/profile_form",
    games = "catchink/ui/views/games",
    browse = "catchink/ui/views/browse",
    filters = "catchink/ui/views/filters",
    card = "catchink/ui/views/card",
    progress = "catchink/ui/views/progress",
    sprites = "catchink/ui/views/sprites",
    about = "catchink/ui/views/about",
    pick_games = "catchink/ui/views/pick_games",
    type_chart = "catchink/ui/views/type_chart",
    type_summary = "catchink/ui/views/type_summary",
}

function Screen:make(name, args)
    local View = require(VIEWS[name])
    local view = View.new(self, args or {})
    view.kind = name
    return view
end

-- Opens a view on top of the current one.
function Screen:show(name, args)
    local view = self:make(name, args)
    self.stack[#self.stack + 1] = view
    self.notice = nil
    self:set_view(view)
    return view
end

-- Replaces the current view.
function Screen:replace(name, args)
    local view = self:make(name, args)
    self.stack[#self.stack] = view
    self:set_view(view)
    return view
end

function Screen:back()
    if #self.stack <= 1 then
        return self:close()
    end
    table.remove(self.stack)
    local view = self.stack[#self.stack]
    if view.refresh then
        view:refresh()
    end
    self.notice = nil
    self:set_view(view)
end

function Screen:back_to(kind)
    while #self.stack > 1 and self.stack[#self.stack].kind ~= kind do
        table.remove(self.stack)
    end
    local view = self.stack[#self.stack]
    if view.refresh then
        view:refresh()
    end
    self:set_view(view)
end

function Screen:current()
    return self.stack[#self.stack]
end

function Screen:close()
    UIManager:close(self)
end

---------------------------------------------------------------------------
-- Life cycle.
---------------------------------------------------------------------------

Screen.onSetRotationMode = Portrait.ignore_rotation

-- The Back key of devices with keys goes back one view, and closes the plugin from the first one.
function Screen:onBack()
    self:back()
    return true
end

-- KOReader sends Close to every window before it quits (USB mode on a Kobo, closing the window on a computer).
function Screen:onClose(arg)
    if not (arg and arg.keep_screensaver) then
        UIManager:close(self)
    end
end

-- Sleep.watch has already held the timers and the drawing; a toast would be stale when the device wakes up.
function Screen:onSuspend()
    Sleep.unschedule(self, self.toast_cb)
    self.notice = nil
end

-- The repaint asked for here waits until the sleep screen is gone, and it flashes.
function Screen:onResume()
    self:redraw("full")
end

-- Sleep.watch has already cancelled the timers.
function Screen:onCloseWidget()
    if self.downloader then
        self.downloader:stop()
    end
    self:keep_awake(false)
    if self.settings then
        self:save_settings()
    end
    SpriteCache.forget()
    Portrait.close(self)
    UIManager:setDirty(nil, "full")
end

-- A view that failed to draw: a short message and a way back, so the screen never locks.
function Screen:paint_failed(ctx)
    local t = self.t or {}
    local s = Draw.s
    local mid = math.floor(ctx.h / 2)
    Draw.text(ctx.bb, t.draw_failed or "This part could not be shown.", Draw.face("serif", s(20)), s(16), mid - s(44), ctx.w - s(32), s(36), "center", Draw.BLACK)
    Draw.text(ctx.bb, t.draw_failed_back or "Tap here to go back.", Draw.face("sans", s(16)), s(16), mid, ctx.w - s(32), s(30), "center", Draw.DARK)
    ctx:hit(0, 0, ctx.w, ctx.h, function()
        if #self.stack <= 1 then
            self:close()
        else
            self:back_to("home")
        end
    end)
end

-- Kept in self.notice, never self.toast: UIManager takes a window with a toast field for one of its own toasts
-- and puts every dialog opened meanwhile under it, out of sight.
function Screen:show_toast(text, action, on_action)
    self.notice = { text = text, action = action, on_action = on_action }
    Sleep.schedule(self, TOAST_SECONDS, self.toast_cb)
end

function Screen:draw_toast(ctx, bottom)
    if self.notice then
        local Look = require("catchink/ui/look")
        Look.toast(ctx, self.notice.text, self.notice.action, function()
            local on_action = self.notice and self.notice.on_action
            self.notice = nil
            if on_action then
                on_action()
            end
            self:redraw()
        end, bottom)
    end
end

---------------------------------------------------------------------------
-- Profiles and captures.
---------------------------------------------------------------------------

function Screen:profile_by_id(id)
    for i, p in ipairs(self.profiles) do
        if p.id == id then
            return p, i
        end
    end
    return nil
end

-- The captures of each profile, in KOReader's settings folder next to catchink.lua, where backups look.
function Screen:captures_file(id)
    return self.settings_dir .. "/catchink_profile_" .. id .. ".lua"
end

-- Builds from before the first release kept them in <data folder>/catchink. They move once, with KOReader's .old backup.
function Screen:move_legacy_captures(id)
    local old = self.home_dir .. "/profile_" .. id .. ".lua"
    local new = self:captures_file(id)
    if is_file(old) and not is_file(new) then
        os.rename(old, new)
        if is_file(old .. ".old") and not is_file(new .. ".old") then
            os.rename(old .. ".old", new .. ".old")
        end
    end
end

-- Removes a profile's captures, also where the builds before the first release kept them, and the .old backup that KOReader would read
-- when the file is missing.
function Screen:remove_captures(id)
    SavedState.remove_file(self:captures_file(id))
    SavedState.remove_file(self.home_dir .. "/profile_" .. id .. ".lua")
end

function Screen:caps(profile)
    local c = self.captures[profile.id]
    if not c then
        local store = LuaSettings:open(self:captures_file(profile.id))
        c = State.captures(store:readSetting("captures"), logger.warn)
        c.store = store
        self.captures[profile.id] = c
    end
    return c
end

-- A counter of changes to a profile's captures, so views know when what they keep is old.
function Screen:caps_version(profile)
    return self.caps_versions[profile.id] or 0
end

function Screen:save_caps(profile)
    self.progress_cache[profile.id] = nil
    self.caps_versions[profile.id] = (self.caps_versions[profile.id] or 0) + 1
    local c = self:caps(profile)
    c.store:saveSetting("version", SAVE_VERSION)
    c.store:saveSetting("captures", c:serialize())
    c.store:flush()
end

function Screen:create_profile(name, settings)
    local id = Profiles.next_id(self.profiles, self.last_profile_id)
    self.last_profile_id = tonumber(id:match("%d+"))
    -- What a profile with this id may have left behind (another session, an old version).
    self:remove_captures(id)
    local p = Profiles.new(id, name, settings, os.time())
    self.profiles[#self.profiles + 1] = p
    if settings.copy_from then
        local src = self:profile_by_id(settings.copy_from)
        if src then
            local copy = self:caps(src):copy()
            copy.store = LuaSettings:open(self:captures_file(id))
            self.captures[id] = copy
            self:save_caps(p)
        end
        p.copy_from = nil
    end
    self:save_settings()
    return p
end

function Screen:update_profile(p, settings)
    for k, v in pairs(settings) do
        if k ~= "copy_from" then
            p[k] = v
        end
    end
    p.games = Games.ordered(p.games)
    self.entries_cache = {}
    self.progress_cache[p.id] = nil
    self:save_settings()
end

function Screen:delete_profile(p)
    local _, index = self:profile_by_id(p.id)
    if index then
        table.remove(self.profiles, index)
    end
    self.captures[p.id] = nil
    self.progress_cache[p.id] = nil
    self:remove_captures(p.id)
    self:save_settings()
end

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deep_copy(v)
    end
    return out
end

-- A copy with its own tables: filters and chosen sprite sets of one never change the other.
function Screen:duplicate_profile(p)
    local settings = {}
    for k, v in pairs(p) do
        if k ~= "id" and k ~= "name" and k ~= "created" then
            settings[k] = deep_copy(v)
        end
    end
    settings.copy_from = p.id
    return self:create_profile(string.format(self.t.copy_of, p.name), settings)
end

-- The entries of a game, or of the national view when game_id is "home".
function Screen:entries(profile, game_id)
    local key = table.concat({ profile.id, game_id, profile.gender, tostring(profile.forms), table.concat(profile.games, ",") }, "|")
    local list = self.entries_cache[key]
    if not list then
        if game_id == Games.HOME then
            list = Dex.national_entries(self.data, profile)
        else
            list = Dex.game_entries(self.data, Games.get(game_id), profile)
        end
        self.entries_cache[key] = list
    end
    return list
end

function Screen:state_fn(profile, game_id)
    local caps = self:caps(profile)
    if game_id == Games.HOME then
        return function(key)
            return (caps:national_state(profile, key))
        end
    end
    return function(key)
        return caps:state(game_id, key)
    end
end

-- Progress of a game (or "home"), kept until the profile's captures or settings change.
function Screen:progress(profile, game_id)
    local cache = self.progress_cache[profile.id]
    if not cache then
        cache = {}
        self.progress_cache[profile.id] = cache
    end
    if not cache[game_id] then
        local caps = self:caps(profile)
        cache[game_id] = caps:progress(self:entries(profile, game_id), self:state_fn(profile, game_id))
    end
    return cache[game_id]
end

-- What a tap on an entry does: marks it caught, or clears it, with undo.
function Screen:toggle(profile, game_id, entry)
    local caps = self:caps(profile)
    if game_id == Games.HOME then
        local state, where = caps:national_state(profile, entry.key)
        if state == "c" and where and where ~= Games.HOME then
            self:show_toast(string.format(self.t.caught_in_game, Games.name(Games.get(where), self.lang)))
            self:redraw()
            return
        end
    end
    local before, now_state = caps:toggle(game_id, entry.key, os.time())
    self:save_caps(profile)
    local name = self:entry_name(entry)
    local message = now_state == "c" and string.format(self.t.marked, name) or string.format(self.t.unmarked, name)
    self:show_toast(message, self.t.undo, function()
        caps:restore(game_id, before)
        self:save_caps(profile)
    end)
    self:redraw()
end

function Screen:set_state(profile, game_id, key, state)
    local caps = self:caps(profile)
    caps:apply(game_id, key, state, os.time())
    self:save_caps(profile)
    self:redraw()
end

-- Marks every member of an evolution line present in the game.
function Screen:mark_line(profile, game_id, species)
    local members = {}
    for _, m in ipairs(self.data:chain_members(species)) do
        members[m] = true
    end
    local caps = self:caps(profile)
    local count = 0
    for _, e in ipairs(self:entries(profile, game_id)) do
        if members[e.species] and not e.form and caps:state(game_id, e.key) ~= "c" then
            caps:apply(game_id, e.key, "c", os.time())
            count = count + 1
        end
    end
    self:save_caps(profile)
    self:show_toast(string.format(self.t.line_marked, count))
    self:redraw()
end

function Screen:edit_note(profile, game_id, key)
    local caps = self:caps(profile)
    local record = caps:record(game_id, key)
    local dialog
    dialog = InputDialog:new{
        title = self.t.note,
        input = record and record.n or "",
        buttons = { {
            { text = self.t.cancel, id = "close", callback = function() UIManager:close(dialog) end },
            { text = self.t.save, is_enter_default = true, callback = function()
                caps:set_note(game_id, key, dialog:getInputText())
                self:save_caps(profile)
                UIManager:close(dialog)
                self:redraw()
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Screen:edit_date(profile, game_id, key)
    local caps = self:caps(profile)
    local record = caps:record(game_id, key)
    if not record or not record.t then
        return
    end
    local DateTimeWidget = require("ui/widget/datetimewidget")
    local d = os.date("*t", record.t)
    UIManager:show(DateTimeWidget:new{
        year = d.year, month = d.month, day = d.day,
        -- The first games came out in 1996; the widget would start at 2021.
        year_min = 1996,
        year_max = math.max(d.year, os.date("*t").year),
        ok_text = self.t.save,
        title_text = self.t.caught_on,
        callback = function(time)
            local t = os.time{ year = time.year, month = time.month, day = time.day, hour = 12 }
            caps:set_time(game_id, key, t)
            self:save_caps(profile)
            self:redraw()
        end,
    })
end

---------------------------------------------------------------------------
-- Names and sprites of entries.
---------------------------------------------------------------------------

function Screen:entry_name(entry)
    local name = self.data:name(entry.species, self.lang)
    if entry.form then
        local f = self.data:form(entry.species, entry.form)
        if f then
            return self.data:form_name(f, self.lang)
        end
    end
    return name
end

-- The type charts, read when first needed.
function Screen:type_charts()
    if not self.types_info then
        self.types_info = Types.new(self.data:type_charts())
    end
    return self.types_info
end

-- The generation of a game, or nil for the national view (the newest type chart).
function Screen:game_gen(game_id)
    local game = game_id and game_id ~= Games.HOME and Games.get(game_id)
    return game and game.gen or nil
end

-- The types of an entry in a game: the ones it had there (Clefairy was Normal up to the 5th generation).
function Screen:entry_types(entry, game_id)
    return self:type_charts():of_pokemon(Dex.pokemon_id(self.data, entry), self:game_gen(game_id), Dex.types(self.data, entry))
end

function Screen:entry_info(entry, game_id)
    return {
        name = self:entry_name(entry),
        types = self:entry_types(entry, game_id),
        gen = self.data:generation(entry.species),
    }
end

-- The set of sprites a game shows for a profile, and whether it is the game's own (or chosen) set.
function Screen:set_for(profile, game_id)
    local game = game_id ~= Games.HOME and Games.get(game_id) or nil
    return self.sprites:set_for(game, profile.sets[game_id or Games.HOME])
end

function Screen:sprite_path(profile, game_id, entry)
    local set_id = self:set_for(profile, game_id)
    local stem, female = Dex.sprite_stem(self.data, entry)
    return self.sprites:resolve(stem, female, profile.shiny, set_id)
end

function Screen:species_sprite(profile, game_id, species)
    return self:sprite_path(profile, game_id, { species = species, key = tostring(species) })
end

---------------------------------------------------------------------------
-- Sprite downloads.
---------------------------------------------------------------------------

function Screen:download(set, variant)
    local id = Sprites.item_id(set, variant)
    local files = self.sprites:job_files(set, variant)
    if #files == 0 then
        return
    end
    self.sprites:make_dirs(set, variant)
    self.downloader:add{
        id = id,
        files = files,
        on_done = function(done, failed, total, cancelled, stopped)
            for _, folder in ipairs(SpriteSets.folders(set, variant)) do
                if folder then
                    self.sprites:forget(folder)
                end
            end
            SpriteCache.forget()
            if not cancelled then
                if stopped then
                    self:show_toast(self.t.download_stopped)
                elseif failed > 0 then
                    self:show_toast(string.format(self.t.download_failed, failed))
                else
                    self:show_toast(string.format(self.t.download_done, self:set_label(set, variant)))
                end
            end
        end,
    }
    self:keep_awake(true)
    self:tick()
end

-- The device stays awake while a download runs. Awake.set(false) is only called after a true, so a screen
-- opened without main.lua (the checks in tools/) closes without the awake module.
function Screen:keep_awake(on)
    if on or self.awake then
        Awake.set(on)
    end
    self.awake = on
end

function Screen:cancel_download(set, variant)
    self.downloader:cancel(Sprites.item_id(set, variant))
    self:redraw()
end

-- Every DOWNLOAD_TICK while a download runs. Through Sleep.schedule: due while the device sleeps, it waits
-- for it to wake up. The progress it draws is outside the refresh count, like a clock, so a long download
-- never brings a flash by itself.
function Screen:tick()
    Sleep.unschedule(self, self.tick_cb)
    local active = self.downloader:tick()
    if active then
        Sleep.schedule(self, DOWNLOAD_TICK, self.tick_cb)
    else
        self:keep_awake(false)
    end
    local view = self:current()
    if view and (view.kind == "sprites" or (view.kind == "browse" and view.watch_downloads)) then
        self:redraw_progress()
    end
end

function Screen:set_label(set, variant)
    local label
    if set.id == "base" then
        label = self.t.set_base
    elseif set.id == "gen7-icons" then
        label = self.t.set_gen7
    else
        label = Games.name(Games.get(set.game), self.lang)
    end
    if variant == "shiny" then
        label = string.format(self.t.set_shiny, label)
    end
    return label
end

function Screen:size_text(bytes)
    if bytes >= 1024 * 1024 then
        local mb = bytes / (1024 * 1024)
        return (string.format("%.1f MB", mb):gsub("%.", self.t.decimal))
    end
    return string.format("%d KB", math.max(1, math.floor(bytes / 1024 + 0.5)))
end

---------------------------------------------------------------------------
-- Dialogs.
---------------------------------------------------------------------------

function Screen:menu(title, items)
    local dialog
    local buttons = {}
    for _, item in ipairs(items) do
        buttons[#buttons + 1] = { {
            text = item.text,
            callback = function()
                UIManager:close(dialog)
                item.callback()
            end,
        } }
    end
    dialog = ButtonDialog:new{ title = title, title_align = "center", buttons = buttons }
    UIManager:show(dialog)
    return dialog
end

function Screen:confirm(text, ok_text, on_ok)
    UIManager:show(ConfirmBox:new{
        text = text,
        ok_text = ok_text,
        cancel_text = self.t.cancel,
        ok_callback = on_ok,
    })
end

function Screen:ask_text(title, value, on_ok)
    local dialog
    dialog = InputDialog:new{
        title = title,
        input = value or "",
        buttons = { {
            { text = self.t.cancel, id = "close", callback = function() UIManager:close(dialog) end },
            { text = self.t.ok, is_enter_default = true, callback = function()
                local text = dialog:getInputText()
                UIManager:close(dialog)
                on_ok(text)
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Screen:choose_language()
    local items = {}
    for _, lang in ipairs(LANGUAGES) do
        items[#items + 1] = { text = (lang[1] == self.lang and "✓ " or "") .. lang[2], callback = function()
            self:set_language(lang[1])
            self:save_settings()
            local view = self:current()
            if view.refresh then
                view:refresh()
            end
            -- The same layout in another language: an update without a flash, counted.
            self:redraw()
        end }
    end
    self:menu(self.t.language, items)
end

-- The filters of a game in a profile. They are checked once, then the same table is kept and changed.
function Screen:filters_of(profile, game_id)
    profile.filters = profile.filters or {}
    self.checked_filters = self.checked_filters or {}
    local f = profile.filters[game_id]
    if self.checked_filters[f or false] then
        return f
    end
    f = Filters.valid(f)
    profile.filters[game_id] = f
    self.checked_filters[f] = true
    return f
end

return Screen
