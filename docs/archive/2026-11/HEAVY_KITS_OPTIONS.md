# Heavy kits: what is wrong and the fix I recommend (Sal, 2 Nov 2026)

**The problem.** A player can carry 52.5 kg and starts to slow at 42 kg. Nine building kits weigh more than 52.5 kg, so they cannot be made at all. (`python tools/carry_audit.py` lists them.)

| Kit | Weighs now | Why |
|---|---|---|
| Stone wall | 314 kg | 12 cut blocks at 25 kg each |
| Log floor | 120 kg | 8 logs at 15 kg |
| Log wall | 90 kg | 6 logs |
| Fireplace | 79 kg | 24 bricks at 2.7 kg |
| Log workbench | 61 kg | 4 logs |
| Brick roof | 61 kg | 16 bricks |
| Log roof | 61 kg | 4 logs |
| Brick wall | 57 kg | 16 bricks |
| Brick floor | 54 kg | 20 bricks |

## Recommended: split each piece into smaller kits, carried in several trips
Each kit stays under 35 kg, so one trip carries one without slowing. A full wall, floor or roof is then two or three kits placed side by side. Nothing else changes: same materials in total, same look.

| Now | Becomes | Each kit |
|---|---|---|
| Log floor (8 logs) | 4 kits of 2 logs + 1 twine | 30 kg |
| Log wall (6 logs) | 3 kits of 2 logs + 1 twine | 30 kg |
| Log roof | 2 kits of 2 logs + 10 thatch + 1 twine | 30 kg |
| Log workbench | 2 kits of 2 logs + 3 twine + 3 sticks | 31 kg |
| Brick wall | 2 kits of 8 bricks + 2 mortar | 29 kg |
| Brick floor | 2 kits of 10 bricks + 2 sand | 27 kg |
| Brick roof | 2 kits of 8 bricks + 3 lumber | 31 kg |
| Fireplace | 3 kits of 8 bricks + 1 mortar + 2 clay | 25 kg |
| Stone wall | 12 kits of 1 block + 1 mortar | 28.5 kg |

**The stone wall is the hard one.** One cut block already weighs 25 kg, so 12 trips for one wall is too many. Two ways out, Dave's choice: (a) make a stone wall 6 blocks, or (b) drop block weight to about 12 kg (half-size blocks, more of them, same wall).

## What it needs
- Data: I split the recipes and structure rows (about an hour). Each new kit is a new item and recipe number; old kits are retired, not deleted.
- Code (Steve): a placed structure must be allowed to need N kits (`kits_needed`) before it counts as complete. If that is too much, each kit places a smaller piece instead (a half wall), which needs no new code but needs new footprints and art.
- Tests: Tyler's economy and stations checks, and `carry_audit.py` should then report 0 over the cap.

## Other options I do not recommend
- **Raise the carry limit.** Reality is already lower (about 22 to 30 kg is a hard load), and it would break the other weights.
- **Build from nearby stock.** Materials come from chests and the ground around the site, not the pack. Good later, but it needs a new system.
