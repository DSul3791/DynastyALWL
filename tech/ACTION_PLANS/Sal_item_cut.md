# Action plan: the item cut (Sal, branch claude/sal-item-cut), from design/ITEM_TRIM_DECISIONS.md

One branch, built as separate commits A, B, C, F, I, W so each can be gated or reverted alone. Label RESTART (one small server and inventory code change, in C and F). No protocol version change. Left alone on purpose: D (cobblestone, shingle, pin, tar, softwood twins), E (all food and tea), coins, clothing (trim-h2), building pieces (trim-g2), wooden bowl (39), driftwood (30), shears, tongs, bellows.

## Mechanism first: retire with a merge target (used by A, B, C, F)
Today a retired item only stays in the file for its number; nothing converts old stacks. Add `"merged_into": "<item id>"` on a retired item. One helper `ItemTable.canonical(number)` returns the target, and the server applies it where a number comes in from disk: inventory load, chest load, world items load. A save with an old number keeps working and shows the new item. Numbers are never reused. Test: save with a medium spade and a lumber_oak stack, reload, both come back as the merge targets.

## A. Spades: one per material
- Retire 213-220 (medium and large wooden, stone, iron, steel), `merged_into` the small spade of the same material (19, 45, 46, 47). Retire recipes 131-138.
- Bite size stays as it is today: every spade stays `small` and the existing `tier_extra` in digging.json (wooden 1, stone 2, iron 3, steel 4 extra shovelfuls) already makes a better material dig more. The spade_sizes table stays in digging.json, unused.
- Weight: all four spades the same, 1.5 kg (a real garden spade weighs 1.5 to 2 kg). Say so if Dave wants steel heavier.

## B. Duplicate tools
- Hammer: already one line (wooden 247 tier 1, stone 244 tier 2, copper and up later). Nothing is cut; the blueprint hammer tier reads that line. If Dave meant fewer than two, tell me.
- Vice (83, 84): retire, `merged_into` nothing (no one carries it): recipe 48 retired. Its job is the log workbench's.
- Sewing needle (49): already retired; its future-flag recipe stays gone.
- Camp bench (73) is not in Dave's answer: untouched.

## C. One Lumber and one Beam, species as a tag
- Lumber stays item 27. New item 278 `beam` (stack 20). Retire the 14 live species lumber and beam items (101-102, 107-108, 110-111, 113-114, 125-126, 149-150, 173-174, and the already retired rest) with `merged_into` lumber or beam. Retire rough plank 226 into lumber (recipe 143 retired).
- The species rides in the slot's existing `wear` number (it is unused for materials). Items.json gets `"tag": "species"` on lumber and beam. Inventory `_mergeable` merges only equal tags and `_joined_age` leaves the tag alone, so oak lumber and maple lumber never mix. Wear travels with drops, chests and trades already, so the tag does too. The tooltip reads "Lumber (oak)".
- The sawmill recipes (52-61, 68-69, 84-85, 100-101) collapse to two: `lumber` and `beam` from any log, with `tag_from` the log's species. The log items stay per species (Dave: only lumber and beam merge). Recipes that need `lumber` accept any species (they do today).
- First version: the tag is carried and shown, and affects nothing else. Tier and look by species come later, as Dave's yes said "the species is a tag".
- Weights (real averages, one source): Engineering Toolbox, "Density of Wood" (seasoned, dry wood): oak 600-900, maple 620-750, birch 510-770, walnut 640-700, Scots pine 510, spruce 480-780, Indian teak 660-980 kg/m3. Midpoints average 672 kg/m3. At that density: lumber piece 1.2 x 0.2 x 0.025 m = 4.0 kg (unchanged), beam 1.8 x 0.1 x 0.1 m = 12.1 kg (unchanged at 12.0), wood block 0.165 m cube = 3.0 kg (unchanged). The values already in the game match the real average, so weights stay. Source: https://engineeringtoolbox.com/wood-density-d_40.html
- Cross-check pending: the USDA Wood Handbook table (FPL-GTR-190) for the same species; I cite the one I read.

## F. One forge, upgraded in tiers
- The forge is one item line: the stone forge (87/88, state 17) becomes "Forge". Its model already holds furnace and anvil (Dave's models forge_basic, medium, large, master stay as the four looks of the one forge).
- Tiers become upgrades: blueprint 10 (medium) and new 15 (large), 16 (master) get `"upgrade_of"` naming the tier below. Placing the blueprint within 3 m of the lower forge swaps that piece for the next state in place (17 to 18 to 20 to 21), same position and yaw, paying the row's cost. The same ACT_PLACE_BLUEPRINT action, no protocol change. Takedown of any tier refunds every stage paid, and the pack-full rule from build 1 applies.
- Retire the kits 89 (blacksmithy), 92, 94 (large, master) with the structure items kept for their states. Station levels stay (also forge 1/2/3/4), so every forge recipe keeps working.
- The large and master costs are not yet in the data (they waited for recipes): I propose large = medium cost x 1.5, master = large x 1.5, tunable in blueprints.json.
- Weight: workshop kits about 30 kg: stone forge 30, saw mill 30 (from 120), woodworking table 30 (from 40), clay hearth 30 (from 60), oven 30 (from 90); vice gone; log workbench stays 30.

## I. Scythe and hand sickle (no rake, no shears)
- New items 279 `sickle` (class sickle, tier 1, stone blade) and 280 `scythe` (class scythe, tier 3, iron blade, future until iron). Recipes 178 sickle: 1 stone, 2 stick, 3 twine at the workbench (a tool); 179 scythe: 1 saw blade (iron), 1 beam, 2 twine at the workbench, future.
- Use, so the tools are not empty: gathering grass, thatch and grain with a sickle or scythe in the hand bar gives x2 (sickle) or x4 (scythe) yield, read from gather_rules data (one lookup in the gather yield, plus the held-tool check the axe already uses). Thatch needs plenty of it, which is Dave's reason.
- Names go to Kathleen via the Moderator: sickle, scythe.

## W. Weights (rest of Dave's answers)
Magic and fantasy materials weigh the real thing: apply to the magic-named items in weights.json (listed in the commit message). Spades and kits as above. No other weight changes.

## Tests (David3)
validate_items 0 errors; test_server_items cases for the merge target on load, tag merge rules (oak and maple lumber stay separate stacks), sawmill output tag, forge upgrade in place and refund, sickle recipe and yield; test_blueprints, test_hammer_list, test_craft_menu (next recipe 180), test_first_hour, test_new_player, duplicate sweep, local_check 227.

## Order and numbers
A and B first (data only), then the merge mechanism, C, F, I, W. Items next 281, recipes next 180, blueprints next 17 after this. One hash per commit sent only if David3 wants them split; otherwise one head.
