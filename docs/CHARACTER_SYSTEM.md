# Character system: create, save, load, delete (Steve, 2 Nov 2026)

Paper map from reading the code on main. Nothing was run. Line numbers are left out on purpose; search the function names.

## Two halves
- **Client, local files** (`src/client/character/`): `character_store.gd` keeps one file per character in `user://characters/` (name, body code, gender, pronouns, frame) and the active id in `active.txt`. `character_select.gd` (scenes/character_select) lists, creates, renames, deletes and picks. Looks and body belong to Kathleen and Kathreen.
- **Server, per key** (`src/stream/server_items.gd`): everything that matters in play (pack, vitals, learned recipes, goals, hints, Rested, spawn bed, coins, skills) is stored under a **player key**, in `characters.json`, `inventories.json`, vitals and craft-queue files.

## How the two meet: the key
- `character_keys.gd` (protocol 82) maps character id to its own key in `user://character_keys.json`. `inventory_view._player_key()` sends it in `hello`.
- The first character to play after the update adopts the old machine key (`user://player_key.txt`), so nobody loses progress. Every later character gets a fresh key. No active character (headless, rigs) sends the machine key.
- Result: two characters on one computer no longer share a server record. Test: `test_character_keys`.

## Create
Select screen calls `CharacterStore.add`. No server record exists yet. The record is created on first `hello` with that key (`peer_connected_hello`, `_become_new_player`, new_player flag, first-hour grace_s).

## Save
`_save_characters` queues a write (set `_dirty`, then `items.save()` in tests). Fields: luck, fitness, train, strength, memory, dexterity, perception, charisma, worn, shelter, skills, coins, rep, new_player, tried, learned, rested, spawn_bed, goals_done, goal_counts, hints_seen, grace_s, last spot.

## Load
`_load_characters` copies fields one by one with clamps and defaults. **A new field needs three edits**: default in the new-record builder, a line in the loader, a line in the saver. A corrupt record is skipped and the others load (`test_corrupt_character`). Old files load (`test_save_compat`).

## Delete
1. Client removes the local file (`CharacterStore.delete`) and queues the character's key in `forget`.
2. At the next join the client sends `forget_character(key)`.
3. Server `forget_key` erases inventory, character, vitals and craft queue for that key, but only if no connected peer is using it.
Known gap: a forget that never reaches the server (quit before joining) is dropped, so the record stays on the server. Harmless for now; revisit with accounts.

## Not built
Real death with heirs and children, new-character start options, accounts. See SCOPE_STEVE.md section 11.
