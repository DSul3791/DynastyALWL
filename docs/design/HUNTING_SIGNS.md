# Hunting: signs for everyone, reading sign, fresh tracks (23 Nov 2026)

Thread "Make hunting fun with visible trails". Dave, 23 Nov 2026: "making game trails actually visible with signs of game. signs should
just be there and if you have a higher tracking skill maybe they get highlighted or glow a little these are just ideas. extrapolate from
them and see what would make for a fun hunting game." Blood trails and bleeding out stay as they are. Builds on stage 2d of
[ANIMAL_ROUTINES_TRAILS_TRAPPING.md](ANIMAL_ROUTINES_TRAILS_TRAPPING.md). All values provisional, in data files.

## The hunt this serves
Find sign, read it, follow the trail, spot the animal (trails end at beds and warrens; fresh prints lead to the animal itself), stalk
(senses, wind, crouch: existing), shoot (existing), follow the blood (existing).

## What changed
- **Signs for everyone** (data/look/trail_signs.json everyone_note): every kind shows from the first level within 15 m (30 m at 100).
  From Tracking 10 a faint steady pale patch lies under each shown sign, growing to 0.28 alpha at 100, lit like the ground (no marker at
  night). Spotting (glow, sound, XP) unchanged, now from the first level (server_traps reads see_level 0).
- **Deer beds**: 2-3 ovals of 1.5 x 0.8 m within 1.5-3.5 m of each deer trail's home, pressed into the run map (grass_view
  _press_beds), so grass lies flat and worn earth bares the litter; a sign for spotting and reading.
- **Rubbed trees**: by deer trails, at most one per 35 m, the thinnest loaded trunk (radius up to 0.3 m) within 2.5 m: a pale 0.11 x
  0.5 m strip at knee to chest height on the trail side (terrain_client _trunks_round, read only).
- **Reading a sign**: look right at a sign (within about 10 degrees, read_aim_cos) within 3 m, E; a looser look leaves E to items and snares beside it. Anyone reads what it is; from Tracking 10 which way the trail runs and to what; from
  25 (Advanced, Dave's classes) when its animal uses it.
- **Trails stronger in grass** (data/look/worn_earth.json grass_press 0.6, grass_pale 0.35): on top of the trample's squash, a trail
  presses most of what is left and takes a straw tint.
- **Fresh tracks** (src/client/fresh_tracks.gd, data/look/fresh_tracks.json): each footfall of a drawn animal within 30 m
  (animal_view `stepped`, read only, agreed with the animals thread) leaves a print by shape (hoof, paw, hop), fading over 10 real minutes,
  up to twice as long at Tracking 100; a print only after the animal moved 0.6 m, at most 480 (a walking deer lays about two a second, so with several animals near the oldest go before their time).

## Cost
Client only. No messages, no protocol change, no server work beyond the existing spot check. Signs rebuild only on change or 8 m moved;
fresh prints redraw at most twice a second while any exist.

## Not yet
Fresh prints are not read with E and give no XP (the server has no way to check them cheaply). Pictures on a real GPU are owed (Lane A).
