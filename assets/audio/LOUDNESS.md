# Loudness table (make with `python3 assets/audio/loudness_report.py --md`)

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
| step_gravel_left | recorded | 3 | -18.3 | 0.2 | +0.2 |
| step_gravel_right | recorded | 3 | -18.7 | -1.0 | -0.3 |
| step_leaves_left | recorded | 3 | -18.7 | -2.4 | -0.2 |
| step_leaves_right | recorded | 3 | -18.6 | -1.8 | -0.1 |
| step_mud_left | recorded | 3 | -18.1 | -1.7 | +0.3 |
| step_mud_right | recorded | 3 | -18.2 | -3.8 | +0.2 |
| step_sand_left | recorded | 3 | -18.4 | -2.4 | +0.1 |
| step_sand_right | recorded | 3 | -18.4 | -1.4 | +0.1 |
| step_snow_left | recorded | 3 | -18.4 | -0.5 | +0.1 |
| step_snow_right | recorded | 3 | -18.5 | -1.5 | -0.0 |
| step_stone_left | recorded | 3 | -18.3 | 0.2 | +0.2 |
| step_stone_right | recorded | 3 | -18.7 | -1.0 | -0.3 |
| step_water_left | recorded | 3 | -18.5 | -2.1 | -0.0 |
| step_water_right | recorded | 3 | -18.4 | -1.1 | +0.1 |
| wind_gust | generated | 1 | -20.4 | -1.9 | -1.9 |
| wind_low | generated | 1 | -20.4 | -2.0 | -1.9 |

## ambient (median -17.5 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bird_chirp | generated | 3 | -9.6 | -0.8 | +8.0 |
| bird_feebee | generated | 3 | -7.7 | -1.8 | +9.9 **outlier** |
| bird_trill | generated | 3 | -10.4 | -1.8 | +7.2 |
| bird_whistle | generated | 3 | -8.5 | -1.7 | +9.1 **outlier** |
| cricket_chirp | generated | 3 | -14.1 | -4.1 | +3.5 |
| crow_alarm | recorded | 3 | -20.0 | -5.4 | -2.5 |
| crow_caw | recorded | 7 | -21.3 | -1.9 | -3.7 |
| fish_splash | recorded | 3 | -28.3 | -3.6 | -10.8 **outlier** |
| frog_croak | recorded | 6 | -21.7 | -2.3 | -4.2 |
| hawk_screech | generated | 3 | -15.1 | -2.0 | +2.5 |
| owl_hoot | generated | 3 | -7.5 | -1.8 | +10.1 **outlier** |
| tree_frog_peep | recorded | 6 | -21.3 | -2.5 | -3.7 |
| wing_flap | recorded | 5 | -26.1 | -5.6 | -8.5 **outlier** |
| woodpecker | generated | 3 | -23.5 | -2.5 | -6.0 |

## cave (median -21.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| cave_drip | generated | 5 | -21.2 | -1.7 | +0.0 |

## creatures (median -15.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| bear_growl | generated | 2 | -18.0 | -1.6 | -2.6 |
| bear_roar | generated | 2 | -12.2 | -0.1 | +3.1 |
| deer_grunt | generated | 2 | -14.0 | -2.4 | +1.4 |
| deer_snort | generated | 2 | -21.4 | -3.3 | -6.1 |
| fox_bark | generated | 2 | -18.0 | -2.5 | -2.7 |
| fox_scream | generated | 2 | -15.0 | -3.3 | +0.4 |
| rabbit_squeak | generated | 2 | -9.9 | -4.0 | +5.4 |
| rabbit_thump | generated | 2 | -15.7 | -1.9 | -0.4 |
| wolf_growl | generated | 2 | -18.6 | -2.5 | -3.3 |
| wolf_howl | generated | 2 | -10.1 | -3.0 | +5.2 |

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

## fire (median -19.0 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| fire_large | generated | 1 | -12.3 | 0.5 | +6.7 |
| fire_light | generated | 3 | -19.0 | -3.7 | +0.0 |
| fire_out | generated | 3 | -24.5 | -5.4 | -5.5 |
| fire_rain | generated | 1 | -19.5 | 2.5 | -0.5 |
| fire_small | generated | 1 | -15.4 | 2.1 | +3.6 |

## gear (median -22.2 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| gear_chain | generated | 3 | -21.7 | -5.6 | +0.6 |
| gear_cloth | generated | 3 | -23.8 | -6.5 | -1.6 |
| gear_hobnail | generated | 3 | -27.5 | -7.9 | -5.2 |
| gear_iron | generated | 3 | -20.1 | -4.5 | +2.1 |
| gear_leather | generated | 3 | -19.9 | -5.6 | +2.3 |
| gear_plate | generated | 3 | -22.8 | -3.3 | -0.6 |

## hits (median -20.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| hit_axe_soil | generated | 3 | -18.8 | -1.2 | +1.5 |
| hit_axe_stone | generated | 3 | -22.8 | -1.7 | -2.5 |
| hit_axe_wood | generated | 3 | -20.4 | -1.5 | -0.0 |
| hit_hammer_soil | generated | 3 | -17.7 | -1.4 | +2.6 |
| hit_hammer_stone | generated | 3 | -22.5 | -1.4 | -2.1 |
| hit_hammer_wood | generated | 3 | -18.2 | -1.1 | +2.1 |
| hit_pick_soil | generated | 3 | -20.3 | -1.2 | +0.0 |
| hit_pick_stone | generated | 3 | -22.2 | -1.5 | -1.9 |
| hit_pick_wood | generated | 3 | -18.6 | -1.2 | +1.7 |
| hit_spade_soil | generated | 3 | -21.1 | -1.5 | -0.8 |
| hit_spade_stone | generated | 3 | -21.7 | -1.5 | -1.4 |
| hit_spade_wood | generated | 3 | -20.0 | -1.4 | +0.3 |

## interior (median -15.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| chest_close | generated | 2 | -16.3 | -2.3 | -0.4 |
| chest_open | generated | 2 | -11.9 | -3.8 | +4.0 |
| door_close | generated | 2 | -15.9 | -2.7 | +0.0 |
| door_knock | generated | 2 | -16.3 | -3.0 | -0.4 |
| door_open | generated | 2 | -9.8 | -3.4 | +6.1 |
| furniture_drag | generated | 2 | -19.5 | -4.6 | -3.6 |
| interior_creak | generated | 2 | -12.4 | -6.5 | +3.5 |
| interior_rain_roof | generated | 1 | -16.4 | 0.9 | -0.5 |
| interior_room | generated | 1 | -15.3 | -3.4 | +0.6 |

## items (median -19.9 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| craft_done | generated | 3 | -22.3 | -5.3 | -2.4 |
| inv_close | generated | 3 | -21.9 | -5.8 | -2.0 |
| inv_open | generated | 3 | -19.8 | -6.1 | +0.1 |
| item_drop | generated | 3 | -18.3 | -4.2 | +1.6 |
| item_pickup | generated | 3 | -20.0 | -5.1 | -0.1 |
| item_swap | generated | 3 | -19.5 | -5.8 | +0.5 |

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

## swim (median -19.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| swim_dive | generated | 3 | -23.0 | -2.7 | -3.1 |
| swim_splash_big | generated | 3 | -18.9 | -1.4 | +0.9 |
| swim_splash_small | generated | 3 | -20.7 | -1.5 | -0.9 |
| swim_stroke | generated | 3 | -18.4 | -3.3 | +1.5 |
| swim_surface | generated | 3 | -20.9 | -2.1 | -1.1 |
| swim_under | generated | 1 | -15.3 | -3.3 | +4.5 |

## town (median -13.8 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| town_bell | generated | 3 | -16.3 | -1.4 | -2.5 |
| town_crowd | generated | 1 | -14.6 | -0.8 | -0.8 |
| town_fire | generated | 1 | -12.9 | -0.9 | +0.8 |
| town_hammering | generated | 1 | -11.1 | 1.3 | +2.6 |

## ui (median -16.3 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| ui_click | generated | 2 | -22.2 | -6.3 | -5.9 |
| ui_off | generated | 2 | -15.2 | -4.5 | +1.1 |
| ui_on | generated | 2 | -15.3 | -4.5 | +1.0 |
| ui_quality | generated | 2 | -17.3 | -5.0 | -1.0 |

## water (median -15.7 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| water_brook | generated | 1 | -16.1 | 1.0 | -0.3 |
| water_fall | generated | 1 | -15.4 | -3.4 | +0.3 |
| water_pond | generated | 1 | -14.0 | 1.2 | +1.7 |
| water_river | generated | 1 | -16.9 | 1.8 | -1.1 |

## weather (median -17.1 dB)

| slot | source | files | RMS dB | peak dB | vs median |
|---|---|---|---|---|---|
| rain_drip | generated | 4 | -18.1 | -3.3 | -1.0 |
| rain_heavy | generated | 1 | -16.4 | 2.7 | +0.7 |
| rain_leaves | generated | 1 | -16.4 | 3.2 | +0.7 |
| rain_light | generated | 1 | -16.8 | 2.3 | +0.3 |
| rain_water | generated | 1 | -17.1 | 1.8 | +0.0 |
| thunder | generated | 3 | -22.9 | -0.8 | -5.8 |
| thunder_far | generated | 3 | -17.7 | -2.8 | -0.6 |
| thunder_near | generated | 3 | -22.6 | -1.0 | -5.5 |
| wind_storm | generated | 1 | -15.3 | -3.4 | +1.8 |

## Footsteps as heard (file RMS + SURFACE_DB, before gait)

| surface | file RMS | SURFACE_DB | heard |
|---|---|---|---|
| bushes | -18.6 | -13.0 | -31.6 |
| dirt | -18.3 | -10.0 | -28.3 |
| grass | -18.4 | -15.0 | -33.4 |
| grass_tall | -18.5 | -14.0 | -32.5 |
| gravel | -18.5 | -9.0 | -27.5 |
| leaves | -18.6 | -6.0 | -24.6 |
| mud | -18.2 | -10.0 | -28.2 |
| sand | -18.4 | -8.0 | -26.4 |
| snow | -18.5 | -11.0 | -29.5 |
| stone | -18.5 | -8.0 | -26.5 |
| water | -18.5 | -10.0 | -28.5 |

Median -28.3 dB. Surfaces more than 3 dB off (a deliberate hierarchy: soft grass, crunchy leaves; judge by ear): bushes (-3.3), grass (-5.1), grass_tall (-4.2), leaves (+3.7)

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
