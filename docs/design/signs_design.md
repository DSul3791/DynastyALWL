# Signs: what creatures leave, where it is read, and how it fills the journal (design)

Steve, 7 Nov 2026, for the guiding document's section 9.3 (#544), alongside the field journal (#547, G-18) and the interaction cards (#550, G-17). This is a design only. **No code until Dave reacts to G-18.**

## 1. What exists today

- **`data/animals/animal_sign.json`** (Sal, 31 Oct) has 24 species rows. Each has a `group` (such as clawed), a `track` (what a skilled tracker reads from prints) and `signs`: a kind plus a one-line hint. **Nothing reads it yet.**
- **Tracking levels** (`data/items/tracking.json` `species_reading`, proposed): Tracking 40 tells the group, 65 names the species, and 90 adds age and injury. The tracking skill already makes trampled-grass trails last longer on the player's own client.
- **Live traces that already exist:**
  - game trails: a server grid of worn cells by species weight, saved in `trails.json`;
  - blood drops from a wounded animal (protocol 55), which dry after `life_s`;
  - wolf `growl` and `howl` events (`server_wolves.gd`);
  - carcasses.

## 2. Three kinds of sign, one way to read them

| source | what | where it comes from | lifetime |
|---|---|---|---|
| **Placed** | droppings, scratch, rubbing, rooting, wallow, burrow, den, gnawing, nests, feathers, hair | Deterministic from the cell hash in the species' habitat near where it spawns (Sal's proposal), like ground scatter. Bear scratch and droppings go within the den ring, rabbit burrows at their real `burrow` spots, fox dens at fox burrows | Rebuilt from the world, never saved. A rebake moves them along with the habitat (the same rule as #547 section 4) |
| **Live** | tracks on a game-trail cell the species wore; blood drops; a fresh carcass | The server records the species on each trail cell it already keeps (one byte: the last species, and only if its weight is at least 0.5). Blood and carcass already exist | Their own decay (trails: hours; blood: `life_s`) |
| **Heard** | howl, croak, song, the bear's huff (once built) | Existing sound events, plus each species' `calls` when they exist | The moment only |

**Reading.** A placed or live sign shows its hint when the player looks at it or passes within 3 m (Sal's rule). The server checks the read, because placed signs are deterministic on both sides and live ones are server facts. What the hint says depends on the reader's Tracking skill:
- **below 40:** "Something walked here";
- **40:** the group ("clawed", "hoofed");
- **65:** the species (the row's hint);
- **90:** also age and injury (from the live animal, when the sign is live).

## 3. How signs become journal evidence (#547 rungs)

| evidence | counts toward |
|---|---|
| A **heard** sign within reach | **Sighted** for that species. You know it is there and roughly where. A howl gives the direction only |
| Any sign **read at 65+** | **Heard of** at least, plus one **Tracked** counter for its kind |
| A sign read below 65 | A pending entry ("unknown clawed animal, north wood"). It becomes that species once a later read at 65+ names it, or a sighting near it does |
| **Tracked** | 3 reads of at least 2 kinds, then a sighting within 300 m of the last read, within one game day (#547) |
| **Observed** | Never from signs: only from watching the animal |
| A **fresh live** sign (blood, tracks under 10 game minutes old) followed to its animal | Counts as the Tracked sighting at once, because it is the same animal |

## 4. Today's creatures: what each leaves, where it is read, and the gaps

| creature | leaves (rows today) | read where | gap |
|---|---|---|---|
| Bear | tracks, scratch, droppings | den ring and river banks (habitat near fresh water, #545) | none; huff as a heard sign once built (#550 correction 4) |
| Wolf | tracks, droppings, howl | trail cells of the pack's home square; the howl at night | none (wild packs are off, `natural: false`) |
| Boar | rooting, tracks, wallow | forest floors; wallows by wet ground | none |
| Deer | tracks, droppings, rubbing | meadow edges, forest; rubbing in autumn (rut) | the dusk call, once a sound exists |
| Frog | croak | within 30 m of fresh water | **a second kind** (section 9.3 asks for two): `spawn` in spring at pond edges |
| Goblin | none | no row | **a new row:** `footprints` (small bare prints by a fire's edge, read at night), `litter` (bones and thatch near a den mouth, #543), `stolen` (a missing item: an event sign, once stealing exists) |
| Horse, donkey | tracks, droppings | open grassland | none |
| Seal, seabird, mountain goat | one kind each | coast and crags | **a second kind each** (for example a haul-out for the seal, guano for seabirds, tracks on ledges for the goat) |
| Otter, badger, wild sheep | rows exist | | no species in `animals.json` yet; keep them for later |

## 5. Dependencies

1. **G-18 accepted by Dave.** Signs feed the journal, and without the journal they are only hints.
2. **MikeW's data:**
   - goblin `footprints` and `litter` (with `stolen` later);
   - frog `spawn`;
   - a second kind for the seal, seabird and mountain goat;
   - sign placement rules per kind (density, habitat key, season) in `animal_sign.json`.
3. **Kathreen:** a small model or decal per placed kind (droppings, scratch, rubbing, rooting, wallow, burrow, nest). Tracks reuse the trail tint.
4. **Server:** one species byte on trail cells. The `trails.json` save format goes up one version, and old saves read with "unknown species".
5. **Tracking skill:** the `species_reading` levels move from proposed to used, which needs Dave's yes with G-18.
6. **Sounds (Jason):** calls as heard signs: deer, the bear huff, the goblin whistle.
