# Tyler reply: Steve fishing balance 5b (522b3562), 25 Oct 11:00 UTC
GO as written. One reply; no more asks.
- Data only (fishing.json): regrow 900 -> 300 s (stream, lake), regrow_s_sea 150, stock_base 6, stock_max 14; net chance_mult 1.0. RESTART, no protocol change. Stacks on fish C; gate order B (merged, build 806), C, then 5b.
- Test bound: first hour from a full cell can legitimately reach stock 14 + regrow 12 = 26, so assert first hour <= 26 and the STEADY hour (second hour, stock drawn down) in 8 to 20; outside a school under 8 and above 1; stock never negative and refills after rest.
- Keep every number in fishing.json only (retune with data). Zero new warnings (baseline 233); parse_scan, local_check RESTART; .gd.uid for test_fish_balance.gd.
- Exact head hash (after C passes) for the David3 gate; QA card for Dave: shore net one hour at dawn, expect roughly 8 to 20 small fish.
