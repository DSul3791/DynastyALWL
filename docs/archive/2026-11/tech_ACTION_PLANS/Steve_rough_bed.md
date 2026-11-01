# Action plan: the rough bed's function (list step 13 / EARLY_GAME_FLOW section 7)

Branch: claude/steve-rough-bed. Build 791+ (CHANGE_LABEL: RESTART: server rules + data). Asked by Dave 24 Oct ("these are not Sonny's jobs"). Sal makes the item, recipe 162 (branch sal-bed-recipe-sort) and the placeable structure; Kathleen's bed_lie / bed_rise sounds are hooked on steve-sound-hookup. This plan is only what the bed DOES. Respawn at the bed (R1b) is a separate plan after this one.

## What exists (checked in the code)
Lie (Z, ACT_STANCE 3, animation exists), hold Z 3 s to sleep (ACT_SLEEP), sleep.json: strain x6, regen x2, quality covered 1.0 / open dry 0.6, rain on open ground wakes, auto-wake once energy full and exertion gone, nap rules. Warmth, energy and sickness exist. Hunger and thirst follow exertion only. A lying player is sensed at reduced range by animals.

## What I build (server, data/items/bed.json, no protocol change)
1. **Bed detection.** While lying or asleep the server looks for a placed `rough_bed` structure within bed.reach_m (1.2 m) of the player: `_on_bed(peer)`. Cached per stance change, not per tick.
2. **Roof rule.** The bed counts only under a built roof or tree crown (cover_at > 0.5, same as placing). On a bed without cover it behaves as ground (quality open_dry, rain wakes). With cover: quality bed.quality (1.0) and comfort bed.comfort (1, a number only, for the later Rested buff in R2).
3. **Health and rest.** On the bed: health regeneration x bed.regen_mult (1.25 on top of sleep's x2, data), exhaustion (strain) falls as asleep, energy rises at the sleep rate even when lying awake (Dave: "better rest"): lying on a bed uses the "sleep" energy rate, not "lie".
4. **Slow hunger and thirst.** While asleep, or lying on a bed, food and water drain at bed.drain_mult (0.5, Dave "slow", per the design; also applies asleep on the ground at 0.7 so sleeping is never worse than waking). Goes through the existing vitals tick; one multiplier read.
5. **Stay rule (safe break).** Lying on a covered bed never auto-wakes when rested: the sleeper stays asleep (or lying) until they move, press a stance key, are hit, or rain/cold reaches them. Today auto-wake ends sleep at full energy; on a bed that branch is skipped. The player can leave the keyboard for the hour.
6. **Safe from weather.** Covered bed: rain never wakes (already true under cover); warmth uses the roof-only wind rule from build 789 (a roof, not a tree crown, cuts wind), and bed.warmth_bonus 0.1 off the cold stress (a heap of thatch).
7. **Animals.** A sleeper on a covered bed is sensed at bed.animal_range_mult (0.35) of normal; a bed in a closed room (roof plus at least bed.walls_needed 3 wall pieces within 3 m) is not sensed at all. No invulnerability. Uses the existing sensing range function, one multiplier; the wall count reads the structure list near the bed.
8. **Messages.** First lie on a bed: "Straw and a log. I've slept on worse." is Kathleen/hint-engine (H41, H26); here only the plain say lines from bed.json ("The bed is open to the weather: it is only ground", "You stay in the bed").
9. **Persistence.** Nothing saved (bed state is derived from position and structures).

## Tests (test_bed.gd, added to items_check)
Not on a bed = today's numbers; on a covered bed quality 1.0, regen higher, drain 0.5; bed without cover = ground; stays asleep past rested; wakes on move/hit; animal range 0.35 and room hides; walls count; all numbers read from bed.json; old saves unaffected.

## Cost and risk
One bed lookup per stance change, two multipliers in the vitals tick. Risks: the stay rule must never trap a player (movement or Z always wakes; checked in test); walls-in-range count needs Sal's wall structure kind names (thatch wall, wall kit). Not run in Godot in the cloud (Mike).

## Needs from others
Sal: structure `rough_bed` (placeable, roof needed), item, recipe 162, look. Kathleen: nothing more. Tyler: reply once; the respawn plan follows.

## Build notes (24 Oct 23:40 UTC, Tyler GO with corrections)
Built on Sal's thatch shelter (claude/sal-thatch-shelter 0450dcb1: rough_bed structure already in structures.json, wall pieces have piece_kind "wall"). Code: server_items.gd `_bed_of`, `on_good_bed`, `_bed_room_closed`, `_drain_mult`, hooks in `_sleep_quality`, `_energy_tick`, `_vitals_tick` (drain, regen), the sleep-end rule (stay), `warmth_target`, `peer_stances` (4 = lying on a covered bed, 5 = in a closed room) and server_animals `_sense_factor` (animals.json senses bed_mult 0.7, hidden_mult 0.05). Data: data/items/bed.json (every number; asleep_ground_mult 0.7 is its own row, set 1.0 to zero it, Tyler's correction). Test: src/worldgen/tools/test_bed.gd (in items_check): no bed = today's rules, no cover = ground, far bed, closed room needs a built roof AND 3 walls, energy faster on the bed, stay rule, and never trapped: the bed removed mid-sleep, a stance change, and cover lost all end the sleep. The bed kit recipe number is Sal's (160 per Tyler). Not run in Godot in the cloud: Mike please run test_bed.gd, test_animal_senses.gd, test_warmth.gd and local_check (expect 233).
