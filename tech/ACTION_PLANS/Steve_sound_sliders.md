# Steve: long sliders for the sound mixer (branch claude/steve-sound-sliders)

Dave 24 Oct: the Wind / Nature / Footsteps volume controls were buttons stepping 100-75-50-25-off; he wants nice long sliders.
Change (RUNTIME, client only): Esc > Settings > Sound now has sliders for master, effects, ambient, interface (already sliders, now wider) and wind, nature and water (Nature+Weather buses), footsteps and body (Foley+Body). Slider 420+160 px wide, 1 percent steps, label shows the value. sound_stage.mix_step replaced by set_mix(group, 0..1); mix_index replaced by mix_level floats; saved in sound_settings.cfg under mixer_level, old step saves migrate (100/75/50/25/off -> same share). Same buses.
Water has no bus of its own (it plays on Nature), so there is no separate water slider; say so if Dave wants one (needs a bus split).
Test: drag each slider, hear the bus change, restart, value kept.

## Added 24 Oct (Dave: sound list "not formatted in a way that can be seen", "window smaller than its inner container")
Settings > Sound and the Sound test list sat in a fixed 520 px scroll (plus the sliders added no scroll at all), so on a short window rows ran off the panel. Now both pages scroll inside a container sized at each page change to the window height minus 300 px (200..760), horizontal scroll off, 640 px wide; every button wraps long text (autowrap) instead of running wide. Back button sits outside the scroll so it is always visible.
