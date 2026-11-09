# Inventory and crafting redesign (9 Nov 2026)

Owner: Kathleen (art direction). Asked for by Dave, 9 Nov 2026 03:49 UTC: *"Keep it simple, keep it eloquent and keep it useful … make sure its not crowded and make sure it is easy to use for a human. Also make sure it uses the space on the screen and keeps things big enough to see. Make it better than those games."* References he gave: ARK Survival inventory, Dragonwilds inventory and crafting table, Valheim crafting.

Status: **design for Dave's look. No code until the coordinator says go.** #780 (inventory fit) stays as it is until this replaces it.

Mockup: `inventory_redesign_1920.png` (shared files, top level), drawn at 1920 x 1080 by `docs/ui/mockup/inventory_redesign_mockup.py` from the same numbers as this doc. Run it with `--all` to get the chest view and a copy with every box outlined and measured.

```
python3 docs/ui/mockup/inventory_redesign_mockup.py --out OUT --icons item_icon_sheet.png [--all]
```

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
| Outer margin | | | | | 32 all round |
| Gutter between columns | | | | | 24 |
| **Pack** panel | 32 | 32 | 680 | 1016 | |
| **You** panel | 736 | 32 | 448 | 1016 | |
| **Craft / Chest** panel | 1208 | 32 | 680 | 1016 | |
| Panel frame | | | | | 6 px carved edge + 4 px air = 10 px inside each panel edge |

The coordinator's spec put the pack grid at 680. The panel is 680 at its outside edge, so the grid inside the frame is **660**: 6 slots x 100 + 5 gaps x 12. The slots stay 100 px; only the gap is 12 instead of 16.

### 4.1 Pack (inside x 42 to 702)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title row | 42 | 42 | 660 | 48 | "Pack", Cinzel Bold 30, starts at x 72 to clear the corner cap |
| Search field | 414 | 48 | 240 | 36 | "Search the pack", filters the grid as you type |
| Sort button | 666 | 48 | 36 | 36 | Cycles the 6 sorts already in Settings (name, weight up and down, value up and down, unsorted) |
| Weight line | 42 | 96 | 660 | 24 | "Carrying 38.4 of 52 kg" (EB Garamond 18) and a 6 px gold bar from x 252 |
| **Hotbar row** | 45 | 134 | 654 | 60 | **10 slots of 60 with 6 px gaps** (keys 1 to 9 and 0), on a tray with a 1 px gold rim |
| **Pack grid** | 42 | 214 | 660 | 548 | 6 x 5 slots of 100, 12 px gaps (30 slots) |
| Info strip | 42 | 782 | 660 | 200 | A 100 px slot with the item, the name (Cinzel Bold 30), two lines of description (EB Garamond 20) and one line of facts (18) |
| Action buttons | 42 | 990 | 660 | 48 | Use (E), Drop (D), Split (S), Repair (R): four buttons of 156 with 12 gaps; a button that does not apply is greyed, never hidden |

**Hotbar: 10 keys, not 8.** The game has 10 hotbar keys (`inventory.gd` `HOTBAR_KEYS`), so 8 slots of 76 would leave keys 9 and 0 nowhere. 10 slots of 60 fill the same width. The key number is Cinzel Bold 18 in the top left corner.

**Slot contents:** the icon at 80 % of the slot (80 px in a 100 px slot), the stack count at the bottom right in EB Garamond SemiBold 24 with a 2 px black outline, and the durability bar 4 px tall along the bottom, 7 px in from each side (green over 60 %, gold over 30 %, red below).

### 4.2 You (inside x 746 to 1174)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title row | 746 | 42 | 428 | 48 | The character's name, Cinzel Bold 30, centred |
| Gear, left | 746 | 98 | 100 | 500 | Head, Body, Legs, Feet: 4 slots of 100, 33 px apart |
| Figure | 858 | 98 | 204 | 500 | The character, live (the SubViewport already in the character screen), turning slowly; drag to turn |
| Gear, right | 1074 | 98 | 100 | 500 | Hands, Back, Right hand, Left hand |
| Stats | 746 | 630 | 428 | 278 | Six rows, 48 apart: a 24 px coloured orb, the name (20), a 10 px bar, the value right-aligned (20) |

The 8 gear slots are the 6 wear slots in `items.json` (head, body, legs, feet, hands, back) plus the two hands. There is no belt slot in the game, so none is drawn. An empty gear slot shows its ghost glyph and its name in dim text.

The six stats are the six bars Dave approved on 21 Oct (Health, Exertion, Energy, Warmth, Food, Water), in their existing colours. They are the only bars. Weight lives in the pack header, not here.

### 4.3 Craft (inside x 1218 to 1878)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title row | 1218 | 42 | 660 | 48 | "Craft" (Cinzel Bold 30, from x 1248), station context on the right: "By hand" or "At: Campfire" (20) |
| Category tabs | 1218 | 98 | 48 | 588 | 11 tabs of 48 x 48, 6 apart: All, then the 10 recipe categories. A glyph each; the name shows as a tooltip-free label in the search field's placeholder ("Search tools") |
| Recipe search | 1274 | 98 | 196 | 36 | Filters the list |
| Recipe list | 1274 | 142 | 196 | 896 | Rows of 44, 4 apart (18 rows show; the list scrolls). A 32 px icon, the name (18). Craftable rows have a 4 px gold mark on the left; rows you can't make yet are dimmed to 45 %; rows that need a station show its 22 px badge on the right |
| Detail card | 1486 | 98 | 392 | 940 | Everything about the selected recipe |
| · Icon | 1486 | 98 | 128 | 128 | The made item in a 128 px slot |
| · Name and line | 1630 | 104 | 248 | 122 | Name Cinzel Bold 30; "Tools · by hand · 10 s" (18) |
| · Description | 1486 | 242 | 392 | 64 | Two lines, EB Garamond 20 (from `items.json`) |
| · Stats | 1486 | 316 | 392 | 144 | Up to 6 lines of 26 (chop, dig, warmth, food, lasts, mends with) |
| · Needs | 1486 | 476 | 392 | 164 | Heading "Needs" (Cinzel 22) and a rule; requirement tiles of 80, 12 apart (4 fit a row), each with the item name (18) and **have / need** (18; red only when short). A small chest mark on a tile whose stock is coming from a nearby chest |
| · Quantity | 1486 | 664 | 392 | 48 | "Make", −, the number, +, "Most" |
| · Shortfall line | 1486 | 724 | 392 | 24 | Red, only when something is short, saying what will happen ("Short 1 twine: Craft makes it first from fibre.") |
| · Queue | 1486 | 896 | 392 | 60 | "Making" and up to 5 queued items as 60 px slots; click one to cancel it |
| · Craft button | 1486 | 974 | 392 | 64 | Cinzel Bold 26, the accent button; press, or hold for the hold ring (40 px ring, 5 px stroke) to make "Most" |

The 10 categories are the ones in `recipes.json`: Tools, Weapons, Shelter and building, Workshops and stations, Fire and cooking, Food and drink, Medicine, Clothing, Containers and furniture, Materials.

### 4.4 Chest mode (the right column when a container is open)

| Part | x | y | w | h | Detail |
|---|---|---|---|---|---|
| Title row | 1218 | 42 | 660 | 48 | The container's name; on the right two tabs of 118 x 36: **Chest** and **Craft** (Craft still works with the chest open) |
| Bar | 1218 | 98 | 660 | 48 | "Keep out of crafting" tick box, **Take all** and **Store all** (150 x 48 each) |
| Chest grid | 1218 | 158 | 660 | 548 | The same 100 px slots, 6 across, 12 gaps; it scrolls for big containers |
| Tools | 1218 | 722 | 660 | 48 | **Sort both**, **Stack into my chests** |

Shift-click or drag moves a stack between the pack and the chest. Ctrl-click moves one.

## 5. Interaction

- **Open and close:** the inventory key opens the window on Craft; Esc or the same key closes it. Opening a chest opens it in chest mode.
- **While the window is open** the in-world HUD (hotbar strip, compass, debug text) is hidden, because the hotbar is in the window.
- **Point** at a slot: it lifts (amber glow, 2 px bright rim) and the info strip shows it. Nothing floats.
- **Click** selects; **drag** moves; **shift-click** sends to the other side (chest, or pack to hotbar); **right-click** splits half; **a number key while pointing** puts that item on that hotbar key.
- **Search** filters live, and Esc clears the search before it closes the window.
- **Craft:** pick a tab, pick a row, check the needs, press Craft. Items are taken from the pack, then loose stacks within 3 m, then your own containers within 12 m (that is how it already works; the chest mark shows it).
- **Text size** (Settings) scales the body text only (18 to 24); slots, tiles and buttons keep their size, so the layout never breaks.
- **Reduce motion** (Settings) makes the glow, lifts and fly-to-slot instant, as now.

## 6. The look

### 6.1 Material

One frame material everywhere: **carved dark walnut with a thin gold inlay line and brass corner caps**, on a solid dark field. No parchment panels, no second frame style. Parchment is kept for written things in the world (notes, books), not for the inventory.

### 6.2 Colours (hex)

| Use | Name | Hex |
|---|---|---|
| Panel field | WOOD_DARK | #1F130D |
| Frame wood, buttons | WOOD | #402617 |
| Frame highlight, selected tab and row, accent button | WOOD_LIT | #5C361C |
| Pressed button | WOOD_PRESSED | #2B1A0F |
| Slot well | SLOT_BG | #140D09 |
| Slot inner shadow | | #0A0604 |
| Slot lower lip | | #3A2416 |
| Gold inlay, rims, rules | GOLD_DIM | #8C6933 |
| Gold marks, weight bar | GOLD | #DBA84C |
| Selected and hover rim | GOLD_BRIGHT | #FFD67A |
| Hover glow | | #FFB34D at 47 % |
| Hotbar tray | | #2A1A11 |
| Figure backdrop | | #26180F |
| **Text: body** | CREAM | #F5E6BD |
| **Text: titles, names, key numbers** | HEADING | #F2C76B |
| **Text: shortfall only** | BAD | #BF2E24 |
| Disabled text (cream dimmed) | | #7A6E5C |
| Durability good | GOOD | #6BA84C |
| Bars | Health #D93333, Exertion #F2CC40, Energy #9973E6, Warmth #73CCF2, Food #E68C33, Water #4D99F2 | |

At most **three text colours**: cream, heading gold and red. Green is not used for "have enough"; enough is simply cream.

### 6.3 Type (nothing under 18 px)

| Role | Font | px |
|---|---|---|
| Panel titles, item names | Cinzel Bold | 30 |
| Craft button | Cinzel Bold | 26 |
| Section heads ("Needs") | Cinzel Regular | 22 |
| Body, descriptions, stats, button labels | EB Garamond Regular | 20 |
| Small: facts, list rows, hints, have / need | EB Garamond Regular | 18 |
| Stack counts | EB Garamond SemiBold, 2 px black outline | 24 (18 in slots under 80 px) |
| Hotbar key numbers, "All" tab | Cinzel Bold | 18 |

The fonts are already in `assets/ui/fonts`.

### 6.4 Icon rules

1. **Shown at 80 px** in pack and chest slots, 48 in hotbar slots, 32 in recipe rows, 64 in requirement tiles, 102 in the detail card. Rendered at 128 and scaled down.
2. **Thin items lie on the diagonal,** bottom left to top right, filling the square corner to corner, with the head (axe blade, spear point) at the top right. Stroke at least 6 px wide at 128 so it is at least 2 px at 32.
3. **Tell things apart by shape, not tint.** Each plank species gets its own end grain and bundle shape plus a tint. Spades differ in blade shape (round, square, pointed) and handle. Herbs differ by leaf shape. Seeds differ by seed shape and come in a small cloth pouch. Pies get a crust mark (a fish, a leaf, an apple cut).
4. **The same light for all:** key light from the top left, a soft 2 px dark outline (#0A0604), no background, no cast shadow.
5. **Painted, not rendered:** the 446 baked icons are the base; the painted pass adds hand-painted texture to match the look doc (section 6). **log, stick and stone have no icon yet** and are the most common items in the game; they come first.

## 7. Why this beats ARK, Dragonwilds and Valheim

**ARK.** ARK's inventory is powerful but crowded: small square slots, many tabs and buttons around the edges, and a lot of numbers on every slot. Players learn to live with it rather than like it. Ours keeps what works (a big grid, search, sort, a gear figure in the middle, a hotbar you can fill from the pack) and drops the clutter: slots twice the size on screen, one number per slot, one place to read about an item, and the craft card right beside the pack instead of in another tab.

**Dragonwilds.** Dragonwilds is the cleanest of the three: big, calm slots, a clear crafting table with a recipe card, and a strong fantasy frame. Its weak points are that the pack and crafting are separate screens, and that a recipe's missing parts don't tell you what to do next. Ours shows the pack, you and the craft card at once on one 1920 x 1080 screen, marks parts that come from a nearby chest, and says plainly what Craft will do when you are short ("makes the twine first").

**Valheim.** Valheim's crafting is loved because it is simple: a list, a card, one button. But the list has no categories or search, the station context is easy to miss, and the inventory grid is small and plain. Ours keeps the list-card-button idea, adds 11 category tabs and a search that fit Valheim's simplicity, puts "By hand" or "At: Campfire" in the title where you can't miss it, and badges recipes that need another station.

**Better than all three:** nothing under 18 px, nothing floating over the grid, nothing hidden that you need, and one look (walnut, gold, cream) that belongs to our world.

## 8. Art brief

Everything below goes in `assets/ui/inventory/`. Sizes are canvas px at 1920 x 1080. 9-slice means the art is cut into a 3 x 3 grid with the given margins so it stretches without stretching the corners (Godot `StyleBoxTexture` or `NinePatchRect`). PNG, sRGB, straight alpha. Paint at 2x and export at the size given.

| # | Asset | File | Size px | Material | Colours (hex) | Description |
|---|---|---|---|---|---|---|
| 1 | Panel frame | `frame_panel.png` | 96 x 96, 9-slice margins 16 | Carved dark walnut, 6 px edge with a fine bevel, a 1 px gold inlay line 5 px in | Wood #402617, bevel highlight #5C361C, inlay #8C6933, field #1F130D | The frame of all three panels and the chest panel; corners rounded 8 |
| 2 | Corner cap | `corner_cap.png` | 32 x 32 | Cast brass, slightly worn, one rivet | #DBA84C face, #8C6933 rim and rivet, #FFD67A highlight top left | Sits over each panel corner, 2 px outside the frame |
| 3 | Panel shadow | `panel_shadow.png` | 64 x 64, 9-slice margins 24 | Soft drop shadow | #000000 at 63 %, 12 px blur, offset 4 right 10 down | Under each panel so it lifts off the world |
| 4 | Slot well | `slot.png` | 100 x 100, 9-slice margins 8 | Recessed dark wood well | Fill #140D09, top and left inner shadow #0A0604, bottom and right lip #3A2416, 1 px rim #8C6933 | Pack, chest, gear, hotbar and tile slots; corners 4; one asset for every size |
| 5 | Slot hover | `slot_hover.png` | 116 x 116, 9-slice margins 16 | Warm glow | #FFB34D at 47 %, 5 px blur, and a 2 px rim #FFD67A | Shown round the slot under the pointer |
| 6 | Slot selected | `slot_selected.png` | 100 x 100, 9-slice margins 8 | Bright rim only | 2 px #FFD67A | The selected slot and the active hotbar key |
| 7 | Gear ghosts | `ghost_head.png`, `ghost_body.png`, `ghost_legs.png`, `ghost_feet.png`, `ghost_hands.png`, `ghost_back.png`, `ghost_right.png`, `ghost_left.png` | 56 x 56 each | Flat engraved silhouette | #5A4A3A at 100 % | A helmet, a tunic, trousers, boots, gloves, a pack, a hand holding a tool, a hand holding a shield or torch; shown in empty gear slots above the slot name |
| 8 | Hotbar tray | `hotbar_tray.png` | 96 x 68, 9-slice margins 8 | Darker wood strip | Fill #2A1A11, 1 px rim #DBA84C | Behind the 10 hotbar slots, inside the pack and on the HUD |
| 9 | Button | `button.png`, `button_hover.png`, `button_pressed.png`, `button_disabled.png` | 96 x 48, 9-slice margins 10 | Plank with bevelled edge | Normal #402617, hover #5C361C, pressed #2B1A0F, disabled #402617 with text #7A6E5C; rim 1 px #8C6933 | All plain buttons (Use, Drop, Take all, −, +, Most, tabs off) |
| 10 | Accent button | `button_accent.png`, `button_accent_pressed.png` | 96 x 64, 9-slice margins 12 | Lit plank with a gold rim | #5C361C, rim 2 px #FFD67A; pressed #402617 | The Craft button and the selected Chest / Craft tab |
| 11 | Hold ring | `hold_ring.png` | 40 x 40 | Gold stroke | #FFD67A, 5 px stroke, round caps | Used by a radial `TextureProgressBar` on the Craft button while held |
| 12 | Text field | `field.png` | 96 x 36, 9-slice margins 8 | Recessed well | #140D09, rim 1 px #8C6933 | Both search fields |
| 13 | Search glyph | `glyph_search.png` | 20 x 20 | Line art | #8C6933, 2 px | Magnifier in the search fields |
| 14 | Sort glyph | `glyph_sort.png` | 24 x 24 | Line art | #DBA84C, 3 px | Three bars, longest at top |
| 15 | Category tab glyphs | `tab_all.png`, `tab_tools.png`, `tab_weapons.png`, `tab_building.png`, `tab_stations.png`, `tab_fire.png`, `tab_food.png`, `tab_medicine.png`, `tab_clothing.png`, `tab_storage.png`, `tab_materials.png` | 36 x 36 each | Engraved line art with one flat fill | Off: #F5E6BD; selected: #FFD67A | All: four small squares. Tools: an axe. Weapons: a spear. Building: a log wall. Stations: a workbench. Fire: a flame. Food: a bowl with steam. Medicine: a leaf and a drop. Clothing: a tunic. Storage: a chest. Materials: two planks. (The mockup uses item icons as stand-ins) |
| 16 | Category tab plate | uses #9 and #10 | 48 x 48 | | | Off = button, selected = accent button |
| 17 | Station badges | `station_workbench.png`, `station_forge.png`, `station_campfire.png`, `station_campfire_pot.png`, `station_clay_hearth.png`, `station_oven.png`, `station_saw_mill.png`, `station_woodworking_table.png` | 22 x 22 each | Line art in a 1 px rounded box | #8C6933 | Small badges on recipe rows that need that station (the mockup uses letters as stand-ins) |
| 18 | Chest mark | `mark_chest.png` | 20 x 16 | A tiny chest | Body #5C361C, bands and lid line #DBA84C | Top right of a requirement tile whose stock comes from a nearby container |
| 19 | Stat orbs | `stat_health.png`, `stat_exertion.png`, `stat_energy.png`, `stat_warmth.png`, `stat_food.png`, `stat_water.png` | 24 x 24 each | A coloured enamel disc with a cream engraved symbol | Health #D93333 heart; Exertion #F2CC40 running figure; Energy #9973E6 moon; Warmth #73CCF2 flame; Food #E68C33 bread; Water #4D99F2 drop; symbol #F5E6BD | Left of each stat row |
| 20 | Bar track and fill | `bar_track.png`, `bar_fill.png` | 32 x 10, 9-slice margins 5 | Rounded groove and a plain fill (tinted in code) | Track #140D09; fill white, tinted by the bar colour | The six stat bars |
| 21 | Weight bar | uses #20 at 6 px tall | | | Fill #DBA84C, over the limit #BF2E24 | Pack header |
| 22 | Durability bar | drawn in code | 4 px tall | | #6BA84C over 60 %, #DBA84C over 30 %, #BF2E24 below; track #0A0604 | Bottom of a slot |
| 23 | Rule | drawn in code | 1 px | | #8C6933 | Section dividers |
| 24 | Figure backdrop | drawn in code | 204 x 500 | | #26180F, corners 6 | Behind the live character |
| 25 | Item icons | `assets/ui/items/<item_id>.png` | 128 x 128 | Painted over the icon bake (look doc section 6) | Outline #0A0604 2 px; no background | Every item. First: log, stick, stone (none yet), then the 94 in NEEDS_PAINTING.txt, then the look-alike sets in section 6.4 |

Fonts are not art assets; they are in `assets/ui/fonts` (Cinzel Regular and Bold, EB Garamond Regular and SemiBold).

## 9. HUD hotbar strip (in the world)

The HUD keeps a hotbar strip at the bottom centre when the window is closed. It uses the same tray (#8) and slot art (#4) at **60 px slots with 6 px gaps** (654 x 60), 24 px above the bottom of the canvas, with the key number in Cinzel Bold 18. The pickup feed and the held-item label sit above it.

## 10. What this replaces

`inventory_view.gd` window building, `ui/inventory/item_slot.gd` (64 px slot at unit 1), `pack_grid.gd`, `recipe_list.gd`, `container_panel.gd`, `craft_queue.gd`, `pinned_recipe.gd`, `parchment_tooltip.gd` (replaced by the info strip) and `inventory_look.gd`. #780's shrink-to-fit is not needed once the window is laid out at fixed canvas sizes, so it is removed by this work.

## 11. Open points for Dave

1. **Hotbar: 10 slots of 60 (all 10 keys) instead of 8 of 76.** Recommended, because the game has 10 keys.
2. **Solid panels,** as he asked on 23 Oct, rather than 85 % see-through.
3. **The tooltip goes;** the info strip under the pack replaces it.

## 12. Implementation plan (after Dave's look; no code before the go)

**The canvas.** The canvas has been 2880 x 1620 since the first commit, in `project.godot` (`viewport_width` and `viewport_height`) and in `display_settings.gd` (`BASE`). It returns to **1920 x 1080** in this work; content scale mode `viewport` and aspect `keep` stay as they are, and the window override stays 1920 x 1080. Every existing UI scene then has its sizes rechecked at that canvas (section 13), because every fixed number in them was drawn at two-thirds size until now.

Steps, each its own PR through the gate:

1. **Canvas to 1920 x 1080** plus the section 13 fixes for the menus and the HUD, so nothing gets worse on the day the canvas changes.
2. **The art kit** (section 8) as placeholders drawn in code first (the colours and sizes above), so the layout lands without waiting for the art; the painted PNGs drop in later with no code change.
3. **The new window:** the three columns, the pack and chest grids, the You column, the craft card, the info strip, search and sort. Removes the old window building and #780's fit.
4. **The HUD hotbar strip** in the new slot art.
5. **The painted art** as Kathleen's art jobs finish (items 1 to 24), then the icons (item 25).

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
| `src/client/held_item.gd` | 193-194, 1515 | label 60 above the bottom at 26; hoe menu 40 | 40 at 17; 27 | 84 above the bottom (over the 60 px HUD hotbar and its 24 px margin) at 20; hoe menu 26 (same as the hammer menu) |
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
