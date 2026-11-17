# Edda and Hob's camp under the oak

**Status: DAVE-REQUESTED (17 Nov 2026), built on branch `claude/project-thread-a519fm`; not played.** Values marked PROVISIONAL are assumptions made on Dave's behalf (standing rule, 14 Nov 2026) and wait for his review below.

## What Dave asked (17 Nov 2026)
- "We should move EDDA and Hob under the nearest big tree and give them a large campfire that players cannot access and its just inside the shelter line of the tree so the rain doesnt effect it."
- He picked the tree in a screenshot ("use this tree at these coords": x 53283, z 68083, build 826) and the layout: "put the fire infront of the tree. put hob on the left side of the tree and edda on the right side of the tree both facing the fire."

## As built
- **The tree.** The placer tree beside his spot is an oak, foot x 53284.00 z 68082.53, 12.7 m tall, rain shelter circle 5.84 m (measured on Dave's PC with `tools/npc_camp_spot.gd` at 7679152b). Recorded in `data/npcs/camp.json`. No axe blow, undermining or surveyed road brings it down (`server_items._hit`, `terrain_server._cut_tree`).
- **The fire.** A large fire (the "log" tier, state 41, the normal large campfire look, light, smoke, warmth and wolf ward) at x 53286.70 z 68078.52, 1.0 m inside the oak's shelter circle on the front side, placed with the game's own Cover rule (the same crown circle that stops rain under a tree). The server lays it at every start, keeps it lit, never saves it and lays it again if anything clears it. Nobody can feed it, light it, put it out, cook on it, open its store, hang a pot on it or pick it up; each try says "That is Edda and Hob's fire." Clients get `{"camp": 1}` on its row (PROTOCOL.md) and show no prompt and the name "Edda and Hob's campfire".
- **Hob and Edda.** Two markers in `data/npcs/markers.json` that only they use (`"npc"`): Hob's post at x 53286.21 z 68082.82 (the oak's left, seen from the front), Edda's chair at x 53282.90 z 68080.59 (the right), both turned to face the fire, both about 4.3 m from it. The existing hold (Hob at work, Edda sitting, all day) keeps them there, rain or not. These markers clear no wood (`"clear": false`), so the flora is unchanged and no starter bake is needed; the town's middle (island level, stray dogs) ignores them. The old town markers stay for the day schedules.
- **Kept clear.** Nothing can be put down (building, station, fire, torch, blueprint) within 8 m of the oak: the ghost turns red and the server refuses with "That is Edda and Hob's camp: build away from their oak." As a lit fire, the camp fire also keeps wild spawns off 20 m (no_spawn_m).

## For Dave (PROVISIONAL, change any of these)
- **CAMP-1 Front, left and right.** Read from your screenshot: you looked at the oak toward compass 214 (south-south-west), so "in front" is the north-north-east side, toward where you stood; Hob is on your left (east-south-east of the trunk), Edda on your right (west-north-west).
- **CAMP-2 Fire distance.** 1.0 m inside the shelter line (4.8 m from the trunk). Hob and Edda stand 2 m to the side of the trunk and 1 m toward the fire.
- **CAMP-3 Winter.** An oak drops its leaves, and the game's rule is that a bare broadleaf gives no rain shelter in winter. The camp fire still never goes out, in any weather or season. Players under the oak in winter are not sheltered.
- **CAMP-4 Hob stands, Edda sits.** They keep their current poses (Hob at work, Edda in a chair).
- **CAMP-5 Kept-clear radius.** 8 m round the oak (`keep_m`), enough to keep builds off the fire and both of them.
- **CAMP-6 What still works at the fire.** Passive things a fire gives everyone still work there: warmth, light, the wolf ward, resting comfort, lighting an arrow. Only using the fire itself is refused.

## Not done, known limits
- The ground under the camp can still be dug or raised by a player with a shovel; nothing stops that yet.
- No picture yet; the camp has not been seen in game or played.
