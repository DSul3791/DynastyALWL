# Loudness table (make with `python3 assets/audio/loudness_report.py --md`; guard with `--check`)

Active RMS and peak in dBFS per slot (recorded files win over generated). Steps add the game's surface level.

## . (median -18.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| step_bushes_left | recorded | 3 | -18.7 | -0.6 | -0.2 |
| step_bushes_right | recorded | 3 | -18.6 | -2.1 | -0.2 |
| step_dirt_left | recorded | 3 | -18.4 | -1.5 | +0.1 |
| step_dirt_right | recorded | 3 | -18.3 | -1.6 | +0.1 |
| step_grass_left | recorded | 3 | -18.4 | -2.2 | +0.1 |
| step_grass_right | recorded | 3 | -18.5 | -0.8 | +0.0 |
| step_grass_tall_left | recorded | 3 | -18.5 | -0.6 | -0.0 |
| step_grass_tall_right | recorded | 3 | -18.5 | -1.8 | -0.1 |
| step_gravel_left | recorded | 3 | -19.2 | -1.4 | -0.7 |
| step_gravel_right | recorded | 3 | -18.7 | -1.0 | -0.3 |
| step_leaves_left | recorded | 3 | -18.7 | -2.4 | -0.2 |
| step_leaves_right | recorded | 3 | -18.6 | -1.8 | -0.1 |
| step_mud_left | recorded | 3 | -18.1 | -1.7 | +0.3 |
| step_mud_right | recorded | 3 | -18.2 | -3.8 | +0.2 |
| step_sand_left | recorded | 3 | -18.4 | -2.4 | +0.1 |
| step_sand_right | recorded | 3 | -18.4 | -1.4 | +0.1 |
| step_snow_left | recorded | 3 | -18.4 | -0.5 | +0.1 |
| step_snow_right | recorded | 3 | -18.5 | -1.5 | -0.0 |
| step_stone_left | recorded | 3 | -19.2 | -1.4 | -0.7 |
| step_stone_right | recorded | 3 | -18.7 | -1.0 | -0.3 |
| step_water_left | recorded | 3 | -18.5 | -2.1 | -0.0 |
| step_water_right | recorded | 3 | -18.4 | -1.1 | +0.1 |
| wind_gust | generated | 1 | -18.4 | -2.1 | +0.1 |
| wind_low | generated | 1 | -18.4 | -2.3 | +0.0 |

## ambient (median -20.0 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bird_chirp | generated | 3 | -9.6 | -0.8 | +10.4 **outlier** |
| bird_feebee | generated | 3 | -7.7 | -1.8 | +12.3 **outlier** |
| bird_trill | generated | 3 | -10.4 | -1.8 | +9.6 **outlier** |
| bird_whistle | generated | 3 | -8.5 | -1.7 | +11.6 **outlier** |
| cricket_chirp | generated | 3 | -14.1 | -4.1 | +5.9 |
| crow_alarm | recorded | 3 | -20.0 | -5.4 | +0.0 |
| crow_caw | recorded | 7 | -21.3 | -1.9 | -1.3 |
| fish_splash | recorded | 3 | -28.3 | -3.6 | -8.3 **outlier** |
| frog_croak | recorded | 6 | -21.7 | -2.3 | -1.7 |
| hawk_screech | generated | 3 | -15.1 | -2.0 | +4.9 |
| owl_hoot | generated | 3 | -7.5 | -1.8 | +12.5 **outlier** |
| tree_frog_peep | recorded | 6 | -21.3 | -2.5 | -1.3 |
| wing_grain | recorded | 3 | -17.5 | -3.1 | +2.5 |
| wing_large | generated | 4 | -25.5 | -3.3 | -5.5 |
| wing_medium | generated | 4 | -25.7 | -3.3 | -5.7 |
| wing_small | generated | 4 | -25.6 | -3.4 | -5.6 |
| woodpecker | generated | 3 | -23.5 | -2.5 | -3.5 |

## batch1 (median -23.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| cloak_rustle | generated | 3 | -20.0 | -6.3 | +3.9 |
| deer_step | generated | 3 | -29.0 | -12.0 | -5.1 |
| door_iron_close | generated | 3 | -23.7 | -6.1 | +0.2 |
| door_iron_open | generated | 3 | -12.9 | -5.9 | +11.0 **outlier** |
| door_steel_close | generated | 3 | -24.1 | -5.8 | -0.2 |
| door_steel_open | generated | 3 | -19.2 | -5.9 | +4.7 |
| door_wood_close | generated | 3 | -19.4 | -5.9 | +4.5 |
| door_wood_open | generated | 3 | -12.9 | -5.9 | +11.1 **outlier** |
| duck_step | generated | 3 | -25.4 | -11.8 | -1.5 |
| fox_step | generated | 3 | -25.9 | -12.1 | -2.0 |
| horse_step | generated | 3 | -29.2 | -12.2 | -5.2 |
| ladder_rung | generated | 3 | -23.0 | -6.0 | +0.9 |
| moose_step | generated | 3 | -29.4 | -12.1 | -5.5 |
| rabbit_hop | generated | 3 | -25.8 | -11.7 | -1.9 |
| table_plane | generated | 3 | -23.4 | -6.2 | +0.5 |
| table_vice | generated | 2 | -20.3 | -6.1 | +3.6 |
| water_wheel_loop | generated | 1 | -24.9 | -6.1 | -1.0 |
| wolf_step | generated | 3 | -25.5 | -11.8 | -1.6 |

## batch2 (median -28.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bed_canyon_wind | generated | 1 | -28.5 | -13.9 | +0.0 |
| bed_crickets | generated | 1 | -28.4 | -13.9 | +0.1 |
| bed_desert_wind | generated | 1 | -29.5 | -14.2 | -0.9 |
| bed_forest_day | generated | 1 | -32.7 | -13.8 | -4.2 |
| bed_forest_winter | generated | 1 | -39.0 | -14.4 | -10.5 **outlier** |
| bed_lava_hiss | generated | 1 | -30.1 | -13.8 | -1.5 |
| bed_night | generated | 1 | -27.8 | -13.9 | +0.8 |
| bed_pond | generated | 1 | -29.0 | -13.6 | -0.4 |
| bed_surf | generated | 1 | -33.6 | -12.8 | -5.1 |
| bed_volcano_rumble | generated | 1 | -26.1 | -13.9 | +2.5 |
| bird_trill | generated | 3 | -20.6 | -13.3 | +7.9 |
| bird_tweet | generated | 3 | -24.5 | -12.5 | +4.1 |
| bird_whistle | generated | 3 | -21.9 | -13.5 | +6.7 |
| canyon_echo | generated | 2 | -31.5 | -14.3 | -3.0 |
| frog_croak | generated | 4 | -27.2 | -14.0 | +1.4 |
| ice_crack | generated | 3 | -36.1 | -14.4 | -7.5 |
| owl_hoot | generated | 3 | -21.9 | -13.9 | +6.7 |

## body (median -23.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| breath_gasp | generated | 3 | -23.8 | -7.2 | +0.0 |
| breath_heave | generated | 3 | -20.1 | -4.7 | +3.7 |
| breath_in | generated | 3 | -40.9 | -11.2 | -17.1 **outlier** |
| breath_out | generated | 3 | -40.9 | -11.2 | -17.1 **outlier** |
| heartbeat | generated | 3 | -16.4 | -1.9 | +7.4 |

## bow (median -20.6 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bow_draw | generated | 3 | -22.3 | -5.1 | -1.6 |
| bow_loose | generated | 3 | -19.0 | -3.2 | +1.6 |

## cave (median -21.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| cave_drip | generated | 5 | -21.2 | -1.7 | +0.0 |

## cooking (median -21.6 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| cook_sizzle | generated | 2 | -20.5 | -4.6 | +1.1 |
| drink_gulp | generated | 2 | -17.7 | -4.4 | +3.9 |
| eat_crunch | generated | 3 | -25.5 | -2.9 | -3.9 |
| eat_soft | generated | 3 | -22.7 | -4.1 | -1.1 |
| fire_fuel | generated | 2 | -25.1 | -2.5 | -3.5 |
| heal_bandage | generated | 2 | -21.6 | -5.3 | +0.0 |
| heal_poultice | generated | 2 | -21.0 | -4.3 | +0.5 |

## crafting (median -21.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| craft_bind | generated | 2 | -20.8 | -4.3 | +1.0 |
| craft_carve | generated | 2 | -20.8 | -5.0 | +1.0 |
| craft_knap | generated | 2 | -25.6 | -4.7 | -3.8 |
| craft_pound | generated | 2 | -23.6 | -4.3 | -1.7 |
| craft_stack | generated | 2 | -23.9 | -4.5 | -2.0 |
| craft_twine | generated | 2 | -21.1 | -4.4 | +0.7 |
| craft_wrap | generated | 2 | -21.9 | -4.3 | +0.0 |

## creatures (median -25.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bear_growl | recorded | 2 | -26.6 | -14.2 | -0.6 |
| bear_roar | generated | 2 | -19.5 | -7.2 | +6.4 |
| deer_grunt | recorded | 2 | -29.4 | -13.7 | -3.5 |
| deer_snort | generated | 2 | -26.0 | -7.3 | -0.1 |
| duck_quack | recorded | 2 | -21.9 | -10.9 | +4.0 |
| fox_bark | recorded | 2 | -27.2 | -14.1 | -1.2 |
| fox_scream | recorded | 1 | -28.3 | -14.0 | -2.4 |
| horse_snort | generated | 2 | -25.9 | -7.8 | +0.1 |
| horse_whinny | recorded | 2 | -30.5 | -14.1 | -4.6 |
| moose_bellow | recorded | 2 | -29.0 | -14.3 | -3.1 |
| moose_grunt | recorded | 2 | -28.5 | -14.0 | -2.6 |
| moose_snort | generated | 2 | -24.8 | -7.2 | +1.2 |
| rabbit_squeak | generated | 2 | -14.1 | -7.2 | +11.8 **outlier** |
| rabbit_thump | generated | 2 | -20.8 | -7.0 | +5.1 |
| wolf_growl | generated | 2 | -23.2 | -7.4 | +2.8 |
| wolf_howl | recorded | 2 | -24.4 | -13.8 | +1.5 |

## den (median -24.6 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| den_breath | generated | 3 | -21.4 | -5.9 | +3.1 |
| den_shuffle | generated | 3 | -27.7 | -8.2 | -3.1 |

## dig (median -20.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| dig_clay | generated | 3 | -20.5 | -1.3 | +0.3 |
| dig_gravel | generated | 3 | -25.3 | -1.8 | -4.5 |
| dig_ore | generated | 3 | -20.2 | -1.2 | +0.6 |
| dig_rock | generated | 3 | -21.8 | -1.0 | -1.0 |
| dig_sand | generated | 3 | -19.6 | -1.4 | +1.2 |
| dig_soil | generated | 3 | -24.0 | -1.4 | -3.2 |
| dig_water | generated | 3 | -20.8 | -1.1 | +0.0 |

## fire (median -24.0 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| fire_large | generated | 1 | -27.2 | -0.2 | -3.3 |
| fire_light | generated | 3 | -22.0 | -3.7 | +1.9 |
| fire_out | generated | 3 | -24.6 | -5.6 | -0.6 |
| fire_rain | generated | 1 | -24.0 | -3.0 | +0.0 |
| fire_small | generated | 1 | -24.2 | -0.3 | -0.3 |
| flame_lantern | generated | 1 | -18.7 | -6.2 | +5.3 |
| flame_torch | generated | 1 | -22.7 | -3.5 | +1.3 |

## floors (median -20.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| step_carpet | generated | 3 | -17.3 | -0.9 | +3.0 |
| step_ice | generated | 3 | -21.2 | -1.0 | -0.9 |
| step_path | generated | 3 | -18.5 | -0.7 | +1.8 |
| step_plank | generated | 3 | -19.4 | -0.9 | +0.9 |
| step_slab | generated | 3 | -22.7 | -1.1 | -2.4 |
| step_thatch | generated | 3 | -21.2 | -1.5 | -0.9 |

## gear (median -22.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| gear_chain | generated | 3 | -21.7 | -5.6 | +0.6 |
| gear_cloth | generated | 3 | -23.8 | -6.5 | -1.6 |
| gear_hobnail | generated | 3 | -27.5 | -7.9 | -5.2 |
| gear_iron | generated | 3 | -20.1 | -4.5 | +2.1 |
| gear_leather | generated | 3 | -19.9 | -5.6 | +2.3 |
| gear_plate | generated | 3 | -22.8 | -3.3 | -0.6 |

## harvest (median -23.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| pick_pluck | generated | 3 | -25.8 | -3.0 | -1.9 |
| pick_pull | generated | 3 | -21.6 | -3.2 | +2.3 |
| pick_snap | generated | 3 | -23.9 | -3.8 | +0.0 |
| pick_snip | generated | 3 | -27.3 | -4.6 | -3.4 |
| pick_twist | generated | 3 | -22.4 | -3.1 | +1.4 |
| plant_rustle_leaves | generated | 2 | -24.6 | -6.5 | -0.7 |
| plant_rustle_reeds | generated | 2 | -22.0 | -5.5 | +1.9 |

## hits (median -20.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| hit_axe_soil | generated | 3 | -18.8 | -1.2 | +1.5 |
| hit_axe_stone | generated | 3 | -22.8 | -1.7 | -2.5 |
| hit_axe_wood | generated | 3 | -20.4 | -1.5 | -0.1 |
| hit_hammer_soil | generated | 3 | -17.7 | -1.4 | +2.6 |
| hit_hammer_stone | generated | 3 | -22.5 | -1.4 | -2.2 |
| hit_hammer_wood | generated | 3 | -18.2 | -1.1 | +2.1 |
| hit_pick_soil | generated | 3 | -20.3 | -1.2 | +0.0 |
| hit_pick_stone | generated | 3 | -22.2 | -1.5 | -1.9 |
| hit_pick_wood | generated | 3 | -18.6 | -1.2 | +1.7 |
| hit_spade_soil | generated | 3 | -21.1 | -1.5 | -0.8 |
| hit_spade_stone | generated | 3 | -21.7 | -1.5 | -1.4 |
| hit_spade_wood | generated | 3 | -20.0 | -1.4 | +0.3 |

## ice (median -19.0 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| ice_crack | generated | 3 | -21.0 | -2.1 | -1.9 |
| ice_groan | generated | 3 | -17.1 | -3.1 | +1.9 |

## inner_voice/feminine_nervous_0 (median -17.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -15.8 | -1.9 | +1.7 |
| 0a5fec8b | generated | 1 | -17.4 | -1.2 | +0.1 |
| 15ccdee5 | generated | 1 | -19.2 | -1.8 | -1.7 |
| 216dcadd | generated | 1 | -15.7 | -2.0 | +1.8 |
| 252d67a7 | generated | 1 | -19.1 | -2.2 | -1.6 |
| 2a203c2e | generated | 1 | -17.3 | -2.1 | +0.2 |
| 4521bef6 | generated | 1 | -17.6 | -2.2 | -0.1 |
| 479f0bc7 | generated | 1 | -20.8 | -0.9 | -3.3 |
| 48e2fe37 | generated | 1 | -16.9 | -1.9 | +0.6 |
| 48ec7a9d | generated | 1 | -19.4 | -2.0 | -1.9 |
| 4a508293 | generated | 1 | -16.0 | -2.0 | +1.5 |
| 4e36a42b | generated | 1 | -19.8 | -2.6 | -2.3 |
| 5774e859 | generated | 1 | -18.9 | -1.8 | -1.4 |
| 62f306a8 | generated | 1 | -16.9 | -2.0 | +0.6 |
| 6ed1efcb | generated | 1 | -16.9 | -1.9 | +0.6 |
| 719f316d | generated | 1 | -16.8 | -3.5 | +0.7 |
| 7de54b77 | generated | 1 | -17.0 | -1.7 | +0.5 |
| 7f3c930f | generated | 1 | -17.4 | -2.1 | +0.1 |
| 9b7c47d3 | generated | 1 | -17.7 | -2.1 | -0.2 |
| a3250947 | generated | 1 | -16.4 | -1.8 | +1.1 |
| c2cf2d4e | generated | 1 | -18.7 | -2.0 | -1.2 |
| ccc82d9a | generated | 1 | -17.7 | -1.7 | -0.2 |
| e144cf25 | generated | 1 | -16.7 | -2.2 | +0.8 |
| ee0fb463 | generated | 1 | -18.3 | -2.2 | -0.8 |
| ef37517d | generated | 1 | -18.3 | -2.4 | -0.8 |
| f1b143e2 | generated | 1 | -16.6 | -2.0 | +0.9 |
| f3c493cf | generated | 1 | -17.9 | -2.5 | -0.4 |
| ffb7ac41 | generated | 1 | -17.6 | -1.1 | -0.1 |

## inner_voice/feminine_nervous_1 (median -20.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -21.7 | -0.9 | -1.2 |
| 0a5fec8b | generated | 1 | -21.5 | -1.8 | -0.9 |
| 15ccdee5 | generated | 1 | -22.4 | -1.8 | -1.9 |
| 216dcadd | generated | 1 | -21.6 | -2.1 | -1.0 |
| 252d67a7 | generated | 1 | -20.6 | -2.0 | -0.0 |
| 2a203c2e | generated | 1 | -18.1 | -1.9 | +2.5 |
| 4521bef6 | generated | 1 | -21.8 | -1.9 | -1.2 |
| 479f0bc7 | generated | 1 | -20.4 | -1.8 | +0.1 |
| 48e2fe37 | generated | 1 | -20.5 | -2.2 | -0.0 |
| 48ec7a9d | generated | 1 | -21.8 | -1.6 | -1.3 |
| 4a508293 | generated | 1 | -20.3 | -1.6 | +0.2 |
| 4e36a42b | generated | 1 | -21.6 | -2.3 | -1.1 |
| 5774e859 | generated | 1 | -19.5 | -1.4 | +1.1 |
| 62f306a8 | generated | 1 | -21.9 | -2.2 | -1.4 |
| 6ed1efcb | generated | 1 | -17.4 | -0.8 | +3.1 |
| 719f316d | generated | 1 | -19.0 | -1.5 | +1.5 |
| 7de54b77 | generated | 1 | -20.5 | -1.5 | +0.0 |
| 7f3c930f | generated | 1 | -18.4 | -1.8 | +2.1 |
| 9b7c47d3 | generated | 1 | -21.8 | -1.9 | -1.3 |
| a3250947 | generated | 1 | -18.5 | -1.8 | +2.0 |
| c2cf2d4e | generated | 1 | -18.3 | -1.6 | +2.2 |
| ccc82d9a | generated | 1 | -20.6 | -1.7 | -0.0 |
| e144cf25 | generated | 1 | -20.2 | -2.0 | +0.4 |
| ee0fb463 | generated | 1 | -18.4 | -2.0 | +2.1 |
| ef37517d | generated | 1 | -21.4 | -1.9 | -0.8 |
| f1b143e2 | generated | 1 | -20.3 | -1.5 | +0.2 |
| f3c493cf | generated | 1 | -22.7 | -1.5 | -2.2 |
| ffb7ac41 | generated | 1 | -18.3 | -2.1 | +2.2 |

## inner_voice/feminine_steady_0 (median -18.4 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -16.9 | -1.2 | +1.5 |
| 0a5fec8b | generated | 1 | -19.4 | -1.2 | -1.0 |
| 15ccdee5 | generated | 1 | -21.0 | -2.1 | -2.6 |
| 216dcadd | generated | 1 | -16.8 | -2.1 | +1.6 |
| 252d67a7 | generated | 1 | -18.7 | -2.1 | -0.3 |
| 2a203c2e | generated | 1 | -17.7 | -2.1 | +0.7 |
| 4521bef6 | generated | 1 | -17.0 | -2.2 | +1.4 |
| 479f0bc7 | generated | 1 | -17.5 | -2.3 | +0.9 |
| 48e2fe37 | generated | 1 | -18.6 | -2.0 | -0.2 |
| 48ec7a9d | generated | 1 | -19.6 | -2.0 | -1.2 |
| 4a508293 | generated | 1 | -18.2 | -1.4 | +0.2 |
| 4e36a42b | generated | 1 | -19.5 | -2.4 | -1.1 |
| 5774e859 | generated | 1 | -19.0 | -1.8 | -0.6 |
| 62f306a8 | generated | 1 | -17.7 | -1.6 | +0.7 |
| 6ed1efcb | generated | 1 | -16.1 | -2.3 | +2.3 |
| 719f316d | generated | 1 | -17.6 | -2.2 | +0.8 |
| 7de54b77 | generated | 1 | -17.4 | -1.8 | +1.1 |
| 7f3c930f | generated | 1 | -19.0 | -1.9 | -0.6 |
| 9b7c47d3 | generated | 1 | -17.6 | -2.1 | +0.8 |
| a3250947 | generated | 1 | -17.2 | -1.7 | +1.2 |
| c2cf2d4e | generated | 1 | -18.7 | -1.8 | -0.3 |
| ccc82d9a | generated | 1 | -19.6 | -2.3 | -1.2 |
| e144cf25 | generated | 1 | -17.1 | -2.0 | +1.3 |
| ee0fb463 | generated | 1 | -17.4 | -2.1 | +1.0 |
| ef37517d | generated | 1 | -19.2 | -1.9 | -0.7 |
| f1b143e2 | generated | 1 | -18.7 | -2.2 | -0.3 |
| f3c493cf | generated | 1 | -18.8 | -1.9 | -0.4 |
| ffb7ac41 | generated | 1 | -19.1 | -1.8 | -0.7 |

## inner_voice/feminine_steady_1 (median -18.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -19.3 | -1.8 | -0.8 |
| 0a5fec8b | generated | 1 | -17.9 | -2.1 | +0.6 |
| 15ccdee5 | generated | 1 | -21.4 | -2.4 | -2.9 |
| 216dcadd | generated | 1 | -17.4 | -1.8 | +1.1 |
| 252d67a7 | generated | 1 | -18.8 | -2.3 | -0.3 |
| 2a203c2e | generated | 1 | -19.2 | -1.9 | -0.7 |
| 4521bef6 | generated | 1 | -20.4 | -2.0 | -1.9 |
| 479f0bc7 | generated | 1 | -20.3 | -2.0 | -1.8 |
| 48e2fe37 | generated | 1 | -17.6 | -1.7 | +0.9 |
| 48ec7a9d | generated | 1 | -16.6 | -1.9 | +1.9 |
| 4a508293 | generated | 1 | -17.9 | -2.3 | +0.7 |
| 4e36a42b | generated | 1 | -18.5 | -1.5 | -0.0 |
| 5774e859 | generated | 1 | -17.7 | -1.9 | +0.8 |
| 62f306a8 | generated | 1 | -19.5 | -2.1 | -1.0 |
| 6ed1efcb | generated | 1 | -16.7 | -1.9 | +1.8 |
| 719f316d | generated | 1 | -17.6 | -1.6 | +0.9 |
| 7de54b77 | generated | 1 | -21.4 | -2.0 | -2.9 |
| 7f3c930f | generated | 1 | -16.9 | -1.9 | +1.6 |
| 9b7c47d3 | generated | 1 | -19.5 | -2.1 | -1.0 |
| a3250947 | generated | 1 | -16.6 | -1.7 | +1.9 |
| c2cf2d4e | generated | 1 | -18.7 | -1.9 | -0.2 |
| ccc82d9a | generated | 1 | -19.5 | -2.2 | -1.0 |
| e144cf25 | generated | 1 | -16.7 | -2.0 | +1.8 |
| ee0fb463 | generated | 1 | -18.7 | -2.3 | -0.2 |
| ef37517d | generated | 1 | -16.1 | -1.6 | +2.4 |
| f1b143e2 | generated | 1 | -19.9 | -3.9 | -1.3 |
| f3c493cf | generated | 1 | -18.5 | -2.0 | +0.0 |
| ffb7ac41 | generated | 1 | -17.6 | -2.0 | +0.9 |

## inner_voice/masculine_nervous_0 (median -20.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -20.5 | -2.0 | +0.3 |
| 0a5fec8b | generated | 1 | -20.3 | -2.0 | +0.5 |
| 15ccdee5 | generated | 1 | -22.0 | -1.6 | -1.2 |
| 216dcadd | generated | 1 | -19.7 | -1.9 | +1.1 |
| 252d67a7 | generated | 1 | -23.9 | -1.5 | -3.1 |
| 2a203c2e | generated | 1 | -21.1 | -2.1 | -0.3 |
| 4521bef6 | generated | 1 | -21.1 | -1.8 | -0.3 |
| 479f0bc7 | generated | 1 | -18.8 | -1.9 | +2.0 |
| 48e2fe37 | generated | 1 | -20.4 | -1.7 | +0.4 |
| 48ec7a9d | generated | 1 | -21.6 | -2.0 | -0.8 |
| 4a508293 | generated | 1 | -20.9 | -2.1 | -0.1 |
| 4e36a42b | generated | 1 | -21.9 | -1.7 | -1.1 |
| 5774e859 | generated | 1 | -20.4 | -1.9 | +0.4 |
| 62f306a8 | generated | 1 | -22.4 | -1.6 | -1.6 |
| 6ed1efcb | generated | 1 | -23.6 | -2.0 | -2.8 |
| 719f316d | generated | 1 | -20.9 | -1.8 | -0.1 |
| 7de54b77 | generated | 1 | -21.0 | -1.8 | -0.2 |
| 7f3c930f | generated | 1 | -20.7 | -2.2 | +0.1 |
| 9b7c47d3 | generated | 1 | -19.8 | -1.9 | +1.0 |
| a3250947 | generated | 1 | -20.2 | -2.0 | +0.6 |
| c2cf2d4e | generated | 1 | -20.0 | -1.3 | +0.8 |
| ccc82d9a | generated | 1 | -20.9 | -1.8 | -0.1 |
| e144cf25 | generated | 1 | -20.5 | -1.8 | +0.3 |
| ee0fb463 | generated | 1 | -22.2 | -1.9 | -1.4 |
| ef37517d | generated | 1 | -19.3 | -1.3 | +1.5 |
| f1b143e2 | generated | 1 | -19.6 | -2.0 | +1.2 |
| f3c493cf | generated | 1 | -19.9 | -1.8 | +0.9 |
| ffb7ac41 | generated | 1 | -20.9 | -2.1 | -0.1 |

## inner_voice/masculine_nervous_1 (median -19.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -20.0 | -2.0 | -0.3 |
| 0a5fec8b | generated | 1 | -18.7 | -2.0 | +1.0 |
| 15ccdee5 | generated | 1 | -20.9 | -2.1 | -1.2 |
| 216dcadd | generated | 1 | -21.6 | -1.6 | -1.9 |
| 252d67a7 | generated | 1 | -18.9 | -1.9 | +0.9 |
| 2a203c2e | generated | 1 | -18.8 | -2.1 | +1.0 |
| 4521bef6 | generated | 1 | -20.3 | -1.9 | -0.6 |
| 479f0bc7 | generated | 1 | -20.6 | -1.7 | -0.9 |
| 48e2fe37 | generated | 1 | -20.3 | -1.7 | -0.5 |
| 48ec7a9d | generated | 1 | -20.3 | -2.1 | -0.6 |
| 4a508293 | generated | 1 | -18.4 | -2.2 | +1.4 |
| 4e36a42b | generated | 1 | -19.6 | -1.7 | +0.1 |
| 5774e859 | generated | 1 | -17.4 | -1.9 | +2.4 |
| 62f306a8 | generated | 1 | -21.1 | -1.7 | -1.4 |
| 6ed1efcb | generated | 1 | -17.6 | -2.1 | +2.1 |
| 719f316d | generated | 1 | -20.5 | -1.9 | -0.8 |
| 7de54b77 | generated | 1 | -17.4 | -1.6 | +2.3 |
| 7f3c930f | generated | 1 | -20.9 | -1.9 | -1.2 |
| 9b7c47d3 | generated | 1 | -20.5 | -1.9 | -0.7 |
| a3250947 | generated | 1 | -18.0 | -2.1 | +1.8 |
| c2cf2d4e | generated | 1 | -17.1 | -2.2 | +2.7 |
| ccc82d9a | generated | 1 | -20.7 | -1.9 | -1.0 |
| e144cf25 | generated | 1 | -21.3 | -1.6 | -1.5 |
| ee0fb463 | generated | 1 | -18.1 | -2.1 | +1.6 |
| ef37517d | generated | 1 | -19.5 | -1.8 | +0.2 |
| f1b143e2 | generated | 1 | -18.9 | -1.9 | +0.9 |
| f3c493cf | generated | 1 | -19.8 | -2.1 | -0.1 |
| ffb7ac41 | generated | 1 | -18.0 | -1.2 | +1.7 |

## inner_voice/masculine_steady_0 (median -15.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -15.6 | -2.5 | +0.3 |
| 0a5fec8b | generated | 1 | -15.5 | -1.7 | +0.4 |
| 15ccdee5 | generated | 1 | -17.4 | -1.6 | -1.5 |
| 216dcadd | generated | 1 | -16.8 | -2.0 | -0.9 |
| 252d67a7 | generated | 1 | -16.6 | -1.9 | -0.7 |
| 2a203c2e | generated | 1 | -16.9 | -1.5 | -1.0 |
| 4521bef6 | generated | 1 | -15.7 | -2.2 | +0.3 |
| 479f0bc7 | generated | 1 | -15.1 | -1.7 | +0.9 |
| 48e2fe37 | generated | 1 | -16.0 | -2.3 | -0.1 |
| 48ec7a9d | generated | 1 | -18.0 | -2.0 | -2.1 |
| 4a508293 | generated | 1 | -16.0 | -1.6 | -0.1 |
| 4e36a42b | generated | 1 | -16.3 | -1.8 | -0.4 |
| 5774e859 | generated | 1 | -15.0 | -1.9 | +1.0 |
| 62f306a8 | generated | 1 | -17.3 | -2.3 | -1.4 |
| 6ed1efcb | generated | 1 | -15.0 | -2.1 | +0.9 |
| 719f316d | generated | 1 | -16.0 | -2.0 | -0.1 |
| 7de54b77 | generated | 1 | -15.7 | -1.9 | +0.2 |
| 7f3c930f | generated | 1 | -15.9 | -1.9 | +0.1 |
| 9b7c47d3 | generated | 1 | -15.2 | -1.8 | +0.7 |
| a3250947 | generated | 1 | -15.4 | -1.7 | +0.5 |
| c2cf2d4e | generated | 1 | -17.0 | -2.2 | -1.1 |
| ccc82d9a | generated | 1 | -15.6 | -1.7 | +0.3 |
| e144cf25 | generated | 1 | -17.4 | -1.9 | -1.5 |
| ee0fb463 | generated | 1 | -14.5 | -2.2 | +1.4 |
| ef37517d | generated | 1 | -16.5 | -1.5 | -0.6 |
| f1b143e2 | generated | 1 | -16.5 | -2.2 | -0.6 |
| f3c493cf | generated | 1 | -15.5 | -2.1 | +0.4 |
| ffb7ac41 | generated | 1 | -15.0 | -2.0 | +0.9 |

## inner_voice/masculine_steady_1 (median -20.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00207874 | generated | 1 | -20.2 | -1.9 | +0.5 |
| 0a5fec8b | generated | 1 | -21.4 | -2.2 | -0.7 |
| 15ccdee5 | generated | 1 | -21.8 | -1.8 | -1.1 |
| 216dcadd | generated | 1 | -21.3 | -1.9 | -0.6 |
| 252d67a7 | generated | 1 | -19.7 | -2.0 | +1.0 |
| 2a203c2e | generated | 1 | -20.9 | -2.0 | -0.2 |
| 4521bef6 | generated | 1 | -20.3 | -1.9 | +0.3 |
| 479f0bc7 | generated | 1 | -21.8 | -2.2 | -1.1 |
| 48e2fe37 | generated | 1 | -20.1 | -2.1 | +0.5 |
| 48ec7a9d | generated | 1 | -21.9 | -1.9 | -1.2 |
| 4a508293 | generated | 1 | -19.3 | -1.7 | +1.3 |
| 4e36a42b | generated | 1 | -19.8 | -2.0 | +0.8 |
| 5774e859 | generated | 1 | -19.7 | -1.8 | +0.9 |
| 62f306a8 | generated | 1 | -20.5 | -1.6 | +0.1 |
| 6ed1efcb | generated | 1 | -20.8 | -1.8 | -0.2 |
| 719f316d | generated | 1 | -22.1 | -2.0 | -1.4 |
| 7de54b77 | generated | 1 | -18.8 | -2.0 | +1.9 |
| 7f3c930f | generated | 1 | -19.0 | -2.0 | +1.7 |
| 9b7c47d3 | generated | 1 | -20.9 | -1.9 | -0.2 |
| a3250947 | generated | 1 | -19.9 | -1.9 | +0.8 |
| c2cf2d4e | generated | 1 | -18.4 | -1.9 | +2.2 |
| ccc82d9a | generated | 1 | -22.1 | -1.9 | -1.4 |
| e144cf25 | generated | 1 | -21.9 | -1.8 | -1.2 |
| ee0fb463 | generated | 1 | -20.8 | -2.1 | -0.1 |
| ef37517d | generated | 1 | -20.8 | -2.0 | -0.1 |
| f1b143e2 | generated | 1 | -21.5 | -1.6 | -0.9 |
| f3c493cf | generated | 1 | -18.9 | -1.8 | +1.8 |
| ffb7ac41 | generated | 1 | -19.1 | -1.8 | +1.6 |

## insects (median -26.1 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| insect_bed | generated | 2 | -26.1 | -10.0 | +0.0 |

## interior (median -15.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| chest_close | generated | 2 | -16.3 | -2.4 | -0.8 |
| chest_open | generated | 2 | -11.9 | -3.8 | +3.6 |
| door_close | generated | 2 | -15.9 | -2.6 | -0.4 |
| door_knock | generated | 2 | -16.3 | -3.0 | -0.8 |
| door_open | generated | 2 | -9.8 | -3.4 | +5.7 |
| furniture_drag | generated | 2 | -19.5 | -4.6 | -4.0 |
| gate_close | generated | 2 | -15.1 | -2.6 | +0.4 |
| gate_open | generated | 2 | -10.4 | -3.4 | +5.1 |
| hatch_close | generated | 2 | -15.7 | -2.6 | -0.2 |
| hatch_open | generated | 2 | -13.3 | -3.7 | +2.2 |
| interior_creak | generated | 2 | -12.4 | -6.5 | +3.1 |
| interior_rain_roof | generated | 1 | -16.5 | -0.6 | -1.0 |
| interior_room | generated | 1 | -15.3 | -3.4 | +0.2 |
| latch_click | generated | 2 | -23.9 | -6.0 | -8.4 **outlier** |

## items (median -21.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| craft_done | generated | 3 | -22.3 | -5.3 | -1.1 |
| craft_start | generated | 3 | -22.3 | -7.4 | -1.1 |
| hotbar_tick | generated | 3 | -24.7 | -8.2 | -3.5 |
| inv_close | generated | 3 | -21.9 | -5.8 | -0.7 |
| inv_open | generated | 3 | -19.8 | -6.1 | +1.4 |
| item_drop | generated | 3 | -18.3 | -4.2 | +2.9 |
| item_drop_bone | generated | 3 | -24.4 | -6.5 | -3.2 |
| item_drop_cloth | generated | 3 | -19.2 | -6.1 | +2.0 |
| item_drop_food | generated | 3 | -22.1 | -5.7 | -0.9 |
| item_drop_glass | generated | 3 | -21.4 | -6.1 | -0.2 |
| item_drop_metal | generated | 3 | -20.2 | -6.0 | +1.0 |
| item_drop_soft | generated | 3 | -19.4 | -5.7 | +1.8 |
| item_drop_stone | generated | 3 | -25.2 | -6.3 | -4.0 |
| item_drop_wood | generated | 3 | -19.0 | -5.8 | +2.2 |
| item_pickup | generated | 3 | -20.0 | -5.1 | +1.2 |
| item_pickup_bone | generated | 3 | -25.4 | -6.0 | -4.2 |
| item_pickup_cloth | generated | 3 | -22.0 | -7.6 | -0.8 |
| item_pickup_food | generated | 3 | -21.9 | -5.8 | -0.7 |
| item_pickup_glass | generated | 3 | -21.2 | -5.6 | +0.0 |
| item_pickup_metal | generated | 3 | -20.1 | -5.9 | +1.1 |
| item_pickup_soft | generated | 3 | -18.0 | -6.0 | +3.1 |
| item_pickup_stone | generated | 3 | -24.0 | -6.1 | -2.9 |
| item_pickup_wood | generated | 3 | -19.5 | -6.1 | +1.7 |
| item_reject | generated | 3 | -19.8 | -6.0 | +1.4 |
| item_swap | generated | 3 | -19.5 | -5.8 | +1.7 |

## landing (median -17.1 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| land_hard | generated | 3 | -16.2 | -2.0 | +0.9 |
| land_thud | generated | 3 | -18.0 | -3.8 | -0.9 |

## npc_voice/edda (median -22.6 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 06d04234 | generated | 1 | -22.5 | -5.3 | +0.1 |
| 0961b5e7 | generated | 1 | -22.3 | -5.3 | +0.3 |
| 09d0fcd0 | generated | 1 | -21.9 | -7.8 | +0.6 |
| 0d05a30e | generated | 1 | -22.5 | -5.8 | +0.0 |
| 0ebea2d8 | generated | 1 | -22.7 | -9.1 | -0.1 |
| 10155c7a | generated | 1 | -21.9 | -6.0 | +0.7 |
| 168c4414 | generated | 1 | -22.0 | -5.7 | +0.6 |
| 1d17e72a | generated | 1 | -22.8 | -5.7 | -0.2 |
| 28ba0d3b | generated | 1 | -22.9 | -8.0 | -0.4 |
| 2a2da381 | generated | 1 | -22.4 | -6.3 | +0.1 |
| 3162407f | generated | 1 | -22.8 | -6.5 | -0.2 |
| 35847613 | generated | 1 | -22.4 | -5.8 | +0.1 |
| 3a6f4687 | generated | 1 | -22.3 | -4.2 | +0.2 |
| 407f355a | generated | 1 | -22.8 | -4.8 | -0.3 |
| 4f6bd658 | generated | 1 | -21.5 | -3.3 | +1.1 |
| 67c21f3f | generated | 1 | -22.9 | -5.7 | -0.3 |
| 6bba4f82 | generated | 1 | -22.8 | -8.3 | -0.3 |
| 71046085 | generated | 1 | -22.7 | -7.0 | -0.2 |
| 7837de06 | generated | 1 | -22.7 | -7.4 | -0.2 |
| 79a3b3ef | generated | 1 | -21.8 | -5.4 | +0.8 |
| 7e10a682 | generated | 1 | -22.4 | -6.5 | +0.2 |
| 8952f11a | generated | 1 | -22.7 | -7.0 | -0.2 |
| a0f48199 | generated | 1 | -22.8 | -7.0 | -0.2 |
| ac4d285b | generated | 1 | -22.7 | -5.0 | -0.1 |
| ac600317 | generated | 1 | -22.2 | -5.8 | +0.4 |
| b2c56cea | generated | 1 | -22.8 | -6.3 | -0.3 |
| b9f9104b | generated | 1 | -21.4 | -4.7 | +1.1 |
| c0515e2e | generated | 1 | -22.7 | -8.7 | -0.2 |
| c2a8d1ee | generated | 1 | -22.6 | -8.3 | -0.1 |
| c46d8907 | generated | 1 | -22.0 | -5.4 | +0.5 |
| caf1fd90 | generated | 1 | -22.7 | -5.4 | -0.1 |
| d253c744 | generated | 1 | -21.5 | -6.0 | +1.0 |
| e8c9c8d2 | generated | 1 | -22.7 | -5.4 | -0.1 |
| e9f2aac1 | generated | 1 | -22.5 | -8.0 | +0.1 |
| ec265190 | generated | 1 | -22.7 | -5.9 | -0.1 |
| ed50d8da | generated | 1 | -22.1 | -6.1 | +0.4 |
| f0cc489b | generated | 1 | -22.6 | -5.8 | +0.0 |
| f3d647f3 | generated | 1 | -21.9 | -5.9 | +0.7 |
| fb7f6819 | generated | 1 | -22.6 | -5.1 | -0.0 |
| fce78737 | generated | 1 | -22.5 | -5.8 | +0.1 |
| fdbba75f | generated | 1 | -22.9 | -6.5 | -0.3 |

## npc_voice/hob (median -22.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| 00b05e2c | generated | 1 | -22.5 | -7.7 | +0.1 |
| 15286205 | generated | 1 | -22.3 | -7.6 | +0.2 |
| 19169a65 | generated | 1 | -22.6 | -9.0 | -0.0 |
| 1bd522ff | generated | 1 | -22.8 | -7.3 | -0.3 |
| 1c10d877 | generated | 1 | -22.9 | -9.6 | -0.3 |
| 219100d1 | generated | 1 | -22.3 | -5.7 | +0.2 |
| 2b960867 | generated | 1 | -22.3 | -8.4 | +0.2 |
| 2ba3e585 | generated | 1 | -22.1 | -5.6 | +0.4 |
| 3abaab94 | generated | 1 | -22.7 | -7.4 | -0.2 |
| 3adc8ba6 | generated | 1 | -22.8 | -6.6 | -0.3 |
| 3f0a1dac | generated | 1 | -22.7 | -8.3 | -0.1 |
| 49a252e4 | generated | 1 | -22.4 | -7.5 | +0.2 |
| 51faea65 | generated | 1 | -22.8 | -7.8 | -0.3 |
| 5638b18b | generated | 1 | -22.6 | -7.9 | -0.0 |
| 57999da7 | generated | 1 | -22.5 | -8.0 | +0.1 |
| 5cb082b4 | generated | 1 | -22.4 | -7.3 | +0.1 |
| 5cead08f | generated | 1 | -22.7 | -8.0 | -0.2 |
| 5fc83ae6 | generated | 1 | -22.8 | -9.3 | -0.3 |
| 62a46074 | generated | 1 | -22.7 | -8.7 | -0.2 |
| 641bd59c | generated | 1 | -22.1 | -7.9 | +0.4 |
| 705ca721 | generated | 1 | -22.8 | -7.6 | -0.2 |
| 7ee525c1 | generated | 1 | -22.2 | -6.9 | +0.3 |
| 7f7f6615 | generated | 1 | -21.6 | -6.2 | +0.9 |
| 8388fe96 | generated | 1 | -22.3 | -6.9 | +0.2 |
| 85e1e83e | generated | 1 | -22.7 | -8.5 | -0.2 |
| 998657b6 | generated | 1 | -22.3 | -5.6 | +0.2 |
| a7b5978e | generated | 1 | -22.2 | -6.1 | +0.3 |
| ac65772f | generated | 1 | -22.3 | -7.6 | +0.3 |
| b1e45a86 | generated | 1 | -22.6 | -8.2 | -0.1 |
| b258f697 | generated | 1 | -22.4 | -7.5 | +0.2 |
| b6d1f4a1 | generated | 1 | -22.8 | -8.5 | -0.3 |
| ba6f60ea | generated | 1 | -22.9 | -6.1 | -0.4 |
| bf235dd1 | generated | 1 | -22.5 | -8.9 | +0.0 |
| c98c1174 | generated | 1 | -22.9 | -8.7 | -0.4 |
| cbdd1d67 | generated | 1 | -22.3 | -7.3 | +0.2 |
| cf51e45e | generated | 1 | -22.7 | -6.0 | -0.1 |
| d5f47448 | generated | 1 | -22.3 | -6.8 | +0.2 |
| d79e31bd | generated | 1 | -22.1 | -6.5 | +0.5 |
| d9f6c158 | generated | 1 | -22.6 | -8.3 | -0.1 |
| db9c1d3f | generated | 1 | -22.5 | -5.8 | -0.0 |
| db9dc41f | generated | 1 | -22.8 | -6.8 | -0.3 |
| dba50f52 | generated | 1 | -22.5 | -8.8 | +0.0 |
| dbf75878 | generated | 1 | -22.8 | -7.9 | -0.2 |
| dc460261 | generated | 1 | -22.9 | -5.6 | -0.4 |
| e7d06fd7 | generated | 1 | -22.0 | -8.4 | +0.5 |
| e8a79634 | generated | 1 | -21.7 | -7.2 | +0.8 |
| f6b05024 | generated | 1 | -22.5 | -6.3 | +0.0 |

## placed (median -20.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bracing_crack | generated | 2 | -20.9 | -0.8 | +0.0 |
| bracing_creak | generated | 2 | -21.9 | -3.3 | -1.0 |
| bracing_rumble | generated | 2 | -17.3 | -1.9 | +3.6 |
| container_put | generated | 2 | -18.2 | -1.9 | +2.7 |
| container_take | generated | 2 | -20.2 | -1.9 | +0.7 |
| dust_patter | generated | 2 | -25.8 | -6.4 | -4.9 |
| pickup_placed | generated | 2 | -19.1 | -2.2 | +1.8 |
| place_brick | generated | 2 | -21.8 | -2.1 | -0.9 |
| place_chest | generated | 2 | -18.3 | -1.8 | +2.6 |
| place_foundation | generated | 2 | -20.7 | -1.7 | +0.2 |
| place_leanto | generated | 2 | -23.3 | -1.7 | -2.4 |
| place_stone | generated | 2 | -21.5 | -2.1 | -0.6 |
| place_thatch | generated | 2 | -23.9 | -3.4 | -3.0 |
| place_thump | generated | 2 | -19.3 | -2.3 | +1.6 |
| place_timber | generated | 2 | -21.6 | -2.0 | -0.7 |
| quake_tick | generated | 2 | -16.6 | -1.4 | +4.3 |
| soil_load | generated | 2 | -20.8 | -4.4 | +0.1 |
| stone_load | generated | 2 | -24.6 | -3.3 | -3.7 |
| tool_break | generated | 2 | -23.1 | -2.9 | -2.2 |
| tool_repair | generated | 2 | -22.1 | -2.5 | -1.2 |
| tool_warn | generated | 2 | -20.3 | -4.9 | +0.6 |

## r1 (median -29.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bed_lie | generated | 3 | -30.9 | -7.1 | -1.2 |
| bed_rise | generated | 3 | -30.2 | -7.3 | -0.6 |
| net_cast | generated | 3 | -29.1 | -6.8 | +0.6 |
| net_haul | generated | 3 | -21.3 | -6.0 | +8.4 **outlier** |
| thatch_pick | generated | 3 | -30.6 | -5.4 | -0.9 |
| twine_lash | generated | 3 | -21.9 | -6.1 | +7.7 |

## skill (median -27.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| skill_tock | generated | 3 | -27.8 | -14.0 | +0.0 |

## spear (median -20.4 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| spear_flight | generated | 3 | -21.5 | -7.0 | -1.2 |
| spear_hit_flesh | generated | 3 | -17.4 | -2.3 | +2.9 |
| spear_hit_soil | generated | 3 | -18.8 | -2.4 | +1.5 |
| spear_hit_stone | generated | 3 | -23.7 | -1.8 | -3.3 |
| spear_hit_wood | generated | 3 | -19.7 | -1.9 | +0.6 |
| spear_jab | generated | 3 | -21.0 | -4.2 | -0.7 |
| spear_throw | generated | 3 | -20.4 | -3.0 | +0.0 |

## splash (median -21.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| rain_splash_dirt | generated | 3 | -20.3 | -4.5 | +1.0 |
| rain_splash_grass | generated | 3 | -22.3 | -4.7 | -1.0 |
| rain_splash_gravel | generated | 3 | -24.3 | -4.6 | -3.0 |
| rain_splash_litter | generated | 3 | -21.7 | -4.3 | -0.4 |
| rain_splash_mud | generated | 3 | -17.4 | -4.3 | +3.9 |
| rain_splash_sand | generated | 3 | -23.5 | -5.5 | -2.2 |
| rain_splash_stone | generated | 3 | -20.8 | -4.7 | +0.4 |
| rain_splash_water | generated | 3 | -16.9 | -4.5 | +4.3 |

## stance (median -21.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| stance_crouch | generated | 3 | -20.7 | -4.9 | +0.6 |
| stance_lie | generated | 3 | -21.5 | -4.9 | -0.2 |
| stance_rise | generated | 3 | -21.2 | -4.8 | +0.1 |
| stance_settle | generated | 3 | -23.4 | -8.3 | -2.1 |
| stance_sit | generated | 3 | -21.3 | -5.0 | +0.0 |

## stepfx (median -21.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| cloth_walk | generated | 4 | -23.5 | -7.6 | -1.6 |
| wet_squelch | generated | 4 | -20.2 | -5.7 | +1.6 |

## swim (median -19.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| swim_dive | generated | 3 | -23.0 | -2.7 | -3.1 |
| swim_splash_big | generated | 3 | -18.9 | -1.4 | +0.9 |
| swim_splash_small | generated | 3 | -20.7 | -1.5 | -0.9 |
| swim_stroke | generated | 3 | -18.4 | -3.3 | +1.5 |
| swim_surface | generated | 3 | -20.9 | -2.1 | -1.1 |
| swim_under | generated | 1 | -15.3 | -3.3 | +4.5 |

## town (median -14.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| town_bell | generated | 3 | -16.3 | -2.1 | -1.6 |
| town_crowd | generated | 1 | -14.6 | -1.7 | +0.1 |
| town_fire | generated | 1 | -12.9 | -1.1 | +1.7 |
| town_hammering | generated | 1 | -14.8 | -1.8 | -0.1 |

## trees (median -19.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| stump_chips | generated | 3 | -26.5 | -4.9 | -6.7 |
| tree_crash | generated | 3 | -15.1 | -0.7 | +4.7 |
| tree_creak | generated | 3 | -17.5 | -4.4 | +2.2 |
| tree_leaves | generated | 3 | -22.0 | -6.0 | -2.2 |

## treewind (median -15.4 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| treewind_bare | generated | 1 | -15.3 | -2.2 | +0.1 |
| treewind_dry | generated | 1 | -22.0 | -2.2 | -6.6 |
| treewind_leaves | generated | 1 | -15.4 | -2.3 | +0.0 |
| treewind_pine | generated | 1 | -15.4 | -1.8 | -0.0 |

## ui (median -16.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| ui_click | generated | 2 | -22.2 | -6.3 | -5.9 |
| ui_off | generated | 2 | -15.2 | -4.5 | +1.1 |
| ui_on | generated | 2 | -15.3 | -4.5 | +1.0 |
| ui_quality | generated | 2 | -17.3 | -5.0 | -1.0 |

## water (median -15.6 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| lake_lap | generated | 3 | -33.5 | -12.7 | -17.8 **outlier** |
| water_brook | recorded | 1 | -23.7 | -2.1 | -8.0 **outlier** |
| water_fall | generated | 1 | -15.3 | -2.5 | +0.3 |
| water_fall_base | generated | 1 | -15.9 | -2.8 | -0.2 |
| water_pond | generated | 1 | -15.4 | -3.2 | +0.2 |
| water_river | generated | 1 | -15.4 | -3.3 | +0.2 |

## weather (median -19.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| rain_drip | generated | 4 | -18.0 | -3.0 | +1.3 |
| rain_heavy | generated | 1 | -16.5 | -1.2 | +2.8 |
| rain_leaves | generated | 1 | -18.4 | -1.1 | +0.8 |
| rain_light | generated | 1 | -16.9 | -0.1 | +2.4 |
| rain_litter | generated | 1 | -19.0 | -1.2 | +0.3 |
| rain_mud | generated | 1 | -17.1 | -0.3 | +2.2 |
| rain_roof | generated | 1 | -19.9 | -1.1 | -0.7 |
| rain_snow | generated | 1 | -20.0 | -1.5 | -0.7 |
| rain_stone | generated | 1 | -20.0 | -1.5 | -0.7 |
| rain_water | generated | 1 | -19.6 | -1.8 | -0.3 |
| rain_woodroof_heavy | generated | 1 | -19.7 | -1.4 | -0.5 |
| rain_woodroof_light | generated | 1 | -20.6 | -1.4 | -1.3 |
| thunder | generated | 3 | -21.0 | -1.3 | -1.7 |
| thunder_far | generated | 3 | -15.3 | -2.8 | +4.0 |
| thunder_near | generated | 3 | -22.4 | -1.1 | -3.1 |
| wind_storm | generated | 1 | -15.3 | -2.9 | +3.9 |

## wet (median -20.4 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| drip_plink | generated | 4 | -18.7 | -4.2 | +1.6 |
| drip_trickle | generated | 2 | -25.3 | -10.8 | -5.0 |
| wet_step | generated | 4 | -20.4 | -3.7 | +0.0 |

## windhole (median -15.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| wind_hollow | generated | 1 | -15.2 | -3.2 | +0.1 |
| wind_whistle | generated | 1 | -15.3 | -3.7 | -0.1 |

## workshop (median -19.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| chop_split | generated | 3 | -21.0 | -1.8 | -1.4 |
| chop_thock | generated | 3 | -18.3 | -2.0 | +1.4 |
| plank_drop | generated | 2 | -25.1 | -3.3 | -5.4 |
| saw_mill | generated | 1 | -15.4 | -2.0 | +4.3 |

## Footsteps as heard (file RMS + SURFACE_DB, before gait)

| surface | file RMS | SURFACE_DB | heard |
|---|---|---|---|
| bushes | -18.6 | -13.0 | -31.6 |
| dirt | -18.3 | -10.0 | -28.3 |
| grass | -18.4 | -15.0 | -33.4 |
| grass_tall | -18.5 | -14.0 | -32.5 |
| gravel | -19.0 | -9.0 | -28.0 |
| leaves | -18.6 | -6.0 | -24.6 |
| mud | -18.2 | -10.0 | -28.2 |
| sand | -18.4 | -11.0 | -29.4 |
| snow | -18.5 | -11.0 | -29.5 |
| stone | -19.0 | -8.0 | -27.0 |
| water | -18.5 | -10.0 | -28.5 |

Median -28.5 dB. Surfaces more than 3 dB off (a deliberate hierarchy: soft grass, crunchy leaves; judge by ear): bushes (-3.2), grass (-5.0), grass_tall (-4.1), leaves (+3.8)

## Nature calls as played (file RMS + the call's level at the source, before distance)

| call | file RMS | EVENTS db | played |
|---|---|---|---|
| bird_chirp | -9.6 | -12.0 | -21.6 |
| bird_feebee | -7.7 | -11.0 | -18.7 |
| bird_trill | -10.4 | -12.0 | -22.4 |
| bird_whistle | -8.5 | -10.0 | -18.5 |
| cricket_chirp | -14.1 | -16.0 | -30.1 |
| crow_caw | -21.3 | -8.0 | -29.3 |
| fish_splash | -28.3 | -10.0 | -38.3 |
| frog_croak | -21.7 | -18.0 | -39.7 |
| hawk_screech | -15.1 | -4.0 | -19.1 |
| owl_hoot | -7.5 | -13.0 | -20.5 |
| tree_frog_peep | -21.3 | -14.0 | -35.3 |
| woodpecker | -23.5 | -5.0 | -28.5 |

Median -25.4 dB. More than 4 dB off: bird_feebee (+6.8), bird_whistle (+7.0), cricket_chirp (-4.6), fish_splash (-12.9), frog_croak (-14.3), hawk_screech (+6.4), owl_hoot (+5.0), tree_frog_peep (-9.8)
