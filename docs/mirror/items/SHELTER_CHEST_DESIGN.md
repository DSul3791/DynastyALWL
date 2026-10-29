# Lean-to shelter and storage chest: design note (Items and crafting, 2026-10-20)

For Technical direction approval before code. Dave chose these as the first buildables.

## Items and recipes (hand crafts, data only)
- `lean_to_kit` (placeable): 8 sticks + 6 leaves + 2 twine. (Hide is left out until creatures drop it; leaves are the roof.)
- `chest_kit` (placeable): 4 logs + 2 twine.
- Both are kits like the campfire kit: held in the hotbar, a blueprint ring shows where it goes, left click places it.

## Placement
- Reuses `ACT_PLACE`: `a` = hotbar slot, `count` = yaw in degrees (0 to 359; the fire ignores it), `at` = ground point. Server checks as for fires: reach 6 m, ground below, no overlap within 2.5 m of another structure or fire.
- Blueprint colours: green when valid; the lean-to shows its roof footprint. A lean-to is allowed anywhere (it is the cover, so no cover rule). Chest anywhere.
- Per 256 m chunk caps: 6 lean-tos, 8 chests (a notice when full), like the fire cap.
- Pickup: a lean-to or an empty chest can be taken down with E and returns its kit. A chest with contents cannot.

## Data and save format
- Structures are world-item records with a `struct` dict: `{kind: "lean_to"|"chest", yaw}` and states 5 (lean-to) and 6 (chest) in the existing `world_items` rows, `extra` = `{yaw}`. They never despawn (no lifetime) and are saved in world_items.json with the other records.
- Chest contents are 24 slots of the same {number, count} form, in a new save file `chests.json` (versioned, atomic write, `.bad` fallback), keyed by structure id. world_items.json VERSION stays 1 (unknown keys ignored); chests.json is new at version 1.
- Lean-tos do not rot yet (rot belongs to the later decay design).

## Protocol (needs your approval: PROTOCOL_VERSION bump to 15 or the next free)
- New states 5 and 6 in `world_items` rows (old clients would not draw them, hence the bump).
- New `ACT_CHEST_OPEN` (a = structure id), `ACT_CHEST_PUT` (a = player slot, b = structure id, count), `ACT_CHEST_TAKE` (a = chest slot, b = structure id, count) inside `inventory_action`.
- One new RPC `chest_contents(id, bytes)` server to client: the full 24 slots, sent on open and after every put/take. The server does not track "who has it open"; every action re-checks that the player is within 4 m.

## Cover roof (needs Water, who owns cover.gd)
- Each lean-to is one roof circle: centre = placed point shifted 0.6 m along its facing, radius 1.9 m, top = ground + 2.1 m. Same row form as a tree crown: `[id, x, z, radius, top_y]`.
- Proposed API, tiny: `Index.set_roof_chunk(chunk, rows)` and `Index.remove_roof_chunk(chunk)`, which store the rows in the same hash grid under a disjoint chunk key (the chunk plus a fixed offset), so `Cover.at` and `discs_near` see roofs with no other change. I would call it from server_items (on place, pickup, load) for the server index, and from inventory_view (when a lean-to row arrives or leaves, within the 160 m item range) for the client index. Rebuilt per 256 m chunk, rare.
- Effects: fires under a lean-to survive rain (already by Cover.at), the campfire blueprint turns green under it, rain sounds and wetness treat it as canopy.

## Cost at Low
- No per-frame cost: no lights, no shadows, no scripts per instance. Draw: lean-to about 40 triangles (two poles, a slanted roof panel, a back panel), chest about 24 triangles; one shared material each; only structures within 160 m exist on the client. Server: records in the existing item dict, no tick work (they are skipped by the fire and rot loops).
- Memory: a chest is 24 slots x 6 bytes, 144 bytes on the wire.

## Not in this job
Locks and ownership (anyone can open a chest for now; decide with the households design), theft, decay of leaves, storage chests shared by a household.
