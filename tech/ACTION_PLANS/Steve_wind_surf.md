# Steve: wind on its own slider, surf only at the sea in wind (branch claude/steve-wind-surf)

Dave 24 Oct: Nature at 0 loses everything including wind even with Wind maxed; the surf should sound only near the ocean and when windy.
Findings: base wind (wind_low, wind_gust) and treewind_* are on the Wind bus but sit at -49..-35 dB, so Wind alone was nearly silent; the storm wind loop (weather_sounds wind_storm) was on the Weather bus, which the Nature slider drives; bed_surf needed only "beach + water + height < 8 m" with no wind test.
Changes (RUNTIME, defaults printed):
- WIND_LIFT_DB +8 dB on wind_low and wind_gust (sound_stage.gd, one constant).
- weather_sounds: loops named wind* play on the Wind bus.
- bed_surf (the only sea_edge slot): also needs world wind >= SURF_MIN_WIND 0.45 (0.15 calm .. 1 storm; slow value, so it does not flap in gusts). Near-ocean test unchanged: water weight >= 0.4 and height < 8 m. Not changed: forest beds stay on Nature (they are the forest bed, retuned by Kathleen); desert/canyon wind beds on Wind (steve-wind-bus).
After: Nature 0, Wind full, breezy day: a steady wind, tree rustle. Inland no surf ever; at the coast, surf only on a windy day.
F3 lines (steve-nature-debug): "loudest Wind: <file> <dB>" should name wind_low/wind_gust/treewind_*; "loudest Nature:" should never say bed_surf inland.
