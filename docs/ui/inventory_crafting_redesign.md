# Inventory and crafting redesign (9 Nov 2026)

Owner: Kathleen (art direction). Asked for by Dave, 9 Nov 2026 03:49 UTC: *"Keep it simple, keep it eloquent and keep it useful … make sure its not crowded and make sure it is easy to use for a human. Also make sure it uses the space on the screen and keeps things big enough to see. Make it better than those games."* References he gave: ARK Survival inventory, Dragonwilds inventory and crafting table, Valheim crafting. After the first mockup he asked (04:09 UTC) what it takes to look like a top studio built it. Version 2 is the answer: the same layout, with a production finish (three depth levels, a leather and brass frame, a warm palette, engraved glyphs, letter-spaced titles and a set of motion rules). Version 3 (04:25 UTC) puts Dave's review into the picture itself, because what is not in the mockup does not get built: the recipe card's "Made at" and "Used in", the full name on the plate, the hotbar key hint, and the live character wearing its gear. Version 4 (04:40 UTC) answers Dave's 04:35 question ("it shows your hotkeys up top, do we prefer this over just having them across the bottom like most games"): the hotbar leaves the Pack and becomes one strip across the bottom of the screen, under all three panels, at the same place and size as the in-world HUD hotbar, so it does not move when the window opens or closes.

Status: **version 4 is the design (v2 accepted by the coordinator 04:21 UTC; v3 adds Dave's 04:25 review and was approved by Dave to build; v4 moves the hotbar to the bottom strip, decided by the coordinator 04:37 UTC).** The build is under way in the steps of section 12 (step 1, the canvas pass, is PR #785). #780 (inventory fit) is closed when step 3 opens.

Mockup: `inventory_redesign_1920_v4.png` (shared files, top level), drawn at 1920 x 1080 by `docs/ui/mockup/inventory_redesign_mockup.py` from the same numbers as this doc. The script draws at 3840 x 2160 and scales down so edges are smooth; `--measured` adds a copy with every box outlined. The earlier versions, `inventory_redesign_1920.png`, `_v2.png` and `_v3.png`, are kept for comparison.

```
python3 docs/ui/mockup/inventory_redesign_mockup.py --out OUT --icons item_icon_sheet.png [--measured]
```

The figure in the middle column is a painted stand-in for the live 3D character, and the item icons are the 9 Nov bake, standing in until the painted icons exist. Every other pixel is meant as the finished look.

---

## 1. The design size: 1920 x 1080

**1920 x 1080 is the project's fixed UI design size.** Every screen is laid out on a 1920 x 1080 canvas, in whole pixels, and every number in this doc is a pixel on that canvas. It was chosen so the game plays on older, smaller machines: a 1080p canvas is what most of those screens are, and Godot's viewport scaling (content scale mode `viewport`, aspect `keep`, both unchanged) fits the canvas to any other window. **1366 x 768 is the supported floor.** There the canvas is drawn at 0.71, so 18 px text shows as about 13 px, which is still readable. Nothing below 18 px is allowed anywhere for that reason.

**Today the canvas is 2880 x 1620** (`project.godot` lines 32 and 33, `display_settings.gd` `BASE`). It has been that size since the first commit (11 Oct). On a 1920 x 1080 window every canvas pixel is drawn at two-thirds size. That is why the inventory looks small and busy: its slot is 64 x 1.275 = 82 canvas px, which is **54 px on Dave's screen**, and its stack count is **12 px**. The canvas returns to 1920 x 1080 in this work (section 12), and every other screen is rechecked at that size (section 13).

Performance on weak machines is a separate job: a world render scale option for the 3D picture. It does not touch the UI, and it is out of scope here.

## 2. What is wrong now

1. **The slots are too small and don't fill the panel.** 54 px slots, 12 px counts and 10 px key numbers sit in a grid narrower than its frame.
2. **It is crowded.** The pack, gear, stats, recipes, the recipe detail, the queue and a tooltip all compete at one size, with no clear "where do I look first".
3. **Thin items vanish.** Sticks, spears, knives and tools render as hairlines at small sizes (the 9 Nov icon sheet shows this clearly).
4. **Look-alike icons.** About 25 plank bundles differ only by tint, there are 8 near-identical spades, the herb bundles are the same, and so are the seed piles and plain pies.
5. **The floating tooltip** covers the slots next to the one you are reading.
6. **No search, no sort button, no clear station context** in the crafting part.

## 3. Principles

1. **Three columns, always in the same place.** Pack on the left, You in the middle, Craft (or the open chest) on the right. The eye learns one map.
2. **Big targets.** Pack slots are 100 px. Nothing you click is smaller than 44 px.
3. **One thing to read at a time.** The item you point at is described in a fixed strip under the pack, never in a box floating over the grid.
4. **Quiet frame, loud items.** One frame material, a dark solid field, and colour saved for the items, the six bars and the one accent.
5. **Space is part of the design.** Empty slots and gaps are left empty. Nothing is added to fill a gap.
6. **Solid panels.** Nothing of the game shows through a panel (Dave, 23 Oct). The world shows only in the margins round them.

## 4. Layout (1920 x 1080 canvas, px)

| Part | x | y | w | h | Notes |
|---|---|---|---|---|---|
| Outer margin | | | | | 24 all round |
| Gutter between columns | | | | | 22 |
| **Pack** panel | 24 | 24 | 690 | 908 | |
| **You** panel | 736 | 24 | 448 | 908 | |
| **Craft / Chest** panel | 1206 | 24 | 690 | 908 | |
| **Hotbar strip** | 535 | 964 | 850 | 76 | **10 slots of 76 with 10 px gaps**, centred on 960, 40 px above the bottom of the canvas, on a leather tray 16 px bigger all round (519 to 1401, 948 to 1056) with stitching and brass end plates. The same control, at the same place, as the in-world HUD hotbar (section 9) |
| Panel frame | | | | | A 14 px leather edge, then 6 px of air, so the inside starts 20 px in |

690 + 448 + 690 + 2 x 22 + 2 x 24 = 1920. The panels end at y 932, leaving 16 px of air above the hotbar tray; the tray ends 24 px above the bottom, the same outer margin as everywhere else. Inside the 14 px frame the pack grid is 650: 6 slots of 100 and 5 gaps of 10. The slots stay 100 px.

### 4.1 Pack (inside x 44 to 694)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title plate | 72 | 30 | text + 60 | 46 | A brass plate sitting on the top frame, "PACK" engraved (section 6.3) |
| Search field | 414 | 48 | 232 | 36 | "Search the pack", filters the grid as you type |
| Sort button | 656 | 48 | 38 | 36 | Cycles the 6 sorts already in Settings |
| Weight line | 44 | 98 | 650 | 24 | "Carrying" (dim) "38.4 of 52 kg" (cream), then an 8 px brass bar from x 244 |
| **Pack grid** | 44 | 136 | 650 | 650 | 6 x 6 slots of 100, 10 px gaps (36 slots); the height the hotbar row used to take becomes the sixth row |
| Info strip | 44 | 800 | 650 | 76 | An ornament rule above it, then a 72 px well with the item, its name (Cinzel Bold 30), one line of description and one line of facts ("Holds" dim, "8 L" cream) |
| Key hints | 44 | 882 | 650 | 26 | The item's actions as plain text with keycaps: **E** Use, **D** Drop, **S** Split, **R** Repair, **1–0** Put on hotbar (the tenth key is shown as 0, the key you press; digits use EB Garamond SemiBold on the keycap because Cinzel's 1 reads as I). A hint that does not apply is greyed, never hidden. No boxed buttons |

**Hotbar: 10 keys of 76, across the bottom.** The game has 10 hotbar keys (`inventory.gd` `HOTBAR_KEYS`). With the strip under all three panels there is room for all 10 at 76 px (850 px wide), so nothing is cut. The key number is EB Garamond SemiBold 18 in the top left corner with a 1 px dark outline (Cinzel's 1 reads as I). Icons show at 60 px in a 76 px slot. Dragging between the pack and the strip works while the window is open.

**Slot contents:** the icon at 80 % (80 px in a 100 px slot) with a 2 px soft drop shadow; the stack count bottom right in EB Garamond SemiBold 24 with a 1 px #0A0604 outline; the durability bar 4 px tall, 7 px in from each side, 6 to 10 px above the bottom (the count moves up 6 px when a bar is shown).

### 4.2 You (inside x 756 to 1164)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Name plate | centred on 960 | 30 | text + 60, at most 368 | 46 | The character's full name engraved ("ALDWIN OF THE FORD"). It steps down 34, 30, 26, 24, 22, 20, 18 px and letter-spacing 3 to 1 until it fits ("ALDWIN OF THE FORD" fits at 22 px); no line under it |
| Gear, left | 756 | 92 | 96 | 464 | Head, Body, Legs, Feet: 4 slots of 96, evenly spaced |
| Figure | 862 | 82 | 196 | 478 | The live 3D character wearing what is equipped and holding what is in the hands (the mockup shows the linen shirt, hide boots, the backpack's straps and the stone axe in hand); see 6.6. Caption under it, dim 18: "Live character, as equipped" |
| Gear, right | 1068 | 92 | 96 | 464 | Hands, Back, Right hand, Left hand |
| Stats | 756 | 614 | 408 | 276 | An ornament rule above, then six rows, a fixed 6 px apart (each row grows with the text, so the column still fits its 820 px at the largest text step, 1.2; texttest 9 Nov): a 26 px engraved glyph, the name (18), a 10 px bar from x 888 to 1076, the value right-aligned (SemiBold 18, outlined) |

The 8 gear slots are the 6 wear slots in `items.json` (head, body, legs, feet, hands, back) plus the two hands. There is no belt slot in the game, so none is drawn. An empty gear slot shows an engraved silhouette of what goes there (helmet, tunic, trousers, boot, glove, pack, a hand axe, a shield) and no word.

The six stats are the six bars Dave approved on 21 Oct (Health, Exertion, Energy, Temperature, Food, Water), named as the game names them (Dave, 04:25 UTC: "the actual traits are Exertion and Energy"). They are the only bars. Weight lives in the pack header, not here.

### 4.3 Craft (inside x 1226 to 1876)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title plate | 1254 | 30 | text + 60 | 46 | "CRAFT" engraved; station context on the right of the title row: "By hand" or "At: Campfire" (SemiBold 18) |
| Category tabs | 1226 | 100 | 48 | 588 | 11 raised tabs of 48 x 48, 6 apart, each an engraved 28 px glyph: All, then the 10 recipe categories. The selected tab is lit with a bright rim and a gold glyph |
| Recipe search | 1282 | 100 | 196 | 36 | Filters the list; the placeholder names the tab ("Search tools") |
| Recipe list | 1282 | 146 | 196 | 766 | Rows of 44, 3 apart, with a faint rule between rows. A 32 px icon and the name (18). Rows you can't make yet are dimmed to 45 %. A recipe that needs a station is 64 tall and has a second grey line: the station's 20 px glyph and "needs Forge". The selected row is lit, its name SemiBold gold, with a 4 px brass bar on its left edge |
| **Recipe card** | 1490 | 100 | 386 | 812 | A raised card, one step lighter than the panel, with a 1 px top highlight and a 6 px soft shadow |
| · Icon | 1504 | 112 | 96 | 96 | The made item in a well with the soft gold inner glow |
| · Name | 1616 | 114 | 248 | 94 | Name Cinzel Bold 30; "Tools" and "By hand · 10 s" in dim 18 |
| · Description | 1504 | 222 | 360 | 44 | Two lines, 18 (from `items.json`) |
| · Stats | 1504 | 278 | 360 | 96 | Up to 4 lines of 24: label dim on the left, value cream on the right, a faint leader line between |
| · Needs | 1504 | 388 | 360 | 168 | "Needs" (Cinzel 22, small caps) and a gold rule; requirement wells of 80, 16 apart (4 fit); the item name under each (18) and **have / need** (SemiBold 18, outlined; red only when short). A 22 px engraved chest glyph in the top right of a well whose stock comes from a nearby chest. An item with no icon yet shows the missing-icon tile (art brief row 27) |
| · Quantity | 1504 | 570 | 360 | 42 | "Make", −, the number in a well, +, "Most" |
| · Shortfall line | 1504 | 620 | 360 | 24 | Red, only when something is short, saying what will happen |
| · Made at | 1504 | 656 | 360 | 48 | Head "Made at" (Cinzel 22, small caps) with a gold rule; then the station's 22 px engraved glyph and its name: "By hand, anywhere", or "Campfire, within 3 m" (from the recipe's `station` and `station_level`) |
| · Used in | 1504 | 714 | 360 | 48 | Head "Used in" with a gold rule; then up to 2 recipe names that take this item (as a need, or kept as their tool), SemiBold 18 gold, underlined, clickable to select that recipe, and "+N more" in dim. For the stone axe: Log seat · Small wooden blocks · +1 more. A recipe with no uses leaves this block out and the card shrinks |
| · Queue | 1504 | 784 | 360 | 48 | An ornament rule above; "Making" and up to 5 queued items as 56 px wells; the first has a 3 px gold progress arc. Click one to cancel it |
| · Craft button | 1504 | 848 | 360 | 58 | Cast brass with "CRAFT" engraved (Cinzel Bold 26, letter-spaced 4) and a faint warm glow round it when you can make the item; hold for the ring (left end) to make "Most" |

The 10 categories are the ones in `recipes.json`: Tools, Weapons, Shelter and building, Workshops and stations, Fire and cooking, Food and drink, Medicine, Clothing, Containers and furniture, Materials.

### 4.4 Chest mode (the right column when a container is open)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title plate | 1254 | 30 | text + 60 | 46 | The container's name engraved; on the right two raised tabs of 118 x 36: **Chest** and **Craft** (Craft still works with the chest open) |
| Bar | 1226 | 100 | 650 | 44 | "Keep out of crafting" tick box; **Take all** and **Store all** as key hints (keys **A** and **G**, changeable in Key bindings; T was proposed for Take all but is the transfer key) |
| Chest grid | 1226 | 158 | 650 | 540 | The same 100 px wells, 6 across, 10 gaps; it scrolls for big containers |
| Tools | 1226 | 716 | 650 | 32 | Key hints: **F** Sort both, **Q** Stack into my chests |

Shift-click or drag moves a stack between the pack and the chest. Ctrl-click moves one.

## 5. Interaction

- **Open and close:** the inventory key opens the window on Craft; Esc or the same key closes it. Opening a chest opens it in chest mode.
- **While the window is open** the in-world HUD (compass, debug text, stat bars) is hidden; the hotbar strip stays exactly where it is and becomes a drop target, because it is the same control in and out of the window. The world behind is darkened by the backdrop (6.1).
- **Point** at a slot: it brightens and glows (6.5), and the info strip shows it. Nothing floats over the grid.
- **Click** selects; **drag** moves; **shift-click** sends to the other side (chest, or pack to hotbar); **right-click** splits half; **a number key while pointing** puts that item on that hotbar key.
- **Search** filters live, and Esc clears the search before it closes the window.
- **Craft:** pick a tab, pick a row, check the needs, press Craft. Items are taken from the pack, then loose stacks within 3 m, then your own containers within 12 m (that is how it already works; the chest glyph shows it).
- **Text size** (Settings) scales the body text only (18 to 24); slots, tiles and buttons keep their size, so the layout never breaks.
- **Reduce motion** (Settings) makes every motion in 6.5 instant, as now.

## 6. The look

### 6.1 Three depth levels

Everything sits on one of three levels, and each level is one step lighter than the one below. This is what makes a screen read as built rather than drawn.

| Level | What | Colour | Finish |
|---|---|---|---|
| 1. Backdrop (darkest) | Behind the panels: the world, darkened | #17150F at 85 % over the world | A soft vignette (edges down to 45 %) and a faint leather grain (±5 levels) |
| 2. Panel field | The inside of each panel | #231A12 | Faint parchment: soft blotches (±4) and horizontal fibres (±5). A 10 px shadow inside its top edge, where it sits under the leather |
| 3. Raised | Buttons, tabs, keycaps, the hotbar tray, the recipe card, the selected row | #302419 (lit: #402F1F) with a slight top-to-bottom gradient (+8 at the top) | A 1 px top highlight (#523E29; lit #6E5436), a 1 px dark rim (#140D08), a 6 px soft drop shadow (black 60 %, 3 px down) |
| Recessed | Slots, fields, bars, the quantity number | #120C08 | An inner shadow 7 px down from the top (black 75 % to 0) and 4 px in from the left (50 % to 0); a 1 px light line along the bottom (#463626) and a fainter one on the right |

The backdrop over the world is the one place anything shows through, and only in the margins round the panels. The panels themselves stay solid (Dave, 23 Oct).

### 6.2 The frame

- **Aged leather edge, 14 px**, on all three panels: #3A2315 with a coarse grain (±14 levels), a 2 px dark outer line (#160C06), a 1 px light line just inside the top (#604028), and **stitching** 7 px in from the outside: 5 px stitches every 9 px in #B89A68, each with a 1 px dark shadow under it. Corners rounded 12. A 1 px gold line (#8C6933 at 60 %) where the leather meets the field.
- **Cast brass corner pieces**, 46 x 46, over each corner, 4 px outside the panel: an L of two 15 px arms with a gusset and cut tips, a diagonal brass gradient (#F0CF82 top left to #7A5826 bottom right), a dark rim (#4A3416), a bright top-left edge, a few worn scuffs, and one rivet. A soft shadow under each.
- **Brass title plate** behind each panel name, 46 tall, 30 px of brass each side of the title, sitting across the top frame (y 30 to 76): a vertical brass gradient, a bright top line, a dark bottom line, a rivet at each end, and the title engraved into it.
- **Ornament rules** divide sections: a 1 px gold line (#8C6933 at 67 %) with a small open diamond in the middle.

### 6.3 Type (nothing under 18 px)

| Role | Font | px | Colour | Notes |
|---|---|---|---|---|
| Panel titles | Cinzel Bold | 34 | #2B1B0B engraved on brass | Letter-spaced 3 px; a 1 px light line under each letter (#FAE2A0 at 60 %) so it reads as cut into the plate |
| Item names | Cinzel Bold | 30 | #F2C76B | |
| Craft button | Cinzel Bold | 26 | #2B1B0B engraved | Letter-spaced 4 px |
| Section heads ("Needs") | Cinzel Regular | 22 | #F2C76B | Small caps (Cinzel's lower case is small caps) |
| Body, descriptions, rows, labels | EB Garamond Regular | 18 | #F5E6BD | |
| Secondary (labels, "needs Forge", "Tools") | EB Garamond Regular | 18 | #8A7E68 | |
| Values, have / need, weight | EB Garamond SemiBold | 18 | #F5E6BD | 1 px #0A0604 outline |
| Stack counts | EB Garamond SemiBold | 24 | #F5E6BD | 1 px #0A0604 outline |
| Key numbers and keycaps | Cinzel Bold | 18 | #F2C76B | 1 px outline on slots |

**Every number has a 1 px dark outline (#0A0604)** so it reads over any icon. Text colours: cream for reading, gold for names and titles, dim for secondary, red only for a shortfall or a warning.

### 6.4 Colours (hex)

| Use | Hex |
|---|---|
| Backdrop | #17150F |
| Panel field | #231A12 |
| Raised / raised lit | #302419 / #402F1F |
| Raised top highlight | #523E29 |
| Recessed well / its bottom lip | #120C08 / #463626 |
| Leather / its outer line / stitching | #3A2315 / #160C06 / #B89A68 |
| Brass highlight / face / shade / dark | #F0CF82 / #C9A054 / #7A5826 / #4A3416 |
| Gold line, rules | #8C6933 |
| Selected and hover rim, glow | #FFD67A |
| Hover glow round a slot | #FFB34D at 43 % |
| Text: cream / gold / dim / disabled | #F5E6BD / #F2C76B / #8A7E68 / #6A6050 |
| Engraved glyphs / empty-gear silhouettes | #C9A869 / #4A3C2E |
| Engraved text on brass | #2B1B0B |
| Red (shortfalls and warnings only) | #BF2E24 |
| Number outline | #0A0604 |
| Durability: good / worn / nearly broken | #8FA35A / #C9A054 / #BF2E24 |

**The stat bars are all warm**, each only slightly different, and each with an engraved glyph rather than a coloured dot. The fill runs from 25 % lighter at the top to 20 % darker at the bottom, with a faint highlight along the top.

| Stat | Glyph | Fill |
|---|---|---|
| Health | heart | #A8452F |
| Exertion | lightning bolt | #C08F3E |
| Energy | crescent moon | #9C7B52 |
| Temperature | flame | #C86F35 |
| Food | loaf | #A88A44 |
| Water | drop | #6F8A86 (weathered pewter) |

No purple, cyan or bright yellow anywhere.

**Decided (coordinator, 9 Nov 04:21 UTC, under Dave's standing "you are in charge"): the six HUD bars at the top of the screen change to this warm set too, with the same glyphs, so the HUD and the inventory match.** This replaces the brighter colours approved on 21 Oct. It is done in step 1 of the plan (section 12), with the canvas pass.

### 6.5 Motion and polish

| What | Rule |
|---|---|
| Hover on a slot, row, tab or button | Brightens 0.1 s ease-out: the fill toward the lit colour, the rim to #FFD67A, and a 4 px warm glow (#FFB34D, 5 px blur) round a slot. 0.1 s back when the pointer leaves |
| Selected slot | A soft gold inner glow: #FFD67A at 55 % on the rim fading to nothing 8 px in, plus a 1.5 px #FFD67A rim |
| Press | Raised things drop 1 px and lose their shadow for the press (0.05 s) |
| Hold ring on Craft | A smooth arc (no steps), 4 px, round caps, filling clockwise from the top over the hold time; it eases out on the last 10 % |
| Craft ready glow | When you can make the selected recipe, a warm glow round the button (#FFC864 at 35 %, 10 px blur) breathes between 70 and 100 % every 2.4 s |
| Item arriving | Flies to its slot in 0.18 s, the slot flashes gold once (0.25 s) |
| Tab change | The list cross-fades in 0.12 s; no sliding |
| Numbers | Counts and values change instantly (no rolling digits), always with the 1 px outline |
| Sounds (Kathleen's sound list) | A soft leather tap on hover of a tab, a wooden click on press, a brass chime on craft done |

### 6.6 The character

The middle column shows the **live 3D character** (the SubViewport the character screen already has), framed a little larger than the gear columns:
- a key light from the top left;
- a warm rim light from behind on the right (#FFD68C);
- a soft round ground shadow (black 80 %, 168 x 26 px);
- a dim warm pool of light behind (#784E2C at 30 %, 40 px blur).

It turns slowly when you drag it, and it wears what is in the gear slots.

### 6.7 Icon rules

1. **One camera for every icon:** the same three-quarter view (30° down, 45° round), key light from the top left, the item filling 80 % of the square, a 2 px soft drop shadow (black 65 %, 1.5 px blur, 2 px right and down), no background.
2. **Thin items lie on the diagonal,** bottom left to top right, corner to corner, with the head (axe blade, spear point) at the top right. Stroke at least 6 px wide at 128 so it is at least 2 px at 32.
3. **Tell things apart by shape, not tint.** Each plank species gets its own end grain and bundle shape plus a tint. Spades differ in blade shape (round, square, pointed). Herbs differ by leaf shape. Seeds come in a small cloth pouch with the seed shape on it. Pies get a crust mark (a fish, a leaf, an apple cut).
4. **Shown at** 80 px in pack and chest slots, 60 in hotbar slots, 32 in recipe rows, 64 in requirement wells, 90 in the recipe card.
5. **Painted, not rendered:** the 446 baked icons are the base; the painted pass adds hand-painted texture to match the look doc (section 6). **log, stick and stone have no icon yet** and are the most common items in the game; they come first. Until an item has an icon it shows the missing-icon tile, never a blank or a placeholder blob.

## 7. Why this beats ARK, Dragonwilds and Valheim

**ARK.** ARK's inventory is powerful but crowded: small square slots, many tabs and buttons around the edges, and a lot of numbers on every slot. Players learn to live with it rather than like it. Ours keeps what works (a big grid, search, sort, a gear figure in the middle, a hotbar you can fill from the pack) and drops the clutter: slots twice the size on screen, one number per slot, one place to read about an item, and the craft card right beside the pack instead of in another tab.

**Dragonwilds.** Dragonwilds is the cleanest of the three: big, calm slots, a clear crafting table with a recipe card, and a strong fantasy frame. Its weak points are that the pack and crafting are separate screens, and that a recipe's missing parts don't tell you what to do next. Ours shows the pack, you and the craft card at once on one 1920 x 1080 screen, marks parts that come from a nearby chest, and says plainly what Craft will do when you are short ("makes the twine first").

**Valheim.** Valheim's crafting is loved because it is simple: a list, a card, one button. But the list has no categories or search, the station context is easy to miss, and the inventory grid is small and plain. Ours keeps the list-card-button idea, adds 11 category tabs and a search that fit Valheim's simplicity, puts "By hand" or "At: Campfire" in the title where you can't miss it, and badges recipes that need another station.

**Better than all three:** nothing under 18 px, nothing floating over the grid, nothing hidden that you need, and one look (walnut, gold, cream) that belongs to our world.

## 8. Art brief

Everything goes in `assets/ui/inventory/`. Sizes are canvas px at 1920 x 1080; **paint at 2x and export at the size given**. "9-slice" means the art is cut into a 3 x 3 grid with the given margins so it stretches without stretching the corners (Godot `StyleBoxTexture` or `NinePatchRect`). PNG, sRGB, straight alpha. The mockup script draws every one of these in code from the same numbers, so a painter can match the PNG it renders, and the game can ship with the code-drawn version until the painted one lands.

| # | Asset | File | Size px | Material | Colours (hex) | Description |
|---|---|---|---|---|---|---|
| 1 | Backdrop grain | `backdrop_grain.png` | 512 x 512, tiling | Fine leather grain | #17150F, ±5 levels | Tiled over the darkened world behind the panels, at 85 %; the vignette is drawn in code |
| 2 | Panel frame | `frame_leather.png` | 128 x 128, 9-slice margins 20 | Aged dark leather, coarse grain, worn lighter at the edges | Leather #3A2315, outer line #160C06 2 px, top inner light #604028, stitches #B89A68 with #000 shadow, gold line #8C6933 at 60 % at the inner edge | The 14 px edge of every panel, stitching 7 px in (5 px stitch, 4 px gap), corners rounded 12; the centre is transparent |
| 3 | Panel field | `field_parchment.png` | 512 x 512, tiling | Dark parchment | #231A12, blotches ±4, fibres ±5 | The inside of every panel |
| 4 | Panel shadow | `panel_shadow.png` | 96 x 96, 9-slice margins 32 | Soft shadow | #000000 at 75 %, 14 px blur, 8 px down | Under each panel |
| 5 | Brass corner | `corner_brass.png` | 46 x 46 (one; flipped for the other three) | Cast brass, worn | Gradient #F0CF82 to #7A5826 (diagonal), rim #4A3416, scuffs #7A5826, rivet #4A3416 with a #F0CF82 highlight | An L of two 15 px arms with a gusset and cut tips, one rivet in the corner; placed 4 px outside each panel corner |
| 6 | Title plate | `title_plate.png` | 96 x 46, 9-slice margins 24 left and right | Cast brass | Gradient #F0CF82 to #7A5826 (top to bottom), top line #F0CF82, bottom line #7A5826, rim #4A3416, rivets as #5 | The plate behind each panel title; it stretches to the title width + 60 |
| 7 | Ornament rule | `rule_ornament.png` | 24 x 12 (the diamond; the line is drawn in code) | Engraved gold | #8C6933 | The diamond in the middle of a section rule |
| 8 | Recessed well | `well.png` | 100 x 100, 9-slice margins 10 | Recessed dark wood | #120C08, top inner shadow 7 px black 75 % to 0, left 4 px 50 % to 0, bottom lip #463626, right lip #463626 at 43 % | Every slot (100 in the pack, 76 on the hotbar, the same 9-slice), field, bar track and the quantity number; corners 4 |
| 9 | Well selected | `well_selected.png` | 100 x 100, 9-slice margins 10 | Inner gold glow | #FFD67A rim 1.5 px; glow 55 % at the rim to 0 at 8 px in | The selected slot, the active hotbar key, the recipe card icon |
| 10 | Slot hover glow | `slot_hover.png` | 116 x 116, 9-slice margins 18 | Warm glow | #FFB34D at 43 %, 5 px blur | Round a slot under the pointer (with #9) |
| 11 | Raised plate | `raised.png`, `raised_lit.png`, `raised_pressed.png` | 96 x 48, 9-slice margins 10 | Smooth dark wood, slight gradient | Normal #382A1D to #302419; lit #483727 to #402F1F; pressed #261B12 flat; top highlight #523E29 (lit #6E5436); rim #140D08 | Buttons, tabs, the selected row, keycaps |
| 11a | Hotbar tray | `hotbar_tray.png` | 882 x 108, 9-slice margins 20 | The panel leather (#2) with its stitch line (#3) and a cast brass end plate at each end (#4 colours, 22 x 92, two rivets) | Leather #3A2315; stitch #B89A68 dashed 1.5 px, 6 px in; brass #F0CF82 to #7A5826 | The hotbar strip under the window and in the world (section 9) |
| 12 | Raised shadow | `raised_shadow.png` | 48 x 48, 9-slice margins 16 | Soft shadow | #000000 at 60 %, 6 px blur, 3 px down | Under every raised thing except the selected row |
| 13 | Recipe card | uses #11 and #12 | 386 x 936 | | | The card is the raised plate at size |
| 14 | Craft button | `button_brass.png`, `button_brass_pressed.png` | 96 x 64, 9-slice margins 16 | Cast brass | Gradient #F0CF82 to #7A5826 top to bottom, top line #FFECB4, rim #4A3416; pressed 10 % darker, no top line | The Craft button; "CRAFT" engraved in #2B1B0B |
| 15 | Craft glow | `button_glow.png` | 128 x 96, 9-slice margins 32 | Warm glow | #FFC864 at 35 %, 10 px blur | Round the Craft button when the recipe can be made |
| 16 | Hold ring | drawn in code | 36 x 36 | | Track #7A5826 4 px; arc #2B1B0B 4 px, round caps | Left end of the Craft button |
| 17 | Keycap | uses #11 | 26 tall, 26 wide or the text + 14 | | Letter #F2C76B Cinzel Bold 18; a 1.5 px dark line under it | Key hints on the item strip and the chest bar |
| 18 | Stat glyphs | `stat_health.png`, `stat_exertion.png`, `stat_energy.png`, `stat_warmth.png`, `stat_food.png`, `stat_water.png` | 26 x 26 each | Engraved metal, flat fill | #C9A869 with a 1 px #000 shadow at 70 % below | A heart, a lightning bolt, a crescent moon, a flame, a loaf, a drop |
| 19 | Bar fill | `bar_fill.png` | 32 x 10, 9-slice margins 5 | Smooth enamel, tinted in code | White to grey gradient (tinted to the stat fill: +25 % at the top, −20 % at the bottom), a 1 px highlight at 27 % along the top | The six stat bars and the weight bar (tinted #C9A054) |
| 20 | Gear silhouettes | `ghost_head.png`, `ghost_body.png`, `ghost_legs.png`, `ghost_feet.png`, `ghost_hands.png`, `ghost_back.png`, `ghost_right.png`, `ghost_left.png` | 52 x 52 each | Engraved, flat | #4A3C2E with a 1 px #000 shadow below | A helmet, a tunic, trousers, a boot, a glove, a pack, a hand axe, a shield; centred in an empty gear slot, no word |
| 21 | Category tab glyphs | `tab_all.png`, `tab_tools.png`, `tab_weapons.png`, `tab_building.png`, `tab_stations.png`, `tab_fire.png`, `tab_food.png`, `tab_medicine.png`, `tab_clothing.png`, `tab_storage.png`, `tab_materials.png` | 28 x 28 each | Engraved, flat | Off #F5E6BD, selected #F2C76B, 1 px #000 shadow | All: four squares. Tools: an axe. Weapons: a spear. Building: a house. Stations: an anvil. Fire: a flame. Food: a steaming bowl. Medicine: a leaf. Clothing: a tunic. Storage: a chest. Materials: three planks |
| 22 | Station glyphs | `station_workbench.png`, `station_forge.png`, `station_campfire.png`, `station_campfire_pot.png`, `station_clay_hearth.png`, `station_oven.png`, `station_saw_mill.png`, `station_woodworking_table.png` | 20 x 20 each | Engraved, flat | #8A7E68 | On the second line of a recipe row that needs a station, before "needs Forge". Workbench: a bench. Forge: an anvil. Campfire: a flame. Pot: a pot over a flame. Hearth: a clay dome. Oven: an arched oven. Saw mill: a saw blade. Woodworking table: a plane |
| 23 | Chest glyph | `mark_chest.png` | 22 x 22 | Engraved, flat | #C9A869 | Top right of a requirement well whose stock comes from a nearby container |
| 24 | Search and sort glyphs | `glyph_search.png`, `glyph_sort.png` | 18 x 18, 20 x 20 | Engraved line | #8C6933, #C9A869 | In the search fields and on the sort button |
| 25 | Selected-row bar | `row_bar.png` | 4 x 40, 9-slice top and bottom 4 | Brass | #F0CF82 to #7A5826 top to bottom | Left edge of the selected recipe row |
| 26 | Durability bar | drawn in code | 4 px tall | | #8FA35A / #C9A054 / #BF2E24 on #0A0604 | Bottom of a slot |
| 27 | Missing-icon tile | `icon_missing.png` | 80 x 80 (scales) | Hatched | Hatching #3A2C1F every 10 px, dashed rim #8C6933 (6 on, 5 off) 6 px in, a "?" in Cinzel Bold 30 #8C6933 | Shown in place of any item icon that does not exist yet, so a gap is obvious and never mistaken for an item |
| 28 | Item icons | `assets/ui/items/<item_id>.png` | 128 x 128 | Painted over the icon bake (look doc section 6), to the rules in 6.7 | No background; 2 px soft shadow added in the slot, not painted | Every item. First: log, stick, stone (none yet), then the 94 in NEEDS_PAINTING.txt, then the look-alike sets in 6.7 |
| 29 | Character light rig | in the character SubViewport | | | Key light warm white from the top left; rim #FFD68C from behind right; the ground shadow and the backlight pool are drawn in code (6.6) | Set on the existing character view |

Fonts are not art assets; they are in `assets/ui/fonts` (Cinzel Regular and Bold, EB Garamond Regular and SemiBold).

## 9. HUD hotbar strip (in the world)

The hotbar is one control, shown the same way with the window open or closed: ten 76 px recessed wells (#8), 10 px apart (850 x 76, x 535 to 1385, y 964 to 1040), on the leather hotbar tray (#11a, 882 x 108, 24 px above the bottom of the canvas), key numbers in EB Garamond SemiBold 18 with the outline, the active key in the selected well (#9), durability bars as in the pack. Opening the inventory does not move or redraw it; the three panels appear above it. The pickup feed and the held-item label sit above the tray (their offsets in section 13 move up to clear 132 px instead of 84).

## 10. What this replaces

`inventory_view.gd` window building, `ui/inventory/item_slot.gd` (64 px slot at unit 1), `pack_grid.gd`, `recipe_list.gd`, `container_panel.gd`, `craft_queue.gd`, `pinned_recipe.gd`, `parchment_tooltip.gd` (replaced by `ArtKit.card` and the info strip; moved to `proposed_removals/` by #797) and `inventory_look.gd`. #780's shrink-to-fit is not needed once the window is laid out at fixed canvas sizes; #780 was closed unmerged on 9 Nov, so none of it landed.

## 11. Open points for Dave

1. **Hotbar: 10 slots of 76 across the bottom of the screen** (v4, coordinator 04:37 UTC after Dave's 04:35 question), the same control in and out of the window.
2. **Solid panels,** as he asked on 23 Oct; only the margins round them show the darkened world.
3. **The floating tooltip goes;** the info strip under the pack replaces it.

## 12. Implementation plan (after Dave's look; no code before the go)

**The canvas.** The canvas has been 2880 x 1620 since the first commit, in `project.godot` (`viewport_width` and `viewport_height`) and in `display_settings.gd` (`BASE`). It returns to **1920 x 1080** in this work; content scale mode `viewport` and aspect `keep` stay as they are, and the window override stays 1920 x 1080. Every existing UI scene then has its sizes rechecked at that canvas (section 13), because every fixed number in them was drawn at two-thirds size until now.

Steps, each its own PR through the gate. Status 9 Nov 09:15 UTC: steps 1 to 4 are merged (#785 canvas, #787 art kit, #789 frame, #790 pack, #791 craft card, #793 You column, #796 chest tabs, #797 cleanup, #798 chest keys, #794 hotbar strip); step 5 has the painted log, stick and stone (#795) and the icon importer (#800), with the baked icons to follow.

1. **Canvas to 1920 x 1080** plus the section 13 fixes for the menus and the HUD, so nothing gets worse on the day the canvas changes. The six HUD bars move to the warm colours and glyphs of 6.4 in the same pass.
2. **The art kit** (section 8) as placeholders drawn in code first (the colours and sizes above), so the layout lands without waiting for the art; the painted PNGs drop in later with no code change.
3. **The new window:** the three columns, the pack and chest grids, the You column, the craft card, the info strip, search and sort. Removes the old window building (#780's fit never landed).
4. **The hotbar strip**, one control used both in the world and under the open window (section 9), in the new slot art, with the pickup feed and held-item label moved up to clear it.
5. **The painted art** as Kathleen's art jobs finish (art brief rows 1 to 27), then the icons (row 28).

### 12.1 Notes from Dave's review (9 Nov, 04:25 UTC)

Dave: *"if we skip putting it in the mockup it won't get fixed later"*. So each note is drawn in the v3 mockup (and kept in v4) and written into the tables above:
1. **No dead space in the recipe card:** "Made at" and "Used in" (4.3). The data has no "unlocks" field (the skill web in `skill_web.gd` unlocks skills, not recipes), so "Unlocks" is not shown.
2. **Stat names stay the game's own:** Exertion and Energy (Dave: "the actual traits are Exertion and Energy, we are making a change in the way gamers see it"), and Temperature as the character screen already says. Only the colours and glyphs change (6.4).
3. **The full name on the brass plate,** no line under it (4.2).
4. **The tenth hotbar key is shown as 0,** because 0 is the key you press; the digit keys 1 to 9 and 0 are fixed to the hotbar and cannot be rebound (`key_bindings.gd` `refusal`). The key-hint row says "1–0 Put on hotbar" (4.1), and the strip labels its tenth slot 0.
5. **The centre column is the live character model wearing what is equipped,** from the character screen's SubViewport, re-dressed when a gear slot changes, with the light rig in 6.6. It is never a flat silhouette; the mockup's figure is a stand-in that shows where the gear goes.

## 13. Audit: screens with sizes fixed for the 2880 x 1620 canvas

Searched on main 295da042 for fixed font sizes, minimum sizes, offsets and positions, and for anything that reads the canvas size. "Today" is how big it shows on a 1920 x 1080 window (two-thirds of the number in the code). "New" is the number to write at the 1920 x 1080 canvas, using the type scale in section 6.3: titles 30, headings 22, body 20, small 18, big announcements 40; buttons at least 44 tall.

**Already scaled to the window** (they divide by the window height and multiply by 1080, so they look the same before and after the canvas change): `inventory_view.gd` `_px`, `character_screen.gd`, `pickup_feed.gd` font (through `text_px`), `hotbar_strip.gd`, `held_item.gd` line 1132, and the `ui/inventory/*` parts. These need no size fix for the canvas; the inventory parts are replaced by this redesign anyway.

| File | Line(s) | Now (canvas px) | Today on screen | New at 1920 x 1080 |
|---|---|---|---|---|
| `project.godot` | 32-33 | viewport 2880 x 1620 | | 1920 x 1080 |
| `src/client/display_settings.gd` | 11-16 | `BASE` 2880 x 1620 and its comment | | 1920 x 1080, comment rewritten |
| `scenes/terrain_client/terrain_client.gd` | 3210-3215 | 3D scale = render width / `BASE.x` | | Formula stays. Medium (1920) becomes 1.0 and Ultra (2560) becomes 1.33, which is supersampling: clamp to 1.0 unless Dave wants Ultra to supersample |
| `scenes/terrain_client/terrain_client.gd` | 984-999 | notice title 40, note 24, note width 900, buttons 380 x 52 | 27, 16, 600, 253 x 35 | title 30, note 20, width 640, buttons 280 x 48 |
| `src/client/ui/dynasty_theme.gd` | 147 | theme default font 26 | 17 | 20 |
| `src/client/game_menu.gd` | 19, 101, 111, 127, 150-156 | `BUTTON_W` 420; warnings 30; scroll height = window − 300, 200 to 760 | 280; 20 | `BUTTON_W` 300, buttons 48 tall; warnings 20; scroll = window − 220, 160 to 560 |
| `scenes/title/title_settings.gd` | 15, 73, 79, 161-173 | `BUTTON_W` 420; "more" 22; buttons and rows 52 tall at 26 | 280; 15; 35 at 17 | 300; 18; 48 tall at 20 |
| `scenes/title/title_art.gd` | 12-13 | `IMAGE_SIZE` 1670 x 941, `BUTTON_H` 65 | 1113 x 627, 43 | 1280 x 720, 52 |
| `src/client/key_bindings_page.gd` | 10-11, 37-38, 47, 69, 90, 98 | status 1300 wide at 26; scroll 1300 x 820; key column 300; rows 48; labels 28 and 24 | 867 at 17; 867 x 547; 200; 32; 19 and 16 | status 900 at 20; scroll 900 x 640; key column 220; rows 44; labels 22 and 20 |
| `src/client/connect_window.gd` | 25-52 | box 980; title 40; body 26; buttons 300 x 52 at 26 | 653; 27; 17; 200 x 35 at 17 | box 680; title 30; body 20; buttons 220 x 48 at 22 |
| `src/client/character/page_style.gd` | 5-8, 19-22, 48 | fonts 22 / 28 / 24 / 30; buttons 64 tall | 15 / 19 / 16 / 20; 43 | 20 / 22 / 22 / 30; buttons 52 tall |
| `scenes/character_select/character_select.gd` | 14, 73, 101, 139, 196 | rows 190; Play 240 x 72; rename field 48 | 127; 160 x 48; 32 | rows 140; Play 220 x 56; field 44 |
| `scenes/creator_proto/creator_proto.gd` | 89, 146, 201-232 and 15 more | left column 660; labels 150 wide; fields 48 tall | 440; 100; 32 | left column 480; labels 120; fields 44; fonts from `page_style.gd` |
| `src/client/dialogue_view.gd` | 7, 89-143, 201 | text 26, name 30, text width 700, shop 28 | 17, 20, 467, 19 | text 20, name 22, width 560, shop 20 |
| `src/client/death_screen.gd` | 49-57 | text 28; button 24; box placed at (300, 260) | 19; 16 | text 30; button 22; box centred with anchors, not placed |
| `src/client/cavein_death.gd` | 74 | text 44 | 29 | 40 |
| `src/client/idle_timeout.gd` | 162 | warning 40 | 27 | 40 |
| `src/client/held_item.gd` | 193-194, 1515 | label 60 above the bottom at 26; hoe menu 40 | 40 at 17; 27 | 84 above the bottom at 20 in step 1 (over today's strip); step 4 moves it to 132 above the bottom, clear of the 108 px hotbar tray and its 24 px margin; hoe menu 26 (same as the hammer menu) |
| `src/client/hammer_blueprints.gd` | 30-33, 70-75, 327 | menu 40; detail 28; menu at most 75 % of the height | 27; 19 | menu 26; detail 20; 75 % stays |
| `src/client/admin_compass.gd` | 8-10, 22, 63-66 | 900 x 64; names 32, ticks 20; text drawn at y 34 and 28 | 600 x 43; 21, 13 | 640 x 48; names 22, ticks 18; text at y 26 and 22 |
| `src/client/horizon_indicator.gd` | 9-10, 35-40, 120 | 160 wide; 4 px per degree; 40 px to the side; hint 22 | 107; 2.7; 27; 15 | 110 wide; 3 px per degree; 28 to the side; hint 18 |
| `src/client/status_icons.gd` | 15 | icons 88 | 59 | 60 |
| `src/client/pickup_feed.gd` | 24-25 | box at 28, 40 from the top left | 19, 27 | 24, 32 (the outer margin) |
| `src/client/menu_switch.gd` | 18 | 96 x 44 | 64 x 29 | 96 x 44 stays (it grows to its intended size) |
| `src/client/sound_panel.gd` | 52-74 | panel at 16, 16, 520 wide; scroll 500 x 420 | 347; 333 x 280 | at 24, 24, 400 wide; scroll 380 x 320; fonts from the theme (20) |
| `src/client/debug_hud.gd` | | the theme default font | 17 | 20 through the theme (F3 text) |
| `src/debug/shot_runner.gd` | 966, 1077, 1236, 1274, 1118-1518 | screenshot tags 40 and 36; reads the window size | | Debug only: tags 26 and 24; the size reads stay. Shots taken before and after the change are not pixel-comparable |
| `src/debug/jitter_test.gd`, `gpu_probe.gd`, `machine_probe.gd` | | debug overlays with fixed sizes | | Debug only: fonts from the theme; no layout change |
| `src/client/hit_numbers.gd`, `src/client/npc_view.gd` 233 | | `Label3D` font sizes 64 and 48 | | **Not affected:** these are 3D labels in the world, sized in metres, not on the canvas |
| `src/client/link_bars.gd` | 115 | drawn from a unit that follows the window | | No change |
| The inventory parts | | `item_slot.gd` 64 px slot, counts 14, keys 12, captions 12; `parchment_tooltip.gd` 18 / 22, min 14 | 54, 12, 10, 10; 13 / 16, min 10 | **Replaced by this redesign** (section 10) |

No `.tscn` scene in the repo sets fixed sizes; all of the above are built in code.
