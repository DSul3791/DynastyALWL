# Interaction cards: the data schema for today's creatures (design)

Steve, 7 Nov 2026, for G-17 (`docs/design/GUIDING_DOCUMENT.md` section 7, #544). D-01 puts G-16 and G-17 in force for docs and data, so this design covers the data schema. Nothing here changes behaviour.

The scope is the creatures that exist today: bear, wolf, boar, deer, frog and goblin, plus horse and donkey as the only tamable ones. The batch 3 farm animals (cow, goat, chicken, cat, dog, buffalo) have models but no row in `animals.json` yet, so they get stub cards.

## 1. Schema: `data/animals/cards.json`, one card per species id

```
"bear": {
  "niche":    {"habitat": [keys, G-03], "active": "from animals.json", "diet": "omnivore", "chain": "apex"},
  "sign":     "from animal_sign.json",            // a reference, never a copy
  "senses":   "from animals.json senses",         // a reference
  "temperament": "from animals.json temperament", // a reference
  "warning":  [{"cue": "huff", "kind": "sound", "built": false}, {"cue": "turns to face", "kind": "pose", "built": true, "code": "big_game WARN"}],
  "verbs":    {"avoid": {"how": "...", "built": true, "code": "..."}, "hunt": {...}, "study": {...}},
  "reward":   ["meat", "hide", "knowledge"],
  "counterplay": ["stay out of the den ring (den.threat_m 15 m); fire does not help at the den"],
  "level":    "from the spawner (levels 1-20, #485)", "tier": "spear",
  "seasons":  "from animals.json seasons and young",
  "systems":  ["server_animals", "server_big_game", "animal_sign"]
}
```

**Rule: a card never duplicates a number.** A field that `animals.json`, `animal_sign.json` or the spawner already holds is a reference, which the matrix script resolves. A card adds only what has no home today: diet and food-chain place, warning cues, verbs (each with `built` and the code that answers it), reward and counterplay. So the card and the behaviour cannot disagree.

**Loading, with no rebake.** Animals are runtime only: they are not baked or saved. `server_animals.gd` reads `cards.json` next to `animals.json` at setup, as an optional file, and nothing reads it in play yet. The first readers are `tools/interaction_map.py`, which generates `docs/design/INTERACTION_MAP.md` (G-17, section 7.2), and the journal (#547), whose higher rungs reveal the card's fields. A missing card or field means "not described". It is never an error.

## 2. Today's creatures: what already answers a verb, and the gaps

| creature | built today (code or data that answers it) | gaps |
|---|---|---|
| **Bear** | **Avoid**: den threat ring 15 m, charge 25 m at 12 m/s (`defend`), a torch does not protect at the den; spring threat x1.5. **Hunt**: health 120, carcass row. **Discover**: 3 sign kinds (tracks, scratch, droppings) | **Warning**: only a 1.5 s turn-to-face (`WARN`). The huff, jaw-pop and standing pose of card 7.1 are not built (bear poses are on Dave's later list). **Study**: needs the journal (#547) |
| **Wolf** | **Avoid**: pack brain (`server_wolves.gd`); it keeps out of fire light (10 m) and torch light (9 m); it circles and stalks; two players or a wolf killed breaks the pack. **Hunt**: health 30, carcass row. **Discover**: tracks, droppings, howl. Growl and howl events | **Tame (pup)**: wolves have no `young` row and no `tame` row. Wild packs are off (`natural: false`, admin spawn only) |
| **Boar** | **Avoid**: defensive 0.7 / aggressive 0.3, fights when cornered (`defend` reuses the moose block). Herds of 3 to 6 with young, active at dusk and night. **Discover**: rooting, tracks, wallow | **Hunt**: no carcass row in `carcass.json`, so a boar kill has no body yet. **Warning**: no cue beyond `WARN` |
| **Deer** | **Hunt**: health 20 (three spear jabs), blood trail, bleeding out, carcass. **Discover**: tracks, droppings, rubbing. **Warning**: freezes and watches (alert 50 m) before it bolts, which is card 7.1's "head up". A stag strikes inside `threat_m` | The "stamp" and the dusk call are not built (no deer call sound) |
| **Frog** | **Discover**: croak; lives within 30 m of fresh water (now from the baked distance, #545). Active at dusk and night | **Sign**: only one kind; guiding doc 9.3 asks for at least two. **Hunt/Harvest**: no carcass and no drop |
| **Goblin** | **Avoid**: lair groups of 2 to 5 at cave mouths, night only, never with a bear within 120 m, respawn after 30 min; they keep out of light, fight when cornered (`defend`, 8 damage). Dens in dry cave branches (#543) | **Sign**: no `animal_sign.json` row (card 7.1 lists footprints at the fire's edge and glinting eyes). **Warning**: no whistle (`goblin_step` borrows the wolf's). **Study**: needs the journal. **Ally**: see section 3 |
| **Horse, donkey** | **Tame (start)**: a tamable value per animal from 0 to 1 sets its spook distance; a curious one walks up to a calm player. **Avoid**: kicks inside `threat_m`. Carcass rows | **Tame (bond)**: no bond, owner or record. That waits for G-09 and the companion record (#547 section 5). No mount |
| **Cow, goat, chicken, cat, dog, buffalo** | models only (batch 3) | everything: no species row yet. Their cards are stubs listing the intended verbs (Tame, Harvest) for MikeW's integration |

## 3. Where section 7 does not match the game today (for the coordinator)

1. **The wolf torch distance.** Card 7.1 says "Torch 8 m" and project memory says wolf protection is 8 m (Sal's number, for Dave to tune). The data has `wolves.torch_light_m` 9.0. One of them should change. I recommend the card cites the data rather than repeating a number.
2. **Goblins and Ally.** Card 7.1 gives goblins **Ally**. Dave's `docs/GOBLINS.md` describes skittish night thieves that fight when cornered, with nothing allied. Ally should be marked a Proposal until Dave says so.
3. **Wolf: Tame (pup).** There are no wolf young in the game, so this verb has nothing under it yet.
4. **Bear warning.** Card 7.1's huff, jaw-pop and standing are not in the game. Only a turn-to-face is. The card should mark them `built: false`, not describe them as current.

## 4. Dependencies

1. **G-03 habitat keys** (D-02, optional schema), for `niche.habitat`. Until then the card cites `biomes` and `habitat`.
2. **`tools/interaction_map.py`**, which resolves references and writes `INTERACTION_MAP.md` (Jamie or the coordinator; offline Python, no game run).
3. **The journal (#547)** for Study, and **G-09** for Tame beyond the horse's first step.
4. **MikeW's data:**
   - a second sign kind for the frog;
   - a goblin sign row;
   - a boar carcass row;
   - species rows for batch 3.
5. **Sounds (Jason):** the bear huff, the deer call and stamp, and the goblin whistle. These are listed as `built: false` warnings until they exist.
