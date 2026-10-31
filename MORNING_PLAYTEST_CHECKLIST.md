# Morning playtest checklist

For Dave, 2026-10-31 build (the daily branch head a00c2e04 plus the playthrough files; updated 06:50 after the PC crash and the merges of the night). About 45 minutes. Tick the boxes as you go. "Status" is what my checks say about this build (probes on the real server code, the tests, the pictures); "Known limits" is what is already broken or in progress, so you do not have to report it. Anything that does not match, write it in the last box.

## 0. Start the game

- [ ] Open the project in Godot, open `scenes/launcher.tscn`, press **F6**.
- [ ] The **character select page** comes first. With no character, it sends you to the **creator**: type a name (required), make a body, press **Save and play**. The game starts its own background server and joins it (port 24600; if that port is busy it joins the server already there).

## 1. First look (one minute, do not touch anything)

| Look at | You should see | Known limits |
|---|---|---|
| [ ] The ground under you | the spawn is at 53316, 68476 and is dry (Sonny: ground 31.6 m, water 113 m away). If you see a **dark rippled plane** in the foreground it is the sea showing before the ground mesh has built: wait a few seconds and tell us if it stays | the plane was in my pictures before that fix; I have not re-shot it yet |
| [ ] The sea and horizon | a shelf sea with islands, land 0 to about 850 m (the height fix is in: no more "everything 1,000 m high") | the sea is a flat plane, no shore foam yet (Sonny's water plan, in progress) |
| [ ] The trees | a forest of grown beeches, oaks and firs; **new worlds now start on day 100, early summer** (changed from day 30 of spring) so leaves should be green and berries ripe (leaf colour by season landed) | the crowns look like floating clumps with sky gaps (reported) |
| [ ] Tab | five bars: Health, Food, Water, Warmth, Energy | |
| [ ] The NPC Edda | stands near you | she can stand inside a young fir (reported) |

## 2. Twenty-five things to try, in order

Controls: **E** gather (hold E to take several), **I** inventory and crafting, **1 to 9** hotbar, **left click** use, **C** crouch, **Z** lie down (hold Z 3 s to sleep), **Q** put a shouldered log down, **F** open a chest beside you, **P** auto pickup on or off, **Esc** menu.

| # | Try | You should see | Status in this build | Known limits |
|---|---|---|---|---|
| 1 | [ ] Walk, jog (double-tap W), run (Shift+W), crouch (C), jump (Space) | smooth movement | works | arms and hands in progress (Sonny) |
| 2 | [ ] Hold E near **sticks** on the ground, and press E at a shrub | sticks into the pack | PASS (probe) | sticks may jump into the pack by themselves with P on |
| 3 | [ ] Pick up **stones** near the water and on slopes | stones | PASS | |
| 4 | [ ] Pick **nettles** (E on the plant) and **tall grass** | nettle: 1-2 plant fibre; tall grass: fibre and 4 thatch | PASS; tall grass patches are now thick (67 within 50 m) | in progress: flora density tuning |
| 5 | [ ] Press I, craft **Twine** (3 fibre) | 1 twine, 2 s | PASS | |
| 6 | [ ] Craft a **Stone axe** (1 stone, 1 stick, **2 twine** now) | axe in the pack, 10 s craft | PASS (test_first_hour 0 failures) | |
| 7 | [ ] Put the axe on the **hotbar** and hold it | axe in hand | PASS | the axe looks oversized and held stiff (Sonny) |
| 8 | [ ] **Chop a tree** | thin trees fall in about 10 blows, an oak in about 20; the tree **falls and rests on the ground** | PASS (test_fell_pose 0 failures) | the felling look is Kathleen's, in progress; I could not photograph it |
| 9 | [ ] **Work the felled trunk** with the axe | branches give sticks and leaves first; then **logs are cut off the far end and drop on the ground** beside it, the trunk gets shorter, a band marks the cut | PASS (test_trunk_cutting 0 failures) | I did not see this in the client myself |
| 10 | [ ] **Pick a log up on purpose** (E), carry it on your shoulder, put it down with **Q** | one log on the shoulder at a time; Q lays it down; "Put your log down first (Q)" if you try to cut with a log on you | per the commit notes; the carry look is Kathleen's/Sonny's | the shouldered log is hard to see in first person |
| 11 | [ ] Craft a **Campfire kit** (6 sticks, 3 stones), hold it, click to place | a ring: yellow on open ground, green under a tree crown; the laid fire shows a **plant-fibre bed, a criss-cross twig lattice and a teepee of bigger sticks** | PASS (test_fire_state_look 0 failures) | the kit crafts in 8 s now |
| 12 | [ ] Press **E at the fire** to light it with a plant fibre (birch bark or tinder also work; 2 thatch make 2 tinder) | flames; stand within 4 m to warm up | PASS (all four tinders light in the probe) | it will not light on open ground in rain |
| 13 | [ ] Feed it (E adds firewood, then sticks, then logs); **hold E** at a lit fire to roast a raw item | roast food | PASS | a lit fire has no picture from me yet |
| 14 | [ ] **Stand under a big tree** (not a young fir) | cover: rain does not reach you; fire placed here is green and survives rain | PASS in code (6 grown trees within 50 m of the spawn) | only grown trees count; from under the crown it does not look like a roof |
| 15 | [ ] Craft and place a **Lean-to** (8 sticks, 6 leaves, 2 twine; 25 s craft) | a roof of green slabs on posts | PASS | the roof is flat green slabs (reported to Kathleen) |
| 16 | [ ] Craft a **Rough bed** (8 bedding from 2 ferns, or 10 thatch; plus 4 sticks and 2 twine), place it under the lean-to, press **Z** and hold 3 s | you sleep; you wake rested | PASS | the bed looks like stacked planks |
| 17 | [ ] Craft a **Workbench** (12 sticks, 3 twine); then a **Tool rack** (10 sticks, 4 twine) beside it | bench level 2 with the rack; makes the stone hammer, bow, stone spade, pickaxe | PASS (bench and rack place; level 2 measured) | |
| 18 | [ ] **The log chain**: with a log on your shoulder (or lying near you) try a **Chopping block** (2 logs), **Rough planks** (1 log at the bench), a **Log workbench** (4 logs) | **should now work**: the game says "Using nearby logs"; rough planks from the shoulder log gave 4 planks, the chopping block 1 | **FIXED (F-16)** in the probe; I did not do it by hand in the client | lumber needs the **stone wedge** (2 stones + 1 stick) and a log at the workbench; the saw mill is still out of reach (iron) |
| 19 | [ ] Make a **Wooden spear** (1 stick, keep a stone) then a **Stone spear** (+2 twine); a **Stone knife** (2 stones, 1 stick) | spear jabs, hold right click to aim a throw | PASS (probe: rabbit 1 jab, deer 3) | |
| 20 | [ ] **Find animals**: walk about 150 m and look around | rabbits, a deer herd, a fox; they freeze, then bolt; creep upwind and crouch | PASS | **none live within 100 m of the spawn**; only 3 species near it (rabbit, deer, fox) |
| 21 | [ ] Kill a rabbit, then press E with the knife on its carcass (4 blows); roast the meat on your fire; eat it | meat, hide, bone; roast meat; food bar rises | **PASS: I drove the whole chain on the server code** (spear, kill, dress, fire, roast, eat, waterskin from hide) | I did not test the client aiming; antler is a grey blob |
| 22 | [ ] **Food**: look for berries and nuts | the world starts in early summer, so raspberries, brambles, strawberries and blueberries should be ripe; hazelnuts are autumn | the start day moved from 30 to 100 to fix exactly this (F-35 FIXED) | hunting, fishing and snares also feed you; nuts and mushrooms come later in the year |
| 23 | [ ] Craft a **Fishing rod** (2 sticks, 2 twine) and cast at the pond; or a **shore net** (8 twine, 4 stones) at the water's edge | carp or perch bite; roast fish | PASS in tests (fishing, schools, water, balance: 0 failures) | I did not cast in the client |
| 24 | [ ] **The sea and a river** | drink at the edge (E); wade; swimming in deep water | works; rivers start full | water look is Sonny's work in progress |
| 25 | [ ] **Rain and the cave**: wait for rain; if you can, go into a cave or dig a tunnel | rain sounds; under cover you are dry; cave-in sounds when a tunnel is unsafe | not tested by me | sound is Sonny's/Tyler's; tell us what you hear |

## 2b. New since yesterday: things to try

- [ ] **Starter goals**: the server now fires goal events for drinking, gathering fibre, twine, axe, felling a tree, a lit fire, eating something wild, the lean-to, a bed, workbench, spear, knife and a caught fish (data/items/starter_goals.json; test_goals passes). Look for a goal list or hints; if you see none, the client part is not there yet.
- [ ] **Farming**: a hoe tills a bed; seeds sow only in their season; rain keeps a bed wet; winter kills seedlings (server rules, test_farming). Crop and seed items now exist; I did not try it in the client.
- [ ] **Recipes**: 208 of 227 recipes are learnable now (the 19 left are forge, steel and bronze things, plank chest, water wheel).
- [ ] **Blacksmithy**: the blueprint places when 10 logs lie near you (probe).
- Status at 08:15 on the daily head: 19 fixed, 8 still broken (water wheel craft now FIXED). Flint, ore and coal are **still orphans** on the head (Tyler's fix is not in yet); recipes 217 of 236 learnable.
- Still not possible: **flint, copper, tin, iron and coal cannot be picked up** (no source yet); no stairs; the saw mill; hide scraper and leather.

## 2c. New since 07:12 (merged on the daily head, not yet checked by me in the client unless noted)

- [ ] **Bark and felling**: felled trunks and stumps now use the standing trees' bark shader (was flat black in my 07:40 pictures; look again at a felled tree and its stump).
- [ ] **Tree shading**: round 2 of the tree shading and a darker, warmer bark (picture-checked by Kathleen).
- [ ] **Thickets**: shrubs and berry bushes now grow in clumps (13 species); a clump of four or more tall ones is one collider, so you may bump into a thicket.
- [ ] **In-season rule**: herbs, flowers and mushrooms out of season are not drawn and give no gather prompt; a plant picked bare gives no prompt either. At the summer start, expect fewer of them.
- [ ] **Sea edge**: at the water's edge a prompt says "Press E to fill the bucket" or "gather seaweed". Sea water into containers, sea salt, shore foods, jerky and salted fish are no longer "future".
- [ ] **Fruit trees**: only the plan, the items (19 fruits, 8 dishes, a calendar) and the fruit mesh and shader landed. **Fruit trees are still pending**: do not expect to pick apples, pears or cherries yet.
- [ ] **Held looks**: stone mace, club, flanged maces, swords and the quern no longer show a rod and block in the hand.
- [ ] **Beach**: wet sand shines and mirrors the sky; bigger stones.
- **Double F** and the **Carried slot** have landed (Kathleen, test_f_press): try pressing F twice. Not landed yet: the **idle timeout** and the `--timeout` flag (Tyler).
- Known still broken: the **chest** self-test fails (the chest screen may not open); lit-campfire picture not taken.
- **Sound**: the occasional cave-in rumble and the rain-like hiss in clear weather are explained in SOUND_AUDIT.md (listen at the clearing and in a forest and tell me what you hear).

## 3. The character creator (do this first if you like, or after)

- [ ] Hair: **ten styles**, a dice button and a lock; the share code works.
- [ ] **Chest and Bust** are two sliders now (V-taper chest, soft bust); **Shoulders** moves the joints and cloth by up to 12 cm each side; **frames** set several sliders at once.
- [ ] Clothing colours are editable; the body in game wears your skin and clothes colours (generated body is on by default; `--old-body` brings the old one back).
- Known limits: hands and feet pictures exist; the creator is "Plan 14 prototype" in the notes.

## 4. What I could not check (so look for me)

- The lit campfire, the felled trunk and the stump are not photographed by me (the picture rig cannot light a fire; its fell rig finds no tree after 60 s).
- Dry spawn: if the spawn is still at the pond shore in your build, it is the open issue for Sonny.
- `test_playability_bot` stops at step 6 on this build ("working the trunk gave no log") because logs now drop on the ground instead of into the pack; the bot needs a pick-up step (Tyler). Steps 7 to 9 of the bot (fire, shelter, well) are therefore not run today; `test_first_hour` and my probes cover the same chain and pass.
- "Double F" (on the moderator's list): I could not find it in CONTROLS.md or the client; single **F** opens the chest beside you. Tell us what you expected.
- Anything on the list the moderator named that I could not confirm in the code (felling pose on the ground: confirmed by the test; logs cut off the end: confirmed by the test; auto-pickup of sticks: the **P** toggle only, default off).

## 5. Write here what felt wrong

- [ ] ______________________________________________
- [ ] ______________________________________________
- [ ] ______________________________________________

(If a row says STILL BROKEN and you saw it work, that is good news: tell the moderator and I will re-run `bash art/playthrough/run_status.sh`.)
