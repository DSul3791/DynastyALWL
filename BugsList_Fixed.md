# Fixed Bugs

All Fixed Bugs Go here.

## 49. Shovel name

Dave asked on 16 Nov 2026 for every Spade to be called a Shovel, including icons and internal names. Fixed by PR #1182, merged to dev at bcd02908. Verified in a Dave play test on 19 Nov 2026 ("Yes it is now called shovel in game").

## 1. Level terrain without lifting the player or creating free fill

Level keeps the feet height from the start of the held action, never edits within 1.2 m of the feet, and every fill costs Soil from the crafting stock. Fixed by PR #1252, merged to dev at a9fd033a. Automated: test_server_items on Dave's PC. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 2. Foundations must use the edited ground surface

Placement height, slope and roof-panel checks read the saved digs and fills. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items foundation on raised ground. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 3. Rocks must visibly deplete as they are mined

Boulders hold stones by volume at 0.04 a unit (RK-1), crack as they are worked and crumble when mined out; the count survives reload. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items stone counts. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 4. Keep the hoe menu readable on screen

At most 75% of the window wide, wrapped, in view. First fix PR #1252; second fix after the 19 Nov play test, PR #1283 (dev df8716cf). Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 5. Present the hoe actions in a practical order

Level, Plant, Till Garden Grid - 20m Edge Blend, Till Soil 2m, Pathen (one click, one spot), Survey a Path unchanged. Fixed by PR #1252 (dev a9fd033a). Automated: test_server_items Pathen checks. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 6. Make gardening and planting deliberate, quick and predictable

Server-checked neon preview; obstacles and 2 m building clearance refuse before any change; garden grid averages, levels, tills and blends within 20 m, then a 20 s countdown; Till Soil 2m; one-click Plant grid from the crafting stock. Fixed by PR #1252 (dev a9fd033a), validator follow-up PR #1260 (dev a57c24cb). Automated: test_farming and test_farm_prompt on Dave's PC. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").

## 50. Level gives no soil back when it cuts ground

Cutting with Level gives Soil back at the rate a fill of the same depth costs. Fixed by PR #1286, merged to dev at e5272847. Automated: Lane B 201 of 201. Verified in a Dave play test, reported 24 Nov 2026 ("they have all been tested").
