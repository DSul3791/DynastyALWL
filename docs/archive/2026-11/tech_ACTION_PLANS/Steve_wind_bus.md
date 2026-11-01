# Steve: wind slider does nothing (branch claude/steve-wind-bus)

Dave 24 Oct: changing the Wind volume does nothing, lowering Nature removes the noise.

Found (RUNTIME, one line in src/client/ambience_slots.gd _set_bed):
- wind_low, wind_gust (sound_stage.gd) and treewind_pine/leaves/dry/bare (tree_wind.gd Sound3D.make "Wind") are all on the Wind bus. Correct. But wind_low/gust sit at 0.0035 to 0.018 linear (about -49 to -35 dB), so the Wind slider moves almost nothing audible.
- The batch 2 weather beds bed_desert_wind, bed_canyon_wind (and bed_surf, bed_forest_*) all played on the Nature bus. The bed that sounds like wind or surf therefore only answered to Nature.
Change: beds whose slot name contains "wind" now play on the Wind bus. bed_surf stays Nature (it is water). Treewind is already on Wind and needs no change.
Not changed: wind_low/gust levels (Kathleen is retuning the treewind clips).
Test: Settings > Sound > Wind volume at off silences canyon/desert wind; Nature off leaves it.
