# Jason (Champ): backlog after Phase 1 (1 Nov 2026)

Each row: owner of the next step, the exact next step, why. Nothing here has been run or heard (no Godot in Phase 1). "Test" means a line in `test_slot_sounds` or a `--sound-log` check.

| # | Task | Owner | Exact next step | Why |
|---|---|---|---|---|
| 1 | Hear the shovel scoop and the new place sounds | Jason, then Dave | After RESTART run the client, raise ground with a spade, read `--sound-log=30`; QA card with the clips | Ported and wired blind in Phase 1 |
| 2 | Map stone, brick, thatch pieces to the new place sounds | Sal | Set `"sound": "stone"/"brick"/"thatch"` on the matching rows of `data/items/structures.json`, then I run `test_slot_sounds` | The clips exist but nothing asks for them |
| 3 | Stone vs soil in the shovel scoop | Steve (event), Jason (call) | Server reply to `ACT_FILL` carries the material; I then call `shovel_load(stone, at)` on the reply | The call plays the soil scoop always and even if the fill is refused |
| 4 | Sleep and wake sounds | Steve exposes event, Jason places call | Ask Steve for a client-visible sleep start/end (today only `ACT_SLEEP` is sent, `inventory_view.gd:1393, 4571, 4575`); I add a cloth/breath cue via `stance` or `itemfx` | Silent today, a core system |
| 5 | Hurt, death, respawn | Steve | Expose a client event for damage taken and death; I add `hurt_grunt`, a death cue | Only falls (`landing.hurt`) make any sound |
| 6 | Bow, arrow | Steve | Name the client events draw, release, hit; I add slots | None found by name |
| 7 | Fishing cast, bite, catch | Steve / MikeW | Events behind `ACT_FISH` (`held_item.gd:590, 621`); I add line-cast, splash, reel | Ambient fish splash only |
| 8 | Drinking at a water source | Sonny / Steve | Confirm which path plays `drink_gulp` for a mouthful at the water's edge (`terrain_client.gd:3996` area) | Unverified |
| 9 | Animal hit, death, eating | MikeW | Expose the client events; I add calls | Alert and threat calls only |
| 10 | Clothing on/off, craft action, level-up/goal/hint | Sal / Steve | Events then slots; low priority | Polish |
| 11 | Wiring checks for wind_structures, insect bed, NPC voice | Jason | Phase 2: `--sound-log` near a lean-to, a meadow in summer, an NPC | Callers not found by grep |
| 12 | Tree-wind hiss like rain in clear weather | Jason | Phase 2 `--sound-log=180` at spawn; if confirmed apply `SOUND_AUDIT.md` proposals (gate on gusts, uneven swells); tunnel-watch rule changes to Steve | Dave heard rain-like sound |
| 13 | Licence audit | Jason | `assets/audio/check_credits.py`; ask Dave for Pixabay page URLs and voice file origins | Records have TODOs and no rows for voices |
| 14 | Sound review cards for Dave | Moderator (qa.html), Jason | Moderator answers whether `Audio:` lines may render `<audio>`; then ~15 cards, one per group | Dave cannot hear the whole game |
| 15 | Loudness test and mix table | Jason | Test reading every ogg peak vs its bus window | No guard against a too-loud clip |
| 16 | Diff `kathleen-creature-sounds`, `-water-soft` leftovers | Jason | Per-hunk diff vs daily, then drop branches | Cherry says applied; hunks unread |
| 17 | Music | Dave | Card: music yes/no | Undecided |
