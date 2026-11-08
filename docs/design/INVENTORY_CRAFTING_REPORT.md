# Inventory and crafting: design report

Morgan, 8 Nov 2026. Docs only, no code. **Status: Dave answered "yes to all" to the six open calls on 8 Nov 2026, so the recommendations in section 5 are decided. Implementation is not started and will be scheduled separately.** Commissioned by Dave: combine the best of Ark, Valheim, RuneScape Dragonwilds and the other games in our design docs into the easiest inventory and crafting system, at most one or two clicks per action.

Research was kept small to save tokens. **Checked today:** Dragonwilds storage and linking, and what the Valheim quick-stack mod adds. **From my own knowledge, not rechecked today:** Ark, Minecraft, Satisfactory, Medieval Dynasty and the rest. Treat those as pointers, not citations.

## 1. What we have now (from CONTROLS.md and the code)

**Already good, keep it:**
- One screen (I): recipes left, pack right, one search box filtering both, craftable recipes lit and on top.
- A server-side craft queue that runs with the screen closed, and click to cancel and refund.
- **Auto-make the missing part** (`craft_planner.gd`): pick a stone axe with no twine and the queue makes the twine first. This beats anything in the games below.
- Sort (name, weight, value), text sizes, quick keys on the hovered slot (E use, D drop, S split, R repair, T transfer).
- Blueprints already pull from the pack, loose stock and **containers within 30 m**.

**Gaps:**
1. **Craft takes 3 actions:** pick the recipe, set a count, press Craft.
2. **Crafting sees only the pack** (plus logs lying within 3 m). A recipe whose wood sits in the chest next to the bench shows as impossible. Building already sees chests, so the two disagree.
3. **The chest is a separate screen** (F or E), not a panel beside the pack. Moving things is click-then-click or T per stack. There is no "store all", "take all" or "stack into nearby chests".
4. **Hotbar is pack slots 1 to 10**, so sorting or picking things up can silently change what your keys hold.
5. **No favourites or locks**, so sort and bulk moves risk the wrong item.
6. **Size:** `inventory_view.gd` is 5,848 lines and 237 KB. Every change to this screen is risky until it is split into parts.

## 2. What the other games do well

| Game | Best idea | Source |
|---|---|---|
| **RuneScape Dragonwilds** | Crafting and processing use materials in any chest with a "Linked" tick, up to 12 m away. No shared bank; chests are physical objects, so you cluster them near stations. | [gamever.io](https://gamever.io/knowledge-base/player-built-storage-in-dragonwilds-12-to-64-slots-and-the-checkbox-that-lets-you-craft-from-them) |
| **Valheim** | Players fixed vanilla with mods that are now the wish list: stack into **nearby** chests in one press, restock ammo and food from them, Store All, sort, trash, and **favourites** that sorting and bulk moves never touch. Crafting from chests is also a popular mod. | [Quick Stack/Store/Sort mod](https://thunderstore.io/c/valheim/p/Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock/), [Craft With Containers](https://thunderstore.io/c/valheim/p/abearcodes/CraftingWithContainers) |
| **Ark** | Pack and container side by side in one window, hover and press one key to transfer, Transfer All, crafting in the same window. Its engram tree is the thing to avoid: too much menu before you can make anything. | my knowledge |
| **Minecraft** | Shift-click moves a stack to "the other side". The recipe book fills the grid with one click and shows what you are missing. | my knowledge |
| **Satisfactory** | Bulk and quick-move shortcuts on every slot; a recipe tells you where each part comes from. | my knowledge |

## 3. Recommendation: the "one click" rules

1. **Craft where you stand.** The count that matters is *pack plus storage in range*. One click on a craftable recipe makes one. Shift-click makes five. Hold to make as many as you can. The count box stays but is never required.
2. **One screen, two sides.** At a chest or station, the pack is on the right and the chest or station on the left, in the same window as the recipes. No separate chest screen.
3. **Shift-click moves a stack to the other side.** Double-click uses it (eat, hold, apply). Right-click opens the small menu (Split, Drop, Favourite, Repair). Hover shows why something is greyed out.
4. **Four bulk buttons:** Take all, Store all, **Stack to nearby chests**, Sort. Favourited items are skipped by all four.
5. **Hotbar is its own thing.** Ten slots that point at items. A tool you craft or pick up goes onto a free slot automatically. Sorting never changes them.
6. **Missing ingredients are a helper, not a wall.** A greyed recipe shows what is missing, which chest holds it, and the existing "Makes 5 twine first" button. A pinned recipe stays visible as a small checklist while you gather.
7. **Station context.** Opening a bench, kitchen or smithy shows that station's recipes first. Hand recipes are always there.
8. **Never more than two clicks** is checked as a table (below) before anything ships.

| Action | Today | Target |
|---|---|---|
| Craft one | 3 (pick, count, Craft) | 1 |
| Craft five | 3 plus typing | 1 (shift-click) |
| Craft with wood in the chest beside you | 4 or more (walk, take, close, craft) | 1 |
| Move one stack to a chest | 2 (or T) | 1 (shift-click) |
| Tidy the pack into nearby chests | many | 1 button |
| Take everything from a chest | one per stack | 1 button |
| Eat or hold | 1 to 2 | 1 (double-click) |
| Put a crafted tool on the hotbar | drag | 0 (automatic) |

## 4. How it fits the existing design

- **Crafting depths** (hand, camp bench, workshop, master) in DESIGN_IDEAS 5.3 stay. The screen just opens on the right depth.
- **More ingredients, better item** (decided, not built) needs optional extra slots on a recipe. The layout should leave room for them now.
- **Weight and carry** stay on the screen as today.
- **Multiplayer and households:** crafting may use only your own and your household's containers, never a stranger's chest (see call 2).
- **Build it in parts.** Split the 5,848-line `inventory_view.gd` into a recipe list, a pack grid, a container panel and a queue. The rebuild is only safe on those parts. Suggested owners: Steve for logic (what counts as "in range"), Kathleen for look. No new agent.

## 5. Decisions (Dave, 8 Nov 2026: "yes to all")

Each was a recommendation of mine; Dave accepted all six.

1. **[Decided] Which storage does crafting see?** *Recommended:* every chest of yours or your household's within about 12 m of you, with a per-chest "keep out" tick for people who want a private stash. (Dragonwilds uses an opt-in "Linked" tick, which is safer but means a setup step on every chest.) Your blueprint rule already uses 30 m, so pick one distance for both.
2. **[Decided] Other people's chests:** *Recommended:* never used for crafting, even in range.
3. **[Decided] Hotbar separate from pack slots?** *Recommended:* yes. It changes how Dave's "slots 1 to 10 of 30" rule reads.
4. **[Decided] Single screen with a side panel, or keep the separate chest screen?** *Recommended:* single screen.
5. **[Decided] Controller support** now or later? *Recommended:* later, but keep every action reachable with one pointer action so it ports.
6. **[Decided] Quality from extra ingredients:** design the optional slots now, or add them when you decide the quality rules? *Recommended:* leave room, decide later.

Next: write a one-page screen layout and the one-or-two-click table as a build brief for Steve and Kathleen.
