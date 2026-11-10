# Changelog

## [0.2.0]

- The sleep screen shows CatchInk's own cover when the device sleeps with the plugin open and KOReader's sleep screen is set to the book cover.
- The plugin opens in portrait even with KOReader in landscape, ignores rotation while open and gives the previous rotation back when it closes, also when opening fails.
- An opening that fails shows a warning instead of closing KOReader, and a view that fails to draw shows a message with a way back.
- The Back key of devices with keys goes back one view, and closes the plugin from the first one.
- A flash clears the ghosting after 8 updates without one, also while marking in a box. The progress of a download never flashes by itself.
- While a download runs, the power button puts the device to sleep again: it no longer uses the system setting that blocked the button and outlived a crash.
- Nothing is drawn and no timer runs while the device sleeps, also on wakeups of the system.
- Menus and dialogs opened right after marking a Pokémon showed under the plugin, out of sight, while the "Undo" message was on screen.
- Downloads use the same secure request in every plugin of Beater Studios (TLS 1.2 or newer, the name of the server checked), identified by the version of the plugin.
- The catches of each profile move to KOReader's settings folder (`koreader/settings/catchink_profile_<id>.lua`), next to `catchink.lua`. Saves of 0.1.0 open and move on the first opening.
- What a save holds is checked field by field: a profile that cannot be read is left out without taking the others with it, and games or sprite sets that no longer exist leave.
- The search without accents knows every accented capital of Latin-1.
- Texts say "device" instead of naming a brand of e-reader.
- The data is built from PokeAPI and PKHeX at fixed commits, with the files checked, and every release builds it again and stops if it differs from what is published.
- The packages without sprites and with shiny are now `catchink.koplugin-nosprites.zip` and `catchink.koplugin-shiny.zip`.

## [0.1.0]

First version.

- 27 games with their regional Pokédex, from Red / Blue to Legends: Z-A, with the DLCs under their game, and the national view joining every game of a profile.
- Profiles from a model (normal, shiny, alpha, Living Dex, custom): name, normal or shiny sprites, gender mode (simple, by looks, complete), forms (in each game and on the national view) and the games followed. A new profile can copy the catches of another; profiles can be edited, renamed, duplicated and deleted.
- Boxes of 30 and a list, paged with swipes and arrows. A tap marks or clears with undo, a hold opens the card. Not seen, seen, caught and unavailable, with the date of each catch and a note.
- Filters by generation, up to two types, status and category, search by name or number without accents, and three orders.
- A card in six pages: overview, stats and abilities, evolution chain with conditions and marking the whole line, forms in normal and shiny, where to find it and level-up moves in the game, and the games of the profile that have it.
- Progress by generation and by game, with the catches of the last 7 days.
- Three packages (decision of 2026-11-09): with the base sprite set (recommended), with the base set normal and shiny, or without sprites; whatever a package does not bring, and the sets of each game, are downloaded on the device from PokeAPI/sprites (box icons from Sun / Moon on), in three parallel parts, resumed after a cut, with the device kept awake. A notice when a game shows the base sprites, turned off for good with its X.
- Encounters of Brilliant Diamond and Shining Pearl (with the Grand Underground), Legends: Arceus (with alphas and outbreaks), Scarlet and Violet (with Kitakami and Blueberry) and Legends: Z-A (with Mega Dimension), from PKHeX.
- Forms counted in each game that has them: PKHeX's tables from Sword and Shield on, the game each form came in before.
- A game's sprite set downloads only the Pokémon of its Pokédex and their forms.
- The chance of each encounter on the card: from PokeAPI for the older games (the highest across morning, day and night, not their sum) and from Serebii for Brilliant Diamond and Shining Pearl.
- Place names in Spanish for the older games, from PKHeX's lists, and the official English names instead of PokeAPI's old area names ("Route 201", not "Road 201").
- Data from PokeAPI built into the package, with Portuguese Pokédex texts, genus, ability texts and form names translated by Beater Studios, and the Spanish texts PokeAPI lacks (generation 9 Pokédex texts, ability texts and form names).
- Alpha profiles show the Alpha symbol in the corner of each Pokémon.
- Sprites are decoded with lodepng, which keeps their transparency on the device.
- The national view of a profile with only some games counts the Pokémon of those games.
- Every gesture stops at the plugin, so nothing under it (the file browser, PlainUI) reacts.
- Nothing is drawn while the device sleeps, so the plugin never shows over the sleep screen with the touch blocked.
- Interface in Portuguese, English and Spanish.
