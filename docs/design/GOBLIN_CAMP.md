# The Ragtooth goblin camp

**Status: DAVE-REQUESTED (19 Nov 2026), built on branch `claude/project-thread-m8edia`; not played, not seen on screen.** Values marked PROVISIONAL were answered on Dave's behalf by the coordinator while he was away (standing rule, 14 Nov 2026) and wait for his review below.

## What Dave asked (19 Nov 2026)
- "we also already have goblins in our game so we should build them a goblin camp somewhere near the river or in a cave. I want the goblins to be apprehensive but willing to communicate and trade/buy and sell. in the future the game will have various goblin tribes/camps etc that are friendly, not friendly, indifferent etc."
- "the goblin camp could be a cave somewhere near a river."
- Natural caves becoming animal dens is a separate plan (caves thread); this camp uses one cave's mouth only.

Answered for him (coordinator, 19 Nov 2026, provisional): the cave 2.8 km east of Edda and Hob; trade in coins in Hob's shop window; goblins cannot be killed for now, and a player who attacks them is refused for a few days; names Ragtooth and Skritch.

## As built
- **Data.** `data/creatures/goblin_tribes.json` holds every tribe, its attitude and every number. An attitude row (friendly, wary, indifferent, unfriendly, hostile) holds the keep distances, the trading switch and the anger length, so a later tribe is a new row, not new code. The first tribe, the Ragtooth goblins, is **wary**.
- **The camp.** It sits at the mouth of spring cave 3,4#8013, about 2.8 km east of Edda and Hob's camp. Its river runs 50 m west of the mouth, and the cave is where that river's spring comes out. The fire and the three goblins stand on the 13-20 degree bench just east of the mouth, 6-16 m from the opening, facing west toward the river. All of this was read from the baked tile on 19 Nov; `test_goblin_camp` checks it again on the tile. The cave holds no wild goblin band (the den pick `TileTerrainData.goblin_den_node`), and the deep tunnels are untouched.
- **The goblins.** They are NPCs (`server_npcs.gd`), not animals, so the talk and trade of Hob's shop work on them unchanged. They don't use the animal movement code at all.
  - Skritch is the trader, drawn with the Skritch look.
  - Rukz is the lookout, drawn with the Rukz look.
  - Snag is the fire-keeper, drawn with the Skritch look.
  - Each one stands at its own spot all day and night.
  - The client draws them with the wild goblin's model and clips (`npc_view.gd` asks `animal_view.make_goblin`), and their names show above their heads.
- **Apprehensive** (`server_tribes.gd avoid`):
  - A goblin keeps a distance that depends on your standing with the tribe. Other goblins keep 6 / 4 / 3 / 2 m for Stranger / Known / Friend / Trusted. The trader keeps 2.5 / 2 / 1.5 / 1.2 m, which is inside the 3 m "Press E to talk" reach.
  - Come closer than that and it backs away from you while still facing you, but never more than 8 m from its spot. Just outside the distance it holds still and watches. It turns to watch anyone within 20 m.
  - Inside 10 m, running (faster than 3 m/s) or carrying a weapon on the hotbar makes them keep 4 m further away. The trader won't start a talk or a trade then: "No blades near the camp. Put weapons in your pack." / "Slow! Slow, big-folk."
- **Warming up.** Standing is kept for the whole tribe (`rep_key` tribe_ragtooth): what you earn with one goblin counts with all of them. A completed purchase or sale earns 1 standing, at most once a game day. Better standing brings them closer and lowers prices through Hob's own trade rule (rank steps in `coins.json` trade). The dialogue's rank barks also change: Skritch greets a Friend warmly.
- **Talk and trade.** Skritch has "Show me what you have" (opens the shop), "What do you want from me?", "Who are the Ragtooth?" and "Do you trust me yet?". Rukz and Snag send you to Skritch.
  - He sells mushrooms, dried mushrooms, berries, dried berries, flint, bone, claw, claw necklace, gut, copper ore, tin ore, sling stones, bone arrows and herb salve.
  - He buys food, materials, tools, medicine and clothing (`shops.json` skritch). His purse is 120 copper and refills 40 a game day.
- **Attacked.** A melee blow or an arrow at a goblin hurts nobody. The tribe turns on that character for 3 game days. While that character is within 25 m the goblins go into the cave mouth and are not drawn. They refuse that character talk and trade ("You hit us. Go away. No talk, no trade."), and other players see the camp empty while that character is near. Saved in `tribes_state.json` in the server store.
- **The camp fire.** It is a large fire laid by the server like Edda and Hob's. It never goes out and is never saved. Every use is refused: "That is the Ragtooth goblins' fire." It also keeps wild spawns away. Nothing can be put down within 8 m of it: "That is a goblin camp: build away from their fire." The client names it "The Ragtooth goblins' campfire". `npc_camp.gd` now lists every camp fire (Edda and Hob's first), and the server keeps each one lit.
- **No new items, recipes, states or protocol number.** The roster's outfit field carries "goblin:<variant>". The fire row's {"camp": 1} is unchanged. PROTOCOL.md records both.

## For Dave (PROVISIONAL, change any of these)
- **GOBLIN-1 Where.** The cave 2.8 km east, at its mouth. Getting up from the river is steep (30 degrees or more), so the easy way in is along the bench from the east.
- **GOBLIN-2 Who.** Three goblins (Skritch the trader, Rukz the lookout, Snag at the fire) and the tribe name Ragtooth. They stand day and night. They do not sleep or sit yet, because the goblin sit clip lies too flat.
- **GOBLIN-3 Keep distances.** 6 / 4 / 3 / 2 m by rank, the trader 2.5 / 2 / 1.5 / 1.2 m. Running or a weapon within 10 m adds 4 m. They back off up to 8 m from their spot.
- **GOBLIN-4 What counts as a weapon.** Any item of kind weapon on the hotbar, shields included. The server doesn't know which hotbar slot is in your hand.
- **GOBLIN-5 Trade.** Coins, Hob's window, the stock and buy list above, purse 120 copper. Torches are not refused yet (the shop rules have no per-item refusal).
- **GOBLIN-6 Lines.** Skritch's speech style ("Slow, big-folk", no articles) and every line in `data/npcs/dialogue/skritch.json`, `rukz.json` and `snag.json`. Their voices are listed in `voices.json` but no voice clips are rendered yet (tools/gen_npc_voice.py), so they are silent for now.
- **GOBLIN-7 Attacked.** They can't be hurt. There are 3 game days of anger, they hide in the mouth while the attacker is within 25 m, and other players see the camp empty meanwhile. Standing is not lowered.
- **GOBLIN-8 Warming up.** +1 standing per game day of trading. Known comes at 2, Friend at 5 and Trusted at 10 (`reputation.json`).

## Not done, known limits
- No picture yet. The camp has not been seen in game or played.
- The goblins stand on the hill's ground. Nothing checks yet that no tree or rock stands on a spot (`test_goblin_camp` checks slope and water on the baked tile only).
- The other attitudes (friendly, indifferent, unfriendly, hostile) are data rows with no tribe using them. A hostile tribe that fights is not built: like animal attacks, it would be harmless for now.
