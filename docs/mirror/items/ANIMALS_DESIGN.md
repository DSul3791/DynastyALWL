# Animal system design (draft 1, design only, no code until Steve approves)

Status: written from DESIGN_IDEAS 4.3 (server-controlled spawning, classic AI, perception, needs, steering, simulation level of detail) and my HUNTING_PREREQUISITES.md. Tyler has not yet posted animal entries in BEST_PRACTICES.md; I will reconcile this draft when he does. Nothing here has been looked at by eye.

## 1. Species for the starter tiles (first wave, 8 species)
Temperate lowland and forest, matching carcass.json (already in data).
| Species | Role | Behaviour | Danger |
|---|---|---|---|
| Rabbit | Small game | Solitary, grazes at dawn and dusk, bolts to a burrow when spooked | none |
| Grouse | Small game | Flushes with a loud burst at 5 m, short flight | none |
| Deer | Main game, big meat | Herd of 3 to 8, grazes, one sentinel, flees at hearing or scent | none |
| Boar | Big game, fights back | Sow with young or lone boar, charges when wounded or cornered | medium |
| Fox | Predator of rabbits | Solitary, shy of people, steals from unattended food later | none |
| Wolf | Pack predator | Pack of 3 to 5, hunts deer, avoids a fire, attacks only the weak or wounded alone | high |
| Trout, perch, carp, pike | Fish | Already abstract stock in fishing.json; stay stock, never entities | none |
Later waves: bear, elk, seabirds, seals (coast), then fantasy species per climate zone. Livestock (sheep, pigs, cows, horses) is a separate farming job.

## 2. Server model
- One animal = a small record: id, species, position, heading, state, needs (hunger, fear, rest), health, home point. No physics body; movement is a heightfield walk using the ground height the server already has (as for players and boulders).
- States: idle, graze, walk, alert, flee, rest, hunt, fight, dead. A weighted needs choice picks the state every 1 to 3 s (random timer, so not predictable). Steering (avoid trees and water, keep facing the target) runs at 4 Hz, not per frame.
- Perception, cheap and honest: sight cone (range and angle per species, shorter at night and in rain), hearing (noise of players: running louder than sneaking, axe and mining loudest), smell carried by the wind vector (downwind is safe, upwind spooks). Only checked against players inside the animal's range using the existing spatial cells.
- Herds: a leader plus followers with an offset; the sentinel spooks first and the rest copy it a short random moment later.
- Wounded animals flee, bleed a trail of marks (later), and die after a time; a hunter can track them. Decision for later.

## 3. Spawn and despawn
- Spawn by climate, biome, terrain and time of day, server side, never baked. Target density per 128 m cell (same grid the fishing stock uses), with a regrowth timer so a hunted area refills slowly (one animal per cell per game day, like fish).
- Only animals within about 300 m of a player are simulated; farther ones are frozen as a count per cell (simulation level of detail). When a player leaves, the cell's animals are saved as counts only, no individual positions. Despawn when no player within 400 m for 10 minutes and the cell is at target.
- Hard caps: 150 simulated animals server wide at first, 40 per player. A cap overrun makes the farthest animals freeze.
- Saves: counts per cell and carcasses (like remains). Individual animals are not saved; they respawn from the cell count on load. Neutral default = no animals.

## 4. Server cost at 20 players (estimate)
Measured baseline from the stress run: average tick about 2 ms, p99 about 12 ms, worst about 19 ms with everything else on. Animals add:
- Simulated animals: at most 150, each state update at 4 Hz costs about 5 microseconds without perception and about 30 with it. 150 x 4 Hz x 30 us is about 18 ms per second, roughly 0.3 ms per 60 Hz tick average. I spread them across ticks (a quarter per tick), so the spike is under 0.1 ms.
- Perception checks only against nearby players, so the cost grows with animals times nearby players, capped by the 40 per player rule.
- Network: send only position, heading and state for animals within 120 m of a player, at 4 Hz, 10 bytes each, quantised. Worst case 40 animals x 20 players is 40 x 10 x 4 x 20 = 32 KB/s total, about 1.6 KB/s per player; typical use is a tenth of that. Needs a cap per message and delta sending. Protocol cost to be stated at build time (new RPC `animals(numbers)`, protocol bump).
- Client: at most 40 animals drawn, simple capsule-and-leg rig first, interpolated between 4 Hz updates. At Low: 20 drawn, no leg animation beyond a bob.
- Verdict: fine at 20 players on the minimum machine; I will measure with the stress script before shipping.

## 5. Hunting loop
1. Find tracks (hoof marks, droppings, a flush of birds), or watch a clearing at dawn or dusk. Foraging and a new Tracking skill raise what you notice.
2. Approach upwind and slowly (crouch from the existing walk modes; running spooks at 40 m).
3. Hit with a spear (jab 3 m, throw 12 m, damage 6 or 8) or a trap later. Skill and luck set the damage; a rabbit dies in one hit, a deer takes two to three, a boar fights back, a wolf is a bad idea alone.
4. A wounded animal flees and may drop dead within 30 s; follow it.
5. Carcass becomes a world entity (same shape as a felled trunk): owner none, decays over about 2 game days. A knife (class knife) gives parts one blow at a time using carcass.json (4 blows, parts rolled through roll_amount so luck applies). No knife: scraps only. Never picked up whole.
6. Meat spoils (raw 18 h x4), roast at a fire, hides need scraping later, bones and sinew feed cordage and tools.
7. Skills: Hunting (hit chance, damage), Tracking, Butchering (yield), Stealth (noise radius). All use the existing skills system and practice hooks.

## 6. Server hooks needed (all small)
1. `damage(target, amount, source_peer, kind)` shared by spear hits and later animals attacking players (fall damage and drowning already feed the same health).
2. Carcass entity and carcass loot reader (data already in carcass.json).
3. Animal manager in its own file, ticked from the server tick, saving cell counts.
4. Inspection: animals carry `familiarity` and `look_alikes`; the inspect text names them plainly.
5. An admin command to spawn a test animal and drop a test carcass.

## 7. Build order (each its own push)
A) damage hook plus carcass entity plus admin test carcass (no animals yet, protocol-cheap).
B) animal manager with rabbit and deer only: spawn, graze, flee, die. Client capsule rig.
C) perception (hearing, smell with wind), herds, sentinel.
D) boar and fox; then wolf pack and the danger to players.
E) tracking marks, blood trails, skills.

## 8. Open questions (for Dave only if Steve wants them asked)
- Should wolves be allowed to kill a sleeping player in the starter tiles? I recommend no for the starter set; they only threaten near the edge and at night.
- How rare is big game? I recommend deer common, boar uncommon, wolf rare, so a hunter works for the meal.
- Is hunting restricted by a town? Parked until towns exist.


## Built: step B, the rabbit (build 470, protocol 48)
Server src/stream/server_animals.gd, data data/animals/animals.json, client src/client/animal_view.gd, admin Ctrl+R. Six rabbits per player, spawned 150-250 m away (out of sight assumed by distance), never within 60 m of any player, none in deep water; frozen beyond 200 m, dropped beyond 300 m; ticks 10/3/0.5 Hz by distance; rows nearest 30 within 120 m at 4 Hz. Graze 3-10 s, hop within 6 m, bolt at 7.5 m/s from a player within 14 m until 35 m away. Not saved. Stress (src/worldgen/tools/test_animals.gd): 20 players + NPCs average 0.30 ms per 20 Hz tick, p99 0.74, worst 0.82; 150 animals all near players average 1.36 ms, worst 3.2 ms. No hunting yet: damage hook and carcass are the next step, wolves wait for a Dave card.

## Senses and burrows (build 492, Tyler report 16)
Server only, no wire change. data/animals/animals.json "senses": a player is perceived at distance divided by a factor. Wind: downwind of the player (wind carries scent to the animal) the factor rises to 1 + 0.5 x wind strength (1.5 in a gale), upwind it falls to 0.5. Stance: crouch 0.6, sit 0.8, lying 0.5. Sight: ground between the animal's eye and the player's (sampled every 4 m, terrain only, trees do not block yet) multiplies by 0.35 beyond 8 m. Spook and alert distances compare against the perceived distance. Rabbits own a burrow at their spawn spot: a bolt within 40 m and away from the threat runs for it; the rabbit stays in for 20 to 40 s (state 5, never sent, cannot be hunted) and comes out once no player is within 1.5 x spook. Still to do: blood trail (needs a wire change and a look from Mandy), trees blocking sight, habitat-only spawn.

## Habitat and forest sight (build 495)
Server only. A new animal tries 6 spots 150 to 250 m from a player and takes the first its species can live on: not steeper than slope_max (rise over 6 m in four directions: rabbit 0.5, deer 0.6), not more than 250 m above the player, not within 3 m of deep water; a deer takes a spot under trees if one turns up (tree data is only loaded near players, so far spots count as open). Sight through forest: a line of sight under tree crowns loses up to 45 percent of its visibility, so a player in the woods is noticed later. Biome data is not available on the server at runtime, so true biome habitat (meadow vs forest type) waits for that query.
