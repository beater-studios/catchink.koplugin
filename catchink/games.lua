-- The games CatchInk tracks: their Pokédex lists, versions, move data and sprite set.
-- dex: PokeAPI pokedex ids, shown one after the other; a species in more than one counts once.
-- vg: version group of the level-up moves; versions: of the encounters and the Pokédex texts.
-- dlc_of: the base game of an expansion, listed under it.
local Games = {}

Games.LIST = {
    { id = "red-blue", en = "Red / Blue", es = "Rojo / Azul", gen = 1, vg = 1, versions = { 1, 2 }, dex = { 2 }, set = "red-blue", region = "Kanto" },
    { id = "yellow", en = "Yellow", es = "Amarillo", gen = 1, vg = 2, versions = { 3 }, dex = { 2 }, set = "yellow", region = "Kanto" },
    { id = "gold-silver", en = "Gold / Silver", es = "Oro / Plata", gen = 2, vg = 3, versions = { 4, 5 }, dex = { 3 }, set = "gold", region = "Johto" },
    { id = "crystal", en = "Crystal", es = "Cristal", gen = 2, vg = 4, versions = { 6 }, dex = { 3 }, set = "crystal", region = "Johto" },
    { id = "ruby-sapphire", en = "Ruby / Sapphire", es = "Rubí / Zafiro", gen = 3, vg = 5, versions = { 7, 8 }, dex = { 4 }, set = "ruby-sapphire", region = "Hoenn" },
    { id = "emerald", en = "Emerald", es = "Esmeralda", gen = 3, vg = 6, versions = { 9 }, dex = { 4 }, set = "emerald", region = "Hoenn" },
    { id = "firered-leafgreen", en = "FireRed / LeafGreen", es = "Rojo Fuego / Verde Hoja", gen = 3, vg = 7, versions = { 10, 11 }, dex = { 2 }, set = "firered-leafgreen", region = "Kanto" },
    { id = "diamond-pearl", en = "Diamond / Pearl", es = "Diamante / Perla", gen = 4, vg = 8, versions = { 12, 13 }, dex = { 5 }, set = "diamond-pearl", region = "Sinnoh" },
    { id = "platinum", en = "Platinum", es = "Platino", gen = 4, vg = 9, versions = { 14 }, dex = { 6 }, set = "platinum", region = "Sinnoh" },
    { id = "heartgold-soulsilver", en = "HeartGold / SoulSilver", es = "Oro HeartGold / Plata SoulSilver", gen = 4, vg = 10, versions = { 15, 16 }, dex = { 7 }, set = "heartgold-soulsilver", region = "Johto" },
    { id = "black-white", en = "Black / White", es = "Negro / Blanco", gen = 5, vg = 11, versions = { 17, 18 }, dex = { 8 }, set = "black-white", region = "Unova" },
    { id = "black2-white2", en = "Black 2 / White 2", es = "Negro 2 / Blanco 2", gen = 5, vg = 14, versions = { 21, 22 }, dex = { 9 }, set = "black-white", region = "Unova" },
    { id = "x-y", en = "X / Y", es = "X / Y", gen = 6, vg = 15, versions = { 23, 24 }, dex = { 12, 13, 14 }, set = "x-y", region = "Kalos" },
    { id = "omega-ruby-alpha-sapphire", en = "Omega Ruby / Alpha Sapphire", es = "Rubí Omega / Zafiro Alfa", gen = 6, vg = 16, versions = { 25, 26 }, dex = { 15 }, set = "omega-ruby-alpha-sapphire", region = "Hoenn" },
    { id = "sun-moon", en = "Sun / Moon", es = "Sol / Luna", gen = 7, vg = 17, versions = { 27, 28 }, dex = { 16 }, set = "gen7-icons", region = "Alola" },
    { id = "ultra-sun-ultra-moon", en = "Ultra Sun / Ultra Moon", es = "Ultrasol / Ultraluna", gen = 7, vg = 18, versions = { 29, 30 }, dex = { 21 }, set = "gen7-icons", region = "Alola" },
    { id = "lets-go", en = "Let's Go, Pikachu! / Eevee!", es = "Let's Go, Pikachu! / Eevee!", gen = 7, vg = 19, versions = { 31, 32 }, dex = { 26 }, set = "lets-go", region = "Kanto" },
    { id = "sword-shield", en = "Sword / Shield", es = "Espada / Escudo", gen = 8, vg = 20, versions = { 33, 34 }, dex = { 27 }, set = "sword-shield", region = "Galar" },
    { id = "isle-of-armor", en = "The Isle of Armor", es = "La isla de la armadura", gen = 8, vg = 21, versions = { 35, 50 }, dex = { 28 }, set = "sword-shield", region = "Galar", dlc_of = "sword-shield" },
    { id = "crown-tundra", en = "The Crown Tundra", es = "Las nieves de la corona", gen = 8, vg = 22, versions = { 36, 51 }, dex = { 29 }, set = "sword-shield", region = "Galar", dlc_of = "sword-shield" },
    { id = "brilliant-diamond-shining-pearl", en = "Brilliant Diamond / Shining Pearl", es = "Diamante Brillante / Perla Reluciente", gen = 8, vg = 23, versions = { 37, 38 }, dex = { 5 }, set = "brilliant-diamond-shining-pearl", region = "Sinnoh" },
    { id = "legends-arceus", en = "Legends: Arceus", es = "Leyendas: Arceus", gen = 8, vg = 24, versions = { 39 }, dex = { 30 }, set = "legends-arceus", region = "Hisui", alphas = true },
    { id = "scarlet-violet", en = "Scarlet / Violet", es = "Escarlata / Púrpura", gen = 9, vg = 25, versions = { 40, 41 }, dex = { 31 }, set = "scarlet-violet", region = "Paldea" },
    { id = "teal-mask", en = "The Teal Mask", es = "La máscara turquesa", gen = 9, vg = 26, versions = { 42, 52 }, dex = { 32 }, set = "scarlet-violet", region = "Kitakami", dlc_of = "scarlet-violet" },
    { id = "indigo-disk", en = "The Indigo Disk", es = "El disco índigo", gen = 9, vg = 27, versions = { 43, 53 }, dex = { 33 }, set = "scarlet-violet", region = "Blueberry", dlc_of = "scarlet-violet" },
    { id = "legends-za", en = "Legends: Z-A", es = "Leyendas: Z-A", gen = 9, vg = 30, versions = { 47 }, dex = { 34 }, set = "legends-za", region = "Lumiose", alphas = true },
    { id = "mega-dimension", en = "Mega Dimension", es = "Megadimensión", gen = 9, vg = 31, versions = { 48 }, dex = { 35 }, set = "legends-za", region = "Lumiose", dlc_of = "legends-za", alphas = true },
}

-- The national view, and the place for catches marked straight on it.
Games.HOME = "home"

Games.BY_ID = {}
for index, game in ipairs(Games.LIST) do
    game.index = index
    Games.BY_ID[game.id] = game
end

function Games.get(id)
    return Games.BY_ID[id]
end

function Games.name(game, lang)
    if not game then
        return ""
    end
    return lang == "es" and game.es or game.en
end

function Games.all_ids()
    local ids = {}
    for i, game in ipairs(Games.LIST) do
        ids[i] = game.id
    end
    return ids
end

function Games.alpha_ids()
    local ids = {}
    for _, game in ipairs(Games.LIST) do
        if game.alphas then
            ids[#ids + 1] = game.id
        end
    end
    return ids
end

-- The ids of a list, in the order of Games.LIST, without unknown ones.
function Games.ordered(ids)
    local wanted = {}
    for _, id in ipairs(ids or {}) do
        wanted[id] = true
    end
    local out = {}
    for _, game in ipairs(Games.LIST) do
        if wanted[game.id] then
            out[#out + 1] = game.id
        end
    end
    return out
end

-- Entries of a game's Pokédex: { { number = n, species = id, dex = pokedex id } }, each species once.
function Games.dex_entries(game, dex_lists)
    local out, seen = {}, {}
    local offset = 0
    for _, dex_id in ipairs(game.dex) do
        local list = dex_lists[dex_id] or {}
        local top = 0
        for _, pair in ipairs(list) do
            local number, species = pair[1], pair[2]
            if not seen[species] then
                seen[species] = true
                out[#out + 1] = { number = number + offset, species = species, dex = dex_id }
            end
            if number > top then
                top = number
            end
        end
        if #game.dex > 1 then
            offset = offset + top
        end
    end
    return out
end

return Games
