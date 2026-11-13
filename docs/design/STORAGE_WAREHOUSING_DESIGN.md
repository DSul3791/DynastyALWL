# Storage, warehouses, movable crates and access controls

**Status: OWNER-APPROVED DESIGN [D13]. Implementation: Mission 001 phase 9 (M001-T13, 12 Nov 2026) built the sixteen rows, code locks and the Storage sign and Warehouse desk views (`PROTOCOL.md` 108, `docs/ai-team/missions/M001/T13_RESULTS.md`); loaded movable crates (s4 rules 4 to 6, acceptance 6 to 8) are phase 10. The "Safety gate" line in s7 is the record from before the mission.**
**Authority:** `docs/design/DYNASTY_MASTER_ITEMS.md` §3.13 [D13] is the authoritative item catalog and decision source. This companion explains behavior, invariants, risks and acceptance scenarios; it introduces no additional item IDs, recipes, gameplay permissions or authorization to merge. On any conflict, the latest explicit Dave ruling recorded in the master catalog wins.

## 1. Player goal

Avoid settlement interiors filled with stacked generic chests. Storage should be beautiful, specialized and convenient: homes have cupboards, wardrobes and shelves; workshops have tool cabinets and materials bins; woodsheds have visible log/board/fuel piles; warehouses hold freight crates that move **loaded** between carts, wagons, ships and other warehouses. One local interface can aggregate available containers **without becoming a magical second inventory**.

## 2. Existing objects (KEEP, names subject to catalog rename)

| Stable item ID/number | Existing storage | Baseline slots / kg |
|---|---|---|
| `chest` #23 | Wicker Chest | 12 / 40 |
| `plank_chest` #29 | Wooden Chest → Rustic Chest under §3.5 | 20 / 150 |
| `iron_chest` #852 | Iron Chest → Ornate Chest under §3.5 | 30 / 250 |
| `wooden_crate` #850 | Crate | 10 / 80 |
| `wooden_barrel` #649 | Barrel | 8 / 60 |
| `wooden_cupboard` #647 | Cupboard | 16 / 60 |
| `wooden_shelf` #645 | Shelf | 8 / 30 |
| `log_shelf` #848 | Log Shelf | 6 / 30 |
| `hide_sack` #783 and `wicker_basket` #785 | Hide Sack and Basket | each 6 / 25 |
| `storage_jar` #781 | Storage Jar | 4 / 30 |
| `weapon_rack` #787 and `armour_stand` #789 | Weapon Rack and Armour Stand | each 6 / 40 |
| `root_cellar` #832 | Root Cellar | 12 / 120; cool storage |

**Cross-references only:** Rock Pile #235 is a physical 45-stone resource; Tool Rack #82 is a workbench upgrade, **not** the Tool Cabinet.

## 3. Sixteen established storage concepts and their current roles

| Group | Items |
|---|---|
| Household (6) | Large Wooden Chest; Wardrobe; Dresser; Bookcase; Apothecary Cabinet; Bottle & Jar Rack |
| Workshop (2) | Tool Cabinet; **Resource Bin family** (existing Open Storage Bin identity should map to Small, with Medium/Large as two size upgrades) |
| Bulk-material storage (5) | Firewood Rack; Log Rack; Lumber Rack; Mason's Pallet; Ore & Metal Rack |
| Shared zone interface (1) | Storage Sign / Ledger |
| Freight (2) | **Warehouse Crate**; **Warehouse Desk** |

The original storage family roster contained **16 concept types**; the existing Open Storage Bin is now a **three-size resource-bin family**, so do not use the old count as a final current item-total calculation. The Woodshed, Materials Yard and Storehouse are construction layouts (with the Granary, 4), not master item IDs. No separate crate label, warehouse membership token, lock/key or four-digit-code item. The Granary is a fourth layout of these pieces [D17], not a row. The Captain's Table belongs to a **future ship category**, not this 16-item list.

**Known design reconciliation before implementation:** §3.5 already provides graded Crude/Rustic/Fine/Ornate Chests. **Decided [D17]:** the Large Wooden Chest keeps greater weight capacity and a larger footprint, within the 30-slot limit; do not silently duplicate the Fine/Ornate grade. A large chest is eligible for the same code-lock mechanic as all approved chests. Existing #850 Crate remains and can join warehouse views; Warehouse Crate must have a meaningful stronger shipping/handling/stacking role, not just another differently named 10-slot crate. **Actual capacities, craft costs and stack height are unapproved tuning values.**

## 3.1 Approved Resource Bins — dedicated materials, not mixed chests

Resource bins are physical solid-sided/open-top wooden containers with **one visible material-surface mesh** whose height follows the actual fill fraction. They are not an inventory of interchangeable slots or a new full 3D volume mesh.

| Size | Units of ONE item | Exact construction |
|---|---:|---|
| **Small** | **1,000** | **16 Planks + 32 Nails** |
| **Medium** | **5,000** | **32 Planks + 64 Nails** |
| **Large** | **10,000** | **64 Planks + 128 Nails** |

**Assignment:** first successfully deposited resource determines what the bin holds; mixed types are refused until quantity reaches zero. When fully empty it automatically becomes unassigned; the next deposited item can be a different resource. Coal and Charcoal are separate types. Apply the same rule on multiplayer transfers and when smelter/smithy fuel automation empties a bin. No separate bin-type blueprints or manual assignment popup.

**Existing identity reconciliation:** `open_storage_bin` (#1232, blueprint #227) exists in current data as mixed loose-item storage (8 slots, 300 kg, old build cost 6 Planks+8 Wooden Pins). The creator's later size/fill rule replaces that **intended role**. Prefer mapping it to the Small size while preserving existing item numbers and safely handling any legacy placed contents. Do not add a duplicate Small bin without necessity. Existing mixed general chests/racks/warehouse freight remain separate and unchanged. Actual conversion and save handling need code/tests in a reviewed implementation.

**Fuel automatic sourcing, distinct from ordinary locked storage:** every 5 minutes (300 s), smelter/smithy fuel hoppers pull **only produced Coal/Charcoal** from eligible dedicated material bins, kiln or fires within **30m**, in **station creation order** with no permission check. The shared coal/charcoal filter is on the fuel hopper; any saved existing crate code and locked chest permissions still govern regular browsing and crafting. Never pull raw Wood/ground drops/generic mixed chests or silently add fuel to steel recipe INPUT.

## 4. Core physical-storage rules [D13]

1. Every container has its **own actual inventory**. The sign, desk, ship captain's table and station crafting views are **views/transactions** over qualifying nearby physical containers, not stores that duplicate them.
2. Players can stand next to an **accessible crate** and open its inventory, add, remove, sort and move items directly. The Warehouse Desk is an optional convenience, never the only access route.
3. A Warehouse Desk presents searchable totals, deposit and withdraw controls for *currently local, permission-eligible* containers; Storage Sign provides an aggregated area view, both backed by the **same authoritative storage system**.
4. A loaded warehouse crate can be moved **as a single physical cargo object** on appropriate carts/wagons and later aboard ships. Its contents, owner, code, lock state, durability and spoilage follow that *same uniquely identified crate*. Mass and volume include contents.
5. A crate joins its destination desk **from physical location**, not by a permanent ledger link. Move it from Warehouse A → cart → ship hold → Warehouse B and the eligible active view changes along the route. A ship's Captain's Table can use the same system *when separately approved and implemented*.
6. A crate never remains accessible through Warehouse A's interface after leaving A. At most **one active locality/context per crate** (Warehouse Desk, Storage Sign / Ledger, future Captain's Table); overlaps must resolve deterministically with ownership/physical position rules. Recommended: a desk takes priority over a sign covering the same crate, and a desk covers a stated radius or its enclosing building. No remote teleporting of goods, unlimited range, infinite load or duplicate transactions.
7. Stackable crates, material racks, shelves and wardrobe/weapon displays show reasonable **fill states** through low-cost grouped meshes, not thousands of physical item meshes. Actual inventory data and perishability remain authoritative.
8. A player's **ordinary local** workstation ingredient-sourcing rules still apply; this system must not allow crafting from every warehouse remotely. Locked containers feed normal crafting/NPC jobs only for players with access, and only the owner or authorized user may lift/load/take down a locked container. **Exception: automatic SMELTER/SMITHY fuel hopper collection is explicitly authorized by the creator WITHOUT permission checks** (only already-produced Coal/Charcoal in matching dedicated bins, kilns or fires, within 30m, every 300s, oldest station first). This exception is **not** permission to browse/unlock warehouse containers and does not apply to manual crafting or repair.

## 5. Crate/chest ownership, four-digit codes and lockout [D13]

**Owner rule — most important:** the **owner of a crate/chest** always has direct access, and can view/manage their **locked** container at any in-range Warehouse Desk or future Ship Captain's Table **without entering a code**. Ownership of a desk does **not** make its operator the owner of linked containers.

- The container owner may set/change/remove an **optional four-digit numeric code** on applicable crates and chests. Valid values `0000`–`9999`; **store and compare as exactly four digit characters, preserving leading zeros**.
- An unlocked/public container is accessible to a nearby player as appropriate. A locked container denies unauthorized entry.
- A non-owner given the correct code by the owner may enter it to access **that particular** locked container directly or through its current authorized warehouse/ship interface. Entering a code grants the entering player's access; **it does not unlock the crate for all players**. Other explicit owner-granted permissions remain valid. A desk never reveals hidden contents, quantities, codes or ownership privileges to a caller lacking access.
- Changing the code revokes authorizations that depended on the old code. Container movement does not remove its lock, wipe its ownership or disclose the code.
- **Exact escalating failed-attempt rule:** after the *first wrong code* that player waits **10 seconds** before trying that same container again; after the second consecutive wrong code wait **20 seconds**; after the third **30 seconds**; after the fourth **40 seconds**; then continue +10 seconds per further failure. A correct code resets that player's failure streak for that container. **No fixed cap** was approved. Owner access needs no code and thus no guess lockout.
- Failed-attempt state is **per player and persistent crate/chest ID**, not per UI screen. Switching from the crate to its Warehouse Desk/ship table, moving it, reconnecting it or refreshing the UI must not reset the wait. The interface displays remaining time. Do not count merely opening the lock dialog as a failure.
- Implementation recommendation (not an additional owner-set rule): enforce lock and timeout checks **server-side**, storing each wait as a wall-clock deadline per character and container (as the Rested buff stores its end time) so it survives save, server restart and reconnect, avoid transmitting the cleartext code to other clients, and authorize **every** view/transfer operation. A four-digit code is a gameplay feature, not cryptographic security.

| Example access | Result |
|---|---|
| Owner opens their own locked crate directly | Allowed, no code |
| Owner opens their locked crate at Warehouse Desk | Allowed, no code |
| Desk owner tries another person's locked crate | Denied unless separately authorized/correct code entered |
| Friend enters correct code for one locked crate | That crate accessible to friend; others unaffected |
| Stranger opens unlocked crate | Allowed under ordinary public/unlocked permissions |
| Wrong attempts 1/2/3/4 | 10s/20s/30s/40s successive per-player-per-crate waits |
| Move locked crate onto a future ship and dock elsewhere | Same owner, code, contents; prior desk link revoked |

## 6. Persistence, multiplayer and acceptance tests

**Data fields to design before implementation** (suggested structure, not an approved schema): persistent container instance ID; item stack contents and per-instance state; owner/permission records; optional code verifier + code revision; per-player attempts/wait deadline; parent physical carrier/zone; position; cargo mass/volume; and current storage-context resolution. Each needs a `PROTOCOL.md` action or save field: chest actions carry only world id, slot and count today, and structure save rows carry only `owner` and `keep_out`. The server is the source of truth for inventory transactions, permissions and move/unload.

Acceptance tests for subsequent engineering review (not tests already run):
1. Place two unlocked crates; one desk shows their union; direct opening either crate still works.
2. Lock one crate; its owner can still manage it at the desk, another player cannot see its private contents/totals.
3. Owner shares `0042`; recipient enters it and transfers an item from only the intended crate.
4. Fail code three times with enforced 10/20/30 second intervals; switching between crate and desk does not bypass wait; success resets failure streak.
5. Owner rotates the code; prior code-derived access stops, owners and expressly authorized roles remain unaffected.
6. Load a full crate onto a wagon: weight includes goods, direct inventory persists, no duplicates; unloaded warehouse desk loses that crate.
7. Load onto a future ship: ship Captain's Table can access authorized contents, old warehouse desk cannot.
8. Unload at Warehouse B: new desk now sees cargo; no stale Warehouse A or ship link.
9. Save/load and multiplayer reconnection preserve owner, code, content, cargo, lockout state as appropriate; no item duping.
10. Two players transfer simultaneously; transaction has one correct result and never loses or duplicates items.
11. View performance with hundreds of boxes: aggregated query remains quick without one per-item rendered mesh.
12. Deny out-of-range, overcapacity, invalid parent, overlapping conflicting zone or inaccessible stacked-container transfer safely.

## 7. Boundaries and source references

- **Authoritative approved catalog:** [DYNASTY_MASTER_ITEMS.md](DYNASTY_MASTER_ITEMS.md) §§2.5, 3.5, 3.9, 3.11, **3.13 [D13]**.
- **Existing UI direction:** [INVENTORY_CRAFTING_LOOK.md](INVENTORY_CRAFTING_LOOK.md); extend its chest UI to support per-player filtered warehouse inventory and code dialogs, without overturning its visual style.
- **Transport:** §§3.10–3.11 of the master catalog; ship cargo and Captain's Table are *future design*.
- **Food storage:** [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md); preservation roster approved [D14, D17] (2 ADD).
- **Safety gate:** docs only. Nothing here is running in-game; no change to `data/items/*.json`, UI scripts, `dev` or `main`, and no merge until the complete catalog is approved and implementation is separately authorized.
