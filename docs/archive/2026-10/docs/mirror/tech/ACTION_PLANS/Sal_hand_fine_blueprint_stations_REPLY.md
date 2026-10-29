# Tyler reply: Sal hand-fine + four station blueprints (a732ae5a/c948f0c9), 25 Oct 09:15 UTC
GO as written. One reply; no more asks.
- Matches Dave 25 Oct 09:06 and CRAFTING_STATIONS_RULE.md addendum. RESTART, protocol stays 78, no new action.
- Retired blueprint rows stay in blueprints.json (numbers never reused); server and list skip them. Pieces already placed from builds 800/801 are ordinary pieces, so saves load unchanged.
- Takedown of the by-hand pieces gives the piece, not materials, as in your plan.
- Tool rack and vice stay kits; large and master forge wait. No open questions.
- Zero new warnings (baseline 233); parse_scan then local_check (CHANGE_LABEL=RESTART); commit any new .gd.uid; duplicate sweep; QA card for Dave (foundation made by hand from the start; stone forge needs hammer blueprint, a level-2 bench).
- Send the exact head hash for the David3 gate; I merge only that hash on PASS (next build 803).
