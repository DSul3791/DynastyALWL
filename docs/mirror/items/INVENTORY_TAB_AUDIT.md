# Inventory and Tab audit (job 94, 2026-10-21)

Checked in code and data, not by eye (no screen in the cloud).

- Fonts: every label in the inventory and Tab screens goes through `_px` with BODY_PX 30 (bars row 24) and a floor of MIN_FONT_PX 24, so 1080p on a 55" 4K TV stays readable. The bars row now holds six bars (Health, Exertion, Energy, Warmth, Food, Water); at the fixed 90 percent window each gets about 290 px, enough for a 24 px label and a bar. Dave to confirm on his screen.
- Tooltips: every core item has a description (checked); the only short one is "hide". New lines: freshness word and percent for perishable food, rotten food and remains described, water containers show litres, tools show uses and repair.
- Keys: CONTROLS.md now lists the Warmth bar and E at remains next to the Energy bar; check_controls passes.
- Names: plain nouns (Remains, Rotten food).
- Open: Dave to look at the six-bar row and the freshness bar colours (green, amber, red) on the real screen.
