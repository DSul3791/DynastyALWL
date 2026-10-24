# Steve: surf-like roar in the forest (branch claude/steve-forest-bed)

Dave 24 Oct: "massive surf like sound drowning out all the nature sounds in the middle of the forest".
Trace (RUNTIME, ambience_slots.gd): bed_surf only plays for beach / sea_edge, so it is not it. In a forest the weather bed is bed_forest_day (winter: bed_forest_winter) on the Nature bus, looping at full gain; measured mean -27.4 dB (winter -30.9), max -13 dB, steady broadband noise (rebuilt on a wind loop in 7f65ecce). River/fall loops measure -15 dB mean but are only heard near water; treewind_leaves -15 dB mean is played far under that (Wind bus).
Change: BED_TRIM_DB -12 dB on the two forest beds (mean about -39 to -43 dB, the level of the wind Dave found fine). One constant, easy to retune.
If it still happens, read F3 (branch nature-debug): the "loudest Nature:" line names the voice. bed_forest_* = the bed (needs a different recording from Kathleen, less steady noise, more birds/leaves); water_river/water_fall with a distance = water; ambience files like bed_* / creature names = those.
Test: stand in a forest away from water, nature one-shots (birds, leaves) audible over the bed.
