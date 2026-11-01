# Scope: Jason "Champ" (audio engineer, all sound), 1 Nov 2026

> **CORRECTION (Dave, 1 Nov 2026): the sound HOOKS are yours:** which events make a sound, wiring the sound call at those events, auditing events that have none. System owners keep the rules; if an event is not exposed in their code, ask them to expose it (signal or event) and you place the sound call. Replaces the earlier edge that gave 'when a sound plays' to the system owners.

Written with no Godot running (hold in force). Everything below is read from the repo at `966f1247` (daily `DailyDev_20261029`), not heard. I have heard nothing; where a claim needs ears or a running client it says so.

## 1. The job, in plain words, and its edges
Everything the player HEARS: sound effects, footsteps, tool, place and door sounds, creature calls, weather, water, wind, fire, ambience, the speech voices, music if the game ever wants any, the volume mix, the sound mapping tables, and the two sound tests (`src/worldgen/tools/test_slot_sounds.gd`, `test_sound_log.gd`). It starts when a design says "this thing makes a noise" and ends when the clip exists, has a recorded licence, is mapped, is balanced against the rest, has a test line, and Dave has judged it on a QA card.

| Question | Owner |
|---|---|
| The sound HOOKS (CORRECTION from Dave, 1 Nov): which game events make a sound, putting the sound call at each event, auditing every event that has none (steps, tools, placing, eating and drinking, sleeping, fire, doors, water, creatures, weather, UI), and the sound tests | me. I place the call. |
| The RULE and the event itself (what happens, when) | the system owner: Steve (sub-systems), MikeW (animals), Sonny (water), Tyler (shared server rules). If an event is not exposed in their code yet, I message them to expose it; I place the sound call |
| WHAT an item plays (the sound key on an item or structure row) | Sal (item data); I supply the list of slot names that exist and tell Sal when one is missing |
| The sound itself, its file or generator, its licence, the mapping table slot to clips, loudness, the mix, filters, how it sounds | me |
| Code that plays sound (`src/client/*_sounds.gd`, `sound_stage.gd`, the call lines in `terrain_client.gd`, `held_item.gd`, `harvest.gd`) | me; the system owner reviews a call line placed inside their code |
| How things LOOK (including the fire flicker) | Kathleen / Kathreen. Fire LOOK is theirs; fire SOUND is mine |

I never merge into the daily and never touch main.

## 2. What already exists (read from the repo)

**Engine.** `src/client/sound_stage.gd` (1504 lines) is the stage; about 40 modules in `src/client/` hang off it (list in section 3). Buses created in code, no `default_bus_layout.tres`: Master, Wind, Foley (steps, tools, items, fire, town), Nature, Weather, Interface, Body (breath, heartbeat), Inner (inner voice), NpcVoice, World (cave reverb) and the child "Air_*" buses made by `air_bands.gd` for far big sounds. Sliders in Esc > Settings: master, effects, ambient, interface plus wind/nature/steps mixer groups (`levels`, `mix_level`, `MIX_GROUPS`). `sound_presets.gd` holds the voice-cap and distance budget per quality tier. `sound_3d.gd` is the one place for 3D player settings; `sound_occlusion.gd` dulls sounds behind hills and in forest; `cave_sounds.gd` adds reverb and filters under rock. Footstep loudness per surface and gait is data: `data/sound/step_levels.json` (table doc `sound/STEP_LEVELS.md` is named in the file; not in this repo, so unverified).

**Data tables (`data/sound/`).** `batch1_slots.json` (20 slots: species footsteps, 3 door materials open/close, ladder, water wheel, table plane and vice, cloak rustle), `batch2_slots.json` (17 slots: forest, night, crickets, surf, desert wind, canyon, volcano, pond beds plus one-shots, with tags season/time/biome/near_water/altitude), `batch3_slots.json` (R1: bed lie and rise, net cast and haul, thatch pick, twine lash), `cave_air.json`, `step_levels.json`, `zone_tags.json`. Played by `slot_sounds.gd` (events name a slot, no file path in code) and `ambience_slots.gd`.

**Files.** 1155 files, 24 MB, in `assets/audio/` (`ogg`), made by about 45 generator scripts `assets/audio/make_*.py` plus recordings in `assets/audio/recorded/` (a recording of the same name replaces the generated one; delete it to get the generated back). Manifest: `assets/audio/SOUND_PACK.md` (written by `make_manifest.py`): **218 slots: 18 recorded, 190 generated placeholders, 10 empty.** Also `assets/audio/README.md` (487 lines of how-to), `LOUDNESS.md` (loudness table), `validate_pack.py`, `swap_recording.py` (turns a supplied recording into a game sound and a CREDITS row), `tools/clip_check.py`, `tools/sound_check.py`, `tools/validate_sound_slots.py`.

**Kathleen's sound branches.** All ten (`kathleen-sound-1/2/r1`, `-sounds`, `-creature-sounds`, `-door-sounds`, `-wolf-howl`, `-torch-rain`, `-wind-soft`, `-water-soft`) are in the daily: `git cherry origin/DailyDev_20261029 origin/claude/<branch>` shows every commit as already applied (patch-equal), so nothing to merge. (Kathleen's handover message says five of them are not in the daily; I checked: wind-soft and door-sounds show as later-edited versions in the daily, e.g. `sound_stage.gd:596` has the x0.8 wind line. Files that still differ between branch tip and daily: creature-sounds `moose_grunt_0/1.ogg`, `make_creatures.py`, `animal_view.gd`; water-soft `bed_forest_day_0/winter_0.ogg`, `water_sounds.gd`. These are probably later daily edits, not missing work, but I have not diffed each hunk: task for after RESTART.) Related Steve branches `origin/claude/steve-sound-*` and `steve-wind-*` (3d, batch2, hookup, sliders, slots, test-free, wind-bus, wind-surf) were not checked one by one; I assume they were merged long ago and will confirm with `git cherry`.

**Dave's earlier audio verdicts I found** (he judges by ear; these shaped the build): every world sound is directional, only the body and UI stay flat (23 Oct); wind beds follow the Wind slider (24 Oct); creature clips sit near -14 dB peak, -2 dB was far too loud; fall and water beds made softer (24 Oct).

**Tests that exist.** `test_slot_sounds` (every slot has a clip, no clip twice in a row, cooldown and priority under the voice cap, JSON and call sites agree both ways, each door material in `structures.json` has open and close slots), `test_sound_log` (the verification-without-ears report: `--sound-log=N` prints each playing sound with file name, distance and dB, once a second; wired in `scenes/terrain_client/terrain_client.gd:1083`), `test_inner_voice_profile`, `test_inner_voice_settings`. No test yet for: bus levels, loudness limits per file, licence rows vs files, the sound-test menu.

## 3. Inventory of every sound (module, what plays, where, state)
Counts are slots from `SOUND_PACK.md`. State: G = generated placeholder (code-made, no third-party material), R = recorded, E = empty slot. Full row-per-slot table is `SOUND_PACK.md`; I do not copy 218 rows here.

| Group | Module (`src/client/`) | What plays when | Slots / state | Gap |
|---|---|---|---|---|
| Footsteps | `sound_stage.gd`, `step_fx.gd`, `landing_sounds.gd`, `gear_sounds.gd`, `stance_sounds.gd` | step per ground, wet-shoe squelch, cloth rustle, hard landings by drop height, armour jingles, crouch/sit/lie | 11 grounds R (left and right x 3, Dave's Pixabay set); ice, plank, slab, carpet, thatch, path E (generated placeholders in `floors/`); gear G x6, landing G x2, stance G x5 | built-floor steps are placeholders; ice step placeholder |
| Wind | `sound_stage.gd`, `tree_wind.gd`, `wind_structures.gd` | wind_low/gust beds by height and cover, tree hiss by season (leaves, pine, dry, bare), whistle and hollow in gaps | all G | `SOUND_AUDIT.md` (guide, 31 Oct): `treewind_leaves/pine` are even noise and may be heard as rain in clear weather; proposed fixes (gate on gusts, uneven swells, lower band) are unapplied as far as I can see |
| Weather | `weather_sounds.gd`, `rain_splashes.gd`, `interior_sounds.gd` | rain beds (light, heavy, on leaves, on roof, from inside), per-ground drops, gale, thunder near/mid/far, snow and fog hush | G x14 + rain splashes G x8 | all rain and thunder are generated; priority-1 slots in the pack |
| Water | `water_sounds.gd`, `swim_sounds.gd`, `wet_sounds.gd` | brook, river, pond lap, waterfall loops; swim entry by speed, strokes, going under; tunnel drips under water | brook R (one 24 s cut of a Pixabay clip), others G; swim G x6; wet G | `wet_sounds` waits on a "water above" query owned by Sonny/Steve (header says not hooked up); new water (`src/water2`) does not call the water loops: to check |
| Fire | `fire_sounds.gd`, `flame_sounds.gd`, `town_sounds.gd` | fire loop small/large by size, light, fuel, put out, rain on fire, cook sizzle; held torch; town hearth | G x9 (+ town fire) | all generated; torch in rain exists in the daily |
| Tools and hits | `hit_sounds.gd`, `dig_sounds.gd`, `spear_sounds.gd`, `workshop_sounds.gd` | axe/pick/hammer/spade on wood, stone, soil; digging; spear jab, throw, hit; chop block, saw mill | G x13 hits, G x7 dig, G x7 spear, G x4 workshop | the header of `hit_sounds.gd` says "no tool system yet, only the hook": whether any caller plays them is unverified; workshops "do not exist yet" |
| Harvest and items | `harvest_sounds.gd`, `item_sounds.gd`, `ui_sounds.gd` | pluck, pull, snap, snip, twist; inventory open/close, pickup, drop, swap, craft done; menu clicks | G x7, G x22, G x4 | unverified wiring (see below) |
| Placed things | `placed_sounds.gd`, `slot_sounds.gd`, `interior_sounds.gd` | place chest/lean-to, container put/take, doors (3 materials), gate, hatch, lock, ladder, tool break, cave-in quake | G x9+, batch1 20 slots, batch3 slots | **Sal's "placed sounds mapped to the five existing kinds in `structures.json`" is a judgement by ear nobody has made yet** |
| Trees | `tree_sounds.gd` | creak, crash, split when a trunk appears | G x4 | the crash and creak are generated; priority 1 |
| Creatures | `creature_sounds.gd`, `emitters.gd`, `ambient_life.gd`, `ambient_critters.gd` | wolf, bear, horse, fox, moose, deer, duck calls by mood; birds, owl, cricket, frog, crow, hawk, woodpecker, wing flaps, fish jump | R: wolf x2, bear x2, horse x2, duck x2 (Pixabay), fox, moose, deer (Dave's own recordings), frogs, crow, fish, wings (Pixabay via Dave); rest G (bird songs, owl, cricket) | bird songs, owl and cricket are generated; no goat/sheep/pig/chicken/bee voices checked |
| Body and voices | `breath_sounds.gd`, `inner_voice_sounds.gd`, `npc_voice.gd` | breath and heartbeat by exertion; the inner voice lines (8 sets x 28 lines, `assets/audio/inner_voice/`); NPC speech for Hob and Edda (`npc_voice/`, 88 clips) | breath G x5; voices pre-rendered files | **licence and source of these voice files are not in `CREDITS.csv`**; `data/npcs/voices.json` names "Kokoro, Apache 2.0" for the NPC voice; `inner_voice/README.md` says "recordings" and `data/items/inner_voice_sets.json` mentions Kokoro. I do not know the licence terms of the voice files; to confirm |
| Caves and ice | `cave_sounds.gd`, `ice_sounds.gd` | cave reverb and drips, ice cracks and groans | G | placeholders |
| Insects | `insect_bed.gd` | summer insect bed | G | placeholder |
| Music | none | no music in the game | none | undecided: Dave's call, see section 8 |

Wiring (corrected): my first grep missed the real variable names. `sound.hits` (held_item.gd:934-943, terrain_client.gd), `sound.harvestfx` (harvest.gd:145), `sound.trees.watch` (terrain_client.gd:3161), `sound.itemfx.eat/fuel_pressed/reject/hotbar`, `sound.stance`, `sound.creatures.call_at` (animal alert and threat) are all called. Still to confirm in a running client: wind_structures, insect bed, NPC voice. The hook audit is in `docs/SOUND_MAP.md`.

**Licences and sources (what is recorded in `assets/audio/CREDITS.csv`, 24 rows).** All third-party audio there is Pixabay (Pixabay Content License: usable inside the game, not shippable as separate files or a sound pack; "verify before release"). Dave's own recordings (fox, moose, deer) are "own-recording". Generated sounds are our own code. Gaps in the record: Dave's supplied sets (footsteps, frogs, tree frogs, fish, crow, wings, brook) have a page URL of TODO because Dave did not give one, and the brook's file name says "freesound_community" although the row says Pixabay; the voice files (above); `recorded/` folders not listed in CREDITS patterns: none found, but I will cross-check every file in `recorded/` against the CSV patterns with a script (task 2).

## 4. Plan, in order
1. **Wait for RESTART.** No Godot until then. Meanwhile, with no engine: finish the text-side cross-checks (items 2 and 3).
2. **Licence audit.** Script `assets/audio/check_credits.py`: every file under `recorded/`, `inner_voice/`, `npc_voice/` matches a CREDITS.csv pattern; list unmatched. Fill the rows I can prove from the repo; leave TODO for anything I cannot (never invent a source). Ask Dave (QA text card) for the Pixabay page URLs and for how the voice files were made.
3. **Sound map and hook audit.** `docs/SOUND_MAP.md` (first hook audit written 1 Nov; event, where in code, sound or none). Next: fill every `none?` row by reading the owner's code, ask the owner to expose events that are missing, then place the calls. Generated sound map to follow: event → module → slot → clips → bus → level, built from `data/sound/*.json` and `SOUND_PACK.md`, so Sal and Steve can see which slot an item or structure can use.
4. **Sound review tool for Dave** (section 6): one QA card per sound group, with a short description and a playable clip.
5. **Verification without ears.** After RESTART run the client with `--sound-log=180` at spawn in clear weather, in a forest, at the brook, in rain, in a cave, at a fire, and read the lines: confirm or kill the `SOUND_AUDIT.md` suspicion (tree-wind hiss), check wiring of the six modules with 0 callers, list anything playing above -20 dB.
6. **Mix pass by numbers.** Loudness per bus from `LOUDNESS.md`; a test that reads every ogg and fails when a clip's peak is outside its bus window (steps -25 to -13 dB by gait, creatures near -14 dB peak per Dave).
7. **Fix the loudest complaints first:** tree-wind loops (even hiss), placeholders for the priority-1 slots (rain, thunder, tree crash, wind), the five empty built-floor step slots.
8. **Placed sounds by ear** (Sal's open call) as one card per kind.
9. **Music decision** as a card; do nothing until Dave answers.

## 5. Top five priorities
1. Know the truth: a `--sound-log` pass in the real game for the main places (nothing here has been heard by anyone; Dave found rain-like sound in clear weather).
2. Licences: no sound in the repo without a CREDITS row, voices included, before any release.
3. Dave can review sound without hearing the game (the QA audio cards).
4. The loudest daily-life placeholders: wind, rain, footsteps on built floors, tree crash, fire.
5. Balance: one mix table, one test that fails when a bus is too loud.

## 6. How Dave reviews sound without hearing the whole game
Proposal (needs the moderator): one card per sound GROUP, not per file (about 15 cards: footsteps, doors, tools, fire, weather, water, wind, creatures, birds, harvest, items, voices, ...). Each card has: a one-line description ("what plays, when, how loud versus a footstep"), 3 to 6 short clips as a single stitched preview (about 20 s, no ffmpeg on this machine; I would stitch with Python and Godot's `AudioStreamOGGVorbis`, or send one wav per clip), choices `- Yes, keep` / `- No, change` and the usual Comments box. `questions/audio/` already exists on branch `qa` (ten creature clips from 29 Oct) but `questions/qa.html` only renders `Image:` lines as `<img>`; it has no `<audio>` element. **Question for the moderator:** may I add an `Audio: questions/audio/<file>.ogg` note line to `qa.html` that renders `<audio controls>` the same way `Image:` is fetched (the page reads files through the GitHub API with Dave's token)? If not, the fallback is the in-game sound test menu (Esc > Settings > Sound test) with a card that says which button to press.

## 7. Dependencies
- **Moderator:** QA page audio support (above); RESTART; merging my branch.
- **Steve:** when sounds play (the triggers); any new rule needs a slot name from me. I ask him which hooks are still missing (wet tunnel, workshops, town, gear).
- **Sal:** item and structure sound keys; I give him the list of valid slot names and tell him when a key points nowhere (`test_slot_sounds` already checks door materials).
- **MikeW:** animal behaviour decides when a call happens; I supply the call set per species. Animal species without a voice need his list.
- **Sonny:** water depth/flow and the "water above" query for tunnel drips; new water (`src/water2`) should drive the water loops.
- **Kathleen / Kathreen:** fire and flame look (my fire sound follows their flame size); creature models list.
- **Tyler:** test passes, rigs, the sound tests in the suite, slot use (3 heavy jobs max).
- **Dave:** judging by ear; Pixabay page URLs; whether the game wants music.

## 8. How to tell it is finished
1. Every file under `assets/audio` has a licence row or is generated by a script that is in the repo (checked by script).
2. `test_slot_sounds`, `test_sound_log` and the new loudness test pass; `--sound-log` runs in the main places show nothing unexpected above -20 dB and no rain-like hiss in clear weather.
3. No priority-1 slot in `SOUND_PACK.md` is a bare placeholder without Dave having answered Yes to its card (a good generated sound he accepts is fine).
4. Every sound key in item and structure data points at a slot that exists.
5. Music: either Dave says "no music" or a track is in with a licence.

## 9. Open questions (none block the first steps)
- Do you want music? (card)
- Pixabay page URLs for Dave's recordings, and how the voice files were made (text card to Dave).
- May I extend `qa.html` with an audio player (moderator).

## 10. Not checked / skipped
The hook audit rows marked `none?` come from a name grep only; some may be covered under another name.
Nothing was run or heard. Not read line by line: the 40 sound modules (headers and bus names only), `LOUDNESS.md`, the full `README.md`, `steve-sound-*` branches. The wiring claims in section 3 come from greps, not from a running game. `docs/PONYTAIL_RULES.md` applies: no new system, reuse `slot_sounds.gd`, `swap_recording.py` and the manifest scripts; one small test per logic piece.
