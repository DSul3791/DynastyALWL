# The Ragtooth goblin camp

**Status: DAVE-REQUESTED (19 Nov 2026). The camp is in dev (#1325); camp life (stage 2, 20 Nov 2026) is in dev too (#1354, 95bb7530). Neither played nor seen on screen yet.** Values marked PROVISIONAL were answered on Dave's behalf by the coordinator while he was away (standing rule, 14 Nov 2026) and wait for his review below.

## What Dave asked (19 Nov 2026)
- "we also already have goblins in our game so we should build them a goblin camp somewhere near the river or in a cave. I want the goblins to be apprehensive but willing to communicate and trade/buy and sell. in the future the game will have various goblin tribes/camps etc that are friendly, not friendly, indifferent etc."
- "the goblin camp could be a cave somewhere near a river."
- Natural caves becoming animal dens is a separate plan (caves thread); this camp uses one cave's mouth only.

Answered for him (coordinator, 19 Nov 2026, provisional): the cave 2.8 km east of Edda and Hob; trade in coins in Hob's shop window; goblins cannot be killed for now, and a player who attacks them is refused for a few days; names Ragtooth and Skritch.

## As built
- **Data.** `data/creatures/goblin_tribes.json` holds every tribe, its attitude and every number. An attitude row (friendly, wary, indifferent, unfriendly, hostile) holds the keep distances, the trading switch and the anger length, so a later tribe is a new row, not new code. The first tribe, the Ragtooth goblins, is **wary**.
- **The camp.** It sits at the mouth of spring cave 3,4#8013, about 2.8 km east of Edda and Hob's camp. Its river runs 50 m west of the mouth, and the cave is where that river's spring comes out. The fire and the five goblins stand on the 13-20 degree bench just east of the mouth, 6-16 m from the opening, facing west toward the river. All of this was read from the baked tile on 19 Nov; `test_goblin_camp` checks it again on the tile. The cave holds no wild goblin band (the den pick `TileTerrainData.goblin_den_node`), and the deep tunnels are untouched.
- **The goblins.** They are NPCs (`server_npcs.gd`), not animals, so the talk and trade of Hob's shop work on them unchanged. They don't use the animal movement code at all.
  - Skritch is the trader, drawn with the Skritch look.
  - Rukz is the lookout, drawn with the Rukz look.
  - Snag is the fire-keeper, drawn with the Skritch look.
  - Vrixa Thornfang (Dave, 20 Nov 2026: "for now she will be a named goblin at the Ragtooth camp. they are friendly goblins but nervous.") rests east of the fire between the bench and the drying rack, drawn with her own look (body 2). Her spot and role are PROVISIONAL (GOBLIN-2).
  - Grikka Ragtooth (Dave, 20 Nov 2026: "this is Grikka Ragtooth please add her to the game") rests just east of Vrixa, drawn with her own look (body 3). That she is Skritch's kin is read from her name, PROVISIONAL like her spot.
  - Vrixa and Grikka gather firewood and fibre (the camp's default round, written in their rows). They carry spears like the others.
  - Each one stands at its own spot at rest, and goes about its chores between rests (camp life, below).
  - The client draws them with the wild goblin's model and clips (`npc_view.gd` asks `animal_view.make_goblin`), and their names show above their heads.
- **Apprehensive** (`server_tribes.gd avoid`):
  - A goblin keeps a distance that depends on your standing with the tribe. Other goblins keep 6 / 4 / 3 / 2 m for Stranger / Known / Friend / Trusted. The trader keeps 2.5 / 2 / 1.5 / 1.2 m, which is inside the 3 m "Press E to talk" reach.
  - Come closer than that and it backs away from you while still facing you, but never more than 8 m from its spot. Just outside the distance it holds still and watches. It turns to watch anyone within 20 m.
  - Inside 10 m, running (faster than 3 m/s) or holding a weapon in hand makes them keep 4 m further away, and a weapon in hand makes them stand guard (camp life, stage C). The trader won't start a talk or a trade then: "No blades near the camp. Put it away." / "Slow! Slow, big-folk."
- **Warming up.** Standing is kept for the whole tribe (`rep_key` tribe_ragtooth): what you earn with one goblin counts with all of them. A completed purchase or sale earns 1 standing, at most once a game day. Better standing brings them closer and lowers prices through Hob's own trade rule (rank steps in `coins.json` trade). The dialogue's rank barks also change: Skritch greets a Friend warmly.
- **Talk and trade.** Skritch has "Show me what you have" (opens the shop), "What do you want from me?", "Who are the Ragtooth?" and "Do you trust me yet?". Rukz, Snag, Vrixa and Grikka send you to Skritch.
  - He sells mushrooms, dried mushrooms, berries, dried berries, flint, bone, claw, claw necklace, gut, copper ore, tin ore, sling stones, bone arrows and herb salve.
  - He buys food, materials, tools, medicine and clothing (`shops.json` skritch). His purse is 120 copper and refills 40 a game day.
- **Attacked.** A melee blow or an arrow at a goblin hurts nobody. The tribe turns on that character for 1 game day and the character loses 3 standing with the clan (camp life, stage C). The goblins within 25 m of that character run into the cave mouth and are not drawn; they come out about 30 s after the character is more than 30 m away. They refuse that character talk and trade ("You hit us. Go away. No talk, no trade."), and other players see the camp empty while that character is near. Saved in `tribes_state.json` in the server store.
- **The camp fire.** It is a large fire laid by the server like Edda and Hob's. It never goes out and is never saved. Every use is refused: "That is the Ragtooth goblins' fire." It also keeps wild spawns away. Nothing can be put down within 8 m of it: "That is a goblin camp: build away from their fire." The client names it "The Ragtooth goblins' campfire". `npc_camp.gd` now lists every camp fire (Edda and Hob's first), and the server keeps each one lit.
- **No new items or recipes.** The roster's outfit field carries "goblin:<variant>". The fire row's {"camp": 1} is unchanged. Camp life adds protocol 146 (held_item, row states WORK and GUARD); PROTOCOL.md records it.

## For Dave (PROVISIONAL, change any of these)
- **GOBLIN-1 Where.** The cave 2.8 km east, at its mouth. Getting up from the river is steep (30 degrees or more), so the easy way in is along the bench from the east.
- **GOBLIN-2 Who.** Five goblins (Skritch the trader, Rukz the lookout, Snag, Vrixa and Grikka at the fire) and the tribe name Ragtooth. Vrixa and Grikka joined as extra goblins rather than taking Snag's or Rukz's post, so nothing else changed; their rest spots (Vrixa x 56081, z 68382; Grikka x 56084, z 68381; both on the ledge east of the fire, clear of the props, facing the fire) are checked against the baked tile by `test_goblin_camp`. They do not sleep or sit yet, because the goblin sit clip lies too flat.
- **GOBLIN-3 Keep distances.** 6 / 4 / 3 / 2 m by rank, the trader 2.5 / 2 / 1.5 / 1.2 m. Running or a weapon within 10 m adds 4 m. They back off up to 8 m from their spot.
- **GOBLIN-4 What counts as a weapon.** Replaced by GOBLIN-13 (a weapon in hand).
- **GOBLIN-5 Trade.** Coins, Hob's window, the stock and buy list above, purse 120 copper. Torches are not refused yet (the shop rules have no per-item refusal).
- **GOBLIN-6 Lines.** Skritch's speech style ("Slow, big-folk", no articles) and every line in `data/npcs/dialogue/skritch.json`, `rukz.json`, `snag.json`, `vrixa.json` and `grikka.json`. Vrixa and Grikka have their own voice rows (`vrixa` Kokoro af_nicole, `grikka` af_sky). No voice clips are rendered yet (tools/gen_npc_voice.py), so they are silent for now.
- **GOBLIN-7 Attacked.** They can't be hurt. Replaced by GOBLIN-12 and GOBLIN-15 (1 game day of anger, 3 standing lost, out about 30 s after the attacker leaves). Other players see the camp empty meanwhile.
- **GOBLIN-8 Warming up.** +1 standing per game day of trading. Known comes at 2, Friend at 5 and Trusted at 10 (`reputation.json`).

## Not done, known limits
- No picture yet. The camp has not been seen in game or played.
- The goblins stand on the hill's ground. Nothing checks yet that no tree or rock stands on a spot (`test_goblin_camp` checks slope and water on the baked tile only).
- The other attitudes (friendly, indifferent, unfriendly, hostile) are data rows with no tribe using them. A hostile tribe that fights is not built: like animal attacks, it would be harmless for now.

## Camp life, stage 2 (20 Nov 2026; in dev, #1354 95bb7530, not played)
What Dave asked on 20 Nov 2026:
- "for now she will be a named goblin at the Ragtooth camp. they are friendly goblins but nervous."
- "they should all keep themselves busy in the area around the camp, either gathering firewood and putting in the fire or gathering supplies around the area like plant fiber to make twine or hunting for meat, hide etc. they should have a small chest of some sort, probably a few drying racks or tanning racks, a campfire maybe some wooden benches around the fire. they should carry spears for weapons. If a character approaches them with no weapon in hand they will be aprihensive but approachable. if the player has a weapon they will take up defensive positions with thier spears and make angry sounds. they will run away if the player attacks and it will hurt the players reputation with the Ragtooth Clan. If the player leaves they will eventually come back to their camp."
- "remember to keep their motions fluid and smooth. Aim for natural."

"She" is Vrixa Thornfang, a Ragtooth goblin (PR #1345, with Grikka Ragtooth). Both take the default round, firewood and fibre.

**The ground.** On the baked tile, the camp's bench is a narrow ledge, one 8 m cell wide (z about 68380 to 68388). It climbs east from the mouth at 18-20 degrees for about 60 m. Everything around it is 30 degrees or steeper. So the props stand along the ledge, and the chores walk up and down it.

**Stage A: the camp and the spears.** No protocol change.
- The props are existing catalog pieces, laid by the server the way the bandit camp lays its Lean-tos:
  - one Crude chest (914)
  - one Drying rack (775)
  - one Tanning rack (773)
  - two Log benches (629), one each side of the fire
- Props are transient pieces marked with the tribe. They are never saved, laid again at every start, and every take-down, open or use is refused: "That belongs to the Ragtooth camp."
- The camp keep (8 m) grows to cover the props.
- Each goblin holds a Wooden spear (item 10's look) in its right hand, fixed to the hand bone so it moves with every clip.

**Stage B: chores.** This needs one protocol number for two new row states.
- Each goblin runs its own loop of jobs from data (`goblin_tribes.json` chores):
  - **Firewood:** walk up the ledge to a wood spot, gather (the gathering clip, 6-10 s), carry it back, and kneel at the fire for 3 s.
  - **Fibre:** walk to a plant spot, gather, and take it to the chest.
  - **Hunt:** one goblin at a time, never the trader. It walks into the cave mouth, is out of sight for 2 to 4 real minutes, comes back out of the mouth, and works at the racks.
  - **Rest:** stand or sit by the fire for a while.
- Skritch keeps to the fire and the chest so a trader is always near.
- **Cheap for the server:** the spots are fixed points in the data, checked on the baked tile by the test. Nothing scans the world. A chore is one timer and one steering step toward a known point, run only while a player is within the NPCs' active radius (200 m), at their existing tick rates (10 Hz near, 3 Hz mid, 0.5 Hz far). A dormant camp is not run. Nothing is taken from or added to the world, and the fire never runs low.
- New row states: WORK (the gathering clip) and GUARD (stage C). Old clients cannot read these, hence the protocol bump.

**Stage C: a weapon in hand, defence, running away, coming back.** This uses the same protocol number as stage B.
- The client tells the server when the item in hand changes: one message per change, at most twice a second. The server keeps it per player.
- That replaces "a weapon on the hotbar" (GOBLIN-4) with "a weapon in hand", as Dave asked.
- **No weapon in hand:** the goblins are nervous but approachable, as now. They keep their distance by standing, watch, and go on with their chores once you are past them.
- **Weapon in hand within 10 m:** each goblin within 10 m stops its chore (backing off first if you are inside its keep distance) and squares up facing you with the spear forward (the defensive clip: Skritch's Combat_Stance, Rukz's Alert, Vrixa's and Grikka's Squat_Stance, the last two PROVISIONAL and not yet seen on screen), and makes an angry chitter every 2-4 s.
  - The chitter is a new short creature sound, made by a script like the other generated animal calls.
  - They relax and go back to work as soon as the weapon is put away or you step back past 10 m.
- **Attacked:**
  - Nobody is hurt.
  - Every goblin within 25 m runs into the cave mouth (one at a far chore point or out hunting carries on).
  - You lose standing with the Ragtooth Clan.
  - They stay out of sight while you are within 30 m.
  - When you leave, they come back out of the mouth after about 30 s, walking, and return to their chores.

**Smooth motion (all stages).**
- The goblins are drawn through the same in-between buffer the animals use since animals part 2 (`src/client/motion_buffer.gd`), not the old chase-the-last-point glide. So walking, backing off, fleeing and returning come out at a steady speed with no lunges.
- The server eases speed changes (it speeds up and slows down over about half a second) and turns at a limited rate, so no goblin spins on the spot.
- Clips cross-fade over 0.3 s, and the walk clip's speed follows the measured pace.
- The spear stays in the hand through every blend.

**Choices made for Dave (PROVISIONAL):**
- **GOBLIN-9:** "Friendly but nervous" is the existing wary row: the same keep distances, trade on.
- **GOBLIN-10:** chores are for show only. The firewood, fibre and game are not real items and change nothing in the world or in Skritch's shop.
- **GOBLIN-11:** the props are one Crude chest, one Drying rack, one Tanning rack and two Log benches, none of them usable by players.
- **GOBLIN-12:** an attack costs 3 standing with the clan (about one rank), and the clan refuses that character trade and talk for 1 game day instead of 3.
- **GOBLIN-13:** the weapon test is "a weapon in hand", for any item of kind weapon (melee, bows, slings). A torch, axe or other tool in hand does not count.
- **GOBLIN-14:** the hunter is out of sight 2 to 4 real minutes per hunt, and only one goblin hunts at a time.
- **GOBLIN-15:** they come back about 30 s after the attacker is more than 30 m away.

**State of A (20 Nov 2026).** Built in PR #1354, not played or seen on screen yet. The props are laid by `server_items.gd` `_tribe_props_tick`. They are refused by `_tribe_piece_refuses`, which covers take-down, use and sit, lock and repair. They have no store and serve no crafting. The spear is drawn by `npc_view.gd` `_goblin_spear` and `_hold_spear`. Goblins are drawn through `motion_buffer.gd`. Things to check on the PC: which way the spear points in the hand, and the props on the slope.

**State of B and C (20 Nov 2026).** Built on the branch under protocol 146. Not played or seen on screen yet.
- `server_tribes.gd` `chore_plan` runs each goblin's round from the camp's `chores` data; `server_npcs.gd` `_step_chore`, `_move` and `_turn_to` walk it with eased speed (accel_mps2 1.5) and a turn limit (turn_dps 160).
- The chores are show only, a provisional first cut (GOBLIN-10): Dave described real gathering, and nothing is gathered, carried or added yet.
- The hand: `held_item.gd` `_report_held` sends `terrain_net.gd` `held_item`; `server_items.gd` `report_held` and `held_number` keep it, checked against the pack. This replaces GOBLIN-4's hotbar test.
- Guard: `avoid` answers guard for a weapon in hand within spook_m; the client turns the spear forward and plays the new goblin chitter and hiss (`creature_sounds.gd`, made by `assets/audio/make_creatures.py`).
- Attacked: wary anger is now 1 game day and costs attack_rep (3) standing once per anger; hidden goblins wait calm_s (30 s) after the attacker has gone, then walk out.
- A goblin that cannot reach a chore point (a build on the ledge, say) gives up after twice the walk time plus 10 s and does the chore where it stands. A member with no `chores` list of its own takes the camp's `default_jobs`, so a new named member joins by its members row alone.
- Known limits: the server trusts the client's word on which item is in hand (it checks only that the pack holds it), and the camp benches can still be sat on by the client like any bench.
- Covered by `test_goblin_camp.gd` `_tile` (every chore point), `_npcs` and `_chores` (which prints the camp's tick cost).

**Order.** A, B and C go together in PR #1354 (protocol 146), ahead of the goblins PR (#1345) that added Vrixa and Grikka; their chore rounds come from data (`default_jobs`, or a `chores` list in their members row). A BugsList entry follows in a docs PR.
