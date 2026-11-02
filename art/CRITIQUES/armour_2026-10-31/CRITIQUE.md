# Armour, swords, maces and shields (guide F-17 and F-18), 2026-10-31, Kathleen

Rule: F-17 is covered: BasicLook.entry() lets every override replace the grey chunk (0bf6e164) and src/worldgen/tools/test_item_looks.gd now fails if any overridden item still draws it (all 20 old overrides and the 18 new ones pass); the placeholder count fell from 56 to 38.

References: Bronze Age leaf-bladed swords and flanged maces, Roman gladius and Coolus / Montefortino bronze helms, Viking plank round shields with an iron boss, Bronze Age round bronze shields, medieval gambeson and mail (museum catalogues, re-enactor build guides); the Sal items spec for the tiers (bronze, iron, steel colours). Offline renders brighten colours: a metal item reads paler here than in the game.

| Item(s) | Pictures | Critique | Rating | Next to improve |
|---|---|---|---|---|
| Leather cap, bronze / iron / steel helm | iron_helm_round1.png, leather_cap_round1.png | dome with a brim, nasal bar, cheek plates, rivets and a ridge; leather cap has soft side flaps and seams. Round 1 ridge stuck out beyond the dome: shortened in round 2 | 2 | a more helmet-like profile (taller crown, neck guard), colour check in game |
| Leather jerkin, gambeson | leather_jerkin_round1.png | a flat T-shaped garment with a neck hole, belt and lacing; blocky; colour was orange (now a darker brown); gambeson has quilting lines | 2 | tapered shoulders, a visible sleeveless armhole curve, a hem skirt; a worn-on-body check (worn.json rows are placeholders on the hood and cloak builders) |
| Mail shirt | mail_shirt_round1.png (chequerboard), round2 | rows of rings, every other row shifted, tone varying: reads as a mail shirt from a distance, too pale and tile-like close up | 2 | finer rings, darker, shorter sleeves, a ragged hem |
| Plate cuirass | plate_cuirass_round1.png | two domed plates with a centre ridge, rivets and shoulder plates; not looked at again | 2 | a tapered waist, a lower plate edge, a neck opening |
| Bronze / iron / steel sword | iron_sword_round1.png, round2 | long flat blade with a fuller, crossguard, wrapped grip, pommel; round 2 gave the blade a pointed tip | 3 | a leaf-shaped bronze blade, tier colours checked in game |
| Bronze / iron / steel mace | iron_mace_round1.png | haft with a wrapped grip, six flanges round a core and a spike | 3 | check the flanges from the side |
| Bronze / iron / steel shield | bronze_shield_round1.png | round disc with a rolled rim, boss, rivets and crossed ribs | 3 | an offset boss and a back view with the grip |
| Plank shield | plank_shield_round1.png | five boards cut to a circle, two iron bands, an iron boss; stepped edge reads as an octagon | 2 | rounder edge, boards with a grain tone, a rim |

None of these has been seen in the real game (the rig's dropped-item frames stay empty after the daily merge), and the worn look on the body (worn.json) is still the hood and cloak placeholder.
