# Water look: clarity after rain, peat colour, white water and foam lines

**Owner:** Kathleen (art). **Status:** design, with code behind the `--water-look` switch (off until Dino's pictures). **Sources:** Jamie's knowledge pages in #623, `docs/knowledge/water-clarity-after-rain.md` and `docs/knowledge/foam-falls-rapids.md`; the numbers below come from them. **Related:** `art_water.md` (#587) section 11, which asked for this; `art_weather_light.md` (8.1, after rain).

Today the land water has one brown "mud" value: it follows the flow rate and a storm murk that rises over 6 real minutes and clears over 15. Every river and lake therefore clears at the same speed. The white on a river comes from its speed alone, so a fast but deep river can look as white as a riffle. There is also no foam that drifts and gathers. This note sets the rules that fix all three, in the order they can be built.

## 1. Clarity after rain

1. **The cloud comes with the rising water.** Clouding follows `Weather.river_push` (dry 0, heavy rain 0.6, storm 1). It rises with a lag of about 1.5 game hours and peaks at or a little before the peak flow.
2. **Running water clears as the supply stops, on a half-life by bed type** (Jamie's model):

   | Reach | Half-life | Clear again (to about 5%) |
   |---|---|---|
   | Clear (rock and gravel beds, mountain streams) | 12 game hours | about 2 days |
   | Cloudy after rain | 24 game hours | about 4 days |
   | Silty (clay lowlands) | 3 game days | about 2 weeks |

   One game hour is 2.5 real minutes, so a mountain stream is clear about 2 real hours after a storm.
3. **Still water clears by settling, and more slowly.** A pond takes the cloud of the water coming in, at about half its strength. It clears with a half-life of 18 game hours (about a 3 m pond at depth / 3 m per hour, plus its inflow's own tail). A deep lake's last faint clay haze (10% for two weeks) is for later.
4. **Until the record gives each reach its class (R6),** all land water uses the clear class, which suits the starter island's rock and gravel streams. Still water uses its own slower rule.
5. **The look:** the existing brown flood colour (`mud_color`), the same in both water looks (the grid look and the live sheets). The water flowing in at high flow is the stronger of the two terms. It stays as today.

## 2. Peat colour

Peat water is a dissolved tea-brown, not a cloud.
- It never settles out: a calm peat pool is as brown as the stream.
- It grows stronger after rain, because the rain flushes the bog, and fades with a 7-day half-life.
- The bed shows through it, stained amber, like strong tea.
- **Not built yet:** the water shader cannot know which reaches drain a bog. It needs the record's peat flag per reach (R6). The colour is set here so it is ready: amber-brown about (0.32, 0.20, 0.08) as a stain on the light through the water. It is not a muddy, opaque colour.

## 3. White water (air in the water)

1. **White water needs a jump, not just speed.** It follows the Froude number Fr = speed / √(g × depth), worked out per pixel in the live sheets, which know both:
   - below about 1.7, standing waves and almost no white;
   - from about 2, white crests;
   - from about 4.5, a full white roller.

   So a shallow riffle at 1.5 m/s and 0.1 m deep (Fr about 1.5) shows waves with a little white, and a 2 m/s chute 0.05 m deep (Fr about 2.9) is white. A deep river at 1.5 m/s and 1.5 m deep (Fr about 0.4) is not white at all, however fast it looks.
2. **Below a fall** the white patch reaches about 3 pool depths downstream, then goes clear quickly. The fall's churn is drawn as today.
3. **Rain does not make white water.** More flow makes more of it, because the speed rises.
4. **The far grid look** has no depth per pixel. It keeps today's rule (speed and the flow rate) until the record gives a turbulence class.

## 4. Foam (froth that drifts and gathers)

1. **Where it comes from:** turbulence (white water and falls) multiplied by organic richness and season. It is heaviest in autumn and after rain, and on peat and forest rivers.
   - Season: 1.0 in autumn, 0.6 in spring and summer, 0.4 in winter.
   - Rain: up to 1.6 times for a day after heavy rain, on the same clouding curve as section 1.
2. **Where it gathers:**
   - in lines along the seam between the fast tongue and the slow edge water, found where the speed changes most across a short distance (the shear between neighbouring cells);
   - in eddies and slack water.
   - Never on still water with no current.
3. **How it moves:** it rides the surface flow, as broken flecks and short lines, never as a fixed texture.
4. **Colour:** white where it is fresh, close to the white water, ageing to light tan (about 0.78, 0.70, 0.55) in slow water further down. It is never bright white far from a fall.
5. **Winter:** foam in still eddies freezing into pale discs is for later, with the ice.

## 5. Never-see checks (from Jamie's pages)

1. A clear river right below a brown tributary for more than a few hundred metres (needs per-reach clarity, R6).
2. A muddy mountain stream four days after rain.
3. A peat stream that runs clear blue after rain.
4. White water on a calm, slow reach, or on a deep, fast, smooth river.
5. Foam on a still pond with no inflow, and no wind or waves.
6. A fixed foam texture that does not move with the current.
7. Clean white foam a kilometre below a fall on a peat river.

## 6. Built behind `--water-look` (first step)

- The clearing curve for running and still water (sections 1.1 to 1.4), sent to both water looks. It replaces the storm murk's share of the brown while the switch is on.
- White water from the Froude number in the live sheets (section 3.1).
- Foam lines on the shear seams in the live sheets, drifting with the flow and tinted by age, with the season and rain supply (section 4).
- Not built: peat colour and per-reach classes (wait for R6), the lake clay haze, and frozen foam.
- Cost: a few uniforms and a handful of shader lines on the live sheets, which already read their neighbour cells. Nothing changes with the switch off.
