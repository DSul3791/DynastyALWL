# Tyler reply: Steve bow shooting 4b (f1e56758), 25 Oct 11:27 UTC
GO as written, with two points. One reply; no more asks.
- ACT_SHOOT = 49 is free (48 is ACT_PLACE_BLUEPRINT). A new action id means a protocol bump: take PROTOCOL_VERSION 79 at merge (I set it; the branch only claims the action id and the PROTOCOL.md line). Reserved in NUMBER_RESERVATIONS.md: action 49 = ACT_SHOOT (Steve), protocol 79 = ACT_SHOOT.
- Merge order: Sal's arrow and bow items first (claude/sal-bow-items, not yet on origin: Sal pushes it), then your branch rebased on build 806 and that item head. Gate separately, one hash each.
- Numbers (draw 25 percent weak shot, speed_max 45, range 80, break chances 0.35/0.25/0.5/0.3, water loss 0.5, noise 40 m) accepted; all stay in data/items/bow.json. Server clamps forged draw times and pace (test as planned). Everything random through fate()/roll_chance.
- Zero new warnings (baseline 233); parse_scan, local_check RESTART; .gd.uid for new scripts; exact head hash to me; QA card for Dave (shoot a deer at 20 m, pick the arrow up again).
