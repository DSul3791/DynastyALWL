# MikeW's PC gate, in one sitting (8 Nov 2026)

The exact order for Dave's PC slot (Dino or MikeW at the keyboard), from `C:/GodotProjects/DynastyALWL_gate` in Git Bash. Everything runs
on the full branch `claude/mikew-eye-placement`, whose tree is the top PR branch's (`claude/mikew-pr25-breath`). Commands are the run
sheet's (PC_SESSION_MIKEW.md) and the shot list's (DINO_SHOTS.md); this page is the order, the flags and the time. **About 1 h 55 min.**

| Step | What | Flags on | Proves | Time |
|---|---|---|---|---|
| 0 | Branch and model import (run sheet step 0) | none | the models load | 3 min |
| 1 | Baseline frame probe: the client at the starter valley (x 53296, z 68080) for 2 minutes with `--life-layer-off` | all off (the kill switch) | the cost on main's terms | 4 min |
| 2 | Head sheets, lynx clips, still checks (run sheet steps 1 to 3) | none | eye placement, dog sit and lie, swim and hop clips | 11 min |
| 3 | The 60 motion strips, m1 to m60, in the run sheet's order (step 4) | each strip turns on only its own flags | every PR below | 52 min |
| 4 | Look through the strips against DINO_SHOTS.md's slot list (each line says what to see) | | pass or fail per strip | 10 min |
| 5 | The live shots (optional): cave mouth, spring brook, basin pond (DINO_SHOTS.md "live" rows) | `--life=` as each row says | the looks in the real world | 10 min |
| 6 | The same frame probe as step 1 with every flag on: `--life=footfall_fx,prints_fx,slope_tilt,foot_ik,stalk_fx,season_coats,coat_dust,coat_ruffle,young_gait,young_follow,water_life,idle_variety,flight_bank,look_at_foe,swarm_fx,sea_life,voice_fx,eye_shine,animal_sign,weather_looks,hunt_feedback,cover_still,bird_rig,swim_rig,wind_looks,fog_looks,cave_air,drink_looks,ice_looks,storm_looks,pose_lib,breath_looks` | all | the whole layer's cost (PERF_BUDGET.md) | 5 min |
| 7 | Gates (run sheet step 5): `gate_pc.sh --lane fast` for `claude/mikew-eyeshine`, `claude/mikew-wet-look`, `claude/mikew-eye-placement` | | CHECKS: pass | 25 min |
| 8 | Send the strips, the two frame-probe numbers and the gate results to MikeW; the PRs open after (run sheet step 6, summary order) | | | 5 min |

## Which strips prove each PR
| PR | Strips |
|---|---|
| pr03 always-on looks | m1 to m10 |
| pr04 footfall and feet | m11 to m14 |
| pr05 predators and flight | m15 to m18 |
| pr06 coats, young, water, idles | m19 to m27 |
| pr08 flight part 2, foe, wiring | m28 to m34 |
| pr09 young part 2, voices, eye shine v2 | m35 to m37 |
| pr10 animal sign | m38 to m40 |
| pr11 weather looks | m41 to m44 |
| pr12 hunting feedback | m45 to m47 |
| pr13 cost pass | the two frame-probe runs (steps 1 and 6) |
| pr14 follow-ups | m38, m39, m48 |
| pr15 posed birds | m49 |
| pr16 posed swimmers | m50 |
| pr17 wind direction | m51 |
| pr18 fog | m52 |
| pr19 prevailing wind | m53 |
| pr20 cave air | m54 |
| pr21 drinking | m55 |
| pr22 ice and snow | m56, m59 |
| pr23 thunder | m57 |
| pr24 pose library | m58, m59 |
| pr25 breath and steam | m60 |

## If time runs short
Steps 0 to 3 for m1 to m27 and step 7 are the core (about 1 hour): they prove the PRs that can merge first (3 to 6) and gate the
branches. The rest of step 3 (m28 to m60) and steps 5 and 6 can follow in a second sitting without redoing the import.

## What is not run
No tests or bakes in the cloud (Dave's rule); no game tests beyond the gate's own lanes; the herd groups server test belongs to #666's
gate (David4).
