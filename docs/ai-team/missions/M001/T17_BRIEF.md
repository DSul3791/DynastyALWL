# M001-T17 brief: Phase 10 movable loaded crates and the Handcart

Mission 001, Phase 10 (`docs/design/CATALOG_IMPLEMENTATION_PLAN.md`). Owner: systems-engineer agent. Reviewer: independent gate-reviewer. Branch `m001/p10` in clone `E:\Software\godotDev\m001_p10` (base `b6ccb3c53` = dev `d21a4bcaa` tree: Phase 9 storage with locks, `_may_access` and the Warehouse desk; Phase 5 bags in instance data; protocol 109). New game: no migration.

Parallel work: Phases 7-8 (m001_p7: food effects, platters; protocol 110). Your protocol: 111. Your numbers: structure states 290-299, blueprints 250-259, recipes 700-719.

## Behaviour (master `docs/design/DYNASTY_MASTER_ITEMS.md` s3.11 rules and reconciliation table, s3.13 loaded crates and locked-crate rule, s7 items 17 and 19; companion `docs/design/STORAGE_WAREHOUSING_DESIGN.md` s4-s6)
1. **A persistent movable world entity** (the first in the game): a Handcart that a player pushes or pulls (one controller at a time; the player is the puller, s3.11 RECOMMEND), saved with its position, owner and cargo, synced to clients, parked when released. It is built from a hammer blueprint of Planks/Hardwood boards, Wooden cart wheels and an Axle (after the first saw, s3.11 note) and dismantles into its materials with its cargo returned safely (never lost). Terrain limits: awkward on narrow, steep or rough ground (slope limit and speed penalty from data; deep water refuses).
2. **Wooden cart wheel and Axle** go live as craftable material rows at the Carpenter's bench (s7 item 17). The Reinforced wagon wheel and every animal vehicle stay FUTURE-GATED (phase 11).
3. **Cargo**: the Handcart has its own container inventory (slots and max_kg, more than a backpack) and can carry **loaded Warehouse crates and Crates** as cargo: lifting a loaded crate onto the cart and setting it down elsewhere moves the crate with its contents intact; contents keep ageing (spoilage continues in transit, `place_mult` of the cart); a crate that leaves a Warehouse desk's area drops out of that desk's view and joins the desk where it is set down; **locked crates obey the locked-crate rule** (only the owner or an authorized player may lift or move it; `_may_access` before every lift, as Phase 9 left the hook).
4. Conservation and authority everywhere: no duplication or loss when lifting, carting, setting down, saving mid-trip, disconnecting while pulling (the cart parks where it is), two players grabbing at once, dismantling a loaded cart.
5. Wire and save: the movable entity's state and cargo in the save (version bump where needed, set-aside for unknown versions as the code does), protocol 111 and PROTOCOL.md.
6. Looks: placeholders marked (NOT visually complete). Ledger rows updated (Handcart, Wooden cart wheel, Axle; Warehouse crate movement note); `catalog_ledger.py --check` passes.

## Rules
Work only in `E:\Software\godotDev\m001_p10`. Never touch `C:\GodotProjects\DynastyALWL` or other clones. Do not push. Godot only through the slot scripts with timeouts; never kill a Godot process you did not start. No catalog changes beyond the catalog text; report problems. Use existing Godot and project architecture where practical (Ponytail: smallest complete and correct change).

## Acceptance (voxel build `GODOT_EXE=/c/GodotInstaller/godot.windows.editor.x86_64.exe`)
- New tests asserting real server state: build a Handcart from its blueprint; move a loaded crate from warehouse A onto the cart, wheel it, set it down at warehouse B: contents identical, ageing continued, desk A no longer lists it, desk B does; save and reload mid-trip; a stranger cannot lift a locked crate, an authorized player can; disconnect while pulling parks the cart; dismantle a loaded cart returns everything; two players cannot both pull.
- `validate_items` PASS, `merge_check.py` clear, a clean full plan `python3 tools/tests_for_diff.py b6ccb3c53 HEAD` at the exact head with no new failures (known flakes: test_flora_density timeout under load, test_npc_view crash at quit).
- Performance: record the per-tick cost of the moving entity (it should only cost while moving).
- `/ponytail-review`; commit with `docs/ai-team/missions/M001/T17_RESULTS.md` (head SHA, counts with log paths, design, numbers, risks).
