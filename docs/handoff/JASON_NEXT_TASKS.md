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

## Added 1 Nov 2026 evening (left over from the play-test fixes)

| # | Task | Owner | Exact next step | Why |
|---|---|---|---|---|
| 18 | Clip-length checks in `test_dynasty_body` (chop 0.95 s, pick 1.0 s) | Jason | My own two runs never got a Godot slot (first timed out at 300 s with no output, second never started); Kathleen's run of the test passed with 0 failures. Re-run once on a free slot to confirm the two new lines | Never seen to run by me |
| 19 | Chop impact frame | Kathleen | **Superseded:** my blow-1 estimate of 0.78 s (arm rotation speed in the glb) is replaced by Kathleen's corrected swing window (`e90c46d1`): the real downstroke is at 1.68 s of the clip. Check that `CLIP_MAP` chop/pick in `dynasty_body.gd` still put the blow at `HIT_AT` (0.5 s of 0.95 s; pick 0.52 s of 1.0 s) with her window | Estimate was not from the hand position |
| 20 | Sound hooks for the three fire tiers | Jason | Find the client event for each tier (fire state in `fire_sounds.gd`/`flame`), wire a call, add a `test_slot_sounds` or `--sound-log` check | Not started |
| 21 | Pickup sounds | Jason | Hook the pick-up action (`pick_up` clip, auto pickup) to an `itemfx` cue; test | Not started |
| 22 | Crouch footsteps | Jason | Add a crouch gait level in `step_levels.json` / `surface_gait_db` and a check in the step test | Not started |
| 23 | Swim and drink hooks for the Dynasty body | Jason (Steve added the hooks) | Read Steve's swim/drink hooks in `terrain_client.gd`, place `swim`/`drink_gulp` calls, test with `--sound-log` | Not started |

## Update 2 Nov 2026 (branch `claude/jason-20261102-audio`, no Godot, nothing heard)

| # | Done | Result |
|---|---|---|
| 12 | Checked | The gust gating, uneven swells (`flutter_db`) and BASE_DB -30 are already in `tree_wind.gd`; only the generator's band (`make_treewind.py`) is unchanged and needs ears. Still needs the `--sound-log=180` run |
| 13 | Done | `assets/audio/check_credits.py` (new). Voice files now have rows (Kokoro, Apache-2.0, as stated in `data/npcs/voices.json` and `inner_voice_sets.json`); fox row pattern fixed; licences `own-made` and `Apache-2.0` allowed. Left: 8 rows with page URL TODO (Dave's Pixabay pages), and the Kokoro voice-pack terms to confirm |
| 15 | Done | `loudness_report.py --check` fails on a clip at or over 0 dBFS and creature peaks over -6 dB. Today it lists 20: gravel/stone step left (+0.2), fire_rain, town_hammering, treewind_dry (+3.9), eight rain beds (up to +2.3, decoded overshoot), and creature snorts/growls/roars (bear_roar -0.1, rabbit_thump -1.9, wolf_growl -2.5, horse_snort -2.6). Fixing needs a listen: Dave's rule is creatures near -14 peak |
