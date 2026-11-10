-- Sprite sets: folders of PokeAPI/sprites that can be downloaded. Each set has a normal and, when the
-- folder exists, a shiny variant; female folders come along with their variant.
local SpriteSets = {}

local V = "versions/"

SpriteSets.LIST = {
    { id = "base", label = "base", normal = "", female = "female", shiny = "shiny", shiny_female = "shiny/female" },
    { id = "red-blue", game = "red-blue", normal = V .. "generation-i/red-blue/transparent/gray", gray = true },
    { id = "yellow", game = "yellow", normal = V .. "generation-i/yellow/transparent/gray", gray = true },
    { id = "gold", game = "gold-silver", normal = V .. "generation-ii/gold/transparent", shiny = V .. "generation-ii/gold/transparent/shiny" },
    { id = "crystal", game = "crystal", normal = V .. "generation-ii/crystal/transparent", shiny = V .. "generation-ii/crystal/transparent/shiny" },
    { id = "ruby-sapphire", game = "ruby-sapphire", normal = V .. "generation-iii/ruby-sapphire", shiny = V .. "generation-iii/ruby-sapphire/shiny" },
    { id = "emerald", game = "emerald", normal = V .. "generation-iii/emerald", shiny = V .. "generation-iii/emerald/shiny" },
    { id = "firered-leafgreen", game = "firered-leafgreen", normal = V .. "generation-iii/firered-leafgreen", shiny = V .. "generation-iii/firered-leafgreen/shiny" },
    { id = "diamond-pearl", game = "diamond-pearl", normal = V .. "generation-iv/diamond-pearl", female = V .. "generation-iv/diamond-pearl/female", shiny = V .. "generation-iv/diamond-pearl/shiny", shiny_female = V .. "generation-iv/diamond-pearl/shiny/female" },
    { id = "platinum", game = "platinum", normal = V .. "generation-iv/platinum", female = V .. "generation-iv/platinum/female", shiny = V .. "generation-iv/platinum/shiny", shiny_female = V .. "generation-iv/platinum/shiny/female" },
    { id = "heartgold-soulsilver", game = "heartgold-soulsilver", normal = V .. "generation-iv/heartgold-soulsilver", female = V .. "generation-iv/heartgold-soulsilver/female", shiny = V .. "generation-iv/heartgold-soulsilver/shiny", shiny_female = V .. "generation-iv/heartgold-soulsilver/shiny/female" },
    { id = "black-white", game = "black-white", normal = V .. "generation-v/black-white", female = V .. "generation-v/black-white/female", shiny = V .. "generation-v/black-white/shiny", shiny_female = V .. "generation-v/black-white/shiny/female" },
    { id = "x-y", game = "x-y", normal = V .. "generation-vi/x-y", female = V .. "generation-vi/x-y/female", shiny = V .. "generation-vi/x-y/shiny", shiny_female = V .. "generation-vi/x-y/shiny/female" },
    { id = "omega-ruby-alpha-sapphire", game = "omega-ruby-alpha-sapphire", normal = V .. "generation-vi/omega-ruby-alpha-sapphire", female = V .. "generation-vi/omega-ruby-alpha-sapphire/female", shiny = V .. "generation-vi/omega-ruby-alpha-sapphire/shiny", shiny_female = V .. "generation-vi/omega-ruby-alpha-sapphire/shiny/female" },
    { id = "gen7-icons", game = "ultra-sun-ultra-moon", label = "gen7", icons = true, normal = V .. "generation-vii/icons", female = V .. "generation-vii/icons/female" },
    { id = "lets-go", game = "lets-go", icons = true, normal = V .. "generation-vii/lets-go-pikachu-lets-go-eevee/icons" },
    { id = "sword-shield", game = "sword-shield", icons = true, normal = V .. "generation-viii/sword-shield/icons", female = V .. "generation-viii/sword-shield/icons/female" },
    { id = "brilliant-diamond-shining-pearl", game = "brilliant-diamond-shining-pearl", icons = true, normal = V .. "generation-viii/brilliant-diamond-shining-pearl/icons" },
    { id = "legends-arceus", game = "legends-arceus", icons = true, normal = V .. "generation-viii/legends-arceus/icons", female = V .. "generation-viii/legends-arceus/icons/female", shiny = V .. "generation-viii/legends-arceus/icons/shiny" },
    { id = "scarlet-violet", game = "scarlet-violet", icons = true, normal = V .. "generation-ix/scarlet-violet/icons", female = V .. "generation-ix/scarlet-violet/icons/female" },
    { id = "legends-za", game = "legends-za", icons = true, normal = V .. "generation-ix/legends-za/icons", female = V .. "generation-ix/legends-za/icons/female", shiny = V .. "generation-ix/legends-za/icons/shiny" },
}

SpriteSets.BY_ID = {}
for index, set in ipairs(SpriteSets.LIST) do
    set.index = index
    SpriteSets.BY_ID[set.id] = set
end

function SpriteSets.get(id)
    return SpriteSets.BY_ID[id]
end

-- The folders a variant ("normal" or "shiny") downloads.
function SpriteSets.folders(set, variant)
    if variant == "shiny" then
        return { set.shiny, set.shiny_female }
    end
    return { set.normal, set.female }
end

function SpriteSets.has_variant(set, variant)
    return variant ~= "shiny" or set.shiny ~= nil
end

-- Every downloadable item: { set, variant }, base first.
function SpriteSets.items()
    local items = {}
    for _, set in ipairs(SpriteSets.LIST) do
        items[#items + 1] = { set = set, variant = "normal" }
        if set.shiny then
            items[#items + 1] = { set = set, variant = "shiny" }
        end
    end
    return items
end

return SpriteSets
