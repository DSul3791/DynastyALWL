# Blueprint sites (Dave 5 Nov 2026)

Dave: placing something without the materials is fine. It puts down a blueprint: a 60 percent see-through blue copy you can walk through. Look at it and you get "Hit it with a hammer to add materials" with what it needs listed under the prompt. A material is green when it is on hand (your pack, loose stock beside you, or a container within about 30 m) and red when not.

How it works (Sal, items):
- Dave 18 Nov 2026: "blue prints should not autocomplete on placement. they should only get supplies added to them when they are hit with a hammer." Every hammer or knife placement sets down a site and takes nothing, whatever is in the pack or nearby (`server_items.gd` `_place`, `_place_structure`). The hammer and station rules still apply. The client still greys a saved plan that is short of materials (unchanged, provisional BP-2).
- The site is the piece's own entry with `struct["site"] = {"bp": blueprint number, "have": {item id: count}}`. It blocks nothing and holds nothing up (`_grid_add`, `_add_roof` skip it).
- A hammer hit on a site (`_gather_site`, the repair swing) pulls what it still needs: the pack first, then loose items and the builder's own containers within `site_gather_m` times the hammer's reach. Partial amounts are kept. When nothing is missing the site becomes the real piece (`_finish_site`).
- E on a site only says to use the hammer; the old E deposit (`_deposit_site`) is deleted (provisional BP-1: Dave said supplies go in only by hammer).
- Hold E takes a site down and gives back everything deposited.
- Saved: column 15 of a structure row holds the site as JSON.
- Client: the sync sends each player their own list `[item id, still needed, on hand]` in the row's extra dict under `site`. The model is drawn blue with collisions off; the list is a bbcode label under the prompt (shown while inspect is on, like every prompt).
- Sites count nothing as built (no goal event, no cover, no support) until finished.

Open for Dave: nothing yet; the list shows only what is still needed.
