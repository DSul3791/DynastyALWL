# Goblin stealing and the den pile (design)

Steve, 8 Nov 2026. This builds Dave's decisions 8, 9, 10 and 13 (8 Nov 2026, "I agree to all recommendations"; `docs/GOBLINS.md` "Decisions, 8 Nov 2026"). It stands on goblin den life (`goblin_den_life_design.md`, #597): the cave path, night tasks, and walking in and out. **Runtime only, no rebake, no protocol change.** Friendship (decision 7) comes after it.

## 1. What Dave decided

| # | rule |
|---|---|
| 8 | One small item at a time, only from what no fire, torch or lamp lights |
| 9 | Stolen things go into a pile in the band's den, where a player can find them and take them back |
| 10 | A killed goblin drops what it is carrying |
| 13 | No new group while a lit building or a player camp with a fire sits within 100 m of the cave mouth |

## 2. Today

- **The fox already steals** (`server_thieves.gd`): it smells loose food on the ground, creeps up (SNEAK, state 13), takes the whole stack (`server_items.take_loose`), and runs off with it (CARRY, 14).
  - A player near the food or the fox, or a fire at the food, makes it give up.
  - A fox hurt while carrying drops the food (`damage()`, the `loot` key).
- **Goblins** do not steal. `lair_guarded` exists in `server_animals.gd`, but nothing answers it.

## 3. How it works

### 3.1 What a goblin may take

- **A loose item lying on the ground:** a world item that is not a structure, fire, tree, boulder, natural scatter, carcass or showroom piece.
- **Small:** not a shoulder carry (`carry` in items.json: logs and the like), and not of kind `structure`, `placeable` or `container`. One piece of the stack is taken; the rest stays (`server_items.take_one`, new).
- **Unlit:** the item is outside every fire's and torch's keep-off radius (the animals' `_fire_cache`, the same light goblins never enter), both when it picks the item and when it takes it. A lamp joins that list when lamps exist.
- **Not from a den pile:** goblins skip any item within `den.den_m` (12 m, height included) of a goblin den. The rule is by place, not by a mark on the item, because world items are saved as fixed rows and a mark would not survive a restart.
- **Never from a pack, a chest or a player.** Chests are a later step, if Dave wants them; Dave's words are "anything they can that is not protected by light", and a closed chest is not loose.

### 3.2 When and how

- **When:** at night, as a third night task beside watching and foraging (`steal_share` of the time, picked first). It looks for an item within `steal_reach_m` (150 m) of its mouth.
- **Creeping:** it creeps there (SNEAK, 13, the fox's state and pose) at `sneak_mps`.
- **Giving up:** it gives up when a player comes within `steal_scare_m` (8 m) of it or of the item, when a fire's light reaches the item, or when the item is gone. Goblins are bolder than the fox (18 m), because they creep to the edge of camps.
- **Taking:** it takes one piece and runs home with it (CARRY, 14) to the cave mouth. Then it walks in along the cave path to the den, and puts the piece on the **den pile**.
  - Where the den pile lies: `server_items.drop_in_world` at the den floor, with a lifetime of `hoard_life_s` (7 days of server time), so it is still there when a player finds it. The lifetime is saved with the item.
  - Same kinds merge into one pile, as every drop does, so the pile is a few heaps, not hundreds of items.
- **Afterwards:** after a theft, that goblin waits `steal_again_s` before it steals again.

### 3.3 Dropping it

- **A goblin killed while carrying** drops the piece where it falls. This is the fox's `loot` rule, now also on death by bleeding (`bleed()` did not drop loot).
- **A carrying goblin that is dropped** because no player is near is taken to have got home: the piece goes on its den pile.

### 3.4 Respawn (decision 13)

- `lair_guarded(x, z)` is answered by the server: true while a **burning placed fire** sits within `guard_m` (100 m) of the mouth.
  - A campfire, a hearth or a forge counts.
  - A torch bearer passing by does not, since that is not a camp.
- A lit building is a building with a lit hearth or lamp inside. Its hearth is a placed fire, so it is already covered.

## 4. Data (`animals.json` goblin)

The new keys go in the `den_life` block:

`"steal_share": 0.4, "steal_reach_m": 150, "steal_scare_m": 8, "sneak_mps": 1.0, "carry_mps": 4.5, "steal_again_s": 120, "hoard_life_s": 604800`

The new key in `lair`:

`"guard_m": 100`

## 5. Systems touched

| file | change |
|---|---|
| `server_items.gd` | `stealable_near(centre, r)`, `take_one(id)`, `lit_fire_near(point, r)` for the guard; the pile is an ordinary `drop_in_world` with a long lifetime |
| `terrain_server.gd` | wires `animals.goblins.stealable`, `take_one`, `hoard_drop` and `animals.lair_guarded` (now `(x, z, radius)`) |
| `server_goblins.gd` | the steal task (pick, SNEAK, CARRY, home, pile) |
| `server_animals.gd` | loot drop in `bleed()`; a carrying goblin dropped at despawn piles its loot |
| `animals.json` | the keys above |

## 6. How we know it works (headless on the PC, then Dino)

- **Headless test (`test_goblin_stealing.gd`):**
  - a goblin at night picks an unlit loose item and never a lit one, a log, or an item in a den pile;
  - it takes one piece and leaves the rest;
  - it gives up when a player comes within 8 m;
  - it carries the piece home, and the piece ends up in a pile at the den floor;
  - killed on the way, it drops the piece;
  - a lit campfire 90 m from the mouth blocks a respawn, while one 110 m away and a torch bearer do not.
- **On the PC:** a night run where a stack of sticks left 20 m outside the camp's light loses a stick, and then a picture of the den pile.

## 7. Must not break

- Goblins never enter light.
- The fox keeps its own rules (its `thief` block). Goblins don't use `server_thieves.gd`'s smell search, only the same state numbers.
- Items in packs and chests are never taken.
- Old saves load as before: nothing new is saved.
