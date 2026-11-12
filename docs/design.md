# CatchInk: design and tools

How the plugin works inside, for anyone who wants to understand the code or change it. To install and use it, see the [README](../README.md). A Beater Studios Pokédex tracker for KOReader, made for e-ink. `catchink` is the plugin identifier. It takes its decisions from [CatchBox](https://github.com/davydmaker/catchbox), the web tracker, but it is a separate product and does not exchange progress with it.

## Status

- **0.1.0 (not published):** profiles with models (normal, shiny, alpha, Living Dex, custom), 27 games with their regional Pokédex (DLCs listed under their game), the national view, boxes of 30 and a list, filters and search, a six-page card, progress, sprite sets downloaded on the device, and the interface in Portuguese, English and Spanish. Since 2026-11-10 it also has the shared patterns of the plugins of Beater Studios (sleep screen cover, portrait, refresh counter, pause while asleep, awake, HTTPS, saved state, texts, letters, data validation, emulator scripts, random touches, packaging and CI). Tested in the desktop emulator; a build from before the patterns runs on the author's Kindle.

## Data

The data comes from PokeAPI, with PKHeX for what PokeAPI lacks (below), built on the computer by `tools/build_data.py` from the CSV files of the [PokeAPI/pokeapi](https://github.com/PokeAPI/pokeapi) repository (BSD-3-Clause), so the device never queries the API: thousands of requests over a slow Wi-Fi that turns off when the device sleeps would not work.

| File | What it holds |
|---|---|
| `data/index.lua` | Every species (name, generation, types, flags, gender rate, chain), Spanish names that differ, the forms of each species and the Pokédex lists. Kept in memory. |
| `data/species/<id>.lua` | The card of one species: size, catch rate, egg groups, stats, abilities, genus and Pokédex texts (English and Spanish per version, one Portuguese text), the evolution chain with its conditions, level-up moves per version group and encounters per version. Loaded when a card opens, with a cache of 12. |
| `data/moves.lua`, `abilities.lua`, `items.lua`, `places.lua` | Names in English and Spanish (and ability texts in Portuguese), only for what the cards use. |
| `data/sprites.lua` | The sprite folders at a fixed commit of PokeAPI/sprites: the file names of each one and their average size. |

Building, from the plugin folder:

```sh
sh tools/fetch_sources.sh /tmp/catchink-sources          # a new, empty folder
python3 -I tools/build_data.py /tmp/catchink-sources/pokeapi/data/v2/csv --out data --pkhex /tmp/catchink-sources/pkhex/PKHeX.Core
python3 tools/fetch_sprite_manifest.py tools/sources/sprites_manifest.json   # only to move the sprites to another commit; needs the GitHub CLI
```

`tools/fetch_sources.sh` downloads PokeAPI and PKHeX at fixed commits (`POKEAPI_COMMIT` and `PKHEX_COMMIT` in the script), only the folders the generator reads, and checks the 129 files it reads against `tools/sources.sha256`. The folder must be new and empty, and nothing downloaded is run. The commits are the ones that built the published data: building from them gives `data/` byte for byte (checked on 2026-11-10 with Python 3.9, 3.13 and 3.14). The sprite list (`tools/sources/sprites_manifest.json`) and Serebii's chances (`tools/sources/serebii_bdsp.json`) are kept in the repository, so building needs no other download.

`--sources <dir>` writes the English and Spanish texts to translate. The Portuguese texts are in `tools/translations/pt` (one Pokédex text and genus per species, ability texts and form names), translated by Beater Studios from English, since PokeAPI has no Portuguese text. Everything translated to Portuguese also exists in Spanish: what PokeAPI lacks in Spanish (the Pokédex text and genus of 127 species of generation 9, 64 ability texts and 148 form names) is translated in `tools/translations/es`, and a test checks it. Names of moves, abilities, items and places stay in English when the interface is in Portuguese, as the official ones; in Spanish they come from PokeAPI.

Two data errors are handled by the builder: an ability text shared by two abilities is left out (Queenly Majesty had Gulp Missile's text), and old games' "POKéMON" becomes "Pokémon". Em and en dashes of the source texts become commas (or hyphens inside place names), as everywhere in the project.

**PKHeX** (`tools/pkhex.py`, with `--pkhex <PKHeX.Core folder>` from a sparse clone of [kwsch/PKHeX](https://github.com/kwsch/PKHeX), GPL-3.0) fills what PokeAPI lacks:

- **Encounters** of Brilliant Diamond and Shining Pearl (overworld, rods, honey trees and the Grand Underground), Legends: Arceus (with alphas and outbreaks), Scarlet and Violet (wild and fixed; locations 132 to 171 are Kitakami, 172 to 200 Blueberry) and Legends: Z-A (with Hyperspace for Mega Dimension), read from the `encounter_*.pkl` files of `Resources/legality/wild` in the formats of `EncounterArea8b`, `8a`, `9`, `9a` and `EncounterFixed9`, plus the static encounters and gifts written in the C# lists of `Legality/Encounters/Data`. Place names come from `Resources/text/locations` in English and Spanish; places with the same name become one.
- **Chances of Brilliant Diamond and Shining Pearl** (`tools/serebii.py`, credited in the plugin): Serebii's Pokéarth pages of Sinnoh are those games' own, with the percent of each Pokémon by version and method (walking, surfing, each rod, honey trees). The script caches the pages, fetches one every 1.5 s and keeps the highest percent of a place across its areas and times of day; `tools/sources/serebii_bdsp.json` holds the result, joined to PKHeX's encounters by place name. About 80% of the wild encounters get a chance; Poké Radar, swarms and daily encounters are listed apart on Serebii and cannot be told apart in PKHeX, and Serebii has no page for Mt. Coronet. Serebii has no chances for Legends: Arceus, Scarlet and Violet or Legends: Z-A. For the older games, PokeAPI's chance of a Pokémon in a place is the sum of its slots under the same conditions, and the highest of those sums (morning, day and night are not added).
- **Spanish place names of the older games:** PokeAPI has Spanish for few places, so the builder takes the official names from every location list of PKHeX, matched by the English name (ignoring case and apostrophes; "Sea Route" as "Route"), with the part that tells areas apart ("1F", "south, towards Jubilife City", "Max Den A") translated. A few names PKHeX lacks are in `tools/translations/es/places.json`. PokeAPI's own area names are old ("Road 201"), so the English name is the official location name plus that part. What is left in English is from Colosseum and XD, which the plugin does not show, or official names that are the same in Spanish (Mt. Moon, S.S. Anne). Altering Cave (Cueva Cambiante) and Nature Sanctuary (Reserva Natural, called Nature Preserve in the games) were checked against PKHeX and WikiDex. These encounters have levels but no chance; Brilliant Diamond and Shining Pearl get theirs from Serebii (below). Tera Raids and distributions are left out by decision of the user (2026-11-09); the Sword and Shield tables come from PokeAPI.
- **Forms of each game** from Sword and Shield on: the `IsPresentInGame` flag of each form in `Resources/byte/personal`. PKHeX numbers the forms of a species as PokeAPI's form order, Gigantamax aside (checked by matching the types of every form present in Scarlet and Violet: 242 of 246, the other 4 are Ogerpon's Terastal forms, which PokeAPI does not list). Before Sword and Shield, a form counts from the version group it came in. Moves of a game without data fall back on its base game (for a DLC) or on the closest earlier game, with a note.

## Sprites

The sprites are copyright The Pokémon Company. `tools/package.sh` builds three packages, by decision of the user on 2026-11-09: `catchink.koplugin.zip` with the base set (`sprites/base` and `female`, recommended), `catchink.koplugin-shiny.zip` with it and base shiny (`shiny`, `shiny_female`), and `catchink.koplugin-nosprites.zip` without sprites (`tools/fetch_base_sprites.py` fills `sprites/`). The plugin sees which folders came (`Sprites.bundled_in`), shows them as included and offers the rest as downloads; each device downloads the other sets its owner wants from `raw.githubusercontent.com/PokeAPI/sprites/<commit>/`, the only host the worker accepts, through the HTTPS pattern (`https_request.lua` and `tls.lua`): TLS 1.2 or newer, the name of the server checked on any KOReader version, no proxy, no redirects, and a `user-agent` with the version.

- **Base:** the default PokeAPI sprites, every species and form (1,541 files, about 2 MB), with the female folder; base shiny is another item. What a package brings shows as included, with nothing to download or delete.
- **Per game:** only the Pokémon of the Pokédex lists of the games that use the set, with their forms (the folders of the newer games hold the whole national Pokédex). The original sprites of each game up to X / Y and Omega Ruby / Alpha Sapphire (Red / Blue and Yellow in gray). From Sun / Moon on, the game sprites in PokeAPI are animated and too big for the device (Scarlet / Violet has 1.6 GB), so those games use their box icons, which are PNG and a few MB. Black 2 / White 2 uses the Black / White set, Sun / Moon and Ultra Sun / Ultra Moon share the generation 7 icons, and DLCs use their game's set.
- **Choice:** a game shows the set chosen for it, else its own set when downloaded, else the base. A missing file falls back on the base, and a shiny that a set does not have on the base shiny. Without any file, a dashed placeholder with the number.
- **Notice:** when a game shows the base because its own set is not on the device, a notice says so on the first box of the visit, with "Change set" and "Download". The X turns it off for good; the Sprites screen turns it back on.
- **Downloads** (`net/downloader.lua`, `net/worker.lua`): a set is split among three child processes (the time goes into connections, not the CPU), each writing "done failed total" to a progress file the screen reads every 1.5 s. Files go to `<name>.part` and are renamed when complete, so a cut download resumes where it stopped. Finished and killed children are collected (`waitpid`), so none is left as a zombie. Each file has two tries; after 8 failures in a row (no Wi-Fi, the server down) a part gives up and the screen says there is no connection, instead of waiting 30 s per try on every file. What came down stays, and "Resume the download" fetches only what is missing. If PokeAPI/sprites ever went away, the plugin keeps working with what is on the device (the data never needs the network); a new version would only have to point the downloads elsewhere. Each file is one `Request.run` of the HTTPS pattern, called inside the part's child process, so the batch of a part keeps its own process instead of one per file; `https_main.lua` comes with the pattern and is not used. The work folder (`koreader/catchink/work`) is private (`chmod 700`) and emptied when the screen opens, so lists left by a crash go. On macOS a forked child cannot use the network, so each part runs as its own `luajit` program (`net/worker_main.lua`). The device stays awake while a download runs, with the awake pattern (`awake.lua`): KOReader's auto suspend is paused and, on a Kindle, the idle timer of the system is reset every 4 minutes, so the power button still puts the device to sleep. While charging the timer is not reset, as in KOReader, so a download of more than about 10 minutes without a touch can be cut by the sleep screen; it resumes later. Closing the plugin stops the downloads; what came down stays. Measured on the Kindle on 2026-11-12, over Wi-Fi: Red / Blue (151 files) in 82 s and Black / White (408 files) in 224 s, about 0.55 s per file with the three parts, so a set with the whole national Pokédex takes around 10 minutes.
- **Drawing** (`ui/sprite_cache.lua`): files are decoded with lodepng (`ffi/png`), because the image renderer of the stable KOReader on the device returned these PNGs without transparency, over white. Pixels are written straight in the buffers' memory (`getPixelP`), never as one color object per pixel, to spare the garbage collector of the device. A file is trimmed to its drawing, enlarged by whole steps without smoothing (pixel art stays sharp) or reduced smoothly when too big, turned to gray with a little more contrast, and kept in four modes: color, silhouette (missing), lighter (seen) and faint (unavailable). A cache of 120 pictures. Measured on the Kindle on 2026-11-12, with a 76 by 76 box as in the boxes view, over three runs with the JIT on and off (the same times): a box of 30 sprites not yet in the cache takes 105 to 160 ms (most for the first box, all caught, in color), a box already in the cache 3 to 7 ms, and the 120 pictures of a full cache add about 1.7 MB to the process.

## Model

- **Entries** (`dex.lua`): one thing to catch. Keys are `25` for a species, `25_m` and `25_f` for its genders, `25:alola` for a form. The gender mode of the profile splits species: "simple" never, "by looks" those with gender differences, "complete" every species with both sexes. When the profile counts forms, each game lists the forms it has (`index.game_forms`) and the national view all of them, only those kept outside battle (no Mega Evolution, Gigantamax or battle forms). On a card, a form the game does not have says so. A game's Pokédex joins its lists (Kalos has three) with growing numbers, each species once.
- **Captures** (`profiles.lua`): per profile and game, `{ s = "c" | "s" | "u", t = time, n = note }`. A gendered key falls back on its species, and a species counts as caught when both genders are, so changing the gender mode keeps the progress. The national state joins every game of the profile and `home`, where catches marked straight on the national view go. A tap marks caught or clears (keeping the note), with undo. Unavailable entries leave the total.
- **Profiles:** the list and the settings in `koreader/settings/catchink.lua` (`version`, `lang`, `profiles`, `banner_off`, `last_profile_id`); the captures of each profile in `koreader/settings/catchink_profile_<id>.lua` (`version`, `captures`), written after each change. Builds of 0.1.0 from before 2026-11-10 kept the captures in `koreader/catchink/profile_<id>.lua`; they move, with KOReader's `.old` backup, when the screen opens. Ids are never handed out again (`last_profile_id`, never below an id in use), and deleting a profile removes its file and the `.old` backup (`SavedState.remove_file`), because KOReader reads that backup when the file is missing. A duplicate gets its own copies of filters and sprite choices.
- **Reading a save** (`state.lua`, plain Lua, with the saved state pattern): the language through `one_of`; each profile on its own through `SavedState.restore` and `Profiles.valid`, so one that breaks is left out with a warning and the others open; a model or gender mode that no longer exists falls back, and games and sprite sets that left the content leave. Repeated ids keep the first. Captures go through `Captures.new`, which keeps only well-formed records. `version` is 1; a file without it is read as 1. `tests/state_spec.lua` has the five tests of the pattern, with a real save in `tests/saves/0.1.0/`, made in the emulator with the code of 0.1.0 from before 2026-11-10 (the build on the author's Kindle).
- **Setting a state** (`Captures:apply`): a gender caught through its species splits the species into its two genders first, so changing one keeps the other; a species shown through its genders replaces them. Taps and the card's selector both go through it, and the undo puts back every key it touched. Sprites in `koreader/catchink/sprites/`.

## Code

| File | What it does |
|---|---|
| `games.lua` | The 27 games: Pokédex lists, versions, version group, sprite set, region. |
| `state.lua` | Reading the settings and the captures back from disk. |
| `sprite_sets.lua` | The downloadable sets and their folders. |
| `data.lua` | Reads the data files. |
| `dex.lua` | Entries of a game or of the national view, keys, types and sprite names. |
| `profiles.lua` | Models, profiles and captures. |
| `filters.lua` | Filters, search without accents and order. |
| `text.lua` | Numbers, dates, names and evolution conditions in the player's language. |
| `sprites.lua` | Sets on the device, what shows an entry, what a download fetches, deleting. |
| `net/` | Downloads in child processes. |
| `screensaver.lua`, `portrait.lua`, `refresh.lua`, `sleep.lua`, `awake.lua`, `https_request.lua`, `tls.lua`, `https_main.lua`, `saved_state.lua`, `letters.lua` | Copies of the shared patterns, never edited here. |
| `ui/draw.lua`, `ui/look.lua` | Drawing helpers (from Matkeeper) and the look: header, bars, pills, cards, marks. |
| `ui/surface.lua` | The screen as one drawing with touch areas, taps, holds and swipes. |
| `ui/screen.lua` | The state and the navigation between views, downloads and dialogs. |
| `ui/views/` | Home, profile form, games, boxes and list, filters, card, progress, sprites, about, games checklist. |

The screen is drawn straight into the blitbuffer and marks its touch areas as it draws, like Matkeeper; menus and text input use KOReader's own dialogs. The surface stops every gesture (`stop_events_propagation`): before, a gesture it did not use (a hold release, a pan) went on to what is under it, and PlainUI opened its Books menu inside the plugin. Lists page instead of scrolling, with arrows and swipes.

- **Refresh** (`refresh.lua`): every view has the same layout, so all of them are one kind (`view`) of one counter with a limit of 8: opening the plugin flashes, then a change inside a view or a move to another view is an update without a flash, and the ninth one in a row flashes. The progress of a download is outside the count (`redraw_progress`), like a clock. Changing the language keeps the layout and does not flash. Waking up flashes, and closing the plugin asks for a full refresh of what is behind.
- **Sleep screen** (`screensaver.lua`, installed when `main.lua` loads): with the sleep screen set to the book cover and the plugin on top, `assets/screensaver.png` shows instead. The cover is drawn by `tools/make_assets.py` (the logo, the name and a box of numbered entries, no Pokémon and no logo of the games), at 1200x1600 in 16 grays.
- **Portrait** (`portrait.lua`): the screen opens in portrait, ignores rotation and gives the previous rotation back on close; the opening (`setup_screen`) runs inside `Portrait.open`, so a failure gives the rotation back. The menu opens the screen with `pcall` and shows `open_failed` in the reader's language. A view that fails to draw is replaced by `draw_failed` and a tap goes back to the first view.
- **While the device sleeps** (`sleep.lua`): `Sleep.watch` in the surface; the toast and the download tick are scheduled with `Sleep.schedule` and the screen paints through `Sleep.dirty`, so nothing is drawn and no timer runs between `Suspend` and the sleep screen going away. On 2026-11-09 a toast timer ran on a system wakeup during sleep and painted the plugin over the sleep screen, so the device looked awake with the touch blocked (KOReader inhibits input while suspended); this pattern came from that fix.
- **Back key:** on devices with keys it goes back one view, and closes the plugin from the first one. `Close` (KOReader quitting) closes the screen, so everything above runs.
- **The toast** is kept in `notice`, never in `toast`: UIManager takes a window with a `toast` field for one of its own toasts and puts every dialog opened meanwhile under it. Before 2026-11-10, a menu opened in the 5 seconds after marking a Pokémon showed under the plugin.

## Hand-written data

`catchink/games.lua` and `catchink/sprite_sets.lua` are written by hand; `tools/validate.lua` checks them with the data validation pattern (`tools/data_check.lua`): an unknown key is an error, numbers are whole, every reference exists, and texts have a limit in letters.

- **A game** (`Games.LIST`): `id`, `en` and `es` (the name; Portuguese uses `en`), `gen`, `vg` (version group of the level-up moves), `versions` (of the encounters and the Pokédex texts), `dex` (PokeAPI Pokédex ids, each in `data/index.lua`), `set` (a sprite set), `region`, `dlc_of` (the base game of an expansion, never an expansion itself) and `alphas` (true for the Legends games). `index` is added when the module loads.
- **A sprite set** (`SpriteSets.LIST`): `id`, `label`, `game` (the game whose Pokédex it downloads, except for `base`), the folders `normal`, `female`, `shiny` and `shiny_female` (each in `data/sprites.lua`), `gray` and `icons`. `index` is added when the module loads.

A field the code starts or stops reading changes the list of keys in `tools/validate.lua` and this section together.

## Data sources

The sources of `data/` follow the data sources pattern:

- **Fixed versions:** PokeAPI and PKHeX at the commits in `tools/fetch_sources.sh`, the sprites at the commit in `data/sprites.lua`. Changing a commit is a change on purpose and alone: download, build, review what changed in `data/`, and write the new checksums (`shasum -a 256` of the files the generator reads, relative to the sources folder) to `tools/sources.sha256`.
- **Checked downloads:** a file that differs from `tools/sources.sha256` stops the download.
- **The release builds again:** `sh tools/check.sh release` downloads the sources, builds `data/` and fails if anything differs from the repository (changed files and new ones; `data/i18n.lua`, written by hand, stays out). The CI runs `tools/check.sh` without `release`, so it never downloads.
- There is no content chosen for the reader (like a word of the day) nor a published order that a day depends on, so the list of approved items and the stable order of the pattern do not apply.

## Tests and tools

```sh
sh tools/check.sh                     # everything below that runs without KOReader, as the CI does
sh tools/check.sh release             # also downloads the sources and builds data/ again, as the release does
luajit tests/catchink_spec.lua        # data, entries, captures, filters, texts, sprite choice, downloader
luajit tests/state_spec.lua           # saves read back, broken and from an older build
luajit tools/check_texts.lua t        # the three languages have the same keys and markers, no dashes, no brand of e-reader
luajit tools/validate.lua             # the hand-written games and sprite sets
sh tools/package.sh                   # the three packages in dist/
```

`tests/catchink_spec.lua` also checks the translated content outside `data/i18n.lua` (what is in Portuguese is also in Spanish) and the dashes in descriptions.

With the desktop KOReader (`KOREADER_DIR`), from the plugin folder:

```sh
tools/koreader/run_emulator.sh                                            # KOReader with the plugin, 600 x 800
tools/koreader/check_all_sizes.sh                                         # check_layout.lua in four screen sizes
tools/koreader/run_headless.sh tools/koreader/fuzz_ui.lua                 # random touches through every view
OUTPUT_DIR=out tools/koreader/run_headless.sh tools/koreader/check_screensaver.lua
tools/koreader/run_headless.sh tools/koreader/check_rotation.lua          # cases in rotation_cases.lua
tools/koreader/run_headless.sh tools/koreader/check_sleep.lua             # cases in sleep_cases.lua
tools/koreader/run_headless.sh tools/koreader/check_awake.lua
tools/koreader/run_headless.sh tools/koreader/check_https.lua             # real connections
CATCHINK_HOME=/tmp/catchink SETS="red-blue@normal base@normal" tools/koreader/run_headless.sh tools/koreader/check_download.lua
CATCHINK_HOME=/tmp/catchink OUTPUT_DIR=/tmp/shots tools/koreader/run_headless.sh tools/koreader/render_screens.lua [w h dpi]
```

- `check_layout.lua` opens every view in the three languages (cards of four Pokémon in all six pages, a toast over a box) and fails on a view that does not draw, a text or touch area off the screen, or a text of the interface cut for not fitting; names, places and other data may be cut on purpose and are only counted. It also checks the version on the About view, the Back key, profiles read again by a new screen, the save of the older build opened by the screen (with the catches moving), the refresh modes and a view that fails to draw.
- `fuzz_ui.lua` has one run per view (home, games, boxes, list, national, card, filters, profile form, progress, sprites, About), in the three languages for home, boxes and card, each from nothing saved; when a run wanders off its view, it goes back to it. Downloads are off. Its first run found the dialogs hidden under the plugin.
- `check_download.lua` downloads real sets through the plugin's downloader; `render_screens.lua` saves PNGs of every view with sample catches, at a fixed date so they are the same every time.
- `readme_screens.sh` (with `CATCHINK_HOME` holding the Red / Blue set) copies four of them to `docs/screenshots` in English and `docs/screenshots/pt` in Portuguese, for the two READMEs; `tools/make_brand_art.py` then draws the icon and the banner (`docs/brand`) and the GitHub social preview (`docs/social-preview.png`) from two of those screenshots.

The other files of `tools/koreader/` and `tools/package_lib.sh`, `tools/check_texts.lua` and `tools/data_check.lua` are copies of the shared patterns. The icon masks and the sleep screen cover come from `tools/make_assets.py` (`KOREADER_DIR` gives it KOReader's fonts).

## How to publish a version

1. Update `version` in `_meta.lua` and add the version section to `CHANGELOG.md`, as `## [1.2.3]`.
2. Run `sh tools/check.sh release`, the emulator checks (`check_all_sizes.sh`, `fuzz_ui.lua`, `check_screensaver.lua`, `check_rotation.lua`, `check_sleep.lua`, `check_awake.lua` and `check_https.lua`) and test on a device, including the device checks of the awake, HTTPS and sleep patterns.
3. If the version changes what is saved, save profiles and catches with the published version in the emulator and keep them in `tests/saves/<published version>/`.
4. If the screens changed, make the README screenshots again (`readme_screens.sh`) and the brand art (`make_brand_art.py`).
5. Publish the `v1.2.3` release on GitHub, creating the tag with it, after the push. The `release.yml` workflow checks the tag against `_meta.lua`, runs `tools/check.sh release` (tests, texts, the hand-written data, and `data/` built again from the sources and compared with the repository), builds the three packages and attaches every zip in `dist/` with its checksum. The CI runs `tools/check.sh` on every push.

The repository on GitHub takes `docs/social-preview.png` as its social preview (Settings > General), by hand.
