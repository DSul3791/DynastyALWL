# Steve: long sliders for the sound mixer (branch claude/steve-sound-sliders)

Dave 24 Oct: the Wind / Nature / Footsteps volume controls were buttons stepping 100-75-50-25-off; he wants nice long sliders.
Change (RUNTIME, client only): Esc > Settings > Sound now has sliders for master, effects, ambient, interface (already sliders, now wider) and wind, nature and water (Nature+Weather buses), footsteps and body (Foley+Body). Slider 420+160 px wide, 1 percent steps, label shows the value. sound_stage.mix_step replaced by set_mix(group, 0..1); mix_index replaced by mix_level floats; saved in sound_settings.cfg under mixer_level, old step saves migrate (100/75/50/25/off -> same share). Same buses.
Water has no bus of its own (it plays on Nature), so there is no separate water slider; say so if Dave wants one (needs a bus split).
Test: drag each slider, hear the bus change, restart, value kept.
