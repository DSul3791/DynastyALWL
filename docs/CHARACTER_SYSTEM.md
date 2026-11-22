# Character records: create, save, load and delete

**Dated implementation reference:** Steve's static read of main, 2 Nov 2026; nothing run. Search function names. Later location design: [Resume spot](design/RESUME_SPOT.md); save compatibility: [Catalog/save policy](design/CATALOG_SAVE_MIGRATION.md).

## Two halves
- **Client, local files** (`src/client/character/`): `character_store.gd` keeps one file per character in `user://characters/` (name, body code, body model, frame; the character has no gender) and the active id in `active.txt`. `character_select.gd` (scenes/character_select) lists, creates, renames, deletes and picks. Appearance: [Dynasty body](DYNASTY_BODY.md). Owners belong in current task state.
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
`_load_characters` copies fields one by one with clamps and defaults. Recorded pattern: default in the new-record builder, loader entry, saver entry; check current callers before changing fields. A corrupt record is skipped and the others load (`test_corrupt_character`). Old files load (`test_save_compat`).

## Delete
1. Client removes the local file (`CharacterStore.delete`) and queues the character's key in `forget`.
2. At the next join the client sends `forget_character(key)`.
3. Server `forget_key` erases inventory, character, vitals and craft queue for that key, but only if no connected peer is using it.
**Gap reported 2 Nov, current status unverified:** a forget that never reaches the server (quit before joining) is dropped, leaving its server record. The author called it harmless then; revisit with accounts.

## Future ideas retained from the snapshot
Listed as not built on 2 Nov: real death with heirs and children, new-character start options, accounts. See [game ideas](../DESIGN_IDEAS.md) and the historical [scope record, section 11](https://github.com/DSul3791/DynastyALWL/blob/286af10bc9abc5c82c768f3617565f6e6ee356b8/docs/handoff/SCOPE_STEVE.md).

## Body models instead of gender (Dave 17 Nov 2026)
Dave: "remove the gender selection in the character creation and remove gender from character. we will simply provide various model meshes people can choose from." The creator's About you section has Name, Body and Frame; gender and pronouns are gone from the record (format version 3), the store, the select page and the inner voice. `src/client/character/body_models.gd` lists the models; adding a row adds a choice.

### For Dave (assumed on his behalf, provisional)
- BM-1: the models are named plainly, "Body 1", "Body 2" and so on. Body 1 is Dynasty_Base_Male.glb; Body 2 is Dave's female player character, Playercharacter_Female_01.glb (Dave 20 Nov 2026: "add this female character to our character creation choices [...] she should be the female selection now and be fully adjustable"). Her label stays plain under this rule; a one-line change in body_models.gd renames it.
- BM-2: pronouns went with gender. Nothing in the game used them.
- BM-3: the three frames keep their saved keys but are shown as Curved, Broad and Even instead of Feminine, Masculine and Neutral. A new character starts Even.
- BM-4: the inner voice timbre follows the body model (`body_families` in data/items/inner_voice_sets.json; Body 1 speaks with the deeper voices, Body 2 with the lighter ones). A model not listed there takes either timbre by character id.
- BM-5: an old character file still loads: its gender and pronouns are dropped and it wears Body 1. Nothing touches live saves.
- Each character wears its own model (dynasty_body.gd `_init(model_id)`; my_character.gd `body_model`); NPCs wear Body 1. Shortcut: every model's first-person arms are Body 1's parts file (there is no parts file for Body 2 yet).
