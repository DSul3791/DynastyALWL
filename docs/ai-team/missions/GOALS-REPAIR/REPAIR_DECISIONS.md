# GOALS-REPAIR — decisions, findings and assumptions

Companion to [STATE.md](STATE.md). Three kinds of entry, kept apart:

1. **Settled by existing authority** — a rule already approved in the design documents; cited, not re-decided.
2. **Engineering decisions (delegated)** — routine technical choices the team may make under `docs/ai-team/DECISION_AUTHORITY.md`.
3. **Assumed on Dave's behalf, for his review** — questions that would otherwise go to Dave. Per his instruction (14 Nov 2026 00:36Z) we answer them from his earlier rulings with a reasonable assumption and log them here. Values are marked `PROVISIONAL (GOALS-REPAIR A-n)` in data or docs where practical so they can be found and retuned. Not used for `main`, destructive or security-sensitive actions, or live/retrospective reward payouts (those stay deferred).

## 1. Settled by existing authority (index)

| Topic | Rule | Source |
|---|---|---|
| Smelting conversions | 1 ore → 1 ingot (Cu, Sn, Fe); 1 Cu ore + 1 Sn ore → 2 Bronze; no temperature | Master §2.7; repair plan P3; CATALOG_IMPLEMENTATION_PLAN §2 |
| Smelter tiers | Primitive 20/20/ground output, 20 s/ingot, no iron; Improved 40/40/80, manned bellows 1.30× and iron; Advanced 80/80/160, integrated windmill + two bellows, 2 lanes, ~11.83 s per 2 ingots, zero production in insufficient wind | same |
| Smithy tiers | Primitive (stone-tool build, copper/bronze), Improved (bronze anvil; makes Iron Saw + Iron Anvil; iron wears it faster), Advanced (built with Iron Anvil; makes Steel Anvil), Master (built with Steel Anvil; integrated quencher) | same |
| Smithy wear/repair | Broken stays placed, "Needs repair", ordinary hammer right-click → Repair, War Hammers excluded, materials from player/nearby storage/ground, atomic | repair plan P3 |
| Resource bins | Small/Medium/Large 1000/5000/10000 units; 16+32 / 32+64 / 64+128 Planks+Nails; first deposit assigns type; unassigned when empty | repair plan P3; STORAGE_WAREHOUSING_DESIGN |
| Fuel auto-pull | Coal/Charcoal only, from assigned bins, kilns, fires within 30 m, every 300 s, oldest station first, full hopper skipped, no permission check, never wood | repair plan P3 |
| Goals | All automatic; no `after` award gate; once per character; coins only; draft reward figures unchanged; HUD = two earliest unfinished in authored order | PLAYER_JOURNAL_GOALS_UI; recovery Q5/Q7, GA-40, GA-91 |
| Admin keys | Every admin/debug action Ctrl+Shift+key incl. custom binds and hardcoded paths; inventory plain-G Store All kept; J/G/M Journal | ADMIN_KEYBINDINGS_POLICY |

## 2. Engineering decisions (delegated)

| ID | Decision | Reason | Affects |
|---|---|---|---|
| D-E1 | The server_items.gd owner lock is held per section (function group) and per shared JSON file, recorded in STATE.md; PRs rebase on `dev` before merge; one PROTOCOL_VERSION bump owner at a time | An 18.5k-line file under a whole-file lock would serialize the whole mission; section locks keep one writer per region and avoid merge collisions | STATE.md ownership table |

## 3. Open decisions (reserved; recommendation recorded, work continues around them)

| ID | Question | Status | Recommendation |
|---|---|---|---|
| (to be filled from the baselines) | | | |

## 4. Assumed on Dave's behalf, for his review

Each entry: question; answer chosen; precedent it was reasoned from; what it affects (files, values, commits); how to change it.

(none yet)

## 5. Findings outside this mission (reported, not fixed)

(none yet)
