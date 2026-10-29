# Digging under trees to fell them (Items job 65, design note, 2026-10-21)

Status: note only, for Technical direction's approval before any code. Rules already decided by Dave (DESIGN_IDEAS 7, lines 532 to 537): enough ground dug from under a tree makes it fall; a fallen tree lies as a trunk worked with tools (no instant drops); the server owns the decision.

## What is dug, with what, how fast
- Tool: the wooden spade (tool_class "spade", exists). No spade, no digging; a stone axe cannot dig. The spade wears one use per dig, like other tools.
- Action: a real dig request replaces today's test `dig(center, radius)` (any client, radius up to 8 m, no checks). New ACT_DIG (a, b, count = x, y, z in centimetres of the aim point, protocol bump; the old test RPC stays admin-only). The server checks: spade in the pack, reach 3.5 m from the player, a pace of one dig per 900 ms, radius fixed at 0.7 m per dig (a hole a person can scoop in about a second), not under water, not inside another player's placed structure.
- Time to fell: support is measured in the soil volume under the trunk (below), so a small tree needs about 6 to 8 digs (one minute), a large one 20 or more. Digging also gives soil/clay/stone items from the ground material when those exist (later; not required).

## What "enough" means (server rule)
- For each standing tree whose root point is within 6 m of the dig, count the share of a disc of radius `support_r = 0.5 * trunk + 0.4 m` (about 1.5 m for a big oak), 1 m deep under the trunk base, that is still solid. 100 % is untouched ground.
- The tree falls when support drops below `fall_below` per species and size: 45 % for conifers and shallow-rooted trees (wardpine, fir), 35 % for hardwoods, 25 % for the biggest. Data in data/items/drops.json "dig_fell" (one row per species class), so tuning is data.
- Saplings and young trees (under 12 game days) fall at once on any dig within 1 m (they are pulled out, no trunk, a seed bundle).
- Rocks resting on dug ground and other tall flora come later; the same rule shape applies (a `support_below` value per kind).

## What falls
- The existing felling code is reused: the block at the end of `_hit` (the stone axe's last blow) is first factored out as `_fell(chunk, tree_id, info, yaw)` (a pure refactor, tests unchanged) and both callers use it. It turns the standing tree into a trunk record (state 3) and a stump (state 4), logs `flora.cut(chunk, id)` into `flora_removed.json`, sends `flora_cut`, and the world-item rows. The fall direction is away from the deepest hole. The trunk needs the axe, as decided. Nothing new is stored per tree.
- Per-chunk caps for trunks (the existing "too many felled trunks" rule) apply: a dig that would exceed it does not fell the tree (the player is told, the hole is still dug).
- Trunk rot, sapling respawn and the lazy catch-up (job 66) work unchanged.

## What it does to saved ground and the block store
- Each dig is `store.dig_sphere` on the server block store: the edited blocks are written to the living layer and each touched tile's revision rises, so every client near it re-downloads that tile's changed blocks. Today's cost: one sphere of 0.7 m touches 1 to 4 blocks; a re-download is a few blocks, not the tile, as long as per-region revisions exist (DESIGN_IDEAS line 457 says they do not yet: "any edit raises its whole tile's revision"). **Risk:** a player digging for a minute makes about 8 revision bumps. Proposal: coalesce bumps to one per second per tile on the server; clients already debounce reloads.
- Dug ground is saved by the block store's own files (worlds/*/blocks), unchanged format. Esc > Advanced > "Clear saved ground" (the stale-block fix) also clears dug holes: say so in its label.
- The dig must not run on the main thread for long: `dig_sphere` takes the edit mutex and loads blocks; at 0.7 m radius it is a few ms. Cap: 2 digs per second per player, 40 per second server-wide, extras queued 1 s then dropped.
- Water: `water_live.dig` already receives dug spheres (the decided dams/trenches rule); a hole filling with water is expected and correct.

## Protocol and cost
- Protocol: ACT_DIG 24 in inventory_action (no new RPC); the existing `dug` RPC (center, radius) plays the dig for everyone; `flora_cut` and world-item rows carry the fall. Client: a short fall animation by Art (not in this job).
- Cost at Low: server: a dig is a few ms, support check reads the flora items within 6 m (tens); client: no per-frame work, only the block re-download that already exists for the test dig.
- Tests (headless, unit level with a stub store): spade required, reach and pace, support share maths per species class, fall happens at the threshold and not before, trunk cap respected, removal persists over a restart (flora_removed.json), no duplication of the trunk.

## Open points (recommendation in bold)
1. Digging in the first version only for trees and surface soil, not tunnels: **yes**, tunnels wait for the support/shoring design (DESIGN_IDEAS 1758).
2. Who may dig under trees on claimed land: **no claims exist yet; allow everywhere, revisit with ownership.**
3. Stable flora ids across generator changes (an open risk in DIRECTIVE_REVIEW): **needed before this ships; felling uses (chunk, id) like the axe does, so it shares the risk, no new exposure.**
