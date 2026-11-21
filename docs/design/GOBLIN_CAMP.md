# The Ragtooth goblin camp

**Status: DAVE-REQUESTED (19 Nov 2026). The camp is in dev (#1325); camp life (stage 2, 20 Nov 2026) is in dev too (#1354, 95bb7530), and so is the camp stock, the light version (#1369, 0d6415cc). None of it played nor seen on screen yet.** Values marked PROVISIONAL were answered on Dave's behalf by the coordinator while he was away (standing rule, 14 Nov 2026) and wait for his review below.

## What Dave asked (19 Nov 2026)
- "we also already have goblins in our game so we should build them a goblin camp somewhere near the river or in a cave. I want the goblins to be apprehensive but willing to communicate and trade/buy and sell. in the future the game will have various goblin tribes/camps etc that are friendly, not friendly, indifferent etc."
- "the goblin camp could be a cave somewhere near a river."
- Natural caves becoming animal dens is a separate plan (caves thread); this camp uses one cave's mouth only.

Answered for him (coordinator, 19 Nov 2026, provisional): the cave 2.8 km east of Edda and Hob; trade in coins in Hob's shop window; goblins cannot be killed for now, and a player who attacks them is refused for a few days; names Ragtooth and Skritch.

## As built
- **Data.** `data/creatures/goblin_tribes.json` holds every tribe, its attitude and every number. An attitude row (friendly, wary, indifferent, unfriendly, hostile) holds the keep distances, the trading switch and the anger length, so a later tribe is a new row, not new code. The first tribe, the Ragtooth goblins, is **wary**.
- **The camp.** Since 21 Nov 2026 it sits by spring cave 3,4#8006, the cave nearest the spawn: about 1.6 km west-south-west of the spawn campfire (GOBLIN-19, below). A brook comes out of the cave mouth (x 56560, z 71776) and runs east. The fire, the props and the five goblins stand on a dry bench of 3 to 11 degrees on the brook's south bank, about 50 m south-east of the mouth (fire x 56608, z 71800). All of this was read from the baked tile on 21 Nov; `test_goblin_camp` checks it again on the tile. The cave holds no wild goblin band and no animal den (`TileTerrainData.CAMP_CAVES`), and the deep tunnels are untouched. Until 21 Nov the camp was at cave 3,4#8013, about 3.6 km north-north-west of the spawn.
- **The goblins.** They are NPCs (`server_npcs.gd`), not animals, so the talk and trade of Hob's shop work on them unchanged. They don't use the animal movement code at all.
  - Skritch is the trader, drawn with the Skritch look.
  - Rukz is the lookout, drawn with the Rukz look.
  - Snag is the fire-keeper, drawn with the Skritch look.
  - Vrixa Thornfang (Dave, 20 Nov 2026: "for now she will be a named goblin at the Ragtooth camp. they are friendly goblins but nervous.") rests just east of the fire, by a bench, drawn with her own look (body 2). Her spot and role are PROVISIONAL (GOBLIN-2).
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
- **GOBLIN-1 Where.** Replaced by GOBLIN-19 (21 Nov 2026: the cave nearest the spawn). It was the cave 2.8 km east of Edda and Hob's first camp, at its mouth.
- **GOBLIN-2 Who.** Five goblins (Skritch the trader, Rukz the lookout, Snag, Vrixa and Grikka at the fire) and the tribe name Ragtooth. Vrixa and Grikka joined as extra goblins rather than taking Snag's or Rukz's post, so nothing else changed; their rest spots (Vrixa x 56615, z 71799; Grikka x 56618, z 71798; both on the bench east of the fire, clear of the props, facing the fire) are checked against the baked tile by `test_goblin_camp`. They do not sleep or sit yet, because the goblin sit clip lies too flat.
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

**The ground.** At cave 3,4#8006 (since 21 Nov 2026) the camp stands on a bench of 3 to 11 degrees south-east of the mouth, about 20 m across. The wood and fibre points are on the slope 25 to 40 m east of the fire, at 11 to 18 degrees. The hunter walks about 50 m to the mouth, along the brook's shallow edge (only water deeper than 0.7 m blocks a walk). (At the old cave the bench was a narrow 18-20 degree ledge.)

**Stage A: the camp and the spears.** No protocol change.
- The props are existing catalog pieces, laid by the server the way the bandit camp lays its Lean-tos:
  - one Small chest (1512; was the Crude chest 914 until Dave retired the knife chests 21 Nov 2026, "get ride of both of those")
  - one Drying rack (775)
  - one Tanning rack (773)
  - two Log benches (629), one each side of the fire
- Props are transient pieces marked with the tribe. They are never saved, laid again at every start, and every take-down, open or use is refused: "That belongs to the Ragtooth camp."
- The camp keep (8 m) grows to cover the props.
- Each goblin holds a Wooden spear (item 10's look) in its right hand, fixed to the hand bone so it moves with every clip.

**Stage B: chores.** This needs one protocol number for two new row states.
- Each goblin runs its own loop of jobs from data (`goblin_tribes.json` chores):
  - **Firewood:** walk out to a wood spot, gather (the gathering clip, 6-10 s), carry it back, and kneel at the fire for 3 s.
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
- **GOBLIN-10:** chores are for show only. What the goblins carry is not a real item and changes nothing in the world or in Skritch's shop. The camp's stock (the light version, below) fills on its own clock.
- **GOBLIN-11:** the props are one Small chest, one Drying rack, one Tanning rack and two Log benches, none of them usable by players.
- **GOBLIN-12:** an attack costs 3 standing with the clan (about one rank), and the clan refuses that character trade and talk for 1 game day instead of 3.
- **GOBLIN-13:** the weapon test is "a weapon in hand", for any item of kind weapon (melee, bows, slings). A torch, axe or other tool in hand does not count.
- **GOBLIN-14:** the hunter is out of sight 2 to 4 real minutes per hunt, and only one goblin hunts at a time.
- **GOBLIN-15:** they come back about 30 s after the attacker is more than 30 m away.

**State of A (20 Nov 2026).** Built in PR #1354, not played or seen on screen yet. The props are laid by `server_items.gd` `_tribe_props_tick`. They are refused by `_tribe_piece_refuses`, which covers take-down, use and sit, lock and repair. They have no store and serve no crafting. The spear is drawn by `npc_view.gd` `_goblin_spear` and `_hold_spear`. Goblins are drawn through `motion_buffer.gd`. Things to check on the PC: which way the spear points in the hand, and the props on the slope.

**State of B and C (20 Nov 2026).** Built on the branch under protocol 146. Not played or seen on screen yet.
- `server_tribes.gd` `chore_plan` runs each goblin's round from the camp's `chores` data; `server_npcs.gd` `_step_chore`, `_move` and `_turn_to` walk it with eased speed (accel_mps2 1.5) and a turn limit (turn_dps 160).
- The chores are show only, a provisional first cut (GOBLIN-10): Dave described real gathering; nothing is gathered or carried, and the camp's stock fills on its own clock instead (the light version, below).
- The hand: `held_item.gd` `_report_held` sends `terrain_net.gd` `held_item`; `server_items.gd` `report_held` and `held_number` keep it, checked against the pack. This replaces GOBLIN-4's hotbar test.
- Guard: `avoid` answers guard for a weapon in hand within spook_m; the client turns the spear forward and plays the new goblin chitter and hiss (`creature_sounds.gd`, made by `assets/audio/make_creatures.py`).
- Attacked: wary anger is now 1 game day and costs attack_rep (3) standing once per anger; hidden goblins wait calm_s (30 s) after the attacker has gone, then walk out.
- A goblin that cannot reach a chore point (a build in the way, say) gives up after twice the walk time plus 10 s and does the chore where it stands. A member with no `chores` list of its own takes the camp's `default_jobs`, so a new named member joins by its members row alone.
- Known limits: the server trusts the client's word on which item is in hand (it checks only that the pack holds it), and the camp benches can still be sat on by the client like any bench.
- Covered by `test_goblin_camp.gd` `_tile` (every chore point), `_npcs` and `_chores` (which prints the camp's tick cost).

**Order.** A, B and C go together in PR #1354 (protocol 146), ahead of the goblins PR (#1345) that added Vrixa and Grikka; their chore rounds come from data (`default_jobs`, or a `chores` list in their members row). A BugsList entry follows in a docs PR.

## Camp stock, the light version (20 Nov 2026; in dev, #1369 0d6415cc, not played)

Dave, 20 Nov 2026: "Build the light version of the goblin camp." It was offered to him as the goblins keep their chores for show, while the camp chest and racks slowly fill to a small capped stock on a timer, with nothing taken from the world. Trading for that stock at good standing was mentioned as a later step. It is not built.

- **What fills:** the Small chest holds Firewood and Plant fibre, the Drying rack Raw meat, and the Tanning rack Hide. All are existing catalog items (`goblin_tribes.json` camp `stock`).
- **How fast:** per game day, 6 Firewood, 4 Plant fibre, 1 Hide and 2 Raw meat. The caps are 20, 12, 3 and 4, so the camp is full in about 3 to 4 game days.
- **How it shows:** opening the chest, or using a rack, is refused as before, and the refusal says what the piece holds. Example: "That belongs to the Ragtooth camp. In it: 20 firewood and 12 plant fibre." A bench holds nothing. Nothing is drawn on the racks yet.
- **Cost:** none per tick. The stock is worked out from the game clock when a player tries a piece (`server_tribes.gd` `stock`, `stock_line`). The fill start is saved in `tribes_state.json` (`stock_from`), so a restart keeps it.
- **Not taken from the world:** no plants, sticks or game are used up. The meat does not spoil and the fire never burns the wood.

**Choices made for Dave (PROVISIONAL):**
- **GOBLIN-16:** the amounts and caps above, filling on the game clock from the server's first run, whether or not anyone is near.
- **GOBLIN-17:** nobody can take the stock. The chest does not open and the racks refuse every use, so there is no theft yet. If Dave wants it takeable, a theft rule is needed first, for example taking counts as an attack (GOBLIN-12).
- **GOBLIN-18:** the stock is shown only in words. Hides and meat are not drawn on the racks or wood beside the fire, which would need new client drawing.

## Moved near the spawn (21 Nov 2026)

Dave, 21 Nov 2026: "I think we should move the goblins cave much closer to spawn so people might actually find it. it should probably be right in the closest mountain or hill to the spawn point then we can make a path to it for players later." And: "include that before merging to main."

- **Where.** Spring cave 3,4#8006, the nearest cave to the spawn: mouth x 56560, z 71776, ground about 23 m, under ridges of 80 to 99 m to the north-west and south. The camp is about 1.6 km west-south-west of the spawn campfire (1.56 km west, 0.44 km south). The next nearest caves are 2.1 km and 2.8 km off; the old one was 3.6 km.
- **Why not nearer.** The nearest hills, about 1.2 km south and 1.2 km north of the spawn, have no cave. A camp there needs a new cave cut into the hill (cave carving like the mines, a terrain version bump and a new starter cache). That is a possible follow-up for Dave, not done.
- **The cave is kept.** By its id, 8006 would hold a wild goblin band and a wolf den. `TileTerrainData.CAMP_CAVES` keeps both out, on the server and every client alike. Cave 8013 is no longer kept; by its id it holds neither a goblin band nor an animal den, and the tile's always-goblins floor (`goblin_den_nodes`) stays on its first spring cave, 3,4#8002, so nothing new appears there.
- **Running for the mouth.** Here the mouth is about 50 m from the fire, further than angry_keep_m (25 m). A member that starts running for the mouth from a striker now goes all the way in (`ServerTribes.avoid`, the npc's `fleeing` mark), rather than stopping in the open once it is 25 m from them; if it cannot get there in twice the run time plus 10 s it stops running. In the cave it counts a striker near while they are within angry_keep_m plus 5 m of the mouth or of its own spot at the camp, so a striker waiting at the camp keeps it in. It comes out calm_s after that.
- **No path yet** (Dave: later).
- **An existing world.** Nothing of the camp is saved at a place: the fire and props are laid by the server and never saved, and the goblins stand at their spots from the data. After a server restart the camp is at the new cave and nothing of it is left at the old one. Standing, anger and the stock clock are kept per tribe, so they carry over. Wild goblins and animals are never saved, so none linger at 8006. Only if a wolf pack denning at 8006 was killed in a world is a row saved for it (its rest or orphans); that row stays. Bandit sites keep 1.5 km off the camp, so the ground they may use moves with it (robbery is off).
- **GOBLIN-19:** cave 3,4#8006 and the layout above, PROVISIONAL (coordinator for Dave, 21 Nov 2026).
