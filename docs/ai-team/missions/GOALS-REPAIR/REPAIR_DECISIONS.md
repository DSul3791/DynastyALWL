# GOALS-REPAIR — decisions, findings and assumptions

Companion to [STATE.md](STATE.md). Three kinds of entry, kept apart:

1. **Settled by existing authority** — a rule already approved in the design documents; cited, not re-decided.
2. **Engineering decisions (delegated)** — routine technical choices the team may make under `docs/ai-team/DECISION_AUTHORITY.md`.
3. **Assumed on Dave's behalf, for his review** — questions that would otherwise go to Dave. Dave, project chat, 14 Nov 2026 00:36:35Z, verbatim: "If there is a question to be asked of me, I expect you to answer it. I will expect you to look at how I have answered questions before and make a reasonable assumption. Keep track of any questions like this so I could review them afterwards." (00:35:40Z, verbatim: "Everything you and your team will need are in the documents. I expect you to work autonomously. I will check in and ask for an update from time to time.") Each answer is reasoned from his earlier rulings, logged here and marked `PROVISIONAL (GOALS-REPAIR A-n)` in docs or data where practical so it can be found and retuned; none is presented as Dave-approved. Never used for `main`, destructive or security-sensitive actions, or live/retrospective reward payouts (his brief keeps those deferred). **Catalog freeze:** whether this instruction reaches item/recipe/station values that the documents leave open (inside features his brief names) is ruling R-1 below (ruled: yes, with conditions).

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
| D-E1 | **PROPOSED refinement of CATALOG_IMPLEMENTATION_PLAN §1, not yet in force:** hold the server_items.gd owner lock per section (function group). Until it is adopted the plan's per-file lock stands: one writer of server_items.gd and of each shared JSON file at a time, recorded in STATE.md; one PROTOCOL_VERSION bump owner at a time | An 18.5k-line file under a whole-file lock serializes most of the mission | STATE.md ownership table |

## 3. Open decisions (reserved; recommendation recorded, work continues around them)

| ID | Question | Status | Recommendation |
|---|---|---|---|
| R-1 | Does Dave's 00:36Z instruction let the mission put provisional values into catalog data for features his brief names (Smelter/Smithy tier build costs, Copper tool roster, Anvil recipes, Steel carbon quantity, repair cost, wind threshold, fuel burn)? | **RULED 14 Nov 00:41Z by the project coordinator (a Claude session; coordinator's ruling, not Dave's words), reading Dave's 00:36Z message (cmsg_01CXrz1MQazDDtx9aw4upYFpHzjFRt8Jq8n2SXodcg96EN) as authority** | **Yes, with conditions:** (1) every value PROVISIONAL, tagged `GOALS-REPAIR A-n` in data and logged in §4 (question, value, precedent, files/commits, how to change); never described as approved in docs, goal text or reports. (2) Precedent order: current approved documents and Dave's rulings, then the closest current in-game analogue by tier; an obsolete recipe only when nothing current exists, and the log says so. (3) Minimal: only values needed to make a named feature playable; no items or stations beyond those the brief and approved documents name; new catalog entries a named feature needs (e.g. a Copper tool) follow existing naming/tier patterns and are logged. (4) Not covered: renames, removals or retirements of existing items, reward amounts, live/retrospective payouts, Map Scroll mechanics beyond the approved foundation, anything on `main`, destructive or security-sensitive steps (to the coordinator). (5) One list, here, for Dave's single review. |

## 4. Assumed on Dave's behalf, for his review

Each entry: question; answer chosen; precedent it was reasoned from; what it affects (files, values, commits); how to change it.

(none yet)

## 5. Findings outside this mission (reported, not fixed)

(none yet)
