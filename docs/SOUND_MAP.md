# Sound map and hook audit (Jason / Champ, started 1 Nov 2026)

Owner of the hooks: Jason (Dave, 1 Nov 2026). Event rules stay with the system owner; if an event is not exposed in their code, I ask them. First pass, read from the repo by grep only, nothing run or heard. `none?` = no sound call found by name; may be covered under another name, to verify. Slot lists: `assets/audio/SOUND_PACK.md`, `data/sound/*.json`.

Direction (23 Nov 2026, Dave: "the sound is not overly directional"): `project.godot` `audio/general/3d_panning_strength` is 1.0 (Godot's default 0.5 left a sound to one side only 6 dB down in the other ear) and the ears are an `AudioListener3D` at the eye (`sound_3d.gd` `ears`), not the third-person camera. `test_world_sound_3d` measures it and lists the modules allowed flat players. Front or behind (23 Nov, part 2): a Foley or Nature voice behind the ears plays through `Rear_Foley` / `Rear_Nature` (-1.5 dB, a -5 dB high shelf above 4 kHz; `sound_3d.gd` `place_rear`, chosen as it starts and at each `sound_occlusion.gd` scan). Animal calls keep rising close by (`creature_sounds.gd` NEAR_MAX_DB 9: Godot's max_db 3 kept a call equally loud anywhere within 0.7 x its unit size). Fights: a wolf's attack (7) and the jaw-pop warning (16) are voiced; black bear and elk call as bear and moose; the animal biting the player snarls where it is (`terrain_client.gd` `_attacker_snarl`). Not yet positional for others: other players' tool blows, gathering and swings (the server sends hit events to the hitter only).

Levels against each other (23 Nov 2026, the coordinator: no everyday sound drowns an approaching animal): `python3 assets/audio/level_pass.py --md` writes assets/audio/LEVELS.md, the heard level of own steps, wind, rain, insects and the beds that are on against animal steps at 20 m, animal warnings at 40 m and other players' blows (clip RMS measured from the files + play level + distance falloff, including Godot's fade to nothing at max_distance, measured in the engine; buses at 0 dB; positional beds and one-shot calls are listed for scale, not checked). From it: animal steps carry farther (slot_sounds.gd CREATURE_STEP_UNIT_M 8, CREATURE_STEP_REACH_M 60; was 6 and 30, which left a wolf's step at 20 m 9.5 dB under the inverse law), the warm-night cricket bed -14 dB and the desert wind bed -11 dB (ambience_slots.gd BED_TRIM_DB), the deer's calls 6 dB louder (creature_sounds.gd db -2). Clip limits: `assets/audio/loudness_report.py --check`. Not yet heard.

## Hook audit (event, where in code, sound)
| Event | Sound call found | Owner of the event | State |
|---|---|---|---|
| Footstep on each ground, wet shoes, cloth | `sound_stage.gd`, `step_fx.gd` (`stepfx.step`) | Sonny (body) | wired |
| Another player's footstep | `player_view.gd` `stepped` (a step per stride of drawn travel, own stride lengths) -> `sound_stage.step_at` (positional at the feet, the own step's ground choice and level, unit 2 m, reach 45 m; 23 Nov 2026: there were none) | Sonny (body) | wired, to hear |
| Landing after a fall | `landing_sounds.gd`, called from `sound_stage.update` | Sonny | wired |
| Stance change (crouch, sit, lie) | `terrain_client.gd:1087` `stance.set_stance` | Steve (stance rules) | wired |
| Tool swing and hit (axe, pick, hammer, spade) | `held_item.gd` `_strike` `hits.hit(_hit_tool())`, `hits.hit_ground`; `_start_swing` `hits.swing` (3 Nov: the swing whoosh was never called; a pick now sounds as a pick, a boulder as stone) | Steve | wired for axe and pick; hammer and spade swings use their own paths |
| Pick a plant | `harvest.gd:145` `harvestfx.pick` | MikeW (plants) | wired |
| Tree falls, trunk creak/crash/chips | `terrain_client.gd:3161` `trees.watch` | Steve (stump and trunk) | wired by world rows |
| Dig terrain | `dig_sounds.gd` (5 call lines) | Sonny | wired |
| Eat, drink, apply poultice/bandage | `terrain_client.gd:1270` `items.eat_event` -> `itemfx.eat` | Sal (item), Steve (food rules) | wired |
| Hotbar change, inventory open/close, pickup/drop/swap, craft done | `held_item.gd:246-270` `itemfx.hotbar`; `itemfx.watch(items)` | Sal / Steve | wired by inventory change; craft_done trigger to verify |
| Rejected action (too far etc.) | `itemfx.reject` | Steve | wired |
| Fuel on fire, light fire, cook, fire out, rain on fire | `fire.set_fires/fuel/cook/hold_manual/sync_world` | Steve (rules), Kathleen (look) | wired; light and out one-shots to verify |
| Held torch/lantern | `flame_sounds.gd` (4 call lines) | Steve | wired |
| Shovel raises ground (fill) | `held_item.gd` `_fill_here` -> `placed.shovel_load` (added 1 Nov, untested; always the soil scoop) | Steve | wired, to hear |
| Place chest, lean-to, doors, gates, hatches, locks, container put/take | `placed.place/use/container/chest/lock/knock/pick_up`, `watch_world`, `watch_open` | Steve (placement), Sal (keys) | wired; structure sound keys by ear: open Sal call |
| Tool wear: break, repair | `placed.tool_break/tool_repair` | Steve | wired |
| Cave-in quake | `placed.quake` | Tyler/Steve (tunnel watch) | wired; see `SOUND_AUDIT.md` |
| Bed lie/rise, net cast/haul, thatch pick, twine lash (batch3 slots) | `slots.play` (5 call lines) | Steve | partly; per-slot trigger to verify |
| Animal alert/threat call | `terrain_client.gd:1225` `creatures.call_at` | MikeW | wired for alert and threat; idle calls by zone (`creatures.call_in_zone`) to verify |
| Weather: rain, wind, thunder | `weather.set_weather`, `weather.strike` | weather owner (unlisted in the scope docs) | wired |
| Water loops, swim | `water_sounds.gd`, `swim_sounds.gd` | Sonny | wired to old water; new water `src/water2` to check |
| Tunnel drips under water | `wet.update` (needs water-above query) | Sonny | partly |
| Steps on built floors and trodden paths | `terrain_client._floor_under` (ray down, `floor_sound` meta set in `inventory_view._model_for_state` from `structure_look.step_surface`) -> `sound_stage.floor_under` (3 Nov: was never set) | Steve | wired, to hear |
| Interior (inside a building), roof rain | `interior.set_inside/object` | Steve | wired |
| Breath and heartbeat | `breath.set_exertion/set_body` | Steve | wired |
| Armour sounds on steps | `gear.set_worn` | Sal | wired |
| Town fire, bell, hammering, saws, chop block | `town.set_sources/ring_bell`, `workshop.chop/set_saws/plank_drop` | Steve | wired; workshops may not exist yet |
| Spear jab/throw/hit | `spear.jab/throw/hit` | Steve | wired |
| Menu clicks | `ui.play` (9 call lines) | Tyler/Steve | wired |
| Sleep and wake | `terrain_client.gd` stance change -> `slots.play("bed_lie")` / `bed_rise`; falling asleep shares the faint blackout | Steve | wired (checked 3 Nov) |
| Player hurt / damage taken, death, respawn | hurt: `inventory_view.hurt_event` (health drops 4 or more in one vitals update) -> `slots.play("player_hurt")` (breath_gasp; 3 Nov). Respawn: `terrain_client.gd` `_respawn_gasp` (after `_on_died` and the cave-in end) -> `slots.play("respawn_gasp")` (breath_gasp; 3 Nov) | Steve | wired, to hear |
| Bow and arrow (draw, release, hit) | `held_item.gd` bow press -> `slots.play("bow_draw")`, release with an arrow in the pack -> `bow_loose` (make_bow.py; 3 Nov). Landing: `spear.arrow` soft thunk where the flight (followed from bow.json) comes down; animal hits thud via animal_hit_point_received (see the animal hit row) | Steve | wired, to hear |
| Fishing (cast, bite, catch) | bite and catch: `slot_sounds.net_cue` maps the rod's server lines (ROD_BITE_LINES, ROD_LAND_LINES) -> `fish_bite` (Dave's fish splash) and `fish_land` (small swim splash; 3 Nov). Cast: none? | Steve/MikeW | bite and catch wired, to hear |
| Drink from water source (not an item) | `inventory_view.drink()` then `eat_event("drink")` when thirst rises -> `itemfx.eat("drink")` (gulp) | Sonny/Steve | wired (checked 3 Nov) |
| Animal hit, death, eating (carcass) | hit: `terrain_client.gd` `animal_hit_point_received` (animal_hit, every hit on an animal within 60 m: any held item, thrown spear, arrow) -> `spear.hit("flesh")` at the wound, full strength, and `animal_view.flinch` (19 Nov; was on `hit_number_received`, which tree and boulder blows also send). Death: `animal_view.fell` (a body gone within 1.5 s of a hit near it) -> `slots.play("animal_fall")` (land thud, soft for small kinds; 3 Nov). Carcass: none? | MikeW | hit and fall wired, to hear |
| Crafting action itself (hand craft, kit use) | `item_sounds.gd`: `craft_start`, a `craft_<type>` loop while it runs (twine, knap, bind, carve, stack, pound, wrap), then `craft_done` | Steve | wired (checked 3 Nov) |
| Clothing put on / taken off | `inventory_view.worn_event` -> `gear.dress` (one rustle, creak or clink) and `gear.set_worn(layers_for(worn ids))`, so worn clothing now sounds on steps (3 Nov) | Sal | wired, to hear |
| Level up, goal done, hint | skill up: `inventory_view.skill_up_event` (a skills message shows a skill's whole level higher than before) -> `slots.play("skill_tock")` (soft wooden tock, make_skill.py; group `skill` cools down 20 s; Dave, QA jason-skill-chime A, 4 Nov). Goal done, hint: none? | Steve | skill up wired, to hear |

| Bird nest near the player (PROTOCOL 91, `terrain_net.nests_received`) | `terrain_client._on_nests_sound` -> `ambient_life.set_nests`; `_nest_tick` calls `call_named` (bird_chirp, bird_trill) from a songbird nest within 45 m every 12-30 s, by day, spring and summer mostly, weather-gated (Jason, 5 Nov). Grouse nests: no grouse clip, silent | MikeW (nests) | songbird wired, to hear; grouse needs a clip |
Next: read each owner's code for the `none?` rows, ask owners (Steve, MikeW, Sonny, Sal) to expose any missing event, place the calls, add a test line per call.

## Phase 1 update (1 Nov 2026, read-only, nothing run)
- Ported from `claude/kathleen-materials` and `claude/kathleen-spades`: `place_stone`, `place_brick`, `place_thatch`, `soil_load`, `stone_load` (clips, generators in `make_placed.py`, levels in `placed_sounds.gd` NAMES, `place()` accepts the kinds stone, brick, thatch, `shovel_load()`). Commits `583e1312`, `9f9db474` on `claude/jason-audio-8366e4`; the `piece_look.gd` part of the first commit was dropped (already in the daily).
- New wiring: `_fill_here()` in `src/client/held_item.gd` calls `placed.shovel_load(false, hit position)` (see the `shortcut:` comment there).
- Stone, brick and thatch pieces in `data/items/structures.json` now carry their own `sound` key (checked 3 Nov), so `place_stone`, `place_brick` and `place_thatch` play.
- Code locations for the `none?` rows (where the call goes, for the backlog): sleep/wake `inventory_view.gd:1393, 4571, 4575` (`ACT_SLEEP` sent; the server owns the state); fishing cast and bite `held_item.gd:590, 621` (`ACT_FISH` sent); hurt from a fall `landing_sounds.gd:27` signal `hurt` is connected in `terrain_client.gd:1277` (only falls hurt the client; damage from animals has no client event I could find). The rest are listed in `docs/handoff/JASON_NEXT_TASKS.md`.

## Phase 2 update (2 Nov 2026, read from code, not heard)
- Sleep and wake: covered. `terrain_client.gd:3230-3231` feeds `breath.set_server_heart/set_body` from the server's `body_phase` (falling asleep, out, waking) and the bed lie/rise slots play on stance change (line 1097). Not `none` any more.
- Fire put out by E (new, PR 32): covered by `fire_sounds.gd` `_was_lit` (lit to unlit plays `fire_out`); picking up an unlit fire plays the generic pickup cue.
- Fishing cast: now plays `net_cast` at `held_item.gd` rod branch (stand-in, needs a listen). Bite and catch still wait on a client event (server text only).
- Boar, songbird, frog, grouse, seal, seabird: step slots borrow existing clips (PR 41). Calls: songbird and frog come from the ambient layer; boar, grouse, seal, seabird have no recording.

## First-day tool audit (3 Nov 2026, read from code, not heard)
| Tool / action | Feedback today | Verdict |
|---|---|---|
| Stone axe on a tree, trunk, stump, log, bush | swing whoosh (`hits.swing`) plus `hit_axe_wood` on the strike; tree-fall sounds come from the world rows | covered |
| Pickaxe or axe on the ground or a boulder | `hit_pick_stone` / `hit_pick_soil` by material (`hit_ground`) | covered |
| Spade dig, fill | dig sounds by ground; fill plays the soil scoop | covered |
| Hoe: path, smooth, grade, till | **none before 3 Nov** | filled: a soft `hit_spade_soil` scrape (strength 0.4, till 0.7) in `held_item.gd _hoe_here`; swap for a hoe recording when there is one |
| Knapping, twine, carving, binding (craft work) | `craft_knap`, `craft_twine`, `craft_carve`, `craft_bind` loops while the craft bar runs, then `craft_done` | covered |
| Fire-starting (kit placed, tinder, lit) | place sound from `placed`, `fire_light` when the fire turns lit, `fire_fuel` for fuel, `fire_out` | covered |
| Torch/lantern held | `flame_torch`, `flame_lantern` | covered |

## First-hours pass (23 Nov 2026, the coordinator: silent, wrong, heard only by the doer, or not from where it happens)
Read from the code and checked headless (`test_world_sound_gaps`, `test_action_cues`, `test_spear_hold`); not yet heard.
| Action | Before | Now |
|---|---|---|
| Lit kiln, smelter or smithy (any station store the server marks lit) | silent (only the bellows strokes sounded) | crackles where it stands for everyone near (`fire_sounds.gd station_fire`: coals small, worked bellows or a smithy's flare large; no rain sizzle under its dome) |
| Iron or steel piece set in place (27 pieces: fences, gates, railings, lanterns) | the soft thump | the metal clank (`placed_sounds.gd` `place_metal`, borrowing `item_drop_metal` until a recording) |
| Another player's arrow or thrown spear | seen flying, silent | the twang where it was loosed and the thunk where it lands; a spear's heave, flight and landing (`held_item.gd add_seen_flight`) |
| Another player swimming | silent (their steps stop in deep water) | a stroke every 1.4 s to 0.6 s by speed, where they swim (`player_view.gd stroked`, `swim_sounds.gd stroke_at`) |
| Another player at a chest, barrel, crate, basket or station store | heard only by the one at it | a chest's lid opening and shutting, things put in and taken out, at the container, within 25 m, only once the server let it through (`action_cue` cue 4, no new protocol number: an older client plays nothing for it) |
Heard by the others too (23 Nov 2026, second pass, `action_cue` cues 5 to 7 under 156 and client-only looks): another player hurt by an attack (the gasp at their head, within 30 m; `server_items.gd hurt_player` -> `server_action_cues.gd hurt`, never held back by the cue gap), a mouthful of water (at the edge or from a waterskin, within 10 m, only when it went down), a thing picked up off the ground (its material's pickup sound where it lay, within 12 m, only when it went), a bow drawn (`player_view.gd drew`: the creak at their shoulder when the players row's bow-drawn flag comes on), a burning torch or lantern carried (`flame_sounds.gd hear_others`: the flutter at their hand, the 2 nearest within 10 m). A fish's bite splashes at the float, where the line went in (`held_item.gd float_point`). Falls, cold and hunger take health without hurt_player and are not sent: only the one hurt hears them.
Faked or missing, needing a recording (Dave only): a snare springing and the caught animal struggling (silent); the hoe (a soft spade scrape stands in); a fishing rod's cast (the shore net's throw stands in); an iron piece set in place (the dropped-item clank stands in); boar, grouse, seal and seabird calls (none).
Fine as they are: tool blows on every material, gathering, crafting, digging, filling, tree falls, doors and hatches (world rows, at the door, its own material), building pieces placed and taken down, campfires lit, fed and put out, wading (water steps for everyone), own swimming, landing, stance, sleep, hurt, weather and day and night beds (assets/audio/LEVELS.md). A swing at nothing stays silent (Dave 10 Nov 2026: no whoosh). Eating and drinking food from the pack stay silent (Dave 17 Nov 2026: "doesnt need sound for eating remove the sound"); a mouthful of water gulps.

## Third pass (23 Nov 2026, the coordinator: what others hear, sound by place, silent things)
Read from the code and checked headless (`test_world_sound_gaps`, `test_sound_by_place`); not yet heard.
| What | Before | Now |
|---|---|---|
| Another player landing from a fall (2.5 m or more) | silent (only the one falling heard it) | their heavy step and the thud or hard landing where their feet came down, within 45 m (`player_view.gd landed`, from the drawn path: sinking faster than 3 m/s and steeper than 45 degrees; `landing_sounds.gd land_at`). A walk down a slope, a hop or a swimmer sinking is no landing |
| A grouse, pheasant or guineafowl bursting up, a crow flying off | silent (state 15, flight, was not voiced) | the whirr of medium wings where it rose, flying away (`animal_view.gd took_off` -> `creature_sounds.gd took_off` -> `ambient_life.flush`); a crow caws its alarm and flaps off (`alarm`, the big flaps only after a crow's call, Dave 3 Nov 2026) |
| Walking into a cave in rain or snow | the ground under the feet stayed soaked (mud steps, splashes) or snowy (crunch) | inside rock (`cave_sounds.rock_enclosure` 0.5 or more) the ground is dry in 4 s and no snow lies underfoot; out again the rain soaks it as before (`weather_sounds.gd in_rock`, `snow_underfoot`) |
| Ambience beds, insects, calls and critters by season | the starter island's calendar everywhere | the season at the player's row (`Weather.season_at`), so across the equator half a year on |
Checked and fine: others' blows, picks, crafts, chests, hurt, drinks, pickups, arrows, spears, swimming, bow draw and torches (passes above); a blow on a goblin or a camp bandit is an animal hit (`animal_hit_point`, the flesh thud for every player within 60 m); rain and wind in a cave fade with the metres walked in (`data/sound/cave_air.json`: -6 dB at 6 m, -45 dB at 25 m, silent at 40 m; Dave 24 Oct) and the rain drops stop under rock (`weather_look.gd sky_share`); the server keeps a player dry in a cave (`terrain_server._cover_at` 2.0, `test_cave_shelter`); weather sound reads the weather at the player's own row and height (`terrain_client._update_weather`); the ambience's biome is the server's zone under the player and its height the player's.
Needing a recording (Dave only), on top of the list above: a cart rolling (wheels on ground, the load creaking; carts are silent for everyone, no clip exists); calls for 37 animals that have none (boar, grouse, seal, seabird, donkey, lynx, bighorn, mountain goat, beaver, chamois, mink, raccoon, rat, pheasant, goose, cow, goat, chicken, cat, dog, buffalo, puma, pronghorn, warthog, hyena, wildebeest, lion, leopard, rhino, elephant, camel, guineafowl, honey badger, kangaroo, mammoth, tiger, alligator; a crow only caws as it flies off); steps for 44 animals (only deer, duck, fox, horse, moose, wolf and rabbit have their own); a goblin's or bandit's cry when struck (the flesh thud only).

## Who hears what, how far (hearing-range pass, 23 Nov 2026)
For stalking and being stalked: how far a second player hears each sound group, and how far an animal senses the player making it. Read from the code and checked headless (`test_hearing_ranges`, which also keeps the player numbers below equal to the code); not yet heard. A sound's "unit" is where it is as loud as at arm's length; past it Godot halves it every doubling of distance and fades it to nothing at the reach, so a sound is faint well before its reach.

Animals sense a player by one rule (`server_animals.gd _sense_factor`): the player seems nearer or farther by the factors below, and the animal watches inside its notice distance and runs inside its flee distance (`animals.json reactions`, e.g. deer 60 / 35 m, wolf 60 m, rabbit 24 / 14 m, boar 40 / 22 m). Standing or walking in the open on a calm day counts 1.0; running 1.5; crouching 0.6; sitting 0.8; lying 0.5; out of sight behind trees or ground down to 0.35 (sound and smell only); downwind of the player up to 1.5, upwind down to 0.75; brushing through undergrowth a little more, less for a good hunter. Nothing is sensed past 1.5 times the notice distance (`far_factor`). New in this pass: a loud action carries at least as far as its `action_heard_x` whatever the stance or cover, for 5 s after it (`server_action_cues.gd loud_kinds`), so a woodcutter crouched in the trees is still heard (the louder of two goes on; a wolf pack noticing a player hears it the same way, `server_wolves.gd heard_of`). A startle (a landing arrow, a tree crash) makes every animal near run from the spot, but never one already running, hidden, in a pack, or standing its ground or charging (`server_animals.gd alarm_near`).

| Sound group | Another player hears it within | Unit | An animal senses the player making it |
|---|---|---|---|
| Footsteps, walking or running | 45 m | 2 m | as the player (1.0, running 1.5) |
| Footsteps, crouched (6 dB softer) | 45 m | 2 m | 0.6 |
| Swimming strokes | 45 m | 2 m | as the player |
| Axe or pick blow (tree, log, stump, bush, boulder, ground) | 60 m | 8 m | 1.4 (deer notices at 84 m, runs from 49 m; rabbit 34 / 20 m) |
| Cry of pain (an attack landed) | 30 m | 6 m | 1.25 |
| Shovel dig, fill or trench | 160 m (everyone hears the ground change) | 8 m | 1.25 |
| Craft work (knapping, carving, twine) | 25 m | 1.5 m | 1.1 |
| Knife on a carcass | 60 m | 8 m | as the player (a quiet cut) |
| Plant picked, cut by sickle or scythe | 30 m | 4 m | as the player |
| Chest lid, things put in or taken out | 25 m | 7 m | as the player |
| Mouthful of water | 10 m | 1.5 m | as the player |
| Thing picked up off the ground | 12 m | 1.5 m | as the player |
| Carried torch or lantern | 10 m | 1 m | animals keep out of its light (the fire rule, not hearing) |
| Bow drawn | 30 m | 6 m | as the player |
| Arrow or spear loosed and landing | 150 m (the flight is sent that far) | 8 m (12 m in flight) | a bow, crossbow or sling shot startles animals within 40 m of the shooter (`bow.json noise_m`); an arrow, stone or thrown spear that misses startles those within 12 m of where it comes down, a fire arrow too (`land_alarm_m`) |
| Tree falling | 260 m | 10 to 18 m | the crash startles animals within 40 m of the fallen tree, 20 m for a small one (`drops.json felling.crush.alarm_m`) |
| Building piece set or taken down | 120 m | 7 m | as the player |
| Campfire | 35 m (fades out by 52 m) | world fire | animals keep out of its light |

Being stalked, what the player hears of animals: an animal's steps within 60 m (unit 8 m, the 6 nearest at once), a slow stalk about half as loud as a run (`slot_sounds.gd footfall_strength`); calls by species out to their reach (`creature_sounds.gd`: rabbit 45 m, deer 260 m, fox 320 m, wolf howl 950 m, bear 320 m). A wolf or big cat that stalks walks in at about 1 m/s once it has noticed the player (`hunter.stalk_mps`), so its steps are quiet and close; its threat call comes before a charge.

Not heard by animals (by design, quiet): picks, chests, gulps and pickups. Values are provisional with the RX table, for Dave's review.
