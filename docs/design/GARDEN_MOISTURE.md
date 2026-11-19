# Garden moisture and irrigation (19 Nov 2026)

Dave, 19 Nov 2026 05:48Z, looking at a seedling's prompt ("hold a filled bucket or waterskin and press E to water it") in play: "now the text does
mention watering it which should be a possibility. I also think the rain should water it pretty good. also if it needs water it should show its
moisture content that can slowly reduce on hot days with no rain. Im hoping in a temperate climate the rain will provide enough but if not we should
be able to run pipes from a water source uphill and have the water run out of irrigation taps or just the end of the pipe onto the garden or into an
irrigation trench that should improve the moisture level of the soil around it for upto 30 meters in either direction." Then: "or something like
that. think it over come up with a plan and implement it."

Status: PROVISIONAL throughout. Every number is a first pick for Dave to retune (section 4).

## 1. What was already in dev (5d10056e)

- Every tilled bed and garden plot already kept a soil moisture of 0 to 100 percent (`src/shared/plot_water.gd`, server `_plots_tick` once a game
  hour, saved in `crops.json` "plots"). Heavy rain filled it, lighter rain wet it, the weather's evaporation dried it (more when hot or windy,
  nothing at freezing, less in a framed plot). A crop counted a wet day when its bed ended the day at 25 percent or more, and ripened only once old
  enough and with wet days on 30 percent of its grow days (most crops).
- Hand watering worked (E with a filled bucket or waterskin in hand on a growing crop), but one bucket added only 8 percent and a bed took one
  bucket a game day, so on a 1 m bed it never kept up with a hot day (16 percent).
- Nothing showed the moisture, and a dry day changed nothing unless the bed stayed dry for most of the crop's life.
- Garden plots can already be consumers in the water network (`water_network.gd`, `_water_resolve`), but no bed or plot has a water block, so no
  pipe or channel can reach one.

## 2. Stage 1: moisture you can see and that matters (PR 1)

What the player sees: aiming at a bed shows its soil in the line, e.g. "Chamomile, seedling, soil 15% dry, needs water: hold a filled bucket or
waterskin and press E to water it", "Press E to water the chamomile (young, soil 45% damp)", "A tilled bed (soil 80% wet): carry seeds and press E to
sow it". The number moves in 5 percent steps.

- **Rain waters well.** Light and moderate rain adds 600 percent a day times its strength (was 200): an hour of moderate rain (0.3) adds 7.5 percent,
  six hours 45. Heavy rain (0.5 and up) fills the bed, as before.
- **Hot dry days dry it slowly**, as before: about 5 percent a cool day, 10 a mild one, 16 a hot one on a bare bed; a framed plot loses 0.7 of that.
- **Hand watering is worth doing.** A pour is up to one bucket (8 L) and its litres go into the bed's soil store (25 mm over its area, the same
  litres piped water uses): 32 percent on a 1 m bed, 8 on a Medium plot, 3.6 on a Large. No daily limit; a soil wet through (99 percent) takes no
  more and says so, and a pour never takes more water than the soil has room for.
- **Dry soil slows the crop.** A day that ends below 25 percent grows the crop half a day instead of a whole one (the 30 percent wet-day rule stays).
- **Cost.** Nothing new ticks: moisture is still worked out once a game hour per bed, and a bed's world row is sent again only when its moisture
  moves a 5 percent step.

Does rain alone do in a temperate climate? A simulation of the game's own weather (`Weather.state` front noise, 40 seeds, 60 days, no watering,
default spirit) with these numbers: in temperate spring and autumn a bed is dry on about 5 to 7 of 60 days, so crops ripen about 5 percent later than
fully watered ones; in high summer (the drier part of the year) about 13 to 16 days, about 12 percent later, and in the worst dry spells up to a
quarter later. So rain is normally enough, as Dave hoped, and watering or irrigation pays off in a dry, hot summer.

## 3. Stage 2: irrigation (PR 2)

The reading used: water comes from a source on higher ground (a well or hand pump spout, a trough's or cistern's base outlet) through the existing
wooden or stone channels and log pipes (docs/design/PLUMBING_DESIGN.md). Where a run ends, the water pours out of its open end, onto a garden plot or
into an irrigation trench. "30 metres in either direction" is read as 30 m from the trench every way round, so one trench can serve a whole garden
around it; water never climbs, so a bed more than 0.5 m above the trench gets none.

What the player does: build a well or hand pump on higher ground, lay channels or log pipes downhill towards the garden, and either end the run over a
garden plot, or pick the hoe's **Irrigation Trench** (the last row of its list) and dig a trench under the run's end. Work the pump (or let a trough
drain down a pipe) and the beds round the trench get wetter.

- **The end of a pipe or channel onto the garden.** Small, Medium and Large gardening plots are water-network consumers: an open end or a spout over
  the plot (within its half side plus 0.3 m across, up to 1.5 m above) pours in, and the litres become moisture over its soil store (a Medium plot,
  1 L a percent). A full plot takes no more and the water backs up the run. Tilled beds do not take pipe water themselves (there can be 200 a chunk,
  and the hoe grid tills up to 100 in a click); they are watered by a trench.
- **Irrigation trench** (new, Dave named it): one left click with the hoe digs a 2 m by 0.5 m trench piece where you aim, along the way you face. No
  items are used and it wears the hoe like tilling. It catches a channel's or pipe's end or a spout within 1.2 m of its middle and up to 1.5 m above. Its
  water is shared among every tilled bed and garden plot within 30 m that is no more than 0.5 m above it, each by the room its soil has, so the driest
  bed takes most; once they are all full the trench takes nothing. Refused under water, on a bed, and within 1 m of another trench or anything standing.
- **Taps.** Not built. The catalog's Tap is iron and belongs to the iron plumbing behind the Master smithy, which is on Dave's future list. An open
  pipe end already pours, and the Sluice already shuts a channel. A wooden tap would be a new item: Dave's call.
- **Cost.** A trench's list of beds is worked out when it is dug and again in the hourly plots pass (one pass over the beds for every trench), never
  per frame; its water is shared out only when the network is solved (a change, or the next fill or empty event).
- **Look.** PLACEHOLDER: the tilled-soil furrows laid 2 m long and darkened; no water surface is drawn. It cannot be filled in or picked up yet, like a
  tilled bed.

## 4. Assumed on Dave's behalf, for his review

- GM-1 Rain gain 600 percent a day times rain strength (was 200); heavy rain (0.5) still fills a bed at once.
- GM-2 A hand pour is up to 8 L into the bed's soil store (32 percent on a 1 m bed, 8 on a Medium plot), no daily limit, refused when the soil is
  99 percent wet. Replaces the earlier GOALS-REPAIR A-3 rule (8 percent a bucket, one bucket a day).
- GM-3 A day ending below 25 percent grows the crop half a day.
- GM-4 The prompt words: wet from 70 percent, damp from 25, dry (needs water) below; shown in 5 percent steps on every bed and plot.
- GM-5 Garden plots catch a channel's or pipe's end or a spout within their half side plus 0.3 m and up to 1.5 m above (tilled beds do not; trenches
  water them).
- GM-6 Irrigation trench (new item 1507, structure state 457, no recipe): dug with the hoe, 2 m by 0.5 m, catches water within 1.2 m and 1.5 m above.
- GM-7 A trench waters every bed and plot within 30 m of it (any direction) no more than 0.5 m above it, shared by each soil's room.
- GM-8 The hoe's list gains Irrigation Trench as its last row (after Survey a Path); Dave's order of the other six is unchanged.
- Not built, Dave's call: an irrigation tap (the Tap is iron, behind the Master smithy, on the future list); filling in a trench.
- Unchanged and still provisional: a 25 mm soil store, 1.25 to 4 mm a day of evaporation from 5 to 25 C, start at 50 percent, wet day from 25.
