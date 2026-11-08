# Bats: a small flapping flier that roosts upside down in caves (MikeW, 8 Nov 2026)

Same shape as FLIGHT_RIGS.md (#609), for a bat: FAUNA_BY_BIOME lists bats (rarity 2, temperate and mixed forest), the caves now exist (spring caves, goblin dens), and a dusk swarm leaving a cave mouth is one of the best "the world is alive" moments the game can show. The pack has no bat; it is a Meshy model for Dave.

## 1. What the model must bring
- One small rigged mesh (body about 8 cm, wingspan about 25 to 30 cm), **wings folded in the rest pose**, hanging head down is not needed in the file: the roost pose is a clip.
- **Clips, in place (no travel):**
  | Role | Clip | Loop |
  |---|---|---|
  | roost (0) | hanging by the feet, head down, wings wrapped, small breathing | yes |
  | alert (3) | hanging, wings part-open, head turning | yes |
  | drop | let go and open the wings (roost to flight) | no |
  | fly (15) | fast flapping, a little jink | yes |
  | glide (17) | short wings-out glide | yes |
  | land | swing up to hang | no |
- No walk or run: a bat never walks in the game.
- If the rig comes without clips, the gait builder makes the fly loop (shoulder, elbow and finger bones beating, period about 0.12 s) and the roost pose from `bone_offsets` (the whole body turned 180 degrees about its side axis, wings folded).

## 2. Server: a colony, not single bats
Like the duck and gull flocks, one wire record is a **colony** (a flock row with `"on_land": false, "cave": true`):
- **By day** it is at a roost spot on a cave ceiling (the cave's roof height at a point inside the mouth), state 0; drawn as 8 to 40 bats hanging close together.
- **At dusk** (the `active` hours) it leaves: state 15, the record rising out of the cave mouth and spreading out over the nearest forest or water within 300 m, at 3 to 15 m above the ground, flying fast and jinking.
- **At dawn** it comes back and roosts (state 15 then 0 inside the cave).
- A player entering the roost chamber with a torch, or making noise there, wakes it: the colony swarms (15) in the cave for some seconds and settles again. No attack, no damage: bats are harmless; a little fear is the point.
- Wire: the same five values per row; the height is in the position. The colony's spread is drawn by the client from the id (like the duck flock).

## 3. Client
- `flock_of` with the roost clip: birds placed under the roof upside down (`bone_offsets` or the roost clip), spread 1.5 m.
- In flight, each bat follows the record with its own jitter (a small noise on its offset), so the swarm boils instead of moving as a plate. That is new for model flocks: a `"swarm": true` row key giving each member a moving offset.
- Sound: a soft chitter slot per colony (Jason), louder when swarming. No eye shine (none in bats).

## 4. Data and order
1. Dave's Meshy bat; install, `creature_check --clips`, rows (`add_species` spec: copy the duck's flock row, add `cave`, `swarm`).
2. Server: the cave-roof roost spot (needs the cave roof height at a point: the cave tool already knows it), the dusk exit and dawn return, the torch wake-up.
3. Client: upside-down roost, swarm jitter.
4. Test: a colony is at its roost by day, outside at night within 300 m, never inside rock; a torch in the chamber wakes it.
