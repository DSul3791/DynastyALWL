# Cave light: from the mouth, the eyes, and drips along cracks

**Owner:** Kathleen. **Status:** design and code together (small fix), 8 Nov 2026. **Behind:** `--cave-light` (off until Dino's pictures).
**Reads:** Jamie's research page `docs/knowledge/cave-microclimate.md` (#664): lessons 5 to 7, "Daylight reach", "Drips" and the never-see list.

## 1. What is wrong today

- **The light comes from enclosure, not from the mouth.** `weather_look.cave_light` fades sun, sky and ambient light with rock enclosure (0.1 to 0.6). A long straight passage with the mouth in view and a twisting one two bends in look the same. The twilight zone at the mouth is pitch black with the "Dark" setting as soon as the ceiling closes over.
- **"Normal" is far too bright.** It keeps 12 % of daylight deep in. Jamie's sums: 0.5 to 3 % at 10 to 20 m with the mouth in view, about 0.01 % after one bend, and none after two.
- **Coming out is a slow brighten** (2.5 s). Real eyes adapted to the dark see a short glare, 1 to 3 s, and then normal.
- **Drips are spread evenly** round the player at random. Real drips fall in rows along cracks, and the same spot drips every visit.

## 2. Rules

### 2.1 The view of the mouth (`cave_sounds.gd`, every 0.5 s, only under rock)

- **Rays:** rings of rays from the eyes, level and at 10 and 30 degrees up. There are 4 per ring on Low and 8 above, so 12 or 24 rays, each up to 80 m (the cave's physics rays, rock only, as the enclosure uses).
- **When a ray sees daylight:** it leaves the rock, or it ends on a surface with no rock within 30 m above it (open sky).
- **`mouth_view`** is the share of the rays that see daylight.
- **Bends:** when no ray sees daylight, the two farthest rock hits look round the next bend the same way (a level ring of up to 60 m).
  - If one sees daylight, that is one bend (`bends` = 1).
  - Otherwise it is two or more (`bends` = 2).
- **Cost:** at most about 100 physics rays every 0.5 s on High, and none in the open air.

### 2.2 The light (`weather_look.gd`)

- **How much light (`cave_light_view`):**
  - mouth in view: `mouth_view` x 0.6. That gives about 0.3 at the mouth, where half the view is open, and about 2.5 % when one ray of 24 still sees out;
  - one bend: 0.0005, about moonlight;
  - two bends: 0.
  - The setting's floor is the least: "Dark" 0, "Normal" 1.5 % (a faint dusk to find the walls, not 12 %).
- **The eyes:**
  - going in, the light drops over 1 s, as today;
  - while the light is under 0.1, the eyes adapt over 90 s. Where some light exists, they lift it up to 4 times, but never above 3 %. Black stays black, because 0 lifted is 0;
  - coming out, the light is back in 0.4 s, and the still-adapted eyes see a glare: exposure x (1 + 1.2 x adapt), which settles over 2 s.
- **Setting text:** the "Normal" note in the Esc menu says "a faint dusk deep in" with the switch on.

### 2.3 Drips in rows (`cave_sounds.gd`)

- **The cracks:** two cracks per 16 m cell. Each crack's start and heading come from a hash of its cell, so they are the same every visit.
- **The drip spots:** every 1.8 m along each crack.
- **Each drip** plays from one of the spots 3 to 12 m away, 1.5 m above the feet.
- **Unchanged:** when and how often drips play (wet caves only, from enclosure 0.45).

## 3. Never-see checks (from Jamie's list)

- daylight in a chamber two bends in with "Dark", or on any day past 100 m (the rays reach 80 m; past that, nothing sees out);
- the mouth's twilight zone pitch black by day;
- a slow 2.5 s brighten coming out of a deep cave instead of a short glare;
- drips spread evenly over the roof.

## 4. Pictures (Dino, with the switch on and off)

These use Cave 3,4 #8003 (mouth 54864, 73288, floor 627.1), by day:

1. 5 m in, facing out.
2. 15 m in, facing in.
3. One bend in.
4. Deep in (the farthest chamber).

Then step out after 2 minutes inside: two frames 0.5 s and 2 s after the mouth. For the exact spots, Dino uses F3 at each place, which shows the enclosure and, with the switch, "view" and "bends".

**Must:**
- 5 m in shows colour;
- 15 m in shows grey shapes;
- one bend in shows outlines at most;
- deep in is black with "Dark";
- the 0.5 s frame out is brighter than the 2 s one.

**Never:** daylight two bends in.

## 5. Open points

- Physics colliders end some way from the player. A ray that leaves the loaded colliders counts as seeing out. Inside a cave the colliders are close, so this is judged harmless. A very long straight tunnel might show a little light past 80 m.
- Drip speed by rock depth and by rain hours earlier (Jamie's drip table) waits for the server's leak data to carry rock depth.
