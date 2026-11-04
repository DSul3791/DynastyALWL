# Sound map and hook audit (Jason / Champ, started 1 Nov 2026)

Owner of the hooks: Jason (Dave, 1 Nov 2026). Event rules stay with the system owner; if an event is not exposed in their code, I ask them. First pass, read from the repo by grep only, nothing run or heard. `none?` = no sound call found by name; may be covered under another name, to verify. Slot lists: `assets/audio/SOUND_PACK.md`, `data/sound/*.json`.

## Hook audit (event, where in code, sound)
| Event | Sound call found | Owner of the event | State |
|---|---|---|---|
| Footstep on each ground, wet shoes, cloth | `sound_stage.gd`, `step_fx.gd` (`stepfx.step`) | Sonny (body) | wired |
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
| Interior (inside a building), roof rain | `interior.set_inside/object` | Steve | wired |
| Breath and heartbeat | `breath.set_exertion/set_body` | Steve | wired |
| Armour sounds on steps | `gear.set_worn` | Sal | wired |
| Town fire, bell, hammering, saws, chop block | `town.set_sources/ring_bell`, `workshop.chop/set_saws/plank_drop` | Steve | wired; workshops may not exist yet |
| Spear jab/throw/hit | `spear.jab/throw/hit` | Steve | wired |
| Menu clicks | `ui.play` (9 call lines) | Tyler/Steve | wired |
| Sleep and wake | none? | Steve | to verify |
| Player hurt / damage taken, death, respawn | respawn: `terrain_client.gd` `_respawn_gasp` (after `_on_died` and the cave-in end) -> `slots.play("respawn_gasp")` (breath_gasp; 3 Nov). Hurt: landing `hurt` signal only | Steve | respawn wired, to hear; hurt to verify |
| Bow and arrow (draw, release, hit) | `held_item.gd` bow press -> `slots.play("bow_draw")`, release with an arrow in the pack -> `bow_loose` (make_bow.py; 3 Nov). Landing: `spear.arrow` soft thunk where the flight (followed from bow.json) comes down; animal hits thud via hit_number | Steve | wired, to hear |
| Fishing (cast, bite, catch) | none? (fish splash is ambient only) | Steve/MikeW | to verify |
| Drink from water source (not an item) | none? | Sonny/Steve | to verify |
| Animal hit, death, eating (carcass) | death: `animal_view.fell` (a body gone within 1.5 s of a hit near it) -> `slots.play("animal_fall")` (land thud, soft for small kinds; 3 Nov). Hit: PR 204. Carcass: none? | MikeW | fall wired, to hear |
| Crafting action itself (hand craft, kit use) | none? (craft_done cue only) | Steve | to verify |
| Clothing put on / taken off | `inventory_view.worn_event` -> `gear.dress` (one rustle, creak or clink) and `gear.set_worn(layers_for(worn ids))`, so worn clothing now sounds on steps (3 Nov) | Sal | wired, to hear |
| Level up, goal done, hint | none? | Steve | to verify |

Next: read each owner's code for the `none?` rows, ask owners (Steve, MikeW, Sonny, Sal) to expose any missing event, place the calls, add a test line per call.

## Phase 1 update (1 Nov 2026, read-only, nothing run)
- Ported from `claude/kathleen-materials` and `claude/kathleen-spades`: `place_stone`, `place_brick`, `place_thatch`, `soil_load`, `stone_load` (clips, generators in `make_placed.py`, levels in `placed_sounds.gd` NAMES, `place()` accepts the kinds stone, brick, thatch, `shovel_load()`). Commits `583e1312`, `9f9db474` on `claude/jason-audio-8366e4`; the `piece_look.gd` part of the first commit was dropped (already in the daily).
- New wiring: `_fill_here()` in `src/client/held_item.gd` calls `placed.shovel_load(false, hit position)` (see the `shortcut:` comment there).
- Still silent until Sal sets the `sound` key on the rows: stone, brick and thatch pieces in `data/items/structures.json` still use `timber`/`thump`, so the new place sounds exist but nothing asks for them.
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
