# BUGLIST-001 effort-axe: BUG-001, BUG-003, BUG-005

Baseline `origin/dev` f5d6b54 (protocol 117, PRs #1059 tool tiers and #1067 every swing names the tool in hand). Branch `claude/buglist001-effort`. PROTOCOL CHANGE: 118 (ACT_MINE b = 1, "struck nothing"; the lead-assigned number, ruled yes by the COORDINATOR, not by Dave; reversible in one commit; update client and server together, an old client is refused at the welcome). No save or catalog change. Godot has NOT run on any of this (no cloud runs): every test below is NOT RUN until the PC run.

| Bug | Status |
|---|---|
| BUG-001 missed swings cost nothing | NEEDS PLAYER VERIFICATION |
| BUG-003 axe in air says "no ice to cut" | NEEDS PLAYER VERIFICATION |
| BUG-005 walking raises exertion | NEEDS PLAYER VERIFICATION (the extra that tipped Dave's walk is not proven, see below) |

## How effort works (facts, read from code)

- The Exertion bar and the heart are the server's `strain`, sent as `points[0]` (`server_items.gd _strain_tick`; bar = strain / faint_at in `inventory_view.gd`).
- Strain rises while `effort_of(peer)` is above `rest_effort` (0.52) at `rise_per_s` 0.06 x (effort - rest), and falls below it at `fall_per_s` 0.05 x (rest - effort). `effort_of` = the larger of movement effort (`_exertion`, smoothed from the speed the server measures between position reports through `exertion.json effort_by_speed`) and the held tool effort, plus additive terms: sickness floor, shivering, heat load of worn clothes (`heat_effort`), armour past 8 kg, a pack past 80 percent, a loaded bag or cart.
- A tool's effort is not a per-swing counter: `_wear_slot` holds `_work_level = tool_effort[class]` until `_work_until = now + work_s` (2.5 s). "A swing costs effort once" means the swing makes that hold once.

## BUG-001: missed swings consume no exertion

Reproduction (by reading): axe in hand, left click on empty air. `held_item.gd _strike`: `if hit.is_empty() or _sound == null: return` sent nothing, so the server never heard the swing. The only place the server held effort was `_wear_slot`, reached only from a blow that landed. Fact. The same on bare soil: `ACT_MINE` was sent, but `_mine` returned at `rock_at` false before `_wear_slot`, so a swing at soil or grass cost nothing either (found while tracing, not in Dave's report).

Other weapons and tools, with evidence: the spear/weapon jab. The client always sends `ACT_STRIKE` but `server_items._strike` called `_wear_slot` only `if hit`, so a jab at nothing cost nothing: same failure, same fix. Looked at and NOT changed (no evidence of the failure, or not a swing): bow (`_shoot` wears and charges once per shot, hit or not), rod, net and fish spear (charged per cast before the result), spade and hoe in empty air (the client refuses with a notice, no swing is made), knife (works on a carcass only).

Change:
- `server_items.gd`: `_note_work(peer, tool_class)` is the two effort lines pulled out of `_wear_slot`, so a hit still charges exactly as before, once, through `_wear_slot`. `_mine`: after the tool and the 700 ms cooldown checks (a click inside the cooldown is not a swing), a swing whose point is not rock calls `_note_work` and returns (no wear, no stone); a rock hit goes on to `_wear_slot` as before (one charge). `_strike`: `else: _note_work(...)` on a miss.
- `held_item.gd _strike`: an empty ray sends `ACT_MINE` with the held slot + 1 (the miss still names the tool in hand), `b = 1` and a point `MISS_POINT_M` (2.5 m) ahead of the eye. This reuses the existing action, no new message.
- Gate review finding (fixed): `rock_at` looks at x and z only, so a point in the air over bare rock would have broken a stone, worn the axe 5 and trained mining. Hence protocol 118: `_mine(..., struck_nothing)`; with `b = 1` the server only holds the effort (no stone, no wear, no practice), whatever lies under the point. A claimed miss can only lose the player something, so the flag cannot dodge wear or yield on a real hit (a real blow sends `b = 0`). Notes in `terrain_net.gd` and `PROTOCOL.md` (118, newest first; ACT_MINE row). 2.5 m keeps the point inside the server's `MINE_REACH_M` (4.5 m from the feet) even looking straight up. The server's reach check and cooldown are untouched.

Tests (NOT RUN), `src/worldgen/tools/test_swing_effort.gd`: a hit on rock, a swing at soil and a swing into air hold the same effort level and duration; only the rock hit wears the axe, breaks a stone (1) and trains mining; a miss (b = 1) over bare rock (rock = true) holds the effort and gives 0 stone, 0 wear, no practice; effort_of >= 1.0 after one air swing; a second click inside the cooldown holds nothing; nothing in hand holds nothing; a blow on a tree holds the same as a miss (one charge); a spear jab that misses costs what one that lands does; client part: a swing into an empty world sends `ACT_MINE` with slot + 1 and the 2.5 m point.

Regression risks: (a) a held-down axe now keeps effort at 1.05 in the air too, so chopping at nothing tires like chopping wood (intended); (b) one more small rpc per missed swing (about one a second); (c) with no sound system (`_sound == null`, headless) a swing that hits still sends nothing, as before (not touched).

F6 check: hold an axe and swing at open air for 20 s with the left button held: the Exertion bar on Tab climbs, as it does chopping a tree.

## BUG-003: axe into empty air says "There is no ice to cut here."

Reproduction (by reading): the only source of the text is `fishing.json ice.say_no_ice`, said only by `server_items._cut_hole`, reached only from `ACT_ICEHOLE`, which `held_item.gd mouse_button` sends on every RIGHT click with an axe or pick (and plays the "use" arm clip), whatever is around the player. The LEFT click swing cannot reach it: `_start_swing` -> `_strike` -> ACT_MINE / HIT / PROCESS only. Not a regression of tonight's PRs: the right-click ice hole dates from #896/#928 (`git log -S`); #1067 only added the slot that was already sent. Fact. Guess (to verify): Dave used the right button, which looks like a swing, or his report mixes the two.

Change: `_cut_hole` says there is no ice only within `fishing.json ice.no_ice_water_m` (6 m) of water; anywhere else a right click with an axe is not asking for a hole and stays silent. At the water but off the ice it still says "There is no ice to cut here."; on ice the six blows still cut a hole ("You cut a hole through the ice."). The server decides, so the client is unchanged for this bug.

Tests (NOT RUN, same file): right click away from water: no message; at the water, no ice: the ice message; on ice: six blows open a hole, no complaint; left swings at air and ground and a blow on a tree: no message containing "ice".

Open question for Dave (decision recorded, not blocking; status stays NEEDS PLAYER VERIFICATION): which button did he press, and what were the exact steps (axe in hand, where standing, left or right click)? If it was the LEFT button, this is not the cause and the report needs the exact steps. The right-click arm clip still plays with nothing cut; left alone (a client cannot know it stands on ice without copying the server's rule).

F6 check: axe in hand in a wood, right click: nothing is said; at the edge of an unfrozen pond, right click: "There is no ice to cut here."; on a frozen pond, right click six times: a hole.

## BUG-005: normal walking raises exertion

Facts: the walk is 3.2 m/s (`terrain_client.gd WALK_SPEED`), `effort_by_speed` gave it 0.5, `rest_effort` is 0.52. A bare walk therefore recovered at (0.52 - 0.5) x 0.05 = 0.001 strain/s against 0.026/s standing: 26 times slower, nearly nothing, so ANY additive term in `effort_of` above 0.02 turned the walk into a climb.

Which extra is active in ordinary conditions (looked up for the gate review, calculation from `items.json` warmth and fabric, `warmth.json layers`, same layered sum as `heat_load`; script kept in the scratchpad, not committed):
- A new character starts with nothing worn and a light pack, so no extra: its walk recovers (barely). Shivering needs warmth below 40 (cold, not ordinary). A starting pack is far below the 80 percent limit (load term 0).
- The first clothes a player makes are the ordinary extra: the heat load of worn hide or wool on a day warmer than 15 C (`heat_effort` 0.5 x load x min((feels - 15) / 10, 1)). Hide tunic + trousers (load 0.294): +0.044 effort at 18 C, +0.073 at 20 C, +0.147 at 25 C; wool tunic + trousers (0.26): +0.039 / +0.065 / +0.130; hide tunic + trousers + cloak (0.437): +0.066 / +0.109 / +0.218; a linen shirt (breath 1.0): 0. With the old 0.5 anchor a hide outfit already tipped the walk at 18 C (0.544 > 0.52). Fact (arithmetic from data). Not proven: that Dave was wearing hide or wool, or what the air temperature was, in the playtest; the playtest log has neither. If he walked naked or in linen, the cause is not this and the bar was rising from something else I could not find (position-speed measurement checked: noise lowers the average because the curve is concave at 3.2; a trodden path eases effort).
- Also tips it, outside ordinary play: armour or padding past 8 kg (T14_RESULTS.md: "gambeson + mail walks at 0.504, any heavier padding layer tips it"), a loaded bag or cart, sickness floor 0.5.

Choice (a DELEGATED Level B tuning decision, made by me under the coordinator's delegation, Dave has not seen it): the walking anchor of `effort_by_speed` 0.5 -> 0.4, in `data/items/exertion.json` (data only). Before/after: bare walk effort 0.5 -> 0.4; recovery while walking 0.001 -> 0.006 strain/s (standing 0.026 either way, so walking recovers 4% -> 23% of standing). Why 0.4 and not 0.45 (recovery 0.0035/s, 13%): with a hide tunic + trousers the walk recovers up to about 23 C feels at 0.4 (0.4 + 0.147 x factor < 0.52, factor 0.82) but only up to about 20 C at 0.45, and the full summer span (25 C: +0.147) tips both; 0.4 is the smallest round step that keeps an ordinary first outfit restful over a normal temperate range. It keeps 0.12 of room for the extras above; effort 0.52 is reached at about 4.4 m/s (a jog) and 1.0 at 9 m/s (sprint) is unchanged, so the sprint tuning ("winds an unfit character in about 35 s") and `rest_effort` (which the knife 0.55, treading water 0.55 and tool efforts depend on) are untouched. Comments updated (`server_items.gd`, `test_swim.gd`).

Side effects to review (arithmetic from `vitals.json` and `energy.json`, not tested): walking now counts 0.4 for hunger, thirst and energy burn (`exertion_of` feeds them; running unchanged): kcal per game day at 75 kg 2400 -> 2250 (-6%), water 1600 -> 1480 ml (-7.5%), energy drain 33 -> 28.8 per game day (-13%); fitness XP per 10 s tick at a walk 2.0 -> 1.8 (walking alone to +10 about 15 h instead of 14 h). Armour: it starts to make a walk work at a total of about 20 kg instead of about 10 kg (`effort_free_kg` 8 + (0.52 - effort) / 0.01 per kg: 8 + 2 = 10 before, 8 + 12 = 20 now); a full steel kit still does (`test_armour` 8), a gambeson plus mail (8.4 kg) now stays restful. `docs/ai-team/missions/M001/T14_RESULTS.md` armour numbers (0.504, "any heavier padding layer tips it") describe the old 0.5 walk and are now out of date; no history rewrite. Not changed: `effort_free_kg`, kcal and fitness tuning.

Stale leftovers fixed: the fallback anchors in `server_items.gd _effort_at_speed` ([3.2, 0.4]), the "2 at a steady walk" comment and `fitness.json` note, `tools/balance_sheet.py` (it hard-coded walking 0.5 in five places; it now reads `effort_by_speed[1][1]`). `docs/mirror/items/BALANCE.md` NOT regenerated: the generator already crashes on dev (`KeyError: 'forge'` at balance_sheet.py line 167, an item without `also.forge`, unrelated to this change), so the sheet is stale on dev; its walking rows (0.5) stay until someone fixes that.

Double charging with BUG-001: movement effort and tool effort combine by `maxf`, never add, so a swing while walking is the tool's effort, not walk plus swing.

Tests (NOT RUN, same file): at 0 and at 0.06 extra effort (a warm day in clothes) the strain rate orders idle < walk < 0 < jog (6 m/s) < sprint (9 m/s); a walk recovers less than half as fast as standing; sprint, then walk, then standing: strain rises, falls on the walk, falls faster standing. `test_run_speed.gd` (walk anchor under rest_effort) and `test_armour.gd` 8 are still valid by reading (bare walk 0.4 <= rest; a full steel kit 0.4 + 0.01 x (kg - 8) is above rest).

F6 check: sprint (Shift) for 20 s, then walk for two minutes: the Exertion bar on Tab only goes down; stand still: it goes down faster; Shift-run: it climbs. Repeat dressed warmly on a warm day.

## Open questions and recorded decisions

1. BUG-003: which mouse button? Decision: treated as the right click (the only code path); silent away from water.
2. BUG-005: lowering the walk effort 0.5 -> 0.4 cuts walking burn of food (-6%), water (-7.5%) and energy (-13%). Decision (delegated Level B tuning): the smallest change that gives a real walking margin without touching `rest_effort`; Dave may prefer 0.45 or a separate effort for the burn. Also unconfirmed: whether Dave was dressed in hide or wool.
3. Protocol 118 (ACT_MINE b = 1): the coordinator's ruling, not Dave's; Dave should know it exists. Reversible in one commit (the miss then goes back to costing nothing).

## Test evidence (PC run, 13 Nov 2026)

Every "NOT RUN" above is superseded by this run. Ran on the David4 test PC (Linux, Godot 4.7.2 voxel build, headless, 2 jobs, fresh import) on `claude/buglist001-integration` at 8e46c4b254ed8061938cecee06a2cbb8665393c9 (dev f5d6b54 + all seven BUGLIST-001 heads). Result: 370 pass, 0 fail, no retries (fast 361/361, timing 8/8, slow 1/1 test_worldgen). validate_items PASS (0 errors), check_look_names PASS, warnings: none new over tools/warning_baseline.txt. Startup smoke: welcome 15.7 s, ground ready 133 s, 0 script errors, exit 134 (known headless exit). Picture lanes (5): NOT RUN; visuals and sound not checked. Logs: David4 /work/lanerun/bl001b_plan, /work/lanerun/bl001b_extra. An earlier run on a0b5365 failed 2 tests (test_hammer_list counts, test_server_items road restart height) plus 3 warnings; those were test-only fixes, reviewed, and are in 8e46c4b. Merged to dev by PRs #1068-#1074; dev add271196 has the identical tree (c6ec74eb). Status stays NEEDS PLAYER VERIFICATION until Dave's F6 check.
