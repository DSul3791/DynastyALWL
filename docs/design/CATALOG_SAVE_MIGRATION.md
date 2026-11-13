# Dynasty — Catalog, Storage and Progression Save Compatibility

**Updated 13 November 2026.** Current implementation safety rules. This replaces the obsolete mandatory one-time pre-release migration proposal; the old version remains in Git history, **not** as an active process requirement. No game code is changed by this file.

## Policy

Dynasty has not had a public release. The creator does **not require a blanket migration of every previous experimental world**, and may start a new playtest world when a deliberately versioned format changes. But old item IDs and structure numbers must **never** be reused, and **any existing save the new game claims to support must load without silent loss, wrong items, duplication or unauthorized changes**.

Normal steps:
1. Inspect the current `dev` structures, item IDs, inventory formats, item-instance wear and saved station creation ordering; base decisions on actual code/data, not old 12 Nov inventory estimates.
2. Determine whether a scoped data/format upgrade can retain placed objects and contents safely. Where feasible, implement deterministic, one-time versioned migration; otherwise explicitly refuse unsupported older saves and instruct the playtester to create a new world **before** loading a destructive interpretation.
3. Always save/load newly created worlds correctly, including multiple item stacks, nonstacking enhanced items, worn gear, placed structures, station inventories, multiplayer ownership and progression state; persist no incompatible magic default.
4. On wire-format changes, update documented protocol and `PROTOCOL_VERSION` together with serializer/deserializer and tests, and keep stable item identifiers.
5. When a structure's gameplay role changes, do not automatically reinterpret its old stored contents in a way that destroys material, leaks locked inventory or doubles rewards. All changes must have tests and a recovery/rejection policy. The old rejected proposals are not implicit permissions for compensating items.

## New source-specific save cases

**Resource bin remap:** the existing `open_storage_bin` (#1232, blueprint #227) currently stores mixed resources via slots/weight limits. The new intended Small Resource Bin holds **1,000 units of exactly one material**, assigned by first deposit and unassigned only when empty; Medium and Large hold **5,000 and 10,000**. Reuse existing identity where safe, but **do not silently discard mixed legacy contents** or choose a first item while losing the rest. For old mixed bins, either design a safe explicit conversion/overflow recovery under review or reject that incompatible world with a clear notice. A new-world-only implementation needs no forced old-world migration.

**Smithy station remap:** legacy `stone_forge`, `blacksmithy`, `large_forge`, `master_forge`, and standalone Bellows, Quenching Trough/Anvil keys do not form the current Primitive/Improved/Advanced Smelter and Primitive/Improved/Advanced/Master Smithy ladder. Preserve existing IDs as needed; avoid aliasing one old placed object to the wrong station tier or treating retired add-ons as extra stations. Test broken-station durability, **"Needs repair"** state, normal hammer right-click Repair with inventory/nearby storage/ground materials, and preserved station contents after save/reload.

**Smelter contents and processing:** Primitive Smelter has **20 Coal/Charcoal hopper, 20 ore input, NO output inventory; completed ingots drop physically in front**. Improved 40/40/80, Advanced 80/80/160. Save queued inputs, selected recipe and partial work; manual bellows losing its operator pauses unfinished Iron, and Advanced wind falling below threshold pauses all production until wind returns. Never produce duplicate ingots from a restarted queue or silent output-rack conversion.

**Fuel automation:** if multiple smithies/smelters compete for Coal/Charcoal from dedicated bins, kilns or fires, save each station's **creation order** and hopper state, and source the next scheduled **300-second** pull in the correct oldest-station-first order. The 30 m no-permission rule applies only to this fuel hopper action. Never silently backfill separate Steel INPUT carbon using the fuel hopper.

**Goals and character state:** persist automatic completed-goal IDs, counters and coin payment together with adequate crash consistency. Rejoin and world restart must not repay awards, replay old placards or erase exploration/mapping records. Old-character retrospective payout migration remains a distinct later approval, **not** a default rule. The new skill-based charcoal Map must save only per-character observed/recorded territory (and its accuracy) rather than granting a pre-revealed World Map.

## Tests before merging into dev

- New character builds the full metalwork progression, breaks/repairs a Smithy, saves and loads inventories and physical drops with exact counts.
- Mixed old bin saved under an older version is safely converted with all contents or rejected explicitly; empty and occupied current bins round-trip type assignment.
- Interrupt each recipe/smelter queue during wind loss, bellows loss, full output racks and server restart; no duplicate/lost items or accidental Steel from hopper-only fuel.
- Save and reload two competing nearby stations; confirm first-created priority persists for their next 300-second fuel pulls.
- Validate per-character goal completion and payout exactly once after reconnect/server restart and any implemented sparse map records without unexplored-area disclosure.
- Verify older versions are either read with intentionally supported defaults or refused **before** destructive writes, with readable operator guidance.

Retirement history and the older 12 Nov proposed multi-file migration are accessible in Git commits. **No new save migration feature is authorized merely by this design document.**
