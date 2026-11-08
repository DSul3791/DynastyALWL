# Wild wolf packs and the orphan pup (design)

Steve, 8 Nov 2026. This puts Dave's decisions 3 and 4 into practice:
- **4:** wild wolf packs are on, once the pack and pup work is built and checked on the PC;
- **3:** a player may raise a wolf pup, but only an orphan, fed over several game days.

It builds on `wolf_pup_taming_design.md` (#586) and reuses the dog companion system (`dog_companion_design.md`, step 1 in #613). **Runtime only, no rebake, no protocol change.**

## 1. Today [Existing]

- `server_wolves.gd` runs packs of 3 to 5. They prowl, stalk, rush, wait and feed, keep out of fire and torch light, and steal meat.
- **Natural packs** (`wolves.natural`, false today):
  - one home per 2 km cell, placed by a hash of the cell, so the same spot every time;
  - made when a player is within `active_radius_m` of it;
  - gone again with distance, like every animal;
  - a killed pack's cell rests for `respawn_s` (7200 real seconds).
- The cell state is not saved, so a restart forgets killed packs. `exclude` is a fixed `[x, z, r]` and is set to nothing today. `max_wolves` (15) counts every wolf.
- **There are no pups.** A young animal is already drawn smaller when it is sent as its species number + 100 (`YOUNG_NUM`).

## 2. Research

- **Pups:** a pack usually has one litter of 5 to 6 pups a year, born in late spring. Their eyes open at 12 to 14 days. The mother stays with them most of the time for the first 3 to 4 weeks, and after that the pups are often left alone at the den. Pups run back into the den when startled. By about 3 months they follow the adults, and they travel with the pack by winter. Wolves defend a den hard; the author watched a pack drive off a grizzly. Source: [International Wolf Center, "Wolf Den 101"](https://wolf.org/wp-content/uploads/2016/06/wolfden101.pdf).
- **Where dens are:** in Poland's Białowieża Forest, wolves put dens and rendezvous sites farther from villages, forest edges and busy roads than chance would. Resting sites showed no such avoidance. Source: [Canadian Journal of Zoology, 2003, "Selection of den, rendezvous, and resting sites by wolves in the Bialowieza Forest"](https://openpolar.no/Record/crcansciencepubl:10.1139%2Fz02-190).

What the game takes from this:
- dens are well away from the town;
- pups are at the den from late spring until about 3 months old;
- pups are often alone and hide when startled;
- the pack defends the den harder than anywhere else.

## 3. Wild packs on (decision 4)

1. **Town keep-out:** no pack home within `wolves.town_keep_m` (1200 m) of the town point (`starter`, the island level's centre). This replaces the fixed `exclude`. It covers the level 1 to 5 ring (`island_level.town_m`, 800 m) plus room for a pack prowling from its den. Wolves can still be met near town; they just don't live there.
2. **Same den every time:** a pack's den is its cell's hashed home, as today. A player who finds a den finds it again.
3. **The cap counts pack wolves only** (`a.has("pack")`). Pups and companion wolves don't count toward `max_wolves`.
4. **Saved dens:** a new `wolf_dens.json` keeps each cell's killed time and its orphans, in game seconds, so a restart no longer brings a killed pack straight back.
5. **The switch:** the code PR keeps `natural: false`. After Dino's PC check (a pack prowling and stalking, a torch keeping it off, a den with pups, 0 shader errors), a one-line data PR turns it on.

## 4. Pups at the den

- **Season:** pups are at the den from game day `pups.days[0]` (60, late spring) to `pups.days[1]` (150, about 3 months later). Outside that window a pack has none: its pups have grown into the pack. A new world starts on day 100, so the first player meets pups.
- **How many:** `pups.count` [2, 5]. That is fewer than the research's 5 to 6, to keep within the animal cap. Pups are made with the pack, at its den, as wolf records sent as young (number + 100), with `pups.hp_x` (0.25) of a wolf's health. They are not pack members (no `pack` key), so the pack brain doesn't move them.
- **What they do:** they stay within `pups.play_m` (8 m) of the den. By day they play (state 9, the existing wolf play) and rest. A player within `pups.hide_m` (25 m) who is standing or moving makes them run into the den (HIDDEN 5: not sent, not hunted). They come out again once that player has backed off or is crouched and still.
- **The pack guards them** (decision text: "a pack that sees a player near its pups rushes at once, torch or not"):
  1. A player within `pups.guard_m` (40 m) of the den, while the pack is alive: the pack comes home at a run (a new `den_guard` phase) and growls (a "growl" event and the threat call).
  2. **The warning:** for `pups.warn_s` (3 s) it circles between the player and the pups. A player who backs out past `guard_m` ends it; the pack goes back to prowling.
  3. **The rush:** a player still within `pups.rush_m` (25 m) after the warning is rushed, **torch or not**.
     - A placed campfire still holds the pack; only the torch rule is lifted at the den.
     - Two players together still make it back off, as today.
     - The warning comes first so the rush is never a surprise, the same fairness as the bear ladder (#600).

## 5. Orphans (decision 3)

- **Only a killed pack leaves orphans.** When the last adult of a pack with pups dies, its cell gets an orphan record `{den, pups, since_s, trust: {character key: {trust, day}}}` in `wolf_dens.json`. A pack driven off just comes back, so its pups are never orphans.
- **No new pack while orphans live:** the cell gets no new pack until the orphans are taken or `orphan_days` (5 game days) have passed. After that, untamed orphans are gone; they did not make it alone. Then the usual `respawn_s` applies.
- **Live pups are made from the record** when a player comes near, the same way companions are (#613). Orphans hide from a standing or moving player within `hide_m`, and stay out for a crouched, still one.
- **Feeding:** this reuses the dog's feeding code with the wolf's numbers.
  - The orphan eats food that player dropped within `smell_m` (10 m) of the den, once the player is `trust_gap_m` (8 m) from it.
  - Each meal is +1 trust, once a game day per player.
  - At `trust_to_follow` (3), one pup follows that player and becomes their companion: a record in `companions.json` with `"young": true` and `grow_until_s`, a name, and bond 0.1.
  - The other orphans stay for other players. One wolf per player.
- **Growing up:** a companion pup is drawn young (number + 100) with a quarter of an adult's health until `grow_days` (20 game days) have passed. Then it is an adult wolf: full size and health.
- **What a companion wolf does in step 1:** the dog's step-1 abilities, with the wolf's character:
  - it follows at `follow_m` (5 m), and runs to catch up;
  - it warns (state 10, the threat call; `creature_sounds` already has `wolf_growl`) from bond 0.3;
  - unlike the dog, **it keeps out of its owner's torch light too** (`keep_off_torch`). By night, with a torch lit, it walks at the edge of the light, about 9.5 m off. A wolf is wary, not a dog.
- **It is never a wild wolf:**
  - packs never take it in;
  - packs never hunt it (wolf prey is deer and moose only);
  - a dog does not bark at a companion animal, and a companion wolf does not growl at one.
- Stay, come, hunting and guarding are step 2 and later, as in `wolf_pup_taming_design.md` section 3.

## 6. Data (`animals.json`)

```json
"wolves": {"town_keep_m": 1200,
  "pups": {"days": [60, 150], "count": [2, 5], "hp_x": 0.25, "play_m": 8, "hide_m": 25, "guard_m": 40, "warn_s": 3.0, "rush_m": 25},
  "orphan_days": 5}
"wolf": {"companion": {"source": "orphan", "food": ["raw_meat", "roast_meat", "trout", "salmon"], "smell_m": 10, "trust_gap_m": 8,
  "trust_to_follow": 3, "bond_start": 0.1, "bond_per_day": 0.05, "bond_hungry": 0.05, "bond_near_s": 600, "follow_m": 5, "warn_bond": 0.3,
  "warn_m": 40, "warn_kinds": ["bear", "black_bear", "wolf", "goblin"], "grow_days": 20, "keep_off_torch": true, "inherit_bond_share": 0.7,
  "names": ["Ash", "Grey", "Storm", "Fang", "Shadow", "Wren", "Thorn", "Echo"]}}
```

The `tame` row sketched in `wolf_pup_taming_design.md` section 4 becomes this `companion` block, the same shape as the dog's.

## 7. Systems touched (code, stacked on #613)

| file | change |
|---|---|
| `server_wolves.gd` | town keep-out; a cap on pack wolves only; pups made with a pack in season; the pup step (play, hide); the `den_guard` phase (come home, warn, then rush with the torch rule lifted); orphaning on the last death; `wolf_dens.json` |
| `server_companions.gd` | an `orphan` source next to `stray` (made at the den from the orphan record, the same feeding); young companions and growing up; `keep_off_torch`; no barking or growling at companion animals |
| `server_animals.gd` | the pup hook in `_step`; pups are never snared while the pack lives |
| `terrain_server.gd` | load and save `wolf_dens.json` |
| `animals.json` | the keys above |
| `test_wolf_pups.gd` (new) | below |

The client needs nothing new: young drawing, play (9) and the threat call (10) all exist. MikeW may want a pup model later (see `wolf_pup_taming_design.md` section 9); until then the scaled wolf stands in.

## 8. How we know it works

- **Headless test (`test_wolf_pups.gd`):**
  - no natural pack within 1200 m of the town point;
  - a pack made on day 100 has 2 to 5 pups at its den, and one made on day 200 has none;
  - pups hide from a standing player 20 m off, and stay out for a crouched, still one;
  - a player 35 m from the den gets the growl and the circling, and backing off ends it;
  - a player 20 m from the den after the warning is rushed even with a torch, but not beside a campfire;
  - killing the pack's last adult orphans the pups, and the cell stays empty;
  - 3 game days of meals make an orphan follow as a young companion, and it grows up after 20 game days;
  - a companion wolf keeps outside its owner's torch light;
  - the dens file survives a save and a load.
- `test_wolves` and `test_dog_companion` still pass, with `natural` still false.
- **On the PC (Dino):**
  - with `natural` on in a local edit, a pack at its den with pups, and the den warning;
  - 0 shader errors;
  - then the switch PR.

## 9. Must not break

- `natural: false` until the switch PR.
- Wild wolves' fire and torch keep-off everywhere except the torch at their own den.
- Meat stealing and the two-player retreat.
- The dog companion (#613).

## 10. For the coordinator (my recommendations)

1. Untamed orphans are gone after 5 game days. **Recommend yes:** it keeps the cell from staying empty for ever, and it is honest about pups alone.
2. A companion wolf keeps out of its owner's torch light. **Recommend yes:** the wolf rule, and what makes a wolf feel different from a dog.
3. Only a killed pack leaves orphans, never a driven-off one. **Recommend yes:** it is simple and can't be gamed by leading a pack away.
