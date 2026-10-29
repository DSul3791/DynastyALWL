# Items and crafting handoff (Radar), written 2026-10-21

Names (Dave): Radar = Items and Crafting (me). Steve = Technical Director (build numbers, approvals). Mandy = Arts Director. Willy = Grounds Keeper (ground/client perf). Sonny = Water Works.

## What I own
Server-authoritative items, inventory, crafting, survival vitals, digging, sleep, energy, fitness/luck, water containers, fall damage, Tab/inventory screens. Code: src/stream/server_items.gd (server), scenes/terrain_server/terrain_server.gd (wiring), src/stream/terrain_net.gd (RPCs, ACT_* codes, protocol), src/client/inventory_view.gd, character_screen.gd, held_item.gd, faint_effect.gd, src/shared/vitals_rules.gd, tree_support.gd, data/items/*.json (items, recipes, weights, vitals, digging, sleep, energy, fitness, skills, drops...). Docs: ITEMS_DESIGN.md, PROTOCOL.md, CONTROLS.md; design notes in /mnt/project-files/items/ (BALANCE, LUCK_NUMBERS, DEATH_RESPAWN_DESIGN, HUNTING_PREREQUISITES, SKILLS_AND_ATTRIBUTES, WATER_CONTAINERS_DESIGN, FOOD_SPOILAGE_DESIGN, CLOTHING_AND_WARMTH_DESIGN).

## Working rules
- Local branch claude/project-thread-5x1cni; push ONLY `git push origin HEAD:claude/generator-v2`. Never main.
- Before pushing: `GODOT=/tmp/claude/eng/godot python3 tools/items_check.py [--only a,b]`, `--check-only` on changed .gd, `python3 tools/check_controls.py`, `python3 tools/check_luck.py`. Update CONTROLS.md for inputs, PROTOCOL.md for protocol, same push.
- After rebase: git status, grep ^<<<<<<<. BUILD in scenes/terrain_client/terrain_client.gd: HUD BUILD = max(upstream, mine). Log by commit id in tech/BUILD_LOG.md; tell Steve the commit id after each push.
- Steve's standing approval: protocol bumps/save changes for features Dave already chose, if PROTOCOL.md updated, saves versioned with neutral default, Low-tier cost stated. New design not chosen by Dave: ask first (one card, 2-4 options + recommendation).
- Dave uses voice: short replies, no greeting, end result posts with "Still waiting on: ...". Visual claims say "checked headless / software-rendered stills, not by eye". Item names plain nouns. Fonts >= 24 px. E = interact. No bars on the main screen (bars only at top of inventory and Tab screens).
- Commit trailers: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> and Claude-Session line. No model names elsewhere. Never `pkill -f`.
- message_thread/message_coordinator daily quota was spent; use post_message and notes in tech/JOBS.md.

## Dave's decisions (his words where it matters)
- Falling: "a reasonable height to jump from without hurting yourself, above that damage relates to how far you fell", "reduced by your jump skill". Built: safe 6 m, 8 hp/m, faint 12 m, Jumping skill hook.
- Water containers: "keep it light so no dirty water and sickness and no dropping the container and spilling". Built (wear field = millilitres).
- Cards: Fitness "Starts fixed, trains slowly" (built); Spoilage "Gentle" (not built); Cold "Cold costs health" (not built).
- Energy (built): master pool like health. Drains with exertion; ~3 game days (= 3 real hours, 24:1 clock) of normal play empties it; sit refills to max 75%; lying down an hour (game) refills fully; after emptying you need 8 game hours rest (20 real min) or supplements: Energy bars (nuts, fruit, herbs), teas, magic tonics (higher level, future). "using energy supplements is bad for your fitness."
- Sleep: hold Z to lie down and close eyes; exertion falls 6x, health heals 2x; lean-to full, open dry ground 60%, rain 20% and wakes you.
- Death: ALREADY designed in DESIGN_IDEAS.md 6.1 (see below). Do not re-ask.

## Built (all pushed)
- Dig yields/fill/spade tiers, dig under trees fells them, sleep (protocol 29), water containers (31), fitness training, fall + jump skill, persistence drills, next-tier recipes.
- Energy: commit 39aa505 (feature d077109 + build bump), build 399, protocol 33. energy.json (drain 12/day rest + 42 x exertion, sit cap 75, sleep 12.5/game hour), vitals.json energy_aids (energy_bar +25/fitness 0.25, herbal_tea +12/0.1, magic_tonic +50/0.5 future), purple Energy bar at top of inventory and Tab, collapse at 0 = forced sleep (stance bit 8, movement locked, wakes only when full), saved "energy" in vitals.json, fitness loss capped 3 below base. Server unit tests pass; client checks texttest, eat, quickkeys, drills, validate_items pass. Not looked at by eye.
- Protocol: 29 sleep, 30 fill (Ground), 31 containers, 32 breath (River), 33 energy (mine).

## Known issues / gotchas
- Persistence check (test_items_persistence.gd) TIMED OUT at 600 s in the cloud on my last run; not rerun after Energy. Rerun `--only persistence` alone first thing; if it hangs, check whether energy field load/save broke it (older saves must start at 100).
- strainrun client check fails on upstream (body ran 23 m); assigned to Willy, don't chase.
- Eat client check once flaked on a flora_view `_decimate_task` error; rerun passes.
- BUILD_LOG line for 371 points at wrong commit.
- Client tests need a server (about 40 s wait).
- Magic tonic is `future: true`.

## Death and respawn (reviewed 2026-10-21; I reported to Dave)
DESIGN_IDEAS.md 6.1 decides: death when no recovery; restart as new character or child (heir inherits all); ARK-style downed state (revive/carry/drag; downed timer runs offline); remains = body with backpack and all gear; day 1 only owner can loot, days 2-7 anyone and intelligent creatures may hoard, day 8 gone with the gear; server record placed on surface, rechecked on terrain load/change, sinking is visual only; map death marker with countdown; wizard fetches all your remains for ~10% of gear value, min 1 gold (also NPC party gear); disease death rejected. Still open: knocked-out vs downed choice, downed window by age/condition, what to build first. Plan told to Dave: rewrite items/DEATH_RESPAWN_DESIGN.md to follow the doc (my old option (d) full loss was wrong; drop the old card), first build = remains container with 7-day timeline + owner lock + respawn with vitals reset; wizard/heirs/downed later. NOT yet rewritten or built; Dave did not object yet.

## Queue (Steve's tech/JOBS.md, Items refill 8)
91 spoilage note + card (Gentle chosen: write the design note, build after); 92 warmth note + card (Cold costs health chosen); 94 inventory/Tab audit; 87 skills list; death note rewrite then remains build. Other pending: skills system with Strength/Memory attributes, hide-based items (waterskin, backpack effect), placeables not drawn in first-person hand, agree held-tool attach node name with Mandy, fold Sounds' STRUCTURE_EVENTS.md facts in when touching structures, saw mill parked.

## Open cards waiting on Dave
Death/respawn card (should be withdrawn/closed per the doc review). Sleep card (two-question; simple version built). Steve reviewing notes 65 and 68.

## Build numbers I hold
399 used (Energy). 400 spare. Leftovers below 396 usable. Ask Steve for more.
