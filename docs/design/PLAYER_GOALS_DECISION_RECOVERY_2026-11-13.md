# Dynasty — Goal Audit Decision Recovery and Engineering Disposition (13 Nov 2026)

**Purpose:** Re-examine **ALL 80 stable GA findings** and **ALL 11 audit creator questions**, using later creator decisions, current `dev` design files, data and observed runtime code. Answer everything possible without asking the creator again. Historical original audit **remains unchanged** at `PLAYER_GOALS_REWARDS_AUDIT.md`. This document is a **design/triage resolution**, not a claim of gameplay fixes or an authorization to implement the 651-goal catalog, change rewards or promote `main`.

**Checked sources:** `PLAYER_GOALS_REWARDS_AUDIT.md` sections 1–18, `PLAYER_GOALS_AUDIT_LEDGER.csv` (651 rows plus 26 proposed ADD), `PLAYER_GOALS_REWARDS_DRAFT.md`, `PLAYER_JOURNAL_GOALS_UI.md`, `PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md`, `PLAYER_CARTOGRAPHY_MAP_DESIGN.md`, `DYNASTY_MASTER_ITEMS.md`, `progression.md`, `ADMIN_KEYBINDINGS_POLICY.md`, `drinking_water_design.md`, `field_journal_design.md`, `data/items/{recipes,items,blueprints,boulders,drops,crops,structures}.json`, `data/tables/flora.json`; selected `server_items.gd` water intake evidence; Godot community mapping techniques and historical oak bark sources. These sources have **mixed authority**: owner's later decisions override old proposals; runtime JSON/code is evidence of what exists today, not authority to negate newer owner decisions.

**Current status:** Original audit counts remain 230 PASS / 247 NEEDS_CORRECTION / 30 NEEDS_TEST / 144 BLOCKED, none gameplay-verified. **No evidence exists that these have improved**, despite the proposed repair specifications. All status changes must be measured by new tests.

## 1. Audit creator questions — resolved, defaulted or deferred

| Original question | Current disposition | Reason/action |
|---|---|---|
| Q1 Missing resources | SETTLED: repair, never delete | Existing data already names oak tanbark, Scots pine tar, volume-filled containers and farm actions. Minimal code repairs; 500 mL water-unit mapping proposed from the existing filling action, still an engineering convention to validate. |
| Q2 Total coin budget and variant weights | DEFERRED BY CREATOR | Keep proposed 651-goal draft rewards unchanged through repairs; no 3,059/15,670 rebalance until played time/economy evidence. |
| Q3 Legacy item/reputation rewards | DIRECTION SET; migration detail later | The proposed new guide pays coins automatically. Old Twine/Fell/Story item/reputation grants need a safe conversion plan at launch, not an ad-hoc immediate code edit; example draft copper amounts are not final live authorization. |
| Q4 Existing-character catch-up payouts | PROPOSED SAFEST DEFAULT | Migrate old IDs, mark earned historic goals complete without double reward or a flood of placards; preserve historic already-paid state. Needs review before actual payout migration. |
| Q5 Per-character vs per-account | PRESERVE EXISTING | Current game uses per-character goals; keep it until there is explicit approval for a different design. |
| Q6 What counts as Gather | ENGINEERING DEFAULT | Only authentic first-hand natural acquisition, not purchases, chest withdrawal or admin grants. This is consistent with the instructional meaning of Gather; validate source tags. |
| Q7 Two goals on HUD | CREATOR-APPROVED | Two earliest unfinished in approved authored display order; all goals progress in background; no selection/activation. |
| Q8 Map tab with no world map | NEW CREATOR-APPROVED DIRECTION | Mapping is an actual new exploration-skill mechanic: character discovers land; charcoal sketch gets more accurate with skill; revisits refine; map scrolls later share/sell. See PLAYER_CARTOGRAPHY_MAP_DESIGN.md. |
| Q9 Placard alpha, icon and fanfare | MOSTLY ANSWERED BY EXISTING ART | Use blank original supplied design, accurate dynamic currency and existing coin icon; source genuinely licensed/original sound. Alpha problem only returned to creator if a visible issue remains. |
| Q10 Locked 24 blueprints | DIRECTION SET: FIX, DON'T DELETE | 23 approved KEEP but runtime-locked water/garden structures need actual functional unlock; stage content until working, don't label achieved. Wool Rug is FUTURE; do not falsely publish. |
| Q11 Bronze order | CREATOR-APPROVED SUPERSEDED | New Primitive -> Improved -> Advanced metalworking ladder requires copper and bronze before the first iron tools; old iron-first Wilderness route/Stone Forge role are superseded. |

**The 11 questions no longer justify an 11-question interview.** Q1, Q7, Q8, Q10, Q11 are answered by later creator direction; Q5 is a preserve-existing rule; Q6 is a low-risk engineering default to validate; Q9 has an accepted art asset with a sound dependency; Q2/Q3 and Q4 belong in **later economy/migration authorization** and must NOT delay missing-mechanics repairs.

## 2. Complete 80-finding reconciliation

**Classification discipline:** OWNER SETTLED = user-directed; REPAIR/TEST = evidence-based implementation or verification ticket; ENGINEERING DEFAULT = recommendation that needs technical validation and must not masquerade as owner-approved policy; DEFER = explicitly separate future pass; PRESENT STATE ≠ IMPLEMENTED. The original audit GA ID and counts remain stable.

| GA ID | Audit severity | Disposition | Answer, corrective action or proof required |
|---|---|---|---|
| GA-01 | HIGH | REPAIR | Use the existing oak tannin_bark yield (3) through genuine one-time oak bark/trunk harvest; avoid unlimited E-on-tree farming. Verify full tanning chain. |
| GA-02 | HIGH | REPAIR | Fix Scots pine trunk loot enumeration so its already-declared pine_tar 1-2 may actually drop, alongside resin; prove Tar -> Water Wheel -> Sawmill. |
| GA-03 | HIGH | REPAIR | Wire existing client sow/water/harvest affordances to authoritative farming actions; no new farming menu; verify flax and four grains across seasons. |
| GA-04 | HIGH | ENGINEERING DEFAULT | Bridge recipe water demand to volume stored in real filled containers, respecting consumed millilitres. Proposed 1 water ingredient=500 mL (existing fill action); test capacity, partial fills, salty/frozen source rules; do not claim user approved the volume conversion. |
| GA-05 | MED | REPAIR | Replace 12 erroneous gather how-tos from actual item sources/actions in ledger; don't invent gather interactions. |
| GA-06 | HIGH | REPAIR | Link every input to an obtainable source or earlier step with exact tool/station/amount; review 109 affected rows for hidden prerequisites. |
| GA-07 | MED | REPAIR | Reorder side-branch display/instructions after prerequisite teaching but NEVER gate automatic goal eligibility. |
| GA-10 | HIGH | REPAIR | Explain different trees producing plain small-block logs vs key-species large-block logs; route to Wooden Hammer and Chopping Block without a tree-species dead end. |
| GA-11 | HIGH | REPAIR | Teach an actual hunting-capable weapon/action before requesting hide; validate player-controlled hunt and carcass processing. |
| GA-12 | MED | REPAIR | Teach 3 m logs, one shoulder-carried species log at a time, Q placement, 3 m local blueprint sourcing, plain Log stacking separately. |
| GA-13 | HIGH | REPAIR | Credit firewood splitting regardless of legitimately taught chopping method, including direct action vs Chopping Block, with exactly-once completion. |
| GA-14 | MED | REPAIR | Teach craft-kit -> equip hammer -> place using actual build controls for campfire, block and bed. |
| GA-15 | MED | REPAIR | Teach cooking pot on small campfire BEFORE the incompatible bonfire/log upgrade; avoid impossible tutorial order. |
| GA-16 | MED | REPAIR | Teach harvesting Leaves before Lean-to; verified live blueprint consumes 60 Leaves; do not copy a stale 200-leaf note as build cost. |
| GA-17 | MED | TEST | F6 test Thatch Bed under cover/near Crude walls; repair ghost vs authoritative rejection only if reproduced. |
| GA-18 | MED | REPAIR | Teach Roof 45 and Roof 65 panel attachments, edge/top constraints and mouse-wheel rise/fall; use owner-approved no-leg geometry. |
| GA-19 | MED | REPAIR | Give each goal exact input quantities from updated valid recipes and shared prerequisites, never old multi-ore smelting costs. |
| GA-20 | HIGH | REPAIR | Teach fuel and operating state for smithy forges/smelters; use current integrated stations and distinct hopper/input carbon, not obsolete forge/add-on names. |
| GA-21 | HIGH | REPAIR | Explain Sawmill's raised >=0.5 m qualifying foundation and suitable fast/deep water; validate reach in world. |
| GA-22 | MED | ENGINEERING DEFAULT | Teach campfire first-charcoal recipe early; Kiln batch charcoal as later higher-volume upgrade. Do not force building a Kiln as a prerequisite to Primitive Smelter if campfire charcoal is already obtainable. |
| GA-23 | MED | OWNER SETTLED | Replace iron-first guide: Stone tools -> Primitive Smelter + Primitive Smithy -> Copper -> Copper/Tin/Bronze -> Improved -> Iron -> Advanced -> Steel -> Master Smithy. Remove duplicate Stone Forge rung. |
| GA-24 | HIGH | REPAIR | Teach doorway/frame before actual door for each family; doors are separate placeable items, matching approved single/double and arched rules. |
| GA-25 | MED | TEST | Practical F6 checks for all doors/frames and Roof 65 placement, including corner failures; not pass on static model. |
| GA-26 | MED | REPAIR | Rebuild instructional tier groups (foundation, wall, doorway, door, window, roof) at first obtainable material; no disconnected late doors. |
| GA-27 | MED | REPAIR | Honor current master rule: chisel is for sculpture/art, not a hidden required stone-construction tool; reconcile inconsistent Stonecutter recipes or teach a genuine valid dependency. |
| GA-28 | LOW | REPAIR | Explain Workbench upgrades using real station levels, not a fictitious dependency on a later Carpenter's Bench. |
| GA-29 | LOW | REPAIR | Rewrite station descriptions for integrated Improved Smelter bellows, Advanced Smelter integrated windmill/dual bellows and Master Smithy quencher; do not advertise retired standalone add-ons. |
| GA-30 | LOW | REPAIR | Use in-game generic material/group labels (Log, Knife, Axe, Fuel etc.), not internal key-item names. |
| GA-31 | HIGH | REPAIR WITH RUNTIME GATE | 23 approved KEEP water/garden infrastructure blueprints stay planned for activation once their real mechanics exist; currently locked and NOT goal-completable. Wool Rug remains separate FUTURE. Do not delete goals to fake a clean audit. |
| GA-32 | LOW | REPAIR | Move sand, Thread and workstation goals near first useful application, or explain their real function; do not inject meaningless mandatory locks. |
| GA-33 | LOW | REPAIR | Put universal building rules in a concise linked help/how-to once, not repeated paragraphs across 651 rows. |
| GA-34 | LOW | REPAIR | Correct Fire kit starting sticks/lighting text; teach real rain/fire behavior. |
| GA-35 | LOW | REPAIR | Explain that the chosen tree must be big enough for a true log; tiny trees only yield smaller wood items. |
| GA-36 | MED | REPAIR | Move actual drinking/eating goals to a time when the character can consume; preserve full starting hunger/thirst and truthful event completion. |
| GA-37 | LOW | REPAIR | Teach 3 m local log-sourcing once and link from 34 dependent build goals. |
| GA-38 | MED | ENGINEERING DEFAULT | Multiple distinct learned skills may complete on one genuinely performed animal-dressing or build-finish action; each stable goal ID pays once, no invented separate action gates. |
| GA-39 | LOW | TEST | Verify bighorn/wool reachable from ordinary spawns before claiming wool goal chain playable; do not spawn wool for tests. |
| GA-40 | HIGH | REPAIR | Remove after dependency as an automatic award prerequisite; retain instructional links/order only. |
| GA-41 | HIGH | REPAIR | Use persistent earned/made/first-hand histories, not current inventory snapshots. Bought, admin-granted and ordinary container withdrawals do not satisfy Gather. |
| GA-42 | HIGH | OWNER DIRECTION / DEFER | New goal system rewards coins only; existing legacy noncoin grants are technical migration incompatibilities. Preserve existing runtime amounts until reviewed migration; do not silently convert or pay both. Proposed draft conversions: Twine 4, Fell 6, Story 3 copper, not approved for live switch. |
| GA-43 | MED | REPAIR | Credit kiln-produced charcoal, open-fire food, hand-crafts and all legitimate creation paths via common server completion events. |
| GA-44 | MED | REPAIR | Count actual units yielded, not number of craft button activations; preserve item conservation and normal batch output. |
| GA-45 | MED | REPAIR | Emit genuine server activity events for chopping wood and medium/bonfire transitions. |
| GA-46 | MED | ENGINEERING DEFAULT | Gather means first-hand player acquisition (wild pickup/harvest/dig/mine/hunt/fish/farm), not trade, chest take, admin grant, or player-to-player transfer. Test origin metadata; no owner signoff needed before audit planning but flag when authorizing final goal rules. |
| GA-47 | MED | REPAIR | Eliminate unintended duplicate legacy/tier payouts and nonexistent item references while preserving distinct legitimate milestones. |
| GA-48 | LOW | ENGINEERING DEFAULT | Retain distinct craft/place/light/use goals because full guide teaches actions. Merge only true semantic duplicates after review, without deleting approved gameplay or arbitrarily lowering reward. |
| GA-49 | MED | REPAIR | Use indexed event-driven goal evaluation, one reconstruction at login; no 651-goal poll per character every 250 ms. |
| GA-50 | MED | PRESERVE CURRENT | Keep per-character goal/reward ownership for now, as existing runtime does; no unapproved account-wide caps or alt-farming redesign. |
| GA-51 | LOW | REPAIR | Rewrite seven inaccurate legacy goal requirements and labels against current checked server actions. |
| GA-52 | LOW | REPAIR | Tie checks to the actual named action (berry harvest, path destination, torch carrying, sheltered bed) unless creator intentionally authored generic targets. |
| GA-53 | LOW | REPAIR | Fix stale needs_code flags and misleading metadata; verify behavior rather than trust labels. |
| GA-54 | LOW | ENGINEERING DEFAULT | Exclude admin-given items/free crafts/free-build placements from reward eligibility; debug testing cannot mint progression payouts. |
| GA-55 | MED | REPAIR | Persist goals and coin in one atomic save and trigger prompt save after payouts; check hard-crash recovery. |
| GA-56 | HIGH | PROPOSED MIGRATION DEFAULT | Keep legacy IDs/done state; rebuild historic counters once. Default to grandfathering already-earned historical goals as completed WITHOUT retrospective coins/placard flood. Requires explicit release migration review; not an already approved payout decision. |
| GA-57 | MED | REPAIR | Give each of 623 draft goals the stable IDs recorded in ledger, preserving legacy IDs and not deriving user-visible names from IDs. |
| GA-58 | LOW | PRESERVE GUIDE SCOPE | Do not bulk-delete 70 intermediate material/craft goals solely to reduce list length; organize them within the clean Journal and link prerequisites instead. |
| GA-59 | LOW | REPAIR | Correct or remove inflated draft self-audit claims and cite actual verification status. |
| GA-63 | MED | RECOMMEND NOT APPROVED | Review 26 recommended activity goals by actual implemented mechanics; include unique interactions after approval and tests, defer future content. Add possible Explore new area / Draw a Map Scroll goals as later candidates, not automatic edits to the 651. |
| GA-70 | HIGH | DEFER ECONOMY | Creator expressly postponed reward budget and alternatives 15,670 vs 3,059 copper until measured gameplay; no automated rebalance. |
| GA-71 | HIGH | DEFER ECONOMY | Reward scaling/variant family weights require play timings and approval; protect current proposed values meanwhile. |
| GA-72 | MED | DEFER ECONOMY | Price/coin imbalance is a later economic analysis, not reason to weaken material recipes or change goals now. |
| GA-73 | MED | DEFER ECONOMY | Check first-38-goals cash shock in a real test, then revisit with all rewards in one economy pass. |
| GA-74 | LOW | DEFER ECONOMY | Bonfire reward difference reviewed only in approved later economy pass. |
| GA-75 | LOW | REPORT ONLY | Record out-of-scope catalog/economy notes without silently adding gameplay rules. |
| GA-80 | HIGH | REPAIR | J/G/M Journal shortcuts displace jitter/Admin Fly; follow approved Ctrl+Shift admin policy and preserve inventory G Store All. |
| GA-81 | HIGH | REPAIR | Handle Ctrl+Shift in held/inventory controls; admin chords never trigger regular Repair/Store All actions. |
| GA-82 | HIGH | OWNER SETTLED | Every admin/debug action requires exact Ctrl+Shift+key, including hard-coded paths; update saved binds and Help. |
| GA-83 | HIGH | REPAIR SECURITY | Add actual server-side authority validation for privileged actions; shortcuts alone are not authentication. |
| GA-84 | HIGH | REPAIR | Migrate/sanitize old custom admin binds and prohibit future noncompliant rebindings. |
| GA-85 | MED | REPAIR | Align help strings, Controls UI, code map and protocol docs with actual implementation, not proposed keys. |
| GA-86 | LOW | TEST | Test Ctrl+Shift keycode portability and editor F5/F8 interception; adjust unoccupied PRIMARY key only while retaining mandatory modifiers. |
| GA-87 | HIGH | OWNER SETTLED | Journal reuses existing Inventory/Crafting page style/components; HUD is minimalist exception. Keep one window and simple UI. |
| GA-88 | HIGH | REPAIR | Send authoritative goals_state and incremental events to client; no parsing transient notice text or parallel goal engine. |
| GA-89 | HIGH | REPAIR | Rejoin/migration restore states silently; placards only for genuinely new earned completions, queue nonoverlapping fanfares. |
| GA-90 | MED | REPAIR | Position upper-right thin-outline 2-goal box clear of the Comfort/Rested HUD with responsive layout. |
| GA-91 | MED | OWNER SETTLED | HUD displays first TWO unfinished goals in authored approved display order; ALL goals still tracked automatically and eligible out of order. |
| GA-92 | MED | OWNER SETTLED / NEW FEATURE | No world map exists. Build player-explored, sketchy CHARCOAL map in the existing Journal; Mapping skill from exploration and Map Scroll drawing; revisiting old areas refines accuracy. Treat as new gameplay scope, not existing map hookup. |
| GA-93 | MED | REPAIR | Use approved blank placard dynamic title/reward; proper real coin denominations, existing coin art, long-name fit and no fake payouts. |
| GA-94 | LOW | PRESERVE APPROVED ART | Use supplied transparent GoalAchieved blank art as authoritative visual reference; validate alpha/readability and avoid arbitrary opacity redesign. Ask creator only if testing shows a real visible conflict. |
| GA-95 | MED | ASSET DEPENDENCY | Find/commission short original or licensed celebratory fanfare; if unavailable, mark asset dependency and never insert copyrighted sound. |

## 3. Cross-document conflicts that MUST be removed, not overruled in paragraphs

1. **Smelting recipes:** current `recipes.json` still has Copper/Tin smelting `3 ore + 5 fuel -> 1 ingot`, Iron `4 ore + 5 fuel -> 1 ingot`, Bronze `3 Copper Ingot + 1 Tin Ingot -> 4 Bronze Ingots`, and Steel `2 Iron Ingots + fuel -> 1 Steel Ingot`. These are **live OLD data**, directly conflicting with newer owner decisions: **1 ore -> 1 same-metal ingot; 1 Copper Ore + 1 Tin Ore -> 2 Bronze Ingots; Advanced Smelter Iron Ore + Coal or Charcoal as INPUT carbon for steel, distinct from Coal/Charcoal in the fuel hopper; no tracked temperatures**. Replace the old recipe and guide rules together only once implementation is authorized. Carbon ingredient quantity **has NOT been set**; do not hide that gap by copying the old `fuel x5`.
2. **Station identities and progression:** `DYNASTY_MASTER_ITEMS.md` s2.7 and `progression.md` still describe direct no-bronze iron-first access, optional/standalone Stone Forge, Smithy-with-Quencher add-on and old Blast Furnace. The owner's newer ladder is: **Primitive, Improved, Advanced Smelter** (3 stations); **Primitive, Improved, Advanced, Master Smithy** (4 stations); **Primitive Smithy Copper tools**, Improved Smithy Iron Saw/Iron Anvil, Advanced Smithy Steel Anvil, Master Smithy **ornate, Steel Anvil, built-in quencher**. Remove superseded text and migrate item IDs in a reviewed implementation PR; do not allow a parallel Stone Forge or fourth smelter to reappear as a duplicate.
3. **Ore access:** `boulders.json` currently allows **stone picks to mine Copper, Tin, Coal** but requires **Bronze or above for Iron**. This supports the new copper/bronze-first sequence. It has NO copper pick-tool speed or copper entry under ore `needs_material`; first Copper tools therefore require catalog definitions and consistent mining/yield rules. Verify the first upgrade can really mine suitable iron without circularity.
4. **Smelter output:** `DYNASTY_MASTER_ITEMS.md` s2.5 says all finished workstation goods remain in output inventories and never drop; current `structures.json` Smelter has output slots. The owner now specifies **Primitive Smelter: fuel 20/input 20, NO output inventory; finished ingots drop in front. Improved: 40/40/80; Advanced: 80/80/160.** Reconcile s2.5 as a general default with an explicit Primitive exception, and change runtime storage/goal-credit behavior accordingly.
5. **Rates and wind:** approved Primitive 20 s/ingot, Improved 20 s (unmanned) or 30% faster with active bellows (about 15.38 s), Advanced nominal rate another 30% faster **per lane** and 2 simultaneous ingots (2/~11.83 s) while its *integrated windmill* turns. Below wind threshold it must STOP completely; no calm baseline or separate windmill. Wind scaling above threshold and threshold itself need engineering tuning.
6. **Sourcing:** Smelter/Smithy fuel hopper auto-pulls ONLY **Coal or Charcoal** from **appropriate resource bins, fires, kilns** within **30 m**, **once per 5 min**, **no permission check**, **oldest consumer first**, skip full hopper, never Wood or ordinary chests. This dedicated periodic rule does NOT supersede the game's ordinary nearby ground-and-inventory sourcing for construction/repair. Steel carbon input is separate from hopper. General storage auto-pull wording in master s2.5 must not blur these mechanics.
7. **Resource bins:** New **Small/Medium/Large** storage = capacity **1,000/5,000/10,000**, recipes **16 Planks+32 Nails / 32+64 / 64+128**. First deposited resource locks type until empty. Solid-sided/open-top with ONE visually rising resource **surface mesh**; no invisible volume needed. New bins are not yet in current `blueprints.json` and require implementation; no separate Coal/Charcoal mixed storage exception.
8. **Smithy repairs:** Station persistent durability; over-tier forging accelerates wear. Broken at zero remains physically placed, regular UI says **"Needs repair"**. Equip a normal tool hammer, **right-click -> Repair**, excluding War Hammers. Materials can come from **inventory, nearby eligible storage or nearby ground** per existing game convention, consumed only when successful. Exact per-tier repair material costs remain unset.
9. **Journal and player map:** old audit Q8 and the old handoff's World Map placeholder are superseded. No preexisting World Map. Journal Map is a **skill-dependent charcoal drawing of explored areas**, improved by exploration, creating Map Scrolls and actually **revisiting** former territory at higher Mapping skill. Scrolls later share/sell. **Do not show unseen world via client-side full-map textures.** This is new functionality with a clean single-page UI. `PLAYER_CARTOGRAPHY_MAP_DESIGN.md` is the authority; new scroll recipes/transfer economics are not yet decided.
10. **Guide scope/UI:** All gameplay goals remain **automatic and concurrently eligible**, with **coins automatically awarded once**; a selection merely displays instructions. Journal content uses the existing **Inventory/Crafting look**; upper-right thin-outlined **Goals** HUD shows **only two earliest unfinished** titles. No ornate HUD, new mini-game UI, extra floating meters, XP bars or unrelated buttons. Preserve J/G/M/Inventory G and exact Ctrl+Shift admin policy; gate new goal amounts and final list separately.

## 4. Concrete no-question engineering work packages

- **P0 proof:** capture a fresh SHA/source matrix and recreate audit findings, including all 328 formerly rule-only goal checks; negative-test obsolete recipe assumptions and confirm no accidental old rules in newly authorized guidance.
- **P1 resource acquisition:** make oak tannin bark available through one legitimate non-duplicating tree action; repair existing Scots pine tar drop; allow filled water containers to satisfy actual recipe water and debit ml; wire client farming affordances. Iterate first 20 player actions and full player journey.
- **P2 early/mid-metal:** first stone pick gathers Copper/Tin; both Primitive stations are stone-tool buildable; Copper tools are real; 1:1 ore ingots and 1+1 Bronze; bronze fittings -> Improved stations -> staffed bellows iron -> Improved-forged Iron Saw and Iron Anvil -> Advanced Smithy -> Advanced Smelter steel -> Advanced-forged Steel Anvil -> Master Smithy. Check source dependencies, item IDs, blueprint unlocking, no-cycle graph and save migration.
- **P3 purposeful advanced branches:** real tannin/leather/flax/loom/tailor, kiln charcoal, water wheel/sawmill, metalworking/smithy tier wear/repair, bins and fuel sourcing, water/garden module when available, all building tier assemblies with functional openings and roofs, real useful first actions.
- **P4 goal runtime/instructions:** stable IDs, first-hand acquisition event hooks, made quantities, all legitimate crafting modes, no `after` award gate, once-only payouts, unique action credit, event-driven indexed evaluation, persistent/synchronized server state. Correct 651 how-tos and rewrite old recipe totals.
- **P5 polished but simple Journal:** one J/G/M window, Inventory/Crafting visual family, two-item minimal HUD, reward placard dynamic text/safe non-overlapping fanfare, one authoritative goal state/network feed, build **new** explored-charcoal Map subsystem by separate scoped implementation after world/skill design review. No fake full map.
- **P6 release proof:** fresh-character no-admin-craft F6 test, multiplayer operations with competing smelters, world-restart item conservation, owner’s active door/roof playtest, at least one test per finding, count exact runtime status after changes. Defer full reward/economy tuning until true time observations.

## 5. New proposed activity goals (NOT auto-approved)

The audit recommends 26 additions, not part of the 651. Keep them as **candidates**, preserving separate teaching value: first kindling/tinder, cooking, farming/tilling/sowing/harvest, bush planting, snare, tool sharpening/repair, building repair, sleep, storage and locking, handcart, crafting tempering/masterwork, kiln charcoal, buying, food preservation, serving, eating food effects when live, placing torches, diverse foraging/fishing and mining. **All require real user actions and completion signals, not goal-record fiction.**

New map design suggests eventual **"Explore and sketch a new area"** and **"Draw a Map Scroll"** activity goals, but scroll writing and mapping skill remain design only. No addition is authorized to pay coin merely by appearing in this recovery report. The creator's commitment to a full-game guide argues **against dropping valid unique activities to make list shorter**, and against repetitive copy-pasted filler.

## 6. Actual decisions still unsuitable for independent sign-off

These can be **deferred without stopping root-fix implementation planning**, but they require a later actual owner approval or a documented engineering proposal and explicit gate:
1. **Steel carbon ratio**: number of Coal/Charcoal items in the *input inventory* per Iron Ore/Steel Ingot; separate hopper fuel. Do not copy the obsolete Steel recipe, invent carbon yield, or suggest tracked temperature.
2. **Exact per-tier Smithy repair materials and amount restored**, plus hammer wear, if any; use approved material access and hammer controls now, choose costs at a dedicated balance gate.
3. **Legacy payout migration and retrospective reward policy**: preserve old earned states and current awards until a reviewed migration; no retroactive duplicate payout by default. Coin economy as a whole deliberately deferred.
4. **New Map Scroll mechanics**: physical scroll construction recipe, region/accuracy transfer to buyers/readers, sales and inheritance effects. Mapping/exploration UX and skill principle are already specified; implementation economics can be a follow-on.
5. **Still-unmeasured**: wind start threshold/speed curve, mapping XP thresholds and detail curves, exact fuel burn amounts, incomplete per-tier construction material costs and asset sourcing. Engineering can recommend values and tests, never label guessed constants user-approved.

**Do not return the 11 old audit questions to the creator.** Deliver a focused owner review package only at the later actual authority gate, with at most the above substantive choices; everything else here is reproducible engineering/audit work or already settled.

## 7. External context (reference, not override)

- Oak bark historically supplies tannins for tanning, supporting the existing oak `tannin_bark` data; historical literature does **not** authorize adding a new seasonal restriction to the game. https://academic.oup.com/edinburgh-scholarship-online/book/28921/chapter-abstract/240982753
- Godot community examples recommend persistent per-chunk revealed map masks and separating discovery data from presentation. Dynasty still specifically requires a **charcoal sketch with mapping skill**, not an exact exposed minimap. https://www.reddit.com/r/godot/comments/1t3f87z/minimap_with_fog_of_war_how_it_works/

## 8. Iterative review checklist

- **Pass A, authority:** every `OWNER SETTLED` maps to an actual creator decision; suggestions are unmistakably labelled defaults. Historic audit and currency amounts unchanged.
- **Pass B, dependency:** no iron-first tutorial, temperature tracking, separate windmill, early steel without carbon INPUT, automatic wood pull, invented Repair Hammer, mixed bins, or third-party/unknown world map.
- **Pass C, testability:** every GA has a concrete outcome or deferred boundary; no `PASS` label without actual gameplay evidence. Root blockers are chained rather than 144 independent speculative tickets.
- **Pass D, UX:** simple Inventory/Crafting-style Journal, charcoal Map content, thin-border two-goal HUD, actual named interactions with no unnecessary new screens, no key conflicts.
- **Pass E, external reality:** historical/reddit references only support feasibility and implementation techniques, never replace creator's simplified recipes or game rules.

**Exit:** All 80 GA IDs have a disposition; all 11 original creator questions are answered, defaulted or transparently deferred; remaining owner dependencies are isolated. Implementation and final economy/goal activation remain separately gated.
