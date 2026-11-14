# Clay pottery and the potter's wheel (FUTURE)

**Status: FUTURE idea, mapped out only. Not built, not in the item data, no numbers reserved.** Dave, 14 Nov 2026 (project thread "Add clay pottery and salt preserving"):

> "We can have clay pottery, and a spinning wheel or whatever it's called that you used to make things like clay bowls, and pots. Claypot could be used for storage and could help preserve foods if you put salt in the pot with the food" (14:47Z)
>
> "You could also make a water pot something to help carry water or a water jug" (14:48Z)
>
> "For now, just map out the idea of the clay pottery in the potter's wheel, but put it on the future list" (14:49Z)

Dave said in the project thread that clay goes here instead of clay plumbing (that removal belongs to the plumbing work, not to this document). It is listed as a future idea in `DESIGN_IDEAS.md` section 5.3. When Dave says to build it, the catalog rows, ids and code come in a reviewed PR; until then nothing here is an approved catalog addition.

## 1. What the game already has (reuse, do not duplicate)

Checked on `dev` at `bb61b5b2`.

| Piece | Today | Use in pottery |
|---|---|---|
| Clay #36 | Dug with a spade. | The only raw material. |
| Clay - Pot #40 | Carried container, 3 L of water. Recipe 21: 6 Clay at the campfire, 12 s. Also part of the Campfire pot blueprint and the Primitive well's cost. | **This is the water pot.** No new water item. |
| Clay jug #308 | Carried container, 2 L (water, ale, mead). Recipe 197: 4 Clay at the campfire, 14 s. | **This is the water jug.** |
| Mug #812 | 400 ml cup. Recipe 380: 2 Clay at the campfire. | Pottery. |
| Wooden bowl #39 | 300 ml, carved. | Stays; the clay bowl is the potter's version. |
| Storage jar #781 | Placed, blueprint 155 (8 Clay, hammer), state 193: 4 slots, 30 kg, anyone may open. Food in it spoils at 0.5 of the pack's rate (`spoilage.json` `place_mult`). | **This is the covered pot.** It gets the salt rule (section 3). |
| Preserving jar #830 | Placed station: seals batches that mature (Sauerkraut, Pickled vegetables). | Unchanged. It turns food into a new food; the salted storage jar only keeps food longer. |
| Salt #360 | Boiled from sea water at the Campfire pot, also rock salt and salt flats. | The preserving ingredient. |
| Kiln #771 | Fires bricks, roof tiles, lime; burns charcoal. | Not needed for pottery at first (section 2). |
| Spoilage | `data/items/spoilage.json` and `_spoil_tick` in `src/stream/server_items.gd`: every placed container ages its food at its kind's `place_mult`. | The salt rule is one more multiplier there. |

## 2. The potter's wheel (new station)

- **Potter's wheel**: a new catalog row, not the FUTURE Spinning wheel #845 (that one spins thread). A placed station, built with the hammer from a blueprint like the Loom or the Oil press. A heavy stone flywheel on a log frame, kicked with the foot. No metal, so pottery stays a stone-age craft next to the campfire.
- Real life throws a pot on the wheel, dries it, then fires it. Simplified here like the clay vessels today: **one craft at the wheel gives the fired piece** (the firing is folded in, as the campfire recipes already do). A two-step version (unfired ware, then fire at the campfire or kiln) is possible later but doubles the items, so it is not recommended.
- **Made on the wheel:** Clay - Pot, Clay jug, Mug and a new **Clay bowl**. The wheel is the better way: less clay and faster than by hand.
- **The hand route stays for the Clay - Pot only.** It is needed in the first hour (Campfire pot, salt, water), before anyone has a wheel, so a coil-built pot at the campfire remains. The campfire recipes for the Clay jug and Mug move to the wheel (decision 61: the old recipe goes, no duplicate).
- **Clay bowl (new item):** a fired bowl, holds 500 ml, eats and drinks like the wooden bowl. Later it can serve the cooking and platter systems where a bowl fits.

## 3. A covered pot keeps food only with salt in it

Dave, 14 Nov 2026 14:50Z: "I don't think it should be a pot called the salted pot. It should just be a pot and players have to know that if you put food into a covered pot, you have to put salt with it."

- **No new item and no "salted" name.** The covered pot is the existing Storage jar #781 (lidded clay jar, 4 slots, 30 kg). Its name and description stay as they are and do not mention salt.
- **The rule:** food in a covered pot keeps longer **only while Salt is in the pot with it**. Without salt the pot gives food no keeping benefit (it spoils as in the pack). With any Salt stack in the pot, the food spoils at a much slower rate (section 5).
- **The player has to know it.** Nothing on the item says so; players learn it the way real people did: by trying, from another player, or later from an NPC or a book (the nutrition-guide route of [D17] item 6). Opening the jar can say a plain fact once the effect is happening ("The salt is keeping the food fresh."), never a hint before.
- **This changes today's jar:** the plain Storage jar keeps food at 0.5 of the pack's rate. Under this rule the plain jar loses that and only a jar with salt in it keeps food. Flagged for Dave (section 5).
- The salt is not used up (simplest). If it should be, the next simplest rule is one Salt used per game week while food is in the pot.
- It is a keeping rule, not a recipe: salted fish, sauerkraut and the Preserving jar's sealed batches keep their own recipes and shelf lives; salt in the pot simply slows everything in it, raw meat included.
- Code sketch for whoever builds it: in `_spoil_tick`'s container loop in `src/stream/server_items.gd`, a `storage_jar` whose inventory holds `sea_salt` ages under the place key `storage_jar_salted`; `place_mult` gets that row and `storage_jar` goes to 1.0. Nothing on the wire or in the save changes.

## 4. Water carrying

Already done: Clay - Pot (3 L) and Clay jug (2 L) fill at water like the Bucket (8 L) and Waterskin (1.5 L). Making them on the wheel is the only pottery change. No new water vessel, unless Dave wants a bigger one (a large carried water jar, about 6 L, heavy) — listed below.

## 5. For Dave (all assumed, provisional, change any time)

1. Potter's wheel cost: 12 Stone, 2 Log, 4 Stick; hammer blueprint; no metal.
2. Wheel recipes: Clay - Pot 4 Clay 8 s; Clay jug 3 Clay 8 s; Mug 1 Clay 4 s; Clay bowl 2 Clay 6 s. Hand Clay - Pot stays 6 Clay 12 s at the campfire.
3. Clay bowl holds 500 ml.
4. Covered pot (Storage jar) with Salt: food spoils at 0.2 of the pack's rate, so it keeps about 5 times as long. Without Salt: 1.0, no benefit (today it is 0.5; this rule takes that away so salt matters).
5. Salt is not used up. Alternative: one Salt a game week while food is in the pot.
6. No new water item; optional large water jar (about 6 L) if wanted.
7. One-step firing at the wheel; no kiln needed.
8. Salt takes one of the jar's 4 slots, leaving 3 for food.
9. Raw meat in a jar with salt keeps longer. The catalog left out a Salted meat item and a Curing tub ([D14]/[D17], `DYNASTY_MASTER_ITEMS.md` s3.14); this rule adds no item, it only slows spoilage, so it sits beside that roster. Confirm that is fine.

## 6. When it is built

Catalog rows (Potter's wheel structure, its blueprint and state, Clay bowl), numbers reserved in `docs/mirror/tech/NUMBER_RESERVATIONS.md` from a coordinator block, looks and icons, encyclopedia and descriptions, recipe moves, the salted `place_mult` row and code, and tests for the wheel recipes and salted spoilage. Save and load: the wheel is an ordinary placed station and the jar keeps its contents, so no new save fields.
