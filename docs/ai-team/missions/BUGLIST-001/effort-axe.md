# BUGLIST-001 effort-axe: BUG-001, BUG-003, BUG-005

Baseline `origin/dev` f5d6b54 (protocol 117, PRs #1059 tool tiers and #1067 every swing names the tool in hand). Branch `claude/buglist001-effort`. No protocol, save or catalog change. Godot has NOT run on any of this (no cloud runs): every test below is NOT RUN until the PC run.

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
- `held_item.gd _strike`: an empty ray sends `ACT_MINE` with the held slot + 1 and a point `MISS_POINT_M` (2.5 m) ahead of the eye. This reuses the existing action (`ACT_MINE`: a = held slot + 1, at = the point struck), so there is no new message and no protocol number. 2.5 m keeps the point inside the server's `MINE_REACH_M` (4.5 m from the feet) even looking straight up. The server's reach check and cooldown are untouched.
- `terrain_net.gd` and `PROTOCOL.md`: the ACT_MINE description now says a point in the air is allowed (wire format unchanged, version stays 117; a 117 client from before this change just never reports misses).

Tests (NOT RUN), `src/worldgen/tools/test_swing_effort.gd`: a hit on rock, a swing at soil and a swing into air hold the same effort level and duration; only the rock hit wears the axe; effort_of >= 1.0 after one air swing; a second click inside the cooldown holds nothing; nothing in hand holds nothing; a blow on a tree holds the same as a miss (one charge); a spear jab that misses costs what one that lands does; client part: a swing into an empty world sends `ACT_MINE` with slot + 1 and the 2.5 m point.

Regression risks: (a) a held-down axe now keeps effort at 1.05 in the air too, so chopping at nothing tires like chopping wood (intended); (b) one more small rpc per missed swing (about one a second); (c) with no sound system (`_sound == null`, headless) a swing that hits still sends nothing, as before (not touched).

F6 check: hold an axe and swing at open air for 20 s with the left button held: the Exertion bar on Tab climbs, as it does chopping a tree.

## BUG-003: axe into empty air says "There is no ice to cut here."

Reproduction (by reading): the only source of the text is `fishing.json ice.say_no_ice`, said only by `server_items._cut_hole`, reached only from `ACT_ICEHOLE`, which `held_item.gd mouse_button` sends on every RIGHT click with an axe or pick (and plays the "use" arm clip), whatever is around the player. The LEFT click swing cannot reach it: `_start_swing` -> `_strike` -> ACT_MINE / HIT / PROCESS only. Not a regression of tonight's PRs: the right-click ice hole dates from #896/#928 (`git log -S`); #1067 only added the slot that was already sent. Fact. Guess: Dave used the right button, which looks like a swing, or his report mixes the two.

Change: `_cut_hole` says there is no ice only within `fishing.json ice.no_ice_water_m` (6 m) of water; anywhere else a right click with an axe is not asking for a hole and stays silent. At the water but off the ice it still says "There is no ice to cut here."; on ice the six blows still cut a hole ("You cut a hole through the ice."). The server decides, so the client is unchanged for this bug.

Tests (NOT RUN, same file): right click away from water: no message; at the water, no ice: the ice message; on ice: six blows open a hole, no complaint; left swings at air and ground and a blow on a tree: no message containing "ice".

Open question for Dave (decision recorded, not blocking): which button did he press? If it was the LEFT button, this is not the cause and the report needs the exact steps. The right-click arm clip still plays with nothing cut; left alone (a client cannot know it stands on ice without copying the server's rule).

F6 check: axe in hand in a wood, right click: nothing is said; at the edge of an unfrozen pond, right click: "There is no ice to cut here."; on a frozen pond, right click six times: a hole.

## BUG-005: normal walking raises exertion

Facts: the walk is 3.2 m/s (`terrain_client.gd WALK_SPEED`), `effort_by_speed` gave it 0.5, `rest_effort` is 0.52. A bare walk therefore recovered at (0.52 - 0.5) x 0.05 = 0.001 strain/s against 0.026/s standing: 26 times slower, nearly nothing. Any additive term in `effort_of` above 0.02 turns the walk into a climb: the heat load of worn clothes on a day warmer than 15 C, shivering in the cold, armour or padding past 8 kg (T14_RESULTS.md already says "gambeson + mail walks at 0.504, any heavier padding layer tips it"), a loaded bag. A trodden path is not the cause (pace x1.15, effort x0.8). I found no bug in the speed measurement: noise in the measured speed lowers the average effort (the curve is concave at 3.2). I could not tell WHICH extra was active in Dave's playtest: that is a guess, the thin margin is the fact.

Change (data only, `data/items/exertion.json`): the walking anchor of `effort_by_speed` 0.5 -> 0.4. A walk recovers at 0.006/s, a quarter of standing, keeping 0.12 of room for the extras above; effort 0.52 is reached at about 4.4 m/s (a jog) and 1.0 at 9 m/s (sprint) is unchanged, so the sprint tuning ("winds an unfit character in about 35 s") and `rest_effort` (which the knife 0.55, treading water 0.55 and tool efforts depend on) are untouched. Comments updated (`server_items.gd`, `test_swim.gd`).

Side effects to review (flagged, not tested): walking now counts 0.4 for hunger, thirst and energy burn (`exertion_of` feeds them: about a fifth less burn while walking; running unchanged) and for fitness XP (walk 1.8 per 10 s tick instead of 2.0); armour starts to make a walk work at about 20 kg instead of 8 kg (a full steel kit still does, `test_armour` 8; a gambeson plus mail no longer does). Not changed: `effort_free_kg`, kcal and fitness tuning.

Double charging with BUG-001: movement effort and tool effort combine by `maxf`, never add, so a swing while walking is the tool's effort, not walk plus swing.

Tests (NOT RUN, same file): at 0 and at 0.06 extra effort (a warm day in clothes) the strain rate orders idle < walk < 0 < jog (6 m/s) < sprint (9 m/s); a walk recovers less than half as fast as standing; sprint, then walk, then standing: strain rises, falls on the walk, falls faster standing. `test_run_speed.gd` (walk anchor under rest_effort) and `test_armour.gd` 8 are still valid by reading (bare walk 0.4 <= rest; a full steel kit 0.4 + 0.01 x (kg - 8) is above rest).

F6 check: sprint (Shift) for 20 s, then walk for two minutes: the Exertion bar on Tab only goes down; stand still: it goes down faster; Shift-run: it climbs. Repeat dressed warmly on a warm day.

## Open questions and recorded decisions

1. BUG-003: which mouse button? Decision: treated as the right click (the only code path); silent away from water.
2. BUG-005: lowering the walk effort 0.5 -> 0.4 cuts walking burn of food, water and energy by about a fifth. Decision: the smallest change that gives a real walking margin without touching `rest_effort`; Dave may prefer a smaller drop (0.45 leaves 0.07 of room) or a separate effort for the burn.
