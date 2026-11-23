# Skills web design (draft 1, design only, send to Steve before any code)

Source: Dave 2026-10-21 (everyone starts at 1 in every skill; practice raises it slowly but untrained you hit a cap; each level of training from a trained teacher gives a jump, new subskills, a higher cap and slightly faster gains; high subskills need exceedingly more experience; skills form a web; every skill comes from a trait). Replaces the "innate part + practice" model in data/items/skills.json (job 87, protocol 37) but keeps its hooks (`skill_factor`, `practice`, the action table) so nothing that calls skills changes. Tyler's best practices on skill webs and progression curves have been requested; I will reconcile the numbers when his entry is in. Nothing here has been looked at by eye (no code).

## 1. The rules in one page (reconciled with Tyler's entry, version 2)
Numbers below are Tyler's tuning from BEST_PRACTICES.md "Skill web, training and progression curves", which also matches Dave's own example scale (1 to 50, +25 per level) more closely than my first draft. All are data and get simulated before they are trusted.
1. Every skill is a number from **1 to 100**. **Everyone starts at 1 in every skill.** (A value of 1 gives factor exactly 1.0, so existing balance holds; today's neutral 10 goes away.)
2. **Practice** (verified successes, as today) raises a skill slowly. **Untrained cap = 25.**
3. **Training** from a trained teacher is how you pass a cap. Four training levels, each **+25 to the cap: 25 untrained, 50, 75, 100.** Names: Novice 1-25, Apprentice 26-50, Journeyman 51-75, Expert 76-100.
4. Finishing a training level sets a **family floor** at the old cap plus 5 (30, 55, 80). It is not written into every descendant: a skill's effective value is `max(own practice value, floor of its family)`, for the trained skill and its descendants only, and decay never takes it under the floor. Training also makes gains **x1.2** for that skill (stacking per level), and opens new subskills.
5. **Subskills** unlock when the parent reaches a threshold: tier 1 at **15**, tier 2 at **40**, tier 3 at **65**, tier 4 at **90**. Tier 1 is reachable untrained; tier 2 and beyond need the parent trained. Dave's example works as written: sword training to 15 lifts every sword skill to a floor of 15; training with a rapier raises Swordplay a little (20 percent) and Rapier the most (80 percent); Rapier reaching 15 unlocks its subskills; Swordplay reaching 15 unlocks all first-tier subskills.
6. **Higher means more experience**: next-point cost grows 4.5 percent per point and parents cost 1.5 x per generation of depth, so a deep subskill needs far more than its foundation.
7. **Traits** sit at the root. A trait (-10 to +10) changes effectiveness by about +/-20 percent and learning speed by about +/-10 percent through the skill's trait links. Traits never change the cap, so nobody is locked out of anything.
8. **Side links**: a skill may list several parents with weights (light weapons: Athleticism 0.5 + Dexterity 0.5; broadsword: Athleticism 0.5 + Strength 0.5). Practice is shared 80 percent to the skill and 20 percent up the parents, at ratio 0.4 per generation. The working level also counts 0.2 x the weighted parents.
9. Gain per success is scaled by task level: nothing when the task is 20 or more below your skill, up to x1.5 for a task above it (so high-tier actions pay more), and by the per-game-day cap per skill kept from today.
10. Decay stays gentle (idle 7 game days, half-life 60, floor 20 percent of the peak or the family floor, relearn x3).

## 2. Numbers and curve
Cost of the next point from value n: `40 x 1.045^(n-1)` practice units, times 1.5 per generation for non-foundation skills. Cumulative: about 1,800 to reach 25, 7,100 to 50, 23,000 to 75 and 68,000 to 100, which is roughly 6, 24, 80 and 230 real hours of play for one deep skill (Tyler's estimate; a game day is one real hour and the per-day cap bounds speed). **The per-skill practice cap per game day moves from 40 to about 300 practice units** (a success is worth about 7 units, so roughly 40 successes a day as today); with 40 units a day the same curve would take 5 to 8 times longer (tools/skills_sim.py prints both). The simulation (tools/skills_sim.py) at 300 a day gives, for a depth 0 skill with training jumps counted (the wait for a teacher is not), about 6 h to 25, 21 h to 50, 58 h to 75 and 150 h to 100; a depth 1 skill takes 1.5 times that and a depth 2 skill 2.3 times (340 h to 100). A trait of -10 or +10 moves the 150 h to 215 h or 116 h. Tyler's own estimate was 6/24/80/230 h; the training jumps skip part of the curve, which is why the top is lower here. If Dave wants it longer, raise `growth` or `base_cost`. Gain slows to zero in the last 6 points under the cap. Knobs in data: `base_cost`, `growth`, `generation_mult`, `cap_step`, `unlock_tiers`, `floor_over_cap`, `train_speed`, `task_band`.

## 3. Training
- Teacher value at least the target plus 10, trained to at least that level, a different account from the student. The student must be within 5 of their cap. A session lasts 20 to 30 real minutes, takes materials or coins, and has a cooldown of 3 game days per skill. NPC teachers only up to level 1 or 2; higher levels need a player Master. Books give level 1 only.
- Teaching is itself practised (a Teaching skill under Charisma), later.
- Stored per skill: practice, training level 0-4 (the cap and floor follow it), peak.

## 4. The web (traits at the root)
Traits: **Strength, Dexterity, Fitness, Intellect (today's Memory), Perception, Charisma**. Strength, Intellect and Fitness exist now; the rest start at 0 (neutral) for every character, so old saves load.

```
Fitness ──► Athleticism ──┬─► Endurance ─► Running, Swimming, Hauling
(Strength)                ├─► Jumping ─► Vaulting, Landing (cuts fall damage)
(Dexterity)               └─► Fighting ─► Brawling, Swordplay, Axe handling, Spear, Throwing
                                           Swordplay ─► Light blades (Dagger, Rapier) [Athleticism+Dexterity]
                                                    └► Broadswords (Longsword, Greatsword) [Athleticism+Strength]
Strength ───► Labour ─► Woodcutting ─► Felling, Splitting;  Mining ─► Prospecting, Quarrying;  Digging ─► Trenching, Terracing
Intellect ──► Foraging group: Gathering ─► Foraging ─► Herbs, Mushrooms, Berries;  Fishing group ─► Rod, Spear fishing, Ice fishing
Dexterity ──► Trades ─► Crafting ─► Toolmaking, Woodworking, Leatherwork, Metalwork ─► Smithing (+Strength)
Perception ─► Survival ─► Tracking, Hunting ─► Bowman, Trapper;  Weather sense
Charisma ───► Social ─► Haggling, Teaching, Persuasion
Intellect ──► Lore ─► Herb lore, Geology, Surveying, Reading
```
Fighting is a foundation, not a combat system: Brawling, Swordplay and the rest are placeholders in the web until combat exists (they unlock when their weapons do).

## 4b. Special moves come in chains (Dave 2026-10-21)
Skills are things to chase, not a grind (the 150-hour rule stands for now; Dave tunes it in playtest, so every number stays data). After the main item skill come specialty moves, in a chain of tiers, each unlocked by the one before it reaching its threshold:
```
Swordplay ─► Rapier ─► Parry ─────► Parry combo        (names of the specialty moves come later)
                   ├─► Strike ────► Strike combo
                   └─► Sweep ─────► Sweep combo
Swordplay ─► Broadswords ─► Cleave, Guard break, ...
Knives ─► Daggers ─► Backstab, ...
```
**Master tier (Dave 2026-10-21):** an ultimate tier of master moves needs several sibling skills raised together, e.g. Parry, Strike and Sweep all at the tier-3 threshold (65) unlock "Master moves" under Rapier. In data a node's unlock is a list of requirements (`needs: [{skill, value}]`), so one parent threshold is just the simple case and "all siblings at N" is the same field with more entries. Placeholder: Rapier master moves need Parry, Strike and Sweep at 65 each.

Rules: a move node is a normal skill node of depth one deeper than its parent (so it costs more), starts at its parent's value when unlocked, and carries a `move` list of what it grants (a combat move, a crafting technique, a gathering trick) instead of only a bonus. Move names, effects and numbers are placeholders in data until Dave names them. The same pattern applies outside combat: Smithing unlocks Forge welding, which unlocks Pattern welding; Foraging unlocks Herbs, which unlocks Tinctures.

## 4c. The screen is a family tree, bottom up (Dave 2026-10-21, long term)
The skills screen will draw like a family tree growing upward: traits at the bottom as roots, foundations above them, then skills, then subskills and moves at the crown. Example: Knives branch to Daggers, Hunting knives, Chef's knives; Swords branch to Short swords, Broadswords, Greatswords, Scimitars, and so on. The data already carries everything a layout needs: every node has `parents` (with weights, so side links draw as thin extra lines), a computed `depth` (the row, 0 at the roots), an optional `order` hint for left-to-right placement among siblings, `needs` (the unlock requirements, drawn as a lock until met) and a `group` colour key. Locked nodes show greyed with their requirement, unlocked ones with value and tier, so the tree teaches the web. No UI is built yet; step B's list view reads the same data, so the tree can replace it later without a data change.

## 5. How today's skills map in
| Today | Web node (id kept) | Parent(s) | Trait links |
|---|---|---|---|
| foraging | Foraging | Gathering | Intellect 0.6, Fitness 0.4 |
| woodcutting | Woodcutting | Labour (Woodwork) | Strength 0.7, Fitness 0.3 |
| mining | Mining | Labour (Stonework) | Strength 0.6, Fitness 0.4 |
| digging | Digging | Labour (Earthwork) | Strength 0.6, Fitness 0.4 |
| crafting | Crafting | Trades | Dexterity 0.5, Intellect 0.3, Strength 0.2 |
| jumping | Jumping | Athleticism | Strength 0.5, Fitness 0.5 |
| fishing | Fishing | Fishing group, Gathering | Intellect 0.5, Perception 0.3, Fitness 0.2 |
| action tool_care | Crafting (toughness) | | |
Existing action hooks (`gather_plant`, `fell_tree`, `fall`, `craft`, `fish`, `dig`, `mine_rock`) stay as they are; later each action can name a subskill (Felling) and the parent still receives its 20 percent.
Group names stay (athletics becomes Athleticism, labour replaces woodwork/stonework/earthwork as one group with three children, which is the same shape).

## 6. The factor (what a skill does)
`factor = 1 + (max_factor - 1) x (working_value - 1) / 99`, never below 1.0 and capped at max_factor, where max_factor is per skill as today (Jumping toughness 4.0, Woodcutting speed 2.0, and so on). An untrained character at 25 gets about a quarter of the way; an Expert gets the full effect. Rusty shows as today.

## 7. Server and save format
- characters.json "skills": per skill `{xp, train, peak}` (practice points, training level 0-4, best value for decay). Values are computed from xp by the curve (inverse of the cost sum, cached). The skills block carries schema_version 2, a .prev copy is kept, and the migration has a dry-run mode that reports who changes.
- **Migration of old saves**: for each old record, take its old level L_old (0-100, 10 = average), convert the earned part to the new scale, `v = 1 + 24 x (1 - exp(-k x practice))` (the same fraction of the way to the untrained cap); anyone already above 25 is grandfathered at their old value, set xp to match that value, train 0, peak likewise. Nobody loses a point of earned progress relative to their own curve, nobody lands above the untrained cap, and the "average character factor 1.0" is preserved. Unknown skills default to value 1, train 0. Tested in the persistence drills (an older-save drill already exists).
- Protocol: the skills message carries (value, train) per skill and the unlock list; bump when built; cost at Low is a text list in the Tab screen only.
- Server cost: values are a function of xp, recomputed on practice only (a few microseconds), no per-tick work beyond the existing lazy decay.

## 8. Tab screen
A list by group, indented by depth, with value, tier name, a bar to the next unlock or cap, a lock line for skills still shut ("Rapier: needs Swordplay 15"), a "Needs training" mark at the cap, and the trait root named under each group. Fonts at least 24 px. Greyed subskills teach the web by being visible.

## 9. Build order (each its own push, after approval)
A) Data format + curve + migration + tests (no UI): `skills.json` v2, SkillRules v2, a curve table test, migration drill.
B) Unlock rules, parents and side links, shared practice, the Tab screen.
C) Training: trainer NPC hook (needs NPC step A), books, jumps, cooldowns.
D) Fill out the web as systems arrive (fighting with combat, smithing with the forge, tracking with animals).

## 10. Open questions (decided by me unless Steve objects)
- Scale 1-100 with 25-point blocks (Tyler's tuning, close to Dave's examples). Easy to change in data; a simulation script prints the hours per skill before anything ships.
- Traits Dexterity, Perception, Charisma are new and start at 0; character creation does not roll them yet (a later job with the creation screen).
