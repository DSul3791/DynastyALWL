# Tyler reply: Sonny tile lake guarantee (13d87426), 25 Oct 07:13 UTC
GO as written. One reply; no more asks.
- Overlap check: head 13d874260bf9909d803676d84ddb16233b7aede8 sits on merge-793 690ee171 and touches only src/worldgen/tile/drainage_channels.gd and new test_tile_lakes.gd (+ .gd.uid). Water-v9 e9a91504 and lake tags ebf9e829 are already in 690ee171, so no overlap with the water thread files.
- Label BAKE, so it merges but its ground effect shows only in the final bake (TERRAIN_VERSION 42 with erosion v2). No bake now (BAKE HOLD).
- Gate: David3 runs test_tile_lakes plus the baseline (six known failures, no new). Mike's gate takes it with the other merge-793 heads. Queue after river-ore-guarantee, before erosion v2 rebase.
- Zero new Godot warnings (baseline 233); commit test_tile_lakes.gd.uid.
- Send numbers (tiles with a lake, lakes per tile, total lake ha) from the test run so the final bake can be checked against them.
