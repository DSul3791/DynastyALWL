# Steve: hook up Kathleen's R1 sounds (branch claude/steve-sound-hookup)

RUNTIME, client only. Merges claude/kathleen-sound-r1 (6 slots, 18 clips, data/sound/batch3_slots.json) and plays them:
- slot_sounds.gd loads batch3_slots.json beside batch1 (EXTRA_PATHS).
- bed_lie / bed_rise: when the stance changes to lying and back (terrain_client stance.changed).
- net_cast / net_haul: the shore net's server lines ("You spread the net", "You haul in", "The net comes up empty") through a new inventory_view.notice_event (SlotSounds.net_cue); no protocol change.
- thatch_pick: harvest_sounds.pick when the plant yields thatch.
- twine_lash: item_sounds._start_work when the craft's work type is "bind" (spear, torch).
- Fire tiers: fire_sounds maps row "tier" 1/2/3 to size 0.2/0.5/0.9 (fire_small, mix, fire_large); until the world fire row carries a tier it stays 0.5 (campfire). Depends on Sal's fire tiers and kathleen-fire-looks passing the tier.
Test: Sound test is not wired for batch 3; lie down (Z), pull thatch, bind a spear, use the net.
