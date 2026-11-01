# Sound map and hook audit (Jason / Champ, started 1 Nov 2026)

Owner of the hooks: Jason (Dave, 1 Nov 2026). Event rules stay with the system owner; if an event is not exposed in their code, I ask them. First pass, read from the repo by grep only, nothing run or heard. `none?` = no sound call found by name; may be covered under another name, to verify. Slot lists: `assets/audio/SOUND_PACK.md`, `data/sound/*.json`.

## Hook audit (event, where in code, sound)
| Event | Sound call found | Owner of the event | State |
|---|---|---|---|
| Footstep on each ground, wet shoes, cloth | `sound_stage.gd`, `step_fx.gd` (`stepfx.step`) | Sonny (body) | wired |
| Landing after a fall | `landing_sounds.gd`, called from `sound_stage.update` | Sonny | wired |
| Stance change (crouch, sit, lie) | `terrain_client.gd:1087` `stance.set_stance` | Steve (stance rules) | wired |
| Tool swing and hit (axe, pick, hammer, spade) | `held_item.gd:934-943` `hits.hit`, `hits.hit_ground`; `hits.swing` | Steve | wired for axe on wood and pick on ground; other tools to verify |
| Pick a plant | `harvest.gd:145` `harvestfx.pick` | MikeW (plants) | wired |
| Tree falls, trunk creak/crash/chips | `terrain_client.gd:3161` `trees.watch` | Steve (stump and trunk) | wired by world rows |
| Dig terrain | `dig_sounds.gd` (5 call lines) | Sonny | wired |
| Eat, drink, apply poultice/bandage | `terrain_client.gd:1270` `items.eat_event` -> `itemfx.eat` | Sal (item), Steve (food rules) | wired |
| Hotbar change, inventory open/close, pickup/drop/swap, craft done | `held_item.gd:246-270` `itemfx.hotbar`; `itemfx.watch(items)` | Sal / Steve | wired by inventory change; craft_done trigger to verify |
| Rejected action (too far etc.) | `itemfx.reject` | Steve | wired |
| Fuel on fire, light fire, cook, fire out, rain on fire | `fire.set_fires/fuel/cook/hold_manual/sync_world` | Steve (rules), Kathleen (look) | wired; light and out one-shots to verify |
| Held torch/lantern | `flame_sounds.gd` (4 call lines) | Steve | wired |
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
| Player hurt / damage taken, death, respawn | none? (landing mentions the `hurt` signal) | Steve | to verify |
| Bow and arrow (draw, release, hit) | none? | Steve | to verify |
| Fishing (cast, bite, catch) | none? (fish splash is ambient only) | Steve/MikeW | to verify |
| Drink from water source (not an item) | none? | Sonny/Steve | to verify |
| Animal hit, death, eating (carcass) | none? | MikeW | to verify |
| Crafting action itself (hand craft, kit use) | none? (craft_done cue only) | Steve | to verify |
| Clothing put on / taken off | none? | Sal | to verify |
| Level up, goal done, hint | none? | Steve | to verify |

Next: read each owner's code for the `none?` rows, ask owners (Steve, MikeW, Sonny, Sal) to expose any missing event, place the calls, add a test line per call.
