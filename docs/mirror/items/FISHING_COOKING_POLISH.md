# Fishing and cooking polish pass (Radar, 2026-10-21) numbers from data/items/fishing.json, cooking.json, vitals.json

Read from the data and the code, not played by eye. The new-player-day test covers hunting, roasting and sleep but not fishing, so these are calculations.

**Fishing speed.** A cast waits 6-22 s (mean 14) for a bite, then a 3 s window, then a 2 s cooldown: about 19 s a cast. Chance 0.55 times hour (dawn and dusk 1.3, midday 0.7), weather (rain 1.2, storm 0.4, cold below 5 C 0.6) and bait 1.5. Midday no bait: 0.385 per cast, a fish about every 50 s. Dawn with bait: 1.0 (capped), a fish every 19 s.
**Food per fish.** Raw 200-280, roast fish 650 (roast meat 700, roast forage 400). One roast fish is nearly a roast meat for about a minute of work, much cheaper than a deer hunt. That is fine for a starter food, but with bait at dawn it outpaces everything.
**Awkward 1: stock.** A 128 m cell holds 4-12 fish and gives back one per 3600 real seconds. A pond is fished out in 4-12 catches (about 3-7 minutes) and then yields one fish an hour. The "gone quiet" message is right, but one hour per fish is too slow for a town to live on.
**Awkward 2:** raw fish makes you sick (12) yet is worth 200-280 food, a trap for new players; a one-line hint "Cook it first" appears in the item text only.
**Awkward 3:** roast fish spoils in 36 (game hours per spoilage.json), so a day's catch is gone in 1.5 game days; fine, but players are not told.
**Awkward 4:** no way to see a cell's remaining stock, so players cannot tell "unlucky" from "empty".

**Proposals (nothing changed yet):** regrow_s 3600 to 900 (a fish every 15 real minutes per cell, 4 fish an hour); keep stock_max; cap bait at 1.3 so dawn is 0.93 not 1.0; a "fish look restless / still" hint when stock is under 3; add a fishing step to new_player_day. Say go and I change the numbers (data only, no wire change).
