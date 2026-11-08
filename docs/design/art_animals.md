# Art direction for the animals and goblins (design only, no code)

Kathleen, 8 Nov 2026. This is the fourth in the set, after `art_mountains.md`, `art_water.md` and `art_caves.md`.

**Basis:**
- `art/Art_Direction.md`: 85 percent realism, 15 percent storybook exaggeration. Creatures should be "anatomically convincing ... believable within their fantasy biology".
- `data/animals/animals.json` and `data/animals/models.json`: the 50 species and their model rows.
- `design/ANIMALS_BATCHES.md`.
- `docs/knowledge/creature-models.md` and `docs/knowledge/animal-behaviour.md`.
- `docs/knowledge/torches-fire.md`.
- `docs/GOBLINS.md`.
- The coat shader in `src/client/animal_view.gd` (looks: fur, feather, wet, eye).
- The blood trail (protocol 55).
- The critiques in `art/CRITIQUES/` (fauna_2026-10-30, animals_review_2026-11-02, quad_body_2026-11-04, carcass_legs_2026-11-04).

**Scope:**
- This document says **how animals and goblins should look, read and wear**.
- How they move, what they do and how many there are stays with MikeW (models, gaits, rows) and Steve (behaviour, goblin den life).
- It changes **no code and no data**.
- Items marked **[Proposal]** need a decision by Dave, the coordinator or the owner named.

**Evidence:**
- The sizes in section 4 are adult field-guide ranges.
- The eye shine colours in section 6 come from spotlighting guides and the tapetum literature. Each row says how sure it is.
- I have not looked at every species in game light. The pictures to collect are in section 11.

## 1. The rule in plain words

An animal must look like the real animal at every distance. Size, proportions, gait and colour must all be true, because the player reads danger, food and distance from them. It should look like a good wildlife photograph of that animal on a good day.

**The 15 percent goes into:**
- the richness of the coat;
- the crispness of markings;
- the drama of the features a mature animal shows off (antlers, horns, tusks, manes);
- the moments at night when eyes catch the torch.

**It never goes into:** body size, eye size, head size, or cute faces.

The only creatures that get a fantasy budget are the **goblins**, and the **mammoth** a little. Even then, skin, cloth and light obey the same photoreal rules as everything else.

## 2. How far exaggeration goes, per creature

**Levels:**
- **0, true.** No exaggeration. These are animals everyone knows from life: farm and tame animals, and small common prey. Any change reads as wrong.
- **L, light, about 5 percent.** Coat colour about 5 percent richer, and markings a little crisper.
- **M, medium, up to 10-15 percent.** The same as L, plus show features on **mature males**: antler, horn, tusk or mane mass up to 15 percent over the species average. Females and young stay true.
- **F, fantasy.** The creature's own rule, given in its row.

**Sources:**
- "Pack" means the WildMesh3D Realistic set. These models are never committed: `/assets/animals/` is gitignored.
- "Code" means the code-built body in `animal_view.gd`.

| # | Species | Source | Level | Where the budget goes | Hold true / watch |
|---|---|---|---|---|---|
| 1 | Rabbit | Pack | 0 | No exaggeration | Ear length, the white tail flash when it bolts |
| 2 | Deer | Pack | M | Stag antlers in autumn | Hinds and fawns true; slender legs, never "box legs" (critique) |
| 3 | Wolf | Pack | L | Ruff and winter coat depth | Long legs, narrow chest; not a big dog |
| 4 | Moose | Pack | M | Bull palms in autumn, dewlap | Hump, long legs, droopy nose; it must look ungainly, not noble |
| 5 | Fox | Pack | L | White tail tip and black socks crisp | Ears large and pale inside (critique: "thin and dark") |
| 6 | Duck | Pack | L | Drake head gloss (section 5.3) | Female mottled brown; floats high (#584: 45 percent of height under) |
| 7 | Horse | Pack | 0 | No exaggeration | No tack while wild (the saddle is hidden in the row) |
| 8 | Boar | Pack | M | Bristle ridge, tusks on old males | Wedge body, short legs (critique: slab body) |
| 9 | Songbirds | Code | L | Breast colour (robin) | Size; a flight pose is still missing (critique) |
| 10 | Frog | Code | 0 | No exaggeration | Moist skin always (5.4); spots and webbed feet missing (critique) |
| 11 | Grouse | Code | 0 | No exaggeration | Barring missing (critique) |
| 12 | Seal | Code | L | Dry coat mottling (6) | Blotches must lie on the skin, not hover (critique); front flippers longer |
| 13 | Seabird | Code | 0 | No exaggeration | Clean white and grey; flight pose missing |
| 14 | Brown bear | Pack | L | Shoulder hump and coat depth | Mass and slow power; ~1.0-1.1 m at shoulder (MikeW checked) |
| 15 | Donkey | Pack | 0 | No exaggeration | Big ears, pale muzzle and belly |
| 16 | Goblin | Meshy | F | See section 3 | The only fully fantasy creature |
| 17 | Lynx | Pack | L | Ear tufts and cheek ruff | Short tail, big paws; fur cards need clean alpha (5.1) |
| 18 | Black bear | Pack | L | Coat gloss in summer | Smaller than the brown bear, no hump, straight face |
| 19 | Elk | Pack | M | Bull antlers and neck mane in autumn | Pale rump patch; bigger than the deer, smaller than the moose |
| 20 | Bighorn | Pack | M | Ram curl, broomed tips (8.2) | Ewes have short horns |
| 21 | Mountain goat | Pack | L | Shaggy winter "pants" and beard | Off-white, never pure white; short black horns on both sexes |
| 22 | Beaver | Pack | 0 | No exaggeration | Flat scaly tail, orange incisors |
| 23 | Chamois | Pack | L | Face mask contrast | Hooked short horns on both sexes |
| 24 | Mink | Pack | 0 | No exaggeration | Near black, white chin; low and long (#584 gait) |
| 25 | Raccoon | Pack | L | Mask and tail rings crisp | Hunched back; fur cards need clean alpha |
| 26 | Rat | Pack | 0 | No exaggeration | Scaly bare tail, never furry |
| 27 | Crow | Pack | 0 | Blue-black gloss only (5.3) | Size check: a carrion crow is ~0.45 m bill to tail, the row says `length_m` 0.25 (10.4) |
| 28 | Pheasant | Pack | L | Cock copper and green gloss, long tail | Hen dull brown |
| 29 | Goose | Pack | 0 | No exaggeration | Greylag grey-brown; orange bill |
| 30 | Cow | Pack | 0 | No exaggeration | Farm, never wild |
| 31 | Goat | Pack | 0 | No exaggeration | Farm; texture must stay opaque (row has `opaque`) |
| 32 | Chicken | Pack | 0 | No exaggeration | Farm |
| 33 | Cat | Pack | 0 | No exaggeration | Farm |
| 34 | Dog | Pack | 0 | No exaggeration | Farm; wet nose (5.2) |
| 35 | Wild ox | Pack | M | Bull horn spread, shoulder mass | The only wild cattle |
| 36 | Puma | Pack | L | None beyond coat | Small head, long tail, plain tawny coat |
| 37 | Pronghorn | Pack | L | White rump and throat bands crisp | Fastest runner: thin legs, true |
| 38 | Warthog | Pack | M | Tusks and face warts on males | Mane along the spine; kneels to graze |
| 39 | Hyena | Pack | L | Spots and the sloping back | Never a dog; heavy forequarters |
| 40 | Wildebeest | Pack | L | Beard and mane | Horns on both sexes |
| 41 | Lion | Pack | M | Male mane (darker with age) | Lionesses true, no mane |
| 42 | Leopard | Pack | L | Rosettes crisp | Rosettes, not spots; never mixed up with the cheetah |
| 43 | Rhino | Pack | M | Front horn on old animals | Folded skin, grey, mud-coloured from wallows (7.5) |
| 44 | Elephant | Pack | M | Bull tusks, one shorter from wear (8.2) | Size never exaggerated; wrinkles, sparse hair |
| 45 | Camel | Pack | L | Shaggy winter neck and hump wool | ~2.0-2.2 m at the hump (MikeW checked) |
| 46 | Guineafowl | Pack | L | White spotting crisp | Bare blue head |
| 47 | Honey badger | Pack | L | Pale back blanket crisp | Low, broad, fearless stance |
| 48 | Kangaroo | Pack | 0 | No exaggeration | Tail as the third leg when standing |
| 49 | Mammoth | Pack | F | Fur length and tusk curl up to 20 percent | Extinct, so "optional fantasy" (ANIMALS_BATCHES); the body is still an elephant's |
| 50 | Tiger | Pack | L | Stripe contrast | Swims willingly (7.4) |

**Mature males only:** the M budget applies to stags, bulls, rams, boars and old lions. A herd shows real variety: one big old male, several ordinary ones, and young ones with spikes or buttons. **[Proposal: MikeW]** When the model allows it, pick antler or horn size per animal from its id, using the same variant system as `variants` in models.json.

## 3. Goblins (level F)

Built facts:
- 1.1 m tall with a variation of 0.5 m (`height_variation_m`);
- groups of 2 to 5;
- two Meshy models, Skritch Ragtooth and Rukz, about 41k triangles each;
- skittish;
- they sleep by day in a dry side branch of a cave, and come out to forage at night (`docs/GOBLINS.md`, Steve's den life work).

1. **Where the fantasy goes:**
   - big ears;
   - big eyes;
   - long fingers and toes;
   - a hunched, quick, nervous posture;
   - expressive faces.
   This is where the 15 percent can go to 30 percent: they are the game's storybook creature, so they can be memorable.
2. **What stays photoreal:**
   - skin with pores, wrinkles at the joints, and a faint oily sheen on the nose and forehead, with roughness 0.55 to 0.7 elsewhere;
   - cloth, which is real rough-woven rags: frayed, patched, stained with soot and earth;
   - light, which is the same rules as any creature.
   A goblin must look like it could be photographed in a cave.
3. **Colour:** greys, olive and earthy greens, and dusky browns, with variety inside a group. Never bright green, never toy colours.
4. **Den wear:**
   - soot on the hands and face from the den fire;
   - bone and tooth trinkets;
   - torn ears and old scars on the older ones;
   - mud on the feet.
   Their kit is made from what the den shows: bones, sticks, thatch (`cave_dressing.gd`). It should look scavenged, never forged.
5. **Eyes:** see section 6. **Decided by coordinator, Dave may overrule:** goblins get eye shine: amber-yellow, about half the strength of a cat's. This is because they are night creatures, and it makes Steve's "creep to the firelight edge at night" behaviour show as **pairs of eyes at the edge of the light**. It is the one place where the fantasy pays off in play.
6. **Never:**
   - cartoon-goblin green;
   - shiny plastic skin;
   - teeth so big the mouth cannot close;
   - armour or swords (they are not bandits);
   - a group in which every goblin is the same height and colour.

## 4. Scale against the player

The player is a 1.8 m capsule (`src/shared/swim.gd`), so eye height is about 1.65 m. The table gives adult shoulder height (for birds, length from bill to tail) and where that comes up to on the player. These are the numbers to judge any picture against. MikeW's size checks (camel, bear) already follow them.

| Comes up to the player's ... | Species (adult shoulder height, m) |
|---|---|
| **Ankle or shin** (under 0.3) | Frog 0.08 long; songbird ~0.15 long; rat 0.4 long with its tail; mink ~0.15 tall; rabbit ~0.2; honey badger 0.25-0.3; cat ~0.25; raccoon ~0.3; beaver ~0.3; birds: crow ~0.45 long, duck ~0.55 long, guineafowl ~0.5 long, chicken ~0.45 long, grouse ~0.4 long, pheasant ~0.8 long with its tail, goose ~0.8 long, seabird ~0.6 long |
| **Knee** (0.3-0.55) | Fox 0.35-0.4; seal lies ~0.4 high |
| **Thigh or hip** (0.55-0.9) | Dog 0.55-0.6; lynx 0.6-0.7; leopard 0.6-0.7; puma 0.6-0.8; warthog 0.65-0.85; wolf 0.7-0.85; goat 0.7-0.8; chamois 0.75-0.8; hyena 0.7-0.9; boar 0.8-0.95; pronghorn 0.85-0.9; black bear 0.8-0.95; tiger 0.9-1.1 |
| **Waist** (0.9-1.15) | Bighorn 0.9-1.0; mountain goat 0.9-1.0; deer 1.0-1.2; brown bear 1.0-1.1 (it stands 2.0-2.4 m on its hind legs); lion 1.1-1.2; goblin 1.1 (0.6-1.6) |
| **Chest** (1.15-1.5) | Donkey 1.0-1.3; wildebeest 1.15-1.45; cow 1.3-1.5; elk 1.3-1.5; horse 1.4-1.6; kangaroo stands 1.5-1.8 |
| **Over the head** | Wild ox 1.5-1.7; rhino 1.6-1.85; moose 1.8-2.1; camel 2.0-2.2 at the hump; mammoth 2.7-3.4; elephant 3.0-3.3 (bull) |

**Rules:**
1. **Size is never exaggerated.** Not even for drama: a moose that looks too big makes every other animal look small, and the player judges threat and distance from size.
2. **The test is a side picture next to a 1.8 m post.** Dino's side scale views and perspective scale picture already show this (memory). Every new species gets one before it ships.
3. **Variation inside a species** is plus or minus 8 percent at most for adults. Young animals are drawn at their own size (`young_model`, the calf).

## 5. Fur, feather, skin and horn: material rules

These hold for pack textures and for the code coat shader. The numbers are roughness on a 0 to 1 scale (Godot `ROUGHNESS`).

### 5.1 Fur

1. **Dry fur is matte:** roughness 0.85 to 0.95, specular 0.1 to 0.2. The coat shader already uses rough 0.95 and spec 0.15.
2. **Fur shows its depth at the rim:** a pale, soft edge where the coat meets the sky, and a warm glow through the fringe when it is backlit at sunrise or sunset. This is what makes fur read as fur at 30 m. The coat shader's `fuzz` rim does it for code bodies. Pack bodies with flat albedo need the same rim. **[Proposal: MikeW]** Run every pack fur surface through a rim term like the coat shader's `fuzz`, about 0.2 to 0.35.
3. **Fur cards** (lynx `cards`, raccoon `Card`, the puma's whiskers, the kangaroo's eyelashes) must be alpha cut-outs: alpha scissor or alpha hash, never blended. Blended cards sort wrong and flicker. A card surface that draws as solid planes or vanishes is a material bug; the goat's invisible texture was the same class of fault.
4. **Colour range:** no fur is pure black or pure white.
   - The darkest coats (black bear, mink, crow) sit at sRGB 30 to 45.
   - The palest (mountain goat, goose belly, the fox's tail tip) sit at sRGB 200 to 225.
   - Otherwise the sun and the torch have nothing to light, and the coat reads as a hole or a glow.
5. **Countershading:** almost every wild mammal is darker on the back and paler underneath. The coat shader's darker underside does this for code bodies; pack textures already have it.
6. **Seasons:** see section 8.1.

### 5.2 Bare skin, noses and pads

1. Noses on dogs, wolves, foxes, cats, bears and hyenas are glossy and moist: roughness 0.25 to 0.4.
2. Horse and donkey muzzles are velvety: roughness 0.7.
3. Lips, inner ears, pads and udders: roughness 0.45 to 0.6.
4. Elephant, rhino and warthog skin is dry and matte (roughness 0.8 to 0.9), with deep wrinkles and dust in the folds.
5. Rat and beaver tails are scaly and semi-matte (roughness 0.6), never furry.

### 5.3 Feathers

1. Roughness 0.6 to 0.75 with a soft sheen along each vane. The coat shader's feather look uses rough 0.72 and spec 0.3.
2. **Gloss and colour that changes with the view angle, only where the real bird has it:**
   - the mallard drake's green-to-purple head;
   - the pheasant cock's copper and green;
   - the crow's blue-purple sheen on black.
   This is a small hue shift with angle, never a rainbow. Hens, geese, gulls, grouse and guineafowl have none.
3. **Feathers shed water.** See section 7.3.

### 5.4 Amphibian skin

The frog is always moist: roughness 0.3 to 0.45, never matte, with a soft highlight on the back. A matte frog reads as dead or plastic.

### 5.5 Eyes

1. The cornea is glossy (roughness 0.05 to 0.15) and **always carries a highlight**. An eye without a highlight reads as dead. The horse and donkey rows use 0.2, which is acceptable; species with no `Eye` material need a check in the strip pictures (11).
2. **Pupil shapes are true:**
   - horizontal bars on goats, sheep, chamois, deer, horses and cows;
   - vertical slits on the cat and the fox, and vertical ovals on the lynx;
   - round on wolves, dogs, bears and the big cats (lion, tiger, leopard, puma).
3. **Eyes are never enlarged** on a real species (section 1).

### 5.6 Horn, antler, hoof, tusk and claw

1. **Keratin** (horns, hooves, claws, beaks) is semi-matte: roughness 0.5 to 0.7. It is darker at the base, paler or worn at the tip, with growth rings on horns.
2. **Antler** is bone. It has a rough, dark, beaded base (the burr) and polished, pale tips in autumn. Antler in velvet is covered in short, soft, warm-brown fur (8.1).
3. **Tusk** (boar, warthog, elephant, mammoth) is warm ivory, stained brown where it leaves the lip and polished where it is used.

## 6. Eye shine at night in torchlight

**What is real:** many mammals have a mirror layer behind the retina, the tapetum lucidum. It sends light back towards the light source, so the eyes shine only when the light is **close to the viewer's own eye**. A torch in the player's hand does this. A fire behind the animal, the moon or the sun does not.

Some animals have no tapetum and give only a faint red glow from the blood vessels of the retina, or nothing:
- pigs and warthogs;
- most rodents;
- rabbits;
- birds (the night birds that do have one are not in the list);
- people.

**Rules for the game:**
1. **Shine needs the player's own light:** a held torch, later a lantern. A placed torch or a campfire beside the player gives a weak shine. Daylight, moonlight and a fire beyond the animal give none.
2. **Only eyes facing the player shine.** The shine is strongest when the animal looks straight at the light and is gone when it turns past about 30 degrees. Pairs flick off and on as the head turns, and blink out when the animal blinks or looks away.
3. **Range:**
   - Real eye shine from a flame carries far past the light's reach on the ground. Let it show to about **twice the torch's light range**: about 18 m on main (`light_m` 9), and about 24 m once Sal's 12 m number lands.
   - Beyond that the eyes are dark.
   - The 15 percent budget: up to 1.5 times the real brightness, so it reads on an ordinary screen.
4. **Height and spacing tell the species.** Hunters read eye shine this way:
   - a low pair, close together, is a fox or a raccoon;
   - a pair at hip height is a wolf;
   - a high pair, wide apart, is a deer or a moose.
   Shine must sit exactly in the model's eyes, so this reading works for free.
5. **Pack animals shine together.** Five wolves are five pairs at the edge of the light. This is the most frightening honest image the game can show, and it ties into the torch's wolf protection.
6. **A carcass** loses its shine over a few game minutes as the cornea clouds. There is no shine on a cooked or butchered animal.
7. **It is not a glow:** shine adds only to the eye, never lights the ground, and is never drawn through fur or terrain. **[Proposal: MikeW, later code]** Use one emissive term on eye surfaces: the species colour × strength × the torch light arriving at the eye × a cone factor on the angle between the eye's forward and the line to the camera. It needs `shine_color` and `shine` per row in models.json.

**Shine colour per species.** Strength runs from 0 (none) to 3 (very bright). Sureness: "good" means well recorded in spotlighting guides or the tapetum literature; "guess" means it is inferred from close relatives and must be checked against field photographs before code.

| Species | Colour | Strength | Sureness |
|---|---|---|---|
| Deer, elk | Bright white to pale green-white | 3 | Good |
| Moose | Dimmer, warm yellow to orange | 2 | Guess (hunters' reports vary) |
| Wolf, dog | Yellow-green to gold (a puppy's can be blue) | 3 | Good |
| Fox | Bright white-green to yellow | 3 | Good |
| Lynx, puma, lion, leopard, tiger, cat | Green-yellow (house cats also blue-green) | 3 | Good |
| Hyena | Yellow-green, bright | 3 | Good |
| Brown bear, black bear | Amber to orange | 2 | Good |
| Raccoon | Bright yellow-amber | 3 | Good |
| Horse, donkey | Blue-green | 2 | Good |
| Cow, wild ox, wildebeest | Blue-green to green | 2 | Good |
| Goat, chamois, bighorn, mountain goat, pronghorn | Yellow-green to blue-green | 2 | Good for goats and sheep, guess for the rest |
| Camel | Green to blue-green | 2 | Guess |
| Elephant, mammoth | Faint green-yellow | 1 | Guess |
| Rhino | Faint | 1 | Guess |
| Seal | Blue-green-white, strong (marine mammals have a large tapetum) | 3 | Good |
| Beaver | Faint red-orange | 1 | Guess |
| Mink, honey badger | Faint yellow-green | 1 | Guess |
| Kangaroo | Faint red-orange | 1 | Guess |
| Frog | Faint green-silver | 1 | Good for bullfrogs, guess for ours |
| Rabbit, rat | Faint red (no tapetum) | 0.5 | Good |
| Boar, warthog | None (pigs have no tapetum) | 0 | Good |
| All birds in the list | None | 0 | Good |
| Goblin | Amber-yellow | 1.5 | Fantasy, see 3.5 (decided by coordinator) |

## 7. Wet looks for swimmers

**Which animals get wet:**

| Kind | Species |
|---|---|
| Live in water | Seal, duck, goose, seabird, frog, beaver, mink |
| Wade and swim when they must | Moose (a strong swimmer), elk, deer, bears, wild ox, horse, dog, raccoon, tiger, elephant, kangaroo, boar |
| Stay out of water | The rest. The cat, lion and leopard avoid it |

In the current rows, the beaver and mink do not swim ("does not swim in this version"). MikeW's alligator design (#584) will add a swimmer that gets wet the same way.

### 7.1 Wet fur

Wet fur changes in five ways:
1. It goes **25 to 40 percent darker**.
2. It goes **smoother and shinier**: roughness drops from about 0.9 to 0.4-0.5. This matches the coat shader's "wet" look (rough 0.4, spec 0.45).
3. It **clumps into points**, with spiky tufts along the back, tail and chin.
4. It **lies flat**, so the body looks 10 to 20 percent slimmer. A wet dog or wet bear looks thinner, which is true and a little comic.
5. It **drips** from the chin, belly and tail for 10 to 20 seconds after the animal leaves the water.

Drying:
- **Only the wet part is wet.** A wading moose is dark to the belly line and dry above, and a deer that crossed a stream has dark legs.
- Fur dries back over a few game minutes: faster in sun and wind, slower in cold, shade and rain.
- **Shake-off:** dogs, wolves, bears, the mink and the beaver shake their whole body after leaving water, throwing a spray. **[Proposal: MikeW]** Add a shake clip or a hand-built shake from the bones, the same way as #584's `gait`.

### 7.2 The real swimmers: seal, beaver and mink

1. **Seal.**
   - Wet, it is sleek, dark and glossy, with almost no fur grain and the mottling barely visible.
   - Dry on rocks, it is much paler and matte, a dusty grey or tan with the mottling clear.
   - The change from wet to dry is the seal's best look: show it as the animal hauls out.
2. **Beaver.** Wet, it is slick, dark brown and spiky. Dry, it is a fluffy chestnut. The tail is always leathery black and slightly glossy.
3. **Mink.** Wet, it is glossy near black. Dry, it is a rich dark brown with the white chin showing.

### 7.3 Waterfowl and seabirds

1. **Feathers shed water.** The back stays dry-looking and matte, and water beads and rolls off. Only the head and neck look wet after a dabble (the duck tips up, its head under).
2. **A waterfowl never looks soaked.** A soaked duck reads as sick.
3. They **float high:** ducks and geese sit with the back well clear of the water, as #584 sets it. Gulls ride higher still.
4. A **wake**: a soft V ripple behind a swimming bird, using the water's ripple rules (`art_water.md`).

### 7.4 Big animals in water

1. **Moose, elk and wild ox:** a dark wet line where the water reached, water streaming off the belly as they climb out, and mud on the legs.
2. **Tiger:** wet fur flattened, with the stripes darker and sharper.
3. **Elephant:** a dark wet band, and trunk spray when it drinks.
4. **Bears:** dark, slim and spiky when wet, with a big shake when they come out (7.1).

### 7.5 Mud and dust

1. **Wallowers:**
   - boar and warthog: mud to the shoulders;
   - wild ox and rhino: mud on the flanks;
   - elephant: mud or dust over the whole back.
   The mud carries **the colour of the local soil**, which should be read from the ground material where they wallowed, the same rule as the dirt looks. It dries paler, then cracks over hours.
2. **Everyone:** lower legs and belly carry the ground. Mud splash on wet ground, dust on dry ground, snow clinging to the legs in winter.
3. **Snow on backs:** thick-coated animals (wild ox, moose, mountain goat, mammoth) can carry a thin layer of snow on the back in snowfall, because their coat keeps the heat in. Thin-coated animals melt it.
4. **Rain:** fur animals reach the "damp" level, about half wet, after a few minutes of rain. Birds fluff up and hunker down.

**[Proposal: MikeW, later code]** One `wet` value per animal from 0 to 1, plus a `wet_line` height:
- set to 1 below the water line while swimming or wading;
- rising to 0.5 in rain;
- drying over minutes.
The material reads both values. This needs no new animation except the shake.

## 8. Wear, age and injuries

### 8.1 Seasons and age

**Coats:**
1. Winter coats are thicker, longer and duller or greyer. Deer go grey-brown in winter and red-brown in summer.
2. **The spring moult is patchy:** loose tufts hang from moose, wild ox, wolves and the mountain goat, and the camel sheds in big clumps.
3. The seasons already exist in the data (`seasons` blocks).

**Antlers** (deer, elk, moose):
1. They grow **in velvet** from spring through summer: soft, fuzzy and warm brown.
2. By autumn they are polished hard, pale at the tips. The velvet hangs in strips for a few days as it is rubbed off.
3. They are **cast in late winter**, so a winter stag may have none.
4. Antler size grows with age.

**Age:**
- Old wolves, bears and dogs have grey muzzles.
- Old males have scars and torn ears.
- Young animals have their own proportions: big heads and long legs, as with the calf.

### 8.2 Horn and tusk wear

1. **Bighorn rams:** the tips are "broomed", worn or broken back, on old rams.
2. **Bighorn, chamois, mountain goat, wild ox, wildebeest:** horns are permanent, with growth rings and chips.
3. **Pronghorn:** it sheds its horn sheaths every autumn.
4. **Elephant:** one tusk is often shorter or broken from use (it favours one side, as people favour one hand).
5. **Boar, warthog:** tusks are honed sharp and stained at the base.

### 8.3 Injuries (built: health, the blood trail, bleeding out)

1. **A hit shows as a dark, wet patch on the coat where the blow landed.** It is matted fur, darker and shinier, with a little red-brown at the centre. It spreads slowly while the animal bleeds. It is **never a hole, never exposed flesh**.
2. The **blood trail** stays as built: dark red in the middle, drying brown at the rim, ragged, never a perfect disc. Its colour is the reference for every blood look.
3. **[Proposal: MikeW / Steve]** These need hit-location data that the server does not have yet:
   - a **limp** when the leg is hit;
   - head carried low and laboured breathing as health falls.
   Until then, show only the wet patch and the trail.
4. **A carcass** has dull eyes (6.6), relaxed limbs lying on the ground (the carcass_legs critique), fur dulled and flattened, and no new blood after a few minutes.
5. **Butchering** shows only what the butchering design defines, done as a clean cut-away, never anatomy for its own sake.
6. Projectiles stuck in animals: none until projectiles exist.

### 8.4 Farm animals

They look **looked after but working**. They are clean, but with honest dirt on the hindquarters and legs, and well-fed bodies. There is no tack on wild horses and donkeys until taming (wild first, tamed later).

## 9. Never-see list

1. Any species bigger or smaller than its true size range (section 4), or enlarged eyes on a real animal.
2. Pure black or pure white fur (5.1.4); shiny dry fur; matte frogs; matte eyes with no highlight.
3. Fur cards drawn as solid planes, flickering, or invisible.
4. Eye shine in daylight, from the moon, through terrain, or bright shine from a pig, a rabbit or a bird.
5. A soaked duck or goose; a fully wet animal that only got its legs wet; wet fur that never dries.
6. Gore: open wounds, exposed organs, bright cartoon-red blood, dismemberment.
7. Antlers in the wrong season, or every stag in a herd with the same antlers.
8. Cartoon-green or plastic goblins; identical goblins in a group (section 3).
9. A model floating above the ground, sinking into it, or sized by a non-standing pose (#540, the crow).
10. Mixed-up look-alikes: a leopard with cheetah spots, a hyena drawn as a dog, a black bear with a brown bear's hump.

## 10. Proposals and checks (owners)

1. **Decided by coordinator, Dave may overrule:** goblin eye shine, amber-yellow at strength 1.5 (3.5, 6). The section 10 items below are handed to MikeW by the coordinator.
2. **[Proposal: MikeW]**
   - eye shine as one emissive term, with `shine_color` and `shine` per row (6.7);
   - one `wet` value and `wet_line` per animal (7.5);
   - a rim term on pack fur (5.1.2);
   - a shake clip (7.1);
   - antler and horn size per animal from its id (2).
3. **[Proposal: MikeW / Steve]** Hit location for limps and the low head (8.3.3).
4. **[Check: MikeW]** The crow's `length_m` is 0.25. A real carrion crow is about 0.45 m from bill to tail, so 0.25 may be the body without the tail, or too small. Check it against the side scale strip.
5. **[Check: MikeW]** Species with no `Eye` material still need a highlight on the eye (5.5.1).

## 11. Pictures to collect (Dave's PC, after the gate queue; not before)

1. A side strip of every species next to a 1.8 m post, plus a 0.5 m post for the small ones. Dino's scale views already cover several.
2. A night shot with a torch at 6 m, 12 m and 18 m of:
   - a wolf pack;
   - a deer herd;
   - a fox;
   - a bear;
   - a raccoon;
   - a boar (to check it has no shine);
   - goblins.
3. A seal wet in the water and dry on a rock; a moose wading; a duck swimming and dabbling.
4. A stag in each season (velvet, hard, cast) once seasons drive the antlers.
5. A wounded deer at 5 m and 15 m (the wet patch and the trail), and its carcass.
6. Each goblin model in den firelight at 3 m and 10 m.
