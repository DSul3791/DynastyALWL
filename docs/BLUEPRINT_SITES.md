# Blueprint sites (Dave 5 Nov 2026)

Dave: placing something without the materials is fine. It puts down a blueprint: a 60 percent see-through blue copy you can walk through. Look at it and you get "Press E to deposit materials" with what it needs listed under the prompt. A material is green when it is on hand (your pack, loose stock beside you, or a container within about 30 m) and red when not.

How it works (Sal, items):
- A hammer click on a piece whose materials are short sets down a site instead of refusing (`server_items.gd` `_place`, `_place_structure`). The hammer and station rules still apply. A saved plan still needs all its materials.
- The site is the piece's own entry with `struct["site"] = {"bp": blueprint number, "have": {item id: count}}`. It blocks nothing and holds nothing up (`_grid_add`, `_add_roof` skip it).
- E on a site (`_deposit_site`) moves what the builder has of each missing material into it: pack first, then loose stock within 4 m, then containers within 30 m (`SITE_REACH_M`). Partial deposits are kept. When nothing is missing the site becomes the real piece (`_finish_site`).
- Hold E takes a site down and gives back everything deposited.
- Saved: column 15 of a structure row holds the site as JSON.
- Client: the sync sends each player their own list `[item id, still needed, on hand]` in the row's extra dict under `site`. The model is drawn blue with collisions off; the list is a bbcode label under the prompt (shown while inspect is on, like every prompt).
- Sites count nothing as built (no goal event, no cover, no support) until finished.

Open for Dave: nothing yet; the list shows only what is still needed.
