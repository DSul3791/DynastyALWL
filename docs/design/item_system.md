# Dynasty — Item System: Current Implementation Reference

**Current target specification, 13 Nov 2026.** This document has been consolidated after the new creator decisions; **the previous Draft 7 forge, bloomery, smithy-level and copper-tool restrictions have been removed**, rather than retained as competing instructions. The previous version remains recoverable through Git history if provenance is ever needed. No gameplay code is changed by this document.

**Canonical references**:
- [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md): item identities, active design, durable rules, seven building tiers, tools, food, storage, production stations and exact separately built doors.
- [progression.md](progression.md): playable progression and material dependency order.
- [PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md](PLAYER_PROGRESSION_MISSING_SYSTEMS_REPAIR_PLAN.md): missing mechanics and phased gameplay repair.
- [PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md](PLAYER_GOALS_DECISION_RECOVERY_2026-11-13.md): 80 finding/651 goal audit dispositions.
- [PLAYER_CARTOGRAPHY_MAP_DESIGN.md](PLAYER_CARTOGRAPHY_MAP_DESIGN.md): explored charcoal Map and Mapping skill.
- [CATALOG_IMPLEMENTATION_PLAN.md](CATALOG_IMPLEMENTATION_PLAN.md): original Mission 001 baseline and subsequent implementation workflow. Source code/data remains evidence of the running state, not a separate design authority.

## Naming and item identity

Follow master catalog item names and approved house styles. The player-facing name must not be derived from technical IDs if a proper display name exists. Do not silently rename Crude, Rustic, Refined, Sturdy, Superior, Engineered, or Fortified building components into unrelated synonyms. **Planks and Hardwood Boards are separate materials and never substitute for one another** in crafting, blueprints, refills or NPC jobs; 3 m softwood/basic Logs yield six Planks, while 3 m hardwood Logs yield four Hardwood Boards through a saw or sawmill. Do not resurrect species-specific retired beams/lumber.

New item IDs must not reuse retired numbers. Reconcile existing `stone_forge`, `blacksmithy`, `large_forge`, `master_forge`, `open_storage_bin`, any retired Anvil and old add-on IDs via the item ledger and explicit migration. The approved new metal tier design does not retroactively prove the code implements it.

## Tool and production progression

- First stages: Wooden/Stone tools and both **Primitive Smelter and Primitive Smithy** built without metal, Planks, Nails or higher-tier components. The Primitive Smithy's stone anvil allows Copper/Bronze shaping. Copper tool families are approved as a useful new progression step; determine exact items and performance based on real game roles before adding every possible Copper version.
- **Three smelters:** Primitive (Copper/Tin/Bronze; 20 fuel +20 input, **ground drops for output**, 20 seconds/ingot); Improved (40/40/80, manually operated bellows = Iron enabled +30% speed, otherwise only primitive materials at baseline); Advanced (80/80/160, **one integrated windmill/two bellows**, automatic batches, **zero output without adequate wind**, **two ingots per ~11.83 seconds nominal**).
- **Four Smithies:** Primitive with stone anvil; Improved with bronze anvil, Iron Saw and Iron Anvil, ironwork accelerates wear; Advanced uses Iron Anvil and makes Steel Anvil; Master uses Steel Anvil, integrated quencher and suitable Tempered/masterwork craftsmanship.
- **Smelting**: 1 Copper Ore→1 Copper Ingot; 1 Tin Ore→1 Tin Ingot; 1 Iron Ore→1 Iron Ingot; 1 Copper Ore +1 Tin Ore→2 Bronze Ingots. Steel requires Iron Ore with separately consumed Coal/Charcoal **in the input**, plus Coal/Charcoal fuel **in the hopper**. No tracked temperature. Exact steel carbon ratio and per-ingot fuel burn are open, not old values.
- **Smithy repairs**: a broken placed smithy remains, cannot be opened normally, says **"Needs repair"**. Use equipped ordinary hammer's **right-click → Repair** with required materials carried, nearby in storage or on nearby ground. **War Hammers cannot repair**. Never create a special Repair Hammer item. Exact recipe and restoration percentage still need balance.
- Tool durability, item-instance enchantments, sharpening, workbench levels and graded equipment follow master §§2.1–2.9 and the actual authority records. Metal tools may remain broken for repair while disposable early tools vanish at zero; this is separate from persistent broken *stations*.

## Storage, sourcing and manufactured goods

- Resource Bins: one item type, first item in assigns, empty reassigns. Small/Medium/Large **1,000/5,000/10,000 units**, recipes **16 Planks+32 Nails / 32+64 / 64+128**. Solid sides/open top with a moving single resource-surface mesh.
- The earlier Open Storage Bin is an existing item ID: consolidate as the Small bin if migration of any previous mixed contents can be made safe; do not create duplicate small-bin blueprints.
- Automated **smelter/smithy fuel hopper** sourcing: produced Coal/Charcoal from eligible assigned bins, fires and kilns within **30 m**, once every **300 seconds**, oldest station first, no permission check. No wood, ground drops, generic chests, or automatic feeding of steel's separate carbon ingredient. Ordinary building/crafting/repair material sourcing still uses eligible nearby storage/ground with player inventory and its own existing radius and permissions.
- Other storage/warehouse permission systems are unchanged: locked freight crates follow their owner/access rights; the no-permission fuel rule is **not** a general warehouse-unlocking rule. See [STORAGE_WAREHOUSING_DESIGN.md](STORAGE_WAREHOUSING_DESIGN.md).
- All production and item transfers must conserve item counts under simultaneous operations, save/load, drops and cross-station sourcing.

## Goals, usability and release

The Goal/Guide system is a **full-game automatic guide**, not a forced tech tree or manual claim menu. Use one Inventory/Crafting-styled Journal with **J** Index, **G** Goals and **M** discovered charcoal Map. An upper-right simple thin-border HUD shows only the **first two unfinished goals**. All eligible goals remain tracked automatically, including out-of-order actions. Do not invent separate menus, popups or progress-meter panels.

The Map is a new per-character sketch of genuinely discovered terrain. Mapping skill rises from exploring and making Map Scrolls; returning to previously explored areas with higher skill improves their accuracy. Future scrolls may be shared/sold, subject to approved content/transfer rules.

Gameplay repair must restore tanbark from suitable oak, Scots Pine pine-tar drops, usable filled water in crafting and actual client sow/water/harvest actions, with proof from a fresh player walk. Do not silently convert outdated recipe quantities, blueprints or coin amounts as a documentation-only change. Do not revive obsolete forge or bloomery designs.

## Implementation validation

Before changing live JSON, resolve every listed material source, station requirement, component identity, recipe cost and goal dependency. Preserve item numbers and keep unimplemented targets explicitly labelled not-yet-playable. Use a scoped reviewed branch/PR into `dev`; protect `main`. Test actual Godot gameplay, persistence and concurrency. Retired historical source text is obtainable from Git history and is not an active instruction in this file.
