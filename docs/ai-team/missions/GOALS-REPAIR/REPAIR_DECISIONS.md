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
| D-E1 | **ADOPTED 14 Nov 00:44Z by the project coordinator (routine engineering under delegated authority; coordinator's ruling, not Dave's):** server_items.gd is owner-locked per section (split in STATE.md and the briefs); each shared JSON file has one owner; one PROTOCOL_VERSION bump owner at a time, numbers assigned by the lead. Conditions: rebase on current `dev` before merge; the independent reviewer confirms the diff stays inside its own sections; cross-section needs go to the section owner through the lead; if conflicts cost more than they save, serialize and tell the coordinator | An 18.5k-line file under a whole-file lock serializes most of the mission | STATE.md ownership table |

## 3. Open decisions (reserved; recommendation recorded, work continues around them)

| ID | Question | Status | Recommendation |
|---|---|---|---|
| R-1 | Does Dave's 00:36Z instruction let the mission put provisional values into catalog data for features his brief names (Smelter/Smithy tier build costs, Copper tool roster, Anvil recipes, Steel carbon quantity, repair cost, wind threshold, fuel burn)? | **RULED 14 Nov 00:41Z by the project coordinator (a Claude session; coordinator's ruling, not Dave's words), reading Dave's 00:36Z message (cmsg_01CXrz1MQazDDtx9aw4upYFpHzjFRt8Jq8n2SXodcg96EN) as authority** | **Yes, with conditions:** (1) every value PROVISIONAL, tagged `GOALS-REPAIR A-n` in data and logged in §4 (question, value, precedent, files/commits, how to change); never described as approved in docs, goal text or reports. (2) Precedent order: current approved documents and Dave's rulings, then the closest current in-game analogue by tier; an obsolete recipe only when nothing current exists, and the log says so. (3) Minimal: only values needed to make a named feature playable; no items or stations beyond those the brief and approved documents name; new catalog entries a named feature needs (e.g. a Copper tool) follow existing naming/tier patterns and are logged. (4) Not covered: renames, removals or retirements of existing items, reward amounts, live/retrospective payouts, Map Scroll mechanics beyond the approved foundation, anything on `main`, destructive or security-sensitive steps (to the coordinator). (5) One list, here, for Dave's single review. **Disclosed limit:** DECISION_AUTHORITY.md says a direct instruction from Dave does not bypass the item catalog freeze "unless explicit". His 00:36Z message does not name the freeze, so this reading goes beyond that text and is unconfirmed by Dave. It is item 1 of his review list. Until he confirms it, catalog-value PRs merge to `dev` only, every value stays PROVISIONAL, and none goes near `main`. |

## 4. Assumed on Dave's behalf, for his review

Each entry: question; answer chosen; precedent it was reasoned from; what it affects (files, values, commits); how to change it.

| ID | Question | Answer (PROVISIONAL) | Precedent | Affects | How to change |
|---|---|---|---|---|---|
| A-1 | How many millilitres of a filled container make one recipe `water` ingredient? | **500 mL** | `vitals` thirst `fill_ml` = 500 (one fill action); `weights.json` water 0.5 kg; recovery GA-04 proposed the same | WP-R1A water adapter (one data constant); every recipe using `water` (28) | Change the one constant tagged `PROVISIONAL (GOALS-REPAIR A-1)` |
| A-2 | How much Tannin Bark does an oak give, and from which action? | The existing oak harvest yield (3), **once per felled oak trunk** when the player processes it; no standing-tree farming | `drops.json` oak tannin_bark 3; recovery GA-01 "genuine one-time oak bark/trunk harvest; avoid unlimited E-on-tree farming" | WP-R1A trunk processing | Edit drops.json oak count, or move the yield to another action |
| A-3 | How much water does one "water the bed" action pour? | Up to **8000 mL** from filled containers, with the crop's `pour_pct` scaled by what was poured | `crops.json` defines `pour_pct` as one 8 L bucket | WP-R1A ACT_WATER_BED | Change the constant tagged `PROVISIONAL (GOALS-REPAIR A-3)` |
| A-4 | A new world starts on day 100 (summer), when wheat, barley, oats and flax cannot be sown (spring only; rye autumn). Change the seasons? | **No data change.** The guide teaches spring sowing; summer-sowable crops (radish, lettuce) and wild seeds remain the early route | Dave: catalog fixed, no redesign without him; `sow_seasons` is the field the server reads (14664), `sow_season` singular is stale | Goal how-to text (R7); stale `sow_season` field reported in §5 | Change crops.json `sow_seasons` |

## 5. Findings outside this mission (reported, not fixed)

- `data/items/crops.json`: 15 crops carry a singular `sow_season`; for nine of them (oats, carrot, potato, cabbage, onion, peas, beet, flax, parsnip) it disagrees with the `sow_seasons` list the server actually reads (server_items.gd ~14664). Reported; left unchanged pending the catalog owner (R1 baseline).
- `scenes/terrain_preview/terrain_preview.gd`: bare `KEY_G` (tool scene), handled in WP-KEYS.
