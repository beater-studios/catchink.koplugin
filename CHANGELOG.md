# Changelog

## [0.2.0]

- Sprite sets download about five times faster on the Kindle: each part of a download keeps one connection open for all its files and reads the list of trusted certificates once, instead of doing both for every file. Black / White went from 224 s to 41 s.
- The card has a seventh page, Types: what the Pokémon is weak to and resists, and what the moves of its types do, in the type chart of the game's generation and with the types it had in that game (Clefairy is Normal in the older games).
- A full type chart for each generation (the 1st, the 2nd to the 5th, the 6th onwards), opened from the card or from the menu of the home screen, with the summary of each type.
- Every type has its icon, on the card, the list, the moves, the filters and the chart.
- The list, the card and the type filter of a game show the types the Pokémon had in that game.

## [0.1.0]

First version.

- 27 games with their regional Pokédex, from Red / Blue to Legends: Z-A, with the DLCs under their game, and the national view joining every game of a profile.
- Profiles from a model (normal, shiny, alpha, Living Dex, custom): name, normal or shiny sprites, gender mode (simple, by looks, complete), forms (in each game and on the national view) and the games followed. A new profile can copy the catches of another; profiles can be edited, renamed, duplicated and deleted.
- Boxes of 30 and a list, paged with swipes and arrows. A tap marks or clears with undo, a hold opens the card. Not seen, seen, caught and unavailable, with the date of each catch and a note.
- Filters by generation, up to two types, status and category, search by name or number without accents, and three orders.
- A card in six pages: overview, stats and abilities, evolution chain with conditions and marking the whole line, forms in normal and shiny, where to find it and level-up moves in the game, and the games of the profile that have it.
- Progress by generation and by game, with the catches of the last 7 days.
- Three packages: `catchink.koplugin.zip` with the base sprite set (recommended), `catchink.koplugin-shiny.zip` with the base set normal and shiny, and `catchink.koplugin-nosprites.zip` without sprites. Whatever a package does not bring, and the sets of each game, are downloaded on the device from PokeAPI/sprites (box icons from Sun / Moon on), in three parallel parts, resumed after a cut, over a secure connection that checks the name of the server. A notice when a game shows the base sprites, turned off for good with its X.
- The device stays awake while sprites download, and the power button still puts it to sleep.
- Encounters of Brilliant Diamond and Shining Pearl (with the Grand Underground), Legends: Arceus (with alphas and outbreaks), Scarlet and Violet (with Kitakami and Blueberry) and Legends: Z-A (with Mega Dimension), from PKHeX.
- Forms counted in each game that has them: PKHeX's tables from Sword and Shield on, the game each form came in before.
- A game's sprite set downloads only the Pokémon of its Pokédex and their forms.
- The chance of each encounter on the card: from PokeAPI for the older games (the highest across morning, day and night, not their sum) and from Serebii for Brilliant Diamond and Shining Pearl.
- Place names in Spanish for the older games, from PKHeX's lists, and the official English names instead of PokeAPI's old area names ("Route 201", not "Road 201").
- Data from PokeAPI built into the package, with Portuguese Pokédex texts, genus, ability texts and form names translated by Beater Studios, and the Spanish texts PokeAPI lacks (generation 9 Pokédex texts, ability texts and form names). The data is built from PokeAPI and PKHeX at fixed commits, and every release builds it again and checks it.
- Alpha profiles show the Alpha symbol in the corner of each Pokémon.
- Sprites are decoded with lodepng, which keeps their transparency on the device.
- The national view of a profile with only some games counts the Pokémon of those games.
- Its own sleep screen: when the device sleeps with the plugin open and KOReader's sleep screen shows the book cover, CatchInk's cover shows instead.
- Always in portrait, even with KOReader in landscape, giving the previous rotation back on close.
- An opening that fails shows a warning instead of closing KOReader, and a view that fails to draw shows a message with a way back. A save that cannot be read in part never stops the plugin from opening.
- The Back key of devices with keys goes back one view, and closes the plugin from the first one.
- A flash clears the ghosting after 8 updates without one; the progress of a download never flashes by itself.
- Every gesture stops at the plugin, so nothing under it (the file browser, PlainUI) reacts.
- Nothing is drawn and no timer runs while the device sleeps, so the plugin never shows over the sleep screen with the touch blocked.
- Interface in Portuguese, English and Spanish.
