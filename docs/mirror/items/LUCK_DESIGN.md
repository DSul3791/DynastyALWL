# Luck trait (job 77): design note

Dave: luck applies to ALL rolls (chance, loot, fate). Fixed at character creation like innate skills. Small, tunable effect.

## Storage
- New save file `characters.json` in the items store: `{"version": 1, "players": {player key: {"luck": int}}}`. Written with `_write_atomic` (keeps `.prev`), read with `_read_json_version`, so it joins the six existing files in the persistence drills (seven files). A missing record for a known player key gets a luck rolled once on first sight and saved (so existing characters get one, never changed after).
- Luck is an integer from -10 to +10 (0 neutral, most players near 0: sum of three dice, centred). The creation screen, when it exists, sends a chosen or rerolled value once; until then the server rolls it at first hello. Once stored it is read-only: no action changes it (an admin action can, for testing).
- Version: records are new, so no migration. `characters.json` is not part of the wire protocol.

## The one function (src/shared/luck.gd, used by server_items.gd)
- `Luck.bias(luck, strength)` -> a unit shift. Tunable in data/items/luck.json: `strength` (default 0.03 per point, so +10 luck nudges a 50% chance to about 65% and a loot amount up about 15%), `cap`.
- `chance(peer, p)` -> bool: true with probability p nudged by luck (p*(1-p) shaped so 0 and 1 stay 0 and 1).
- `amount(peer, lo, hi)` -> int: a roll in lo..hi with the top end more likely when lucky, the bottom end when unlucky.
- `pick(peer, options)` -> index: weighted pick with luck tilting toward the rarer entries.
- `fate(peer, kind, p)` -> bool: the hook for later fate events (falls, combat, rare world events); it calls chance(), and records `kind` in a counter so we can see what luck touched.
- Unset player or no luck record: neutral (same result as plain random).

## Rolls to route through it (server_items.gd today)
Gather yield and natural pick (lines near 492-536), trunk working: logs, bark, seed, roots (about 1412-1440), tree respawn (about 1460), tool wear later. World layout rolls (scatter, bank stones) stay plain: they are about the world, not a player's chance, and are seeded for repeatability.

## Check that flags raw random calls
`tools/check_luck.py`: fails on any `randf`, `randi`, `randf_range`, `randi_range`, `RandomNumberGenerator.new` in server code (src/stream, scenes/terrain_server) that is not in src/shared/luck.gd and not marked `# luck-exempt: <reason>` on the same line (the seeded world layout lines get that mark). Wired into tools/items_check.py.

## Protocol cost
None now. Later, the character creation screen needs one field (luck choice or reroll) in the hello or a creation message; I'll add it with that screen's protocol bump.
