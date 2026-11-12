# Storage, warehouses, movable crates and access controls

**Status: OWNER-APPROVED DESIGN [D13]; DOCS ONLY — NOT IMPLEMENTED.**
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

## 3. Sixteen approved ADD concepts — not yet catalog/runtime data

| Group | Items |
|---|---|
| Household (6) | Large Wooden Chest; Wardrobe; Dresser; Bookcase; Apothecary Cabinet; Bottle & Jar Rack |
| Workshop (2) | Tool Cabinet; Open Storage Bin |
| Bulk-material storage (5) | Firewood Rack; Log Rack; Lumber Rack; Mason's Pallet; Ore & Metal Rack |
| Shared zone interface (1) | Storage Sign / Ledger |
| Freight (2) | **Warehouse Crate**; **Warehouse Desk** |

Count = **16**. The Woodshed, Materials Yard and Storehouse are **3 construction layouts**, not master item IDs. No separate crate label, warehouse membership token, lock/key or four-digit-code item. The proposed Granary belongs to the **unapproved food-preservation item roster**. The Captain's Table belongs to a **future ship category**, not this 16-item list.

**Known design reconciliation before implementation:** §3.5 already provides graded Crude/Rustic/Fine/Ornate Chests. Large Wooden Chest must earn its distinct role through genuinely larger footprint/capacity or be reconsidered with Dave before implementation (no container can exceed 30 slots without changing the shared slot format; owner question in the 12 Nov audit); do not silently duplicate the Fine/Ornate grade. A large chest is eligible for the same code-lock mechanic as all approved chests. Existing #850 Crate remains and can join warehouse views; Warehouse Crate must have a meaningful stronger shipping/handling/stacking role, not just another differently named 10-slot crate. **Actual capacities, craft costs and stack height are unapproved tuning values.**

## 4. Core physical-storage rules [D13]

1. Every container has its **own actual inventory**. The sign, desk, ship captain's table and station crafting views are **views/transactions** over qualifying nearby physical containers, not stores that duplicate them.
2. Players can stand next to an **accessible crate** and open its inventory, add, remove, sort and move items directly. The Warehouse Desk is an optional convenience, never the only access route.
3. A Warehouse Desk presents searchable totals, deposit and withdraw controls for *currently local, permission-eligible* containers; Storage Sign provides an aggregated area view, both backed by the **same authoritative storage system**.
4. A loaded warehouse crate can be moved **as a single physical cargo object** on appropriate carts/wagons and later aboard ships. Its contents, owner, code, lock state, durability and spoilage follow that *same uniquely identified crate*. Mass and volume include contents.
5. A crate joins its destination desk **from physical location**, not by a permanent ledger link. Move it from Warehouse A → cart → ship hold → Warehouse B and the eligible active view changes along the route. A ship's Captain's Table can use the same system *when separately approved and implemented*.
6. A crate never remains accessible through Warehouse A's interface after leaving A. At most **one active locality/context per crate** for freight interfaces (Warehouse Desk, future Captain's Table); overlaps must resolve deterministically with ownership/physical position rules. Recommended: Storage Signs are views and may overlap, and a desk covers a stated radius or its enclosing building. No remote teleporting of goods, unlimited range, infinite load or duplicate transactions.
7. Stackable crates, material racks, shelves and wardrobe/weapon displays show reasonable **fill states** through low-cost grouped meshes, not thousands of physical item meshes. Actual inventory data and perishability remain authoritative.
8. A player's approved local workstation ingredient-sourcing rules still apply; this system must not silently allow every crafting station to pull from every warehouse on an island. Recommended: locked containers feed crafting and NPC jobs only for players with access, and only the owner or a player with access may lift, load or take down a locked container.

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
- **Food storage:** [FOOD_PREPARATION_PRESERVATION_SERVING.md](FOOD_PREPARATION_PRESERVATION_SERVING.md); preservation item roster not yet owner-approved.
- **Safety gate:** docs only. Nothing here is running in-game; no change to `data/items/*.json`, UI scripts, `dev` or `main`, and no merge until the complete catalog is approved and implementation is separately authorized.
