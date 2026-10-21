# Protocol (PROTOCOL_VERSION 33, src/stream/terrain_net.gd)

Kept current by whoever changes the wire: add the row, bump PROTOCOL_VERSION to the next free number (pull first and read terrain_net.gd), and note the build.

## Messages (RPCs)

| Message | Direction | Reliability | Arguments | Since |
|---|---|---|---|---|
| welcome | server to client | reliable | info: Dictionary | 2 |
| request_blocks | client to server | reliable | keys: PackedInt32Array, urgent: int | 2 |
| deliver_blocks | server to client | reliable | keys: PackedInt32Array, payloads: Array | 2 |
| tile_changed | server to client | reliable | tile: Vector2i, revision: int | 2 |
| dig | client to server | reliable | center: Vector3, radius: float | 2 |
| dug | server to client | reliable | center: Vector3, radius: float | 2 |
| filled | server to client | reliable | center: Vector3, radius: float, material: int (soil id) | 30 |
| request_flora | client to server | reliable | chunks: PackedInt32Array | 3 |
| deliver_flora | server to client | reliable | chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool | 3 |
| cut_flora | client to server | reliable | chunk: Vector2i, id: int | 3 |
| flora_cut | server to client | reliable | chunk: Vector2i, id: int | 3 |
| report_position | client to server | unreliable_ordered | position: Vector3, velocity: Vector3 | 5 |
| step_water_rate | client to server | reliable | direction: int | 6 |
| water_rate | server to client | reliable | rate: float, busy: bool, spring_m3_s: float | 6 |
| water_changed | server to client | reliable | - | 6 |
| ground_reset | server to client | reliable | tiles_stamp: String, starter_stamp: String | 8 |
| request_water | client to server | reliable | chunks: PackedInt32Array | 6 |
| deliver_water | server to client | reliable | chunk: Vector2i, water: PackedByteArray | 6 |
| hello | client to server | reliable | player_key: String | 10 |
| inventory_action | client to server | reliable | kind: int, a: int, b: int, count: int, at: Vector3 | 10 |
| inventory_full | server to client | reliable | bytes: PackedByteArray | 10 |
| inventory_slots | server to client | reliable | bytes: PackedByteArray | 10 |
| world_items | server to client | reliable | added: Array, removed: PackedInt32Array | 10 |
| reject | server to client | reliable | reason: int (0 too far, 1 no tool, 2 pack full, 3 other) | 23 |
| craft_queue | server to client | reliable | entries: Array of [recipe number, crafts left], head first; left_ms: int (time left on the head craft) | 22 |
| strain | server to client | reliable | strain_pm: int, state: int, fade_pm: int, stance: int | 20 |
| breath | server to client | reliable | deciseconds: int (air left in tenths of a second under water; -1 = head above the surface, symbol hides). Sent when the air changes by half a second while diving, once on surfacing | 32 |
| vitals | server to client | reliable | hunger: int, health: int, weight_dkg: int | 18 |
| chest_contents | server to client | reliable | id: int, bytes: PackedByteArray | 15 |
| notice | server to client | reliable | text: String | 12 |

## Inventory action kinds (inventory_action(kind, a, b, count, at))

| Kind | Name | Meaning | Since |
|---|---|---|---|
| 0 | ACT_MOVE | a = from slot, b = to slot | 10 |
| 1 | ACT_DROP | a = slot, count = how many, at = where it lands | 10 |
| 2 | ACT_PICKUP | a = world item id | 10 |
| 3 | ACT_ADMIN_GIVE | a = item number, count (admin tool; tests only) | 10 |
| 4 | ACT_CRAFT | a = recipe number (data/items/recipes.json) | 10 |
| 5 | ACT_THROW | a = slot, at = aim direction (the server starts the throw from the player) | 10 |
| 6 | ACT_PLACE | a = slot of a placeable item, at = where (a campfire kit becomes a fire) | 10 |
| 7 | ACT_HIT | a = tree id, b = flora chunk x, count = flora chunk z: one axe blow on a standing tree | 12 |
| 8 | ACT_MINE | at = the point the axe struck; on bare rock the server gives stone | 10 |
| 9 | ACT_PROCESS | a = world item id of a felled trunk: one axe blow on it gives branches, leaves, bark, logs | 13 |
| 10 | ACT_SPLIT | a = slot, count = how many go to the first empty slot | 13 |
| 11 | ACT_FUEL | a = fire world id: burn one stick (or a log) in the fire | 13 |
| 12 | ACT_COOK | a = fire world id: roast one raw forage item at the fire | 13 |
| 13 | ACT_REPAIR | a = slot of a worn or broken tool: spend its repair materials, win back half its durability | 13 |
| 14 | ACT_CHEST_OPEN | a = chest world id: the server answers with chest_contents | 15 |
| 15 | ACT_CHEST_PUT | a = pack slot, b = chest world id, count = how many to put in | 15 |
| 16 | ACT_CHEST_TAKE | a = chest slot, b = chest world id, count = how many to take out | 15 |
| 17 | ACT_USE_STRUCT | a = structure world id: use it (a chopping block splits one log into firewood) | 16 |
| 18 | ACT_EAT | a = pack slot: eat the food or apply the medicine in it (data/items/vitals.json) | 18 |
| 19 | ACT_LIGHT | a = fire world id: light a loaded fire (uses tinder from the pack, see cooking.json) | 19 |
| 20 | ACT_STANCE | a = wanted stance: 0 stand, 1 crouch, 2 sit, 3 lie; the server answers in strain() | 21 |
| 21 | ACT_CRAFT_QUEUE | a = recipe number, count = how many (1 to 20); the server takes the ingredients now and crafts in order, screen open or not; max 10 entries per player | 22 |
| 22 | ACT_CRAFT_CANCEL | a = queue entry index as last sent; cancels it, the server hands back the ingredients of its unfinished crafts | 22 |
| 24 | ACT_DRINK | a = pack slot of a water container in hand, or -1 (before protocol 31 it had no argument): with a container that has room, E at the water fills it by thirst.fill_ml (500) per press; otherwise drinks one mouthful (thirst.drink_ml) from water within thirst.reach_m of the player's feet; refused with reject(0) when no water is near, paced by drink_pace_ms | 31 |
| 26 | ACT_SLEEP | a = 1 fall asleep, 0 wake. Needs the player lying (stance 3), not fainted, and no rain reaching them (open ground, rain over 0.2); otherwise ignored (a notice says why). Sleep ends on any stance change, a fall hit, rain on an open sleeper, or 10 s of zero exertion. The server tells everyone with strain(): bit 4 (+4) of the stance field = asleep | 29 |
| 25 | ACT_DIG | at = the ground point under the crosshair: one spade dig (0.9 m sphere, 0.25 m below the point); needs a whole spade (tool class spade) in the pack, point within 4.5 m of the player, one per 0.7 s; refused with reject(0 too far, 1 no spade). The server logs the hole (digs.dat) and answers everyone with dug() and tile_changed() | 28 |
| 27 | ACT_FILL | at = the ground point under the crosshair: one spade fill (0.9 m sphere, 0.1 m above the point, one shovelful of soil, sand, gravel, clay or stone from the pack, digging.json fill order); needs a spade, reach 4.5 m, one per 0.7 s (shared with digs); refused with reject(0 too far, 1 no spade), a notice when the pack has nothing to fill with. The server saves it in digs.dat (DIGS2 fill record), tells everyone with filled() and tile_changed(), the water thread raises its ground, shrubs and plants in the sphere are removed | 30 |
| 23 | ACT_FALL | a = drop in centimetres the client landed from (sent from 6 m up); the server turns it into health damage (vitals.json fall) and a faint from 12 m; limited to one per 2 s, drop capped at 60 m | 23 |

## World-item row states (world_items)

0 item, 1 lit fire, 2 out fire (retired in 19, old saves map to 8 or 9), 3 felled trunk, 4 stump, 5 lean-to, 6 chest, 7 chopping block, 8 empty laid fire (ashes), 9 loaded unlit fire.

## Save formats

Every server item file (inventories, world_items, tree_states, chests, vitals, craft_queues) is written atomically (.tmp then rename) and the file it replaces is first copied to `<name>.prev`. A file that does not parse is set aside as `.bad` and the `.prev` copy (one save interval old, 30 s) is restored in its place; a file from a newer version is set aside as `.bad` and not replaced by the old copy. Drilled by src/worldgen/tools/test_persistence_drills.gd.

digs.dat version 2 (DIGS2: seq, kind dig/fill, material, x y z radius, 24 bytes per edit; DIGS1 files are read and upgraded, the old one kept as digs.dat.v1; max radius 3 m, at most 200 edits per 16 m block, a dig inside an earlier dig is dropped), inventories.json version 2 (reads 1), world_items.json version 1, chests.json version 1, vitals.json version 1, tree_states.json. All are written atomically; an unusable file is kept as .bad.

## Notes by version

- 29: ACT_SLEEP (26) and the sleeping flag: the `stance` field of strain() is 0..3 plus 4 when asleep (old clients read 4..7 as a wrong stance, so client and server move together). data/items/sleep.json. No new save data: sleep is not kept over a restart (everyone wakes).
- 28: ACT_DIG (spade digging). Save file `digs.dat` (store folder): "DIGS1" then x, y, z, radius as four little-endian float32 per hole, appended in order; `load_block` cuts every logged hole out of the freshly made block, so holes survive a re-bake. Edits already in edits.sqlite are still read as the base of their block. Design: DIGGING_DESIGN.md.

- 27: boulders. World-item row state 10 (boulder): count = rough stones left, extra {radius, yaw, total}; an ACT_HIT whose b is HIT_BOULDER (-1000000) strikes the boulder with world id a (one blow from the best pick or axe on the hotbar: iron or steel 1 blow per stone, stone 3). Server-owned (server_items _lay_out_boulders, data/items/boulders.json); what is left of a worked boulder is saved in world_items.json "boulders" (same file version). Old clients would draw state 10 as a chopping block, hence the bump.
- 26: vitals() gains a seventh field, fitness (-10 to 10, 0 average): a character attribute stored in characters.json beside luck (older files read as 0), data/items/fitness.json. It multiplies the exertion rise rate by exp(-fitness x strength) on the server (strength 0.05: +10 is about 61 percent of the normal rise, -10 about 165 percent); recovery is untouched. server_items.set_fitness() is the hook for training, not designed yet.
- 24 (strain fade): the fade field of strain() is now the blackout level: 0 to 1 climbing while the player is over-exerted past the faint threshold (state 1), 1.0 from the faint start (state 2 sends 0.625 to 1 over the faint time), then falling 1 to 0 while waking (state 3); sent in steps of 0.02. strain_state, speeds and thresholds are unchanged. Client name: inventory_view.blackout_level(), which Sounds read for the heartbeat.
- 24: vitals() gains a fourth field, thirst (percent of a full body, 100 = full); ACT_DRINK. Thirst is server-owned (data/items/vitals.json "thirst": cap_ml 2400, rest_ml_day 1000, work_ml_day 1200 x exertion, so a full body lasts a whole game day even at full exertion); empty thirst stops health recovering. Saved as "wet" (ml) in vitals.json; older saves start full.
- 23: reject() (refused action: too far, no tool, pack full) for the client's refusal cue; ACT_FALL and server-side fall damage (data/items/vitals.json "fall": safe_m 6, per_m 8, faint_m 12; health never below 1).
- (no version) characters.json, version 1: {players: {key: {luck: -10..10, fitness: -10..10 (from 26)}}}, rolled once at first hello and never changed; server side only. Every server roll goes through server_items roll_chance / roll_amount / fate (src/shared/luck.gd, data/items/luck.json); tools/check_luck.py fails on a raw random call that skips it.
- 22: crafting queue: ACT_CRAFT_QUEUE, ACT_CRAFT_CANCEL, craft_queue(); saved server side in craft_queues.json (version 1, atomic, .bad fallback; the head's progress is kept; runs only while the player is connected).
- 21: ACT_STANCE; strain() gains the confirmed stance.
- 20: strain(strain_pm, state, fade_pm) for over-exertion and fainting.
- 19: ACT_LIGHT; fire states 8 and 9.
- 18: ACT_EAT; vitals(hunger, health, weight_dkg).
- 17: chopping block (ACT_USE_STRUCT, state 7).
- 16: storage chest (ACT_CHEST_*, chest_contents, state 6).
- 15: lean-to (state 5, ACT_PLACE carries yaw in count).
- 14: tool wear (9-byte slot updates, ACT_REPAIR).
- 34: death and remains (data/items/death.json). New server-to-client died(cause, spawn Vector3); the server has already moved the pack onto a remains record, reset the vitals and put the player at the spawn point, so the client only moves the body and fades. World-item row states 11 (fresh remains, owner only) and 12 (anyone may open), extra {yaw, age 0..1}; the remains open with ACT_CHEST_OPEN/ACT_CHEST_TAKE (ACT_CHEST_PUT is refused with reject 3). Save: world_items.json structure rows gain owner key, birth time (unix seconds) and a cave flag as columns 12 to 14 (older files read as none); the pack is a chests.json entry. vitals.json breath can_die is true, so drowning kills. Cost at Low: one record per death, a 30 s check, two boxes drawn per set of remains in view.
- 33: Energy (job 95, data/items/energy.json). New server-to-client energy(percent 0..100) at hello and whenever the whole percent changes (a separate RPC; vitals() is unchanged). Bits of the `stance` field of strain(): +4 asleep (protocol 29), +8 collapsed from exhaustion (cannot wake until rested; the client locks movement). The energy value is saved as "energy" in vitals.json (older saves start full); fitness training is saved as "train" in characters.json (older files read 0). Energy supplements (vitals.json energy_aids) are used with ACT_EAT.
- 32: breath(deciseconds): the oxygen symbol (data/items/vitals.json "breath"). The server reads the head under water from the position report (swim.gd head_under), runs the air down (60 s at swimming pace, x0.5 resting, x1.6 swimming hard), resets it at the surface, and drains health once it is out. Not saved.
- 31: water containers. ACT_DRINK takes a = the held container's pack slot or -1. A container (items.json `capacity_ml`, kind container) keeps its water in the slot's existing `wear` field in millilitres, so slot rows and inventories.json are unchanged (an old save reads 0 = empty). Use (ACT_EAT) on a container drinks a mouthful from it. Carried weight counts 1 kg per litre inside. data/items/vitals.json thirst.fill_ml.
- 30: ACT_FILL (27) and filled(): spade fills saved as DIGS2 fill records. Digs and fills also remove shrubs and plants standing in the sphere (flora_cut).
