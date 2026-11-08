# Grooming and idle variety

A standing animal plays its idle or graze clip on a loop. With the flag `idle_variety` (default off) it does something else now and
then: scratch, shake, stretch after lying, groom, lick a paw, roll in the dust, paw the ground, look round. Client look only.

## The table

Row key `idles` in models.json: a weighted list. Each entry is one of:
- `{"clip": name, "w": weight}`: a clip from the file, played once to its end.
- `{"pose": {bones, waves, period_s}, "s": seconds, "w": weight}`: a bone pose over the normal clip (pose key -10 - i in
  bone_offsets.gd), for a file with no clip for it (the horse's pawing: front leg waves).
- `{"act": shake | look_around | stretch | roll, "s": seconds, "w": weight}`: a movement of the whole body (the Rig), needing no
  bone names: shake dies away, look_around turns the body a little each way, stretch dips the front, roll lies on the side and back.
- `after: "lie"`: played as the animal gets up from sleep (a stretch); with `also_awake` it is also in the normal draw.
- `needs: "dry"`: skipped in water and on rain-wet ground (rolling).

## Timing

Graze 0, alert 3 or recover 12, still and awake: wait 8 to 25 s, pick by weight, play once. Moving, a new state or falling asleep
ends it at once. Rolling dusts the coat when `coat_dust` is on (COAT_SHADER.md).

## Clips found in the files (read from the FBX clip names, 8 Nov 2026)

| Species | Clips | Posed or acts |
|---|---|---|
| Dog | shake 01 and 02, sit scratch, dig, sniff, chin drag | roll, stretch after lying |
| Lynx | shake, stretching | |
| Puma | yawn (named `dle_rest_yawn` in the file), grooming, lick paw, shake, look, stretching | |
| Lion | grooming, lick paws, yawn, shake, stretching | |
| Boar | head shake, look around while eating, look up | |
| Mink | shake, look | |
| Raccoon | stretch, rest stretching | |
| Kangaroo | look around, search, stretching | |
| Deer, moose, buffalo, bighorn | graze-and-look | shake (deer, moose) |
| Mountain goat, warthog, hyena, wildebeest | graze-and-look, calm idle moves 1 to 5 | |
| Black bear | sniffing, snorting, calm move, graze-and-look | |
| Wolf, fox | graze-and-look | shake, stretch after lying |
| Horse | none | shake, look round, roll (dry), pawing (front-leg waves) |
| Donkey | none | shake, look round, roll (dry) |
| Cow, goat, rabbit, cat | none | shake, look round, stretch (cat) |

A clip name that is not in the file is logged (`idle clip ... not in the file`) and skipped.

## Check on the PC

Run sheet m27: dog, lion, horse and boar with the first idle after 1 s.
