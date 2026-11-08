# Art direction for caves and rock shelters (design only, no code)

Kathleen, 8 Nov 2026, the third of the set with `art_mountains.md` and `art_water.md`. Basis: `art/Art_Direction.md` (85 percent realism, 15 percent storybook), `docs/knowledge/caves.md` (what is built and the lessons), `docs/GOBLINS.md` (goblin dens), the brown bear row in `data/animals/animals.json`, `docs/design/cave_lod_carving_design.md` (the R5 cave size requirement) and `docs/water/watershed_rebuild_design.md` (C7 cave springs, R5). This document says **how caves should look, light and read**; where caves go and how they are carved stays with Sonny (shape, placement, water) and Steve (carving, LOD). It changes **no code and no data**. Items marked **[Proposal]** need a decision by Dave, the coordinator or the owners named. I have not walked these caves in the game; the pictures to collect are in section 10.

## 1. The rule in plain words

A cave must look like water and time made it, and like something might live in it. From outside, the mouth tells you what kind of cave it is; ten steps in, the light tells you to turn back or light a torch; at the back, the floor tells you who lives there. **The 15 percent exaggeration goes into the drama of the mouth, the beauty of wet rock under torchlight and the readability of dens**, never into shapes rock cannot make, and never into light that makes a cave less dark than Dave decided ("pitch black without a light", #447).

## 2. The kinds of cave in the world today

| Kind | Facts (code and rules today) | Character |
|---|---|---|
| **Spring cave** | At a river start, inland (1.5 km or more from the sea), at the foot or side of a hill; a passage about 100 m long rising gently, the spring pool at the back (up to 20 m deep, icy), the stream along the floor, side branches with dens; some have 2 or 3 spring passages. Sized from its river; after the rebuild, only where rock lets water travel underground (C7: limestone, marble, fractured basalt, fault zones) | Wet, cold, loud with water, green at the mouth, the classic "something lives here" cave |
| **Rock shelter** | 4 to 8 per tile, at least 500 m apart, in rock faces of 35 degrees or more; 5 to 15 m deep, 4 to 8 m wide, 3 to 5 m tall | Dry, shallow, half lit: the traveller's camp |
| **Lava tube** | Rules exist (300 to 1500 m long) with collapsed skylights as extra entrances; gives goblin dens where generated | Dark basalt, smooth round tunnel, shafts of daylight from skylights |
| **Karst caves and sea caves** | Switched off in generation for now (caves.md lesson 9) | Covered here briefly so they are ready if they return |

Every cave can be inhabited (Dave, 6 Nov): animals, creatures, the odd survivor, low-level bandits on starter islands. The look must let a player read that before meeting the occupant.

## 3. Mouths: what the entrance says

1. **Spring cave mouth:** an arch or a low, wide slot at a hill's foot, the stream running out of it over clean, water-worn stones. Ferns, moss and liverworts thick on the lip and walls, a drip curtain from the brow after rain, cold mist pouring out on warm mornings (the cave air is colder), a darker damp patch fanning down the slope. The mouth's rock is the cave's rock (pale limestone, grey fractured basalt), visibly different from the soil above it.
2. **Rock shelter:** a long, low overhang under a cliff band, deeper at the middle than at the ends; a dry dusty floor of fine grit, a drip line of damp ground and taller greenery exactly under the brow edge, swallow or wren nests in cracks, soot stains on the roof from old fires.
3. **Lava tube:** a round or oval hole, often where the roof has fallen in (a skylight): a ring of broken black rock, ferns and moss growing down into the light shaft, a cone of rubble below it.
4. **Size and framing:** a mouth is 10 to 24 m wide where the cave rules carve it at every level (cave LOD design, fix A). Give each mouth one framing feature: an overhanging brow, a fallen boulder beside it, a tree whose roots hang over the lip. The 15 percent: brows can overhang a little more and roots hang a little longer than nature would usually manage.
5. **Never:** a perfect semicircle, a mouth cut into soil with no rock showing, a mouth with no change in plants around it, or a "drilled" tube (Dave's word for the walls on 5 Nov).

## 4. Light: the walk from day into dark

Built facts: under rock, sky ambient and reflections fade (#365); with no light the cave goes pitch black and fog turns dark (#447); cave water is lit by torchlight only, not the sky (#463).

1. **Three zones.** *Entrance zone* (the first about 5 to 15 m): daylight falls on the floor and lower walls, green plants, warm dust motes. *Twilight zone* (to about 30 to 40 m, or the first bend): grey-blue light only from the mouth behind you, colour draining out, plants stop, moss turns to bare wet rock. *Dark zone*: nothing without a light.
2. **The fade should follow the passage, not a switch.** [Proposal for whoever owns the cave light] Fade the daylight share by distance along the passage from the mouth and by bends (a bend cuts it sharply), so a straight passage keeps a dim glow longer than a winding one. Clamp auto-exposure so the eye never "adapts" the dark zone into grey (caves.md: a known trap in other engines).
3. **Looking back out:** the mouth glows white-bright, overexposed, framing the outside world; this is one of the most beautiful shots a cave gives, so keep it.
4. **Skylights (lava tubes):** a hard shaft of daylight with dust or mist in it, a lit circle of floor with green growth, and dark all around. Rain falls through the shaft only (no rain elsewhere in caves, #304).
5. **Torchlight is the cave's palette:** warm orange on wet rock, deep falloff in about 6 to 10 m, strong glints on wet surfaces and flowstone, long moving shadows from formations. A lantern is steadier and a little whiter. The light must make wet rock shine and dry rock look matt; that difference is how a player reads where water runs.
6. **The one fantasy accent [Proposal]:** in deep chambers only, rare patches of a faintly glowing cave fungus (the game already lists "lumencap" among the fantasy plants) giving a cold blue-green glow too weak to see by. It rewards going deep and never lights a passage.

## 5. Rock: walls, floor, wet rock and flowstone

Dave's direction (5 Nov): rough rock walls, smoother water-worn rock near the stream, a smooth-enough walkable floor with small detail such as roots from above, nothing that blocks movement.

1. **Walls by rock:**
   - *limestone:* pale cream to grey, scalloped (shallow spoon-shaped hollows from flowing water), smooth near the stream, rough and flaky higher up, dark water stains down from cracks;
   - *fractured basalt (lava tube):* black to dark grey, glassy glaze on the lower walls, ropey ridges on the floor, a flat "bench" line along the walls where the lava level once stood;
   - *granite or fault caves:* angular blocks and fallen slabs, sharp-edged, grey-pink with mica glints in torchlight.
2. **Floor:** walkable by design (caves.md lesson 4). Show it as packed grit and silt along the walking line, cobbles and wet pebbles beside the stream, fallen blocks and rubble at the walls only. Roots hang from the roof and thread down the walls in the first 20 to 30 m, where the soil above is thin.
3. **Wet rock:** darker, glossy, with a thin moving sheen where water seeps. Dry rock is matt and a little dusty. Wet patches follow cracks, the roof over the stream and the walls near the spring.
4. **Flowstone and formations (limestone only):** creamy flowstone sheets draping down walls like frozen curtains, rimstone pools (small terraced dams) beside the stream, stalactites as thin "soda straws" in young caves and thick cones in big chambers, stalagmites on the floor below them. The dressing today gives stalagmites (solid when 0.25 m or more in radius) and stalactites hanging out of reach; keep them **out of the walking line** and **only in limestone caves**: no stalactites in lava tubes or granite.
5. **Mineral colour:** iron stains in orange-rust streaks, manganese black, calcite white. A torch catching calcite crystals sparkles; this is allowed to be slightly prettier than real (the 15 percent).
6. **Texture rules:** like the mountains, three scales (fine grain, hand-sized scallops and cracks, large bands and stains) so a 100 m passage never repeats visibly; projected so walls do not stretch.
7. **Cave size follows the R5 requirement:** passages a player can see from inside are baked large enough to hold at coarse detail (about 7 m wide and tall where the rock allows), with Dave's small, medium and large difference above that; a narrower squeeze is a deliberate dead end. Art works with that: make the larger passages feel tall and vaulted, and keep tightness for the deliberate squeezes and side branches.

## 6. Water in caves

The cave stream and spring pool follow `art_water.md` section 9: very clear, almost black where deep, slow and glassy, rings from drips, smooth pale rock along it, no plants inside the dark zone, lit only by torch or the mouth.

1. **The spring pool at the back** is the cave's showpiece: a still, deep, cold pool, its bottom dropping out of sight into blue-black, a faint cold blue where limestone-rich, mist over it on cold days, a smooth worn lip where the stream leaves it. The icy cold (built) should also read: breath mist in the torchlight near it.
2. **Stream course:** scalloped, smooth channel, gravel bars at bends, small falls only at a hard rock step (never a staircase), foam only at those drops.
3. **Sound first:** the water is heard before it is seen (cave sounds and echo are built, #286, #308); louder near drops and the spring.
4. **Never:** sky reflections on cave water, bright blue water underground, plants in the dark zone, or a large stream from a tiny spring with no supply (the watershed rule).

## 7. Who lives here: how dens read

The rule: **the player should be able to tell who lives in a den from 10 to 20 m away by torchlight, before meeting them.** Each den's dressing is distinct in shape, colour and smell-sound.

| Occupant | Where (facts) | What the dressing shows |
|---|---|---|
| **Brown bear** | Den by a river on the far side of the starter island; the bear fishes about half its time, ranges 80 m, defends 15 m round the den (animals.json) | A wide, flattened bed of dragged-in leaves, grass and spruce boughs in a low chamber or the back of a shelter-like branch; long claw scratches on the walls at shoulder height (about 1.5 to 2 m); tufts of brown hair snagged on rock; fish bones and skins, a deer leg bone, crushed berry husks; a trampled, worn path from the mouth; outside, a scratched and stripped tree trunk and large scat near the entrance. Sound: heavy breathing or a low huff when near |
| **Goblins** (dry dead end of a side branch, 2 to 5 at a time, 1.1 m tall, night foragers and thieves; dressing built: bones, sticks, thatch litter and a small fire) | `GOBLIN_DEN_CAVES`, `cave_dressing.gd` | Everything at goblin scale (knee-to-waist high for a person): low sleeping nests of thatch and stolen cloth; a soot-blackened roof over the small fire; a hoard pile of shiny stolen trinkets (a cup, a buckle, a broken knife, coloured glass) that glints in the torch; gnawed bones and berry stains; crude scratch marks or tally lines on the wall at goblin height; a few sharpened sticks propped by the entrance of the branch. The hoard and scratches are the storybook part. Sound: whispering and scuttling, a crackle from their fire |
| **Small animals and creatures** (tier 1 on starter islands: bats, snakes, foxes) | Chambers, dead ends, near entrances (tile_sites dens) | Bats: dark guano heaps under a high roof crack, a squeak-and-flutter sound, a sharp smell implied by stained rock. Snakes: shed skins in warm dry cracks near the mouth. Fox or badger: a smaller nest and scattered small bones near the entrance |
| **Old remains** | Bone piles at entrances and far ends (built: animal and human) | Bones read as old and weathered (warm ivory with stains, built); human bones may have a rusted buckle or a broken lantern beside them so they tell a small story. Never gory |
| **Survivors and low-level bandits** (Dave 6 Nov; not built) | Runtime occupants of a cave site | Survivor: a tidy bedroll, a small fire ring with a cooking pot, drying herbs on a line, a tool or two: reads as "someone trying to live". Bandits: crates and sacks, a rough barricade of logs at the branch mouth, weapons racked, gambling dice, a lookout spot with a view of the mouth: reads as "keep out". Both [Proposal] for when they are built |

Den rules for builders: dens stay off the walking line of the main passage; a den is visibly a **place** (a change in floor, light and clutter), not scattered objects; and the closer a player gets, the more detail appears (hair, scratches, trinkets).

## 8. Hazards should be readable

Caves have natural hazards (DESIGN_IDEAS 4.4: steep slopes, thin rock bridges, tight squeezes, drops beyond). Each must read before it bites:
1. **Drops and pits:** the floor edge is lighter (worn, dry) and the dark beyond it is total; a cold draught or water echo from below.
2. **Rock bridges:** thin, cracked, with a few fallen fragments below them.
3. **Squeezes:** the walls come in, scratched and polished where bodies (animal or human) have rubbed through.
4. **Unstable roof (man-made tunnels only, the collapse system):** cracked roof, dust trickling, as already set for cave-ins.

## 9. Rock shelters in detail

1. **Why players will love them:** a dry roof, a view out, half daylight. They are the natural first camp and should look inviting.
2. **Floor:** dry, fine, pale dust and grit, with older ash patches and a ring of fire-blackened stones in some (someone camped here before); scattered animal bones in a few (a predator's lunch spot).
3. **Roof:** smoke-blackened in a fan over the old fire ring; swallow or wren nests; spider webs in the dry corners.
4. **The drip line:** a sharp edge where rain falls from the brow: wet dark soil and taller greener plants exactly along it, dry dust just inside. That one line makes a shelter believable.
5. **[Proposal] Old marks:** on a few shelters on harder ground, faint, very old ochre hand marks or simple animal figures on the back wall, as a quiet trace of people long gone (the storybook part, and a journal discovery later). Rare, never more than one shelter in a wide area.

## 10. Never, checks and pictures

**Never see:** smooth "drilled" tube walls; stalactites outside limestone; cave water reflecting the sky; daylight colours deep inside; a dark zone that is grey instead of black; dens as random objects on the walking line; the same den look for different occupants; gore; a large stream from a tiny opening.

**Checks for every cave picture:** What kind of cave and rock is it, and do walls, floor and formations agree? Does the light fall off by zone and bend? Is the walking line clear? Can I tell who lives here before I see them? Does the water look and sound right?

**Pictures to collect (Dave's own are best):** a spring flowing out of a limestone cave mouth, a rock shelter with a drip line, a lava tube with a skylight, wet scalloped limestone under torchlight, flowstone and rimstone pools, a bear den with a scratched entrance (wildlife photography), a still cave pool. Game pictures to take with the look rig when the cave work resumes: from 10 m inside a spring cave mouth looking in and looking out, the goblin den at 10 m and 3 m by torchlight, a rock shelter from 20 m outside.

**For the owners (how, not what):** Sonny and Steve own the shape, carve and placement (R5 cave sizes); the client cave light owner picks how the zone fade and exposure clamp are made; the dressing (`cave_dressing.gd`) gets new rows for bear dens, the goblin hoard and scratches, shelter fire rings and drip-line plants when those are built. Two calls for Dave or the coordinator, with my recommendations: (1) the faint glowing cave fungus in deep chambers: **yes, rare**, because it rewards exploring without breaking "pitch black"; (2) old ochre marks in a few rock shelters: **yes, rare**, because it adds history and a later journal find at almost no cost.
