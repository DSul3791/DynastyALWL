# Inventory and crafting: look and feel

Kathleen (art direction), 8 Nov 2026. This is a design doc only: no code and no renders. It goes with Morgan's `INVENTORY_CRAFTING_REPORT.md`, whose six calls are decided. It sets out how the new one-screen inventory, chest and crafting window looks and answers to the hand. It is built on `art/Art_Direction.md` (the twelve approved paintings) and on the menu look already in the game (`src/client/ui/dynasty_theme.gd`: dark walnut, gold frame, cream serif lettering).

## 1. The idea in one line

**A craftsman's chest of drawers, lit by candlelight.** The window is the same dark polished walnut and gold as the Esc menu and the title buttons, so the game reads as one thing. The inventory is open dozens of times an hour, though, so it is calmer than the title page: thinner gold, less glow, and more room for the items themselves. The items are the colour on the screen. The frame stays quiet around them.

## 2. What the reference games teach (from memory, not rechecked today)

| Game | How it reads on screen | Take | Leave |
|---|---|---|---|
| **Valheim** | Dark, see-through panels with orange highlights and small painted icons. Moody, but cramped, and the tooltips are low in contrast. | Warm dark panels; painted icons with a strong silhouette; an orange-gold hover. | See-through panels (Dave, 23 Oct: nothing of the game shows through); tiny text. |
| **Ark** | Flat, clean blue panels with two grids side by side, big stack counts and Transfer All buttons. Very readable, but sci-fi in tone. | Pack and chest side by side; counts that read at a glance; bulk buttons always in the same place. | The flat blue technical look, and walls of numbers. |
| **RuneScape Dragonwilds** | Warm leather and parchment tones, chunky rounded slots, big friendly painterly icons, and a clear "linked" chest marker. | Generous slot size; big painterly icons; parchment for reading text; a small marker on materials that come from a chest. | Its slightly cartoon shapes: we are 85 % real. |

## 3. Layout as it looks

- **Three columns in one solid window:**
  - left: **recipes**, grouped by station depth;
  - middle: the **chest or station**, shown only when one is open;
  - right: the **pack**.
- One search box sits across the top. The four bulk buttons (Take all, Store all, Stack to nearby, Sort) always sit in the same place, under the chest panel.
- **Weight** shows as a short gold bar in the pack header, filling toward amber, then red, as the load nears the carry limit.
- **Hotbar:** a separate strip of 10 slots along the bottom of the screen, in the same slot style. It stays visible while the window is open, so items can be dropped onto it. Each slot carries its number (1 to 0) small in its top-left corner.
- **Header plates:** each column has a small carved name plate in Cinzel and gold, for example "Pack", "Oak chest" or "Smithy". An open station shows its emblem on the plate (hammer and anvil, pot, saw). The frame stays gold everywhere, so the window never changes colour by station.

## 4. Panels

- Solid `WOOD_DARK` with a **2 px** `GOLD` frame (the menu uses 3 px) and 6 px corners. The deep soft shadow is kept.
- Columns sit inside the frame as slightly lighter inset boards, `WOOD` at about 60 %, divided by a 1 px `GOLD_DIM` rule.
- Ornament goes only on the outer frame's four corners: small brass corner plates, like a studded chest. Nowhere else. The paintings put the gold on edges, not on every surface.
- A faint wood grain can come later as one tiling texture at 6 % strength. It must never make the items harder to see.

## 5. Slots

- **Size:** 64 px at the default text size, scaled with the existing text size setting. Gaps are 4 px and corners 4 px.
- **Look:** recessed into the wood, as if carved.
  - The fill is darker than the board: `SLOT_BG`.
  - A 1 px dark inner edge sits top and left, and a 1 px light inner edge bottom and right.
  - The border is 1 px `GOLD_DIM`.
- **Stack count:** bottom-right, Cinzel 14 px in cream with a 1 px dark outline, so it reads over any icon.
- **Durability:** a 3 px bar along the bottom edge. It is forest green when full, gold at half and heraldic red near broken. It is hidden when full, to keep the grid calm.
- **States** (each change eases in 80 ms):

  | State | Look |
  |---|---|
  | Hover | Border `GOLD_BRIGHT`, a 6 px warm `GLOW` round the slot, fill lifts toward `WOOD_LIT` by 30 %. |
  | Picked up / dragging | The slot dims to 50 %. The icon follows the pointer at 90 % size with a soft drop shadow. |
  | Valid drop target | That panel's frame glows softly while the drag is over it. |
  | Invalid drop | The slot flashes heraldic red for 150 ms with the error click. |
  | Favourite | A small gold wax seal in the top-left. Sort and the bulk buttons skip it. Not shown on the hotbar, whose key number has the top-left. |
  | Hotbar link | The pack slot of an item the hotbar points at shows its key number in gold at the bottom-left (the count has the bottom-right, the quality corner the top-right). |
  | New item | A soft gold shimmer that fades over 2 s the first time it appears. |

- **Room for quality later** (call 6): the top-right corner of each slot is kept free for a small quality gem or band once those rules exist.

## 6. Icons

- **Painted, one object, three-quarter view**, on a transparent background.
- **Light:**
  - one warm key light from the top left, the same for every icon;
  - a thin cool rim light, so dark things (iron, charcoal) separate from the wood;
  - a 1 to 2 px dark outline round the silhouette.
- **Colour that tells you the material at a glance** (art direction: rich, never grey-brown mush):
  - iron: cool steel with a blue edge;
  - copper and bronze: orange and gold;
  - wood: honey to walnut;
  - stone: blue-grey;
  - herbs: green;
  - food: warm red and gold;
  - cloth: the dye colour.
- **Size:** 128 px source, shown at about 48 to 56 px inside a 64 px slot.
- **Silhouette test:** every icon must read as a solid black shape at 32 px. A stack of logs and a single log must look different.
- **How they are made:**
  - an icon bake from each item's own 3D model on Dave's PC, in a fixed light rig, then touched up by hand where needed;
  - small items with no model (seeds, twine, nails) are painted to the same rig;
  - never baked in the cloud.

## 7. Lettering

- **Cinzel** (carved capitals, already in `assets/ui/fonts`) for column plates, tab names, button labels and stack counts.
- **EB Garamond** for item names, recipe rows, descriptions and tooltips.
- Body text is never under 14 px, and it follows the existing text size setting.
- **Tooltips sit on a parchment card**, not on wood: `PARCHMENT` with `INK` text, a thin `GOLD_DIM` edge and a soft shadow.
  - It reads like a page from the wizard's book, it gives the best contrast for longer text, and it separates "reading" from "handling".
  - The order on the card: item name in Garamond semibold; one line of use; weight and value; then, for a greyed recipe, what is missing and which chest holds it.

## 8. Colours

Reuse `dynasty_theme.gd`: `WOOD_DARK`, `WOOD`, `WOOD_LIT`, `GOLD`, `GOLD_DIM`, `GOLD_BRIGHT`, `GLOW`, `CREAM`, `CREAM_DIM` and `HEADING`. Add only these:

| Name | Colour (r, g, b) | Use |
|---|---|---|
| `SLOT_BG` | 0.08, 0.05, 0.035 | the recessed slot |
| `PARCHMENT` | 0.93, 0.86, 0.70 | tooltips and the pinned recipe card |
| `INK` | 0.20, 0.12, 0.07 | text on parchment |
| `GOOD` | 0.42, 0.66, 0.30 (forest green) | craftable, full durability |
| `WARN` | 0.92, 0.66, 0.22 (amber gold) | half durability, nearly over the weight limit |
| `BAD` | 0.75, 0.18, 0.14 (heraldic red) | missing ingredients, broken, invalid drop |
| `MAGIC` | 0.62, 0.72, 1.00 (cold blue) | enchanted items only, matching the paintings' rule that magic is the only cold light |

Colour is never the only signal. A missing ingredient also shows its count in red, for example "2 / 5", and a greyed recipe also shows the word "Needs".

## 9. Recipes and crafting feedback

- **Craftable recipe row:** a warm gold bar on its left edge, with full-colour icons. **Not craftable:** icons at 70 % desaturation and 60 % opacity, a red missing count, and the "Makes 5 twine first" helper as a small wooden button on the row.
- **Materials from a chest** (call 1): the ingredient shows a tiny chest mark, like Dragonwilds' "linked" marker. A chest with "keep out" ticked shows a small lock on its name plate. ("Keep out" only excludes a chest from crafting; the four-digit code lock in s14 is a separate setting and needs a different icon.)
- **Click to craft:**
  - the recipe icon presses in by 2 px;
  - a gold ring fills round it as the queue works;
  - when an item finishes, its icon pops (1.15 times, back over 150 ms) and flies to its slot or the hotbar (250 ms) with a soft wooden knock.
- **Bulk buttons:** a short toast on parchment, for example "12 stacks into 3 chests". Each chest that took something glows briefly in the world.
- **Pinned recipe:** a small parchment card at the screen edge with check marks that tick off as you gather.

## 10. Sound (needs Dave's listen before it is turned on)

The slot sounds in `slot_sounds.gd` stay the base, so the feel is wood, leather and iron, never electronic beeps:
- pick up: a soft leather lift;
- drop: a wooden tap that is heavier for heavy items;
- invalid: a dull knock;
- craft done: a short tool sound of the station (a saw stroke, a hammer tap, a pot lid);
- bulk store: a chest lid and a shuffle.

## 11. Motion and comfort

- Every animation is 250 ms or shorter, nothing bounces more than once, and nothing shakes.
- Hover tooltips wait 300 ms, then follow the pointer without lag.
- A "reduce motion" setting turns the fly-to-slot and the shimmer into instant changes.
- Every action stays reachable with one pointer action (call 5), and every hover state also shows for keyboard focus, so a controller port later needs no new art.

## 12. Do not

- The flat blue sci-fi look (Ark), or grey stone slabs.
- See-through panels.
- Ornament on every slot.
- Thin grey text.
- Icons lit from different sides.
- Colour as the only signal.

## 13. Pictures, once it is built (not now)

Dino's shots on Dave's PC, each at the small and large text sizes:
1. pack alone;
2. pack beside an open chest;
3. at the smithy;
4. hovering a greyed recipe whose wood sits in a nearby chest;
5. mid-craft with the ring filling;
6. the hotbar with the window closed.

## 14. Later owner-approved storage/food UI extensions (design only)

**Supersession notice:** This UI art/layout document is dated 8 Nov 2026. Later item decisions and permission rules are recorded in [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md) §§3.12–3.16 and elaborated in [STORAGE_WAREHOUSING_DESIGN.md](STORAGE_WAREHOUSING_DESIGN.md) and [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md). The master catalog remains the authority for approved and proposed item status.

**Approved storage UI [D13]:**
- Opening an accessible crate/chest nearby still uses the familiar pack-and-container interface; the player can see and manipulate its own real inventory, with no forced visit to a desk.
- A Warehouse Desk or Storage Sign is an optional **combined view over multiple local physical containers**. Search, deposit, withdraw, remaining room and per-container location must show **only crates that this interacting player has permission to use**. The UI does not create an extra shared pool or magically move crates.
- An owner may open/manage their **own locked crates from an in-range Warehouse Desk** without entering a code. A desk owner does **not** gain rights to other players' containers by owning the desk.
- Crates and chests may have optional **owner-assigned 4-digit codes** (allow `0000`). Unauthorized users can submit the right code for that individual locked container, including through a desk, without making it public. Hide secrets and other players' private contents.
- After wrong code attempt #1/#2/#3/#4, show lockout countdown **10/20/30/40 seconds**, then +10s per additional consecutive failure; success resets the player's streak for that container. Use the same player+container state in both direct and desk views. The owner bypasses code entry.
- Moving the *loaded* same crate from one warehouse to cart/wagon to future ship to another warehouse changes the local aggregated view automatically; the old desk immediately loses the moved crate. Future ship **Captain's Table** is a planned view on the same storage system, **not an approved ship item yet**.
- Use compatible dark-walnut/gold/cream styling from §§1–13; add a clear container breadcrumb, lock status/owner access, filtering and noncolour status indicators. No functional UI change has been implemented.

**Approved food UI [D12]:** Food Preparation Table is a recipe UI for making tangible uncooked/prepared food items, which are then finished at correct cooking stations. Kitchen knives/board/rolling pin are built into the visible table model, not required inventory tools. For simple foods use cooking stations directly.

**Owner-approved boards [D15] and pending preservation [P14-v2]:** The Food Preparation Table handles straightforward **preservation batches**, including real sealed jars that mature automatically. The **preservation NEW ITEM roster is NOT approved yet**. A functional generic reusable Serving Platter presents **the nine OWNER-APPROVED edible boards** on existing dining tables, where real servings disappear as diners eat. Previous lists of 15 or 20 are superseded. Do not invent gameplay JSON or models yet.

**Future food-benefit UI [D16]:** Display **three compact active-food effect slots**, each with the primary food group, food identity, main bonus and separate expiry countdown. Active foods must belong to **different groups** (Main Meals, Breads & Grains, Fruit & Vegetables, Desserts, Beverages, names provisional); food from an occupied group replaces that effect, while eating a fourth distinct group should offer a simple replace-one choice. Explicitly show temporary Fitness/skill XP boosts, no XP bonus from ordinary grain/bread, and any dessert XP downside; overlapping XP modifiers don't compound. Normal hunger and calories are separate from effect slots. **Percentages/durations are not yet owner-approved**.

**Learned food tips [P17 — proposed future content]:** NPC conversations or readable guides may reveal effective role-oriented combinations to a knowledge journal, using actual available foods and effects. No mandatory book gate, class restriction or secret extra buff. Avoid displaying unavailable coffee/mana/spell skill functionality.

This section records **future look/interaction intent only**. No gameplay code, data schema, or merge has been authorized by its presence.
