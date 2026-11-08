# Self review of the life-layer branch (MikeW, 8 Nov 2026)

`claude/mikew-eye-placement` read end to end against main 91b51800 (and the main merged in after it), as a strict reviewer would:
dead code, duplicated helpers, naming, flags read in several places, node lookups by string, magic numbers, TODOs. Behaviour kept
the same throughout; every change is a fold, a rename or a named constant.

## Static tools (no game runs)
- `tools/merge_check.py`: all clear. `tools/check_doc_links.py`: 0 dead links. `tools/check_luck.py`: ok (every `randf` in the hooks
  carries its luck-exempt note). `tools/check_shader_comments.py`: clean. `tools/check_dupe_names.py`: ok.
- `tools/check_warnings.sh --changed` (Godot's own script warnings, no game run): 5 warnings in changed files before, 2 after. The 3
  fixed were mine: the voice signal's argument named `call` (it shadows `Object.call`; now `voice`), a ternary mixing a
  ShaderMaterial and a StandardMaterial3D (now an if), and creature_motion's option parser ternary (now an if chain). The 2 left are
  older lines in terrain_client.gd that are not this branch's (line 1950 `sea` shadowing, from 31 Oct; line 4487 integer division,
  from 4 Nov): left for their owners.

## Changed
1. **One helper file for the hooks:** `src/client/life_layer_util.gd` (`LifeUtil`): `rig(node)` for the Rig every look turns, `fire_once`
   for the one-shot particle effects (puffs, splashes, spouts, steam all ended with the same four lines), `see_through` for their
   material. 15 Rig lookups and 4 particle tails now go through it.
2. **One camera helper:** `_cam()` replaces 8 copies of the camera-or-null line.
3. **One row helper:** `_row_of(node)` replaces 7 copies of the `model_row` read where the node is a single animal. The flock's own
   node keeps reading its own (empty) row in `_flap_bob`, so a model flock still does not bob as a whole: that one stays as it was.
4. **Named constants** for the new hooks' numbers: eye shine (`SHINE_FACE_FULL_DEG` 30, `SHINE_FACE_OFF_DEG` 60, `SHINE_READS_DARK_M` 20,
   `SHINE_READS_MOON_M` 5, `SHINE_MOON_SHARE` 0.1, `SHINE_DOTS_FROM_M` 6, `SHINE_DOTS_FULL_M` 10, `RETRO_DEG` 12), steam
   (`STEAM_NEAR_M` 30), the mother (`MOTHER_SEARCH_M` 8, `NURSE_NEAR_M` 3), alongside the ones already named (`SIGN_CAP`,
   `SIGN_NEAR_M`, `GAME_DAY_S`, `COLD_C`, `HUDDLE_C`, `GALE`, `PRINT_CAP`, `HERD_M`, `HERD_SPACE_M`).
5. **No TODO, FIXME or XXX** in the branch's files (checked).

## Left as they are, and why
- **Flags read in more than one place:** `eye_shine`, `idle_variety` and `coat_ruffle` are read when a model is built (to make the dots,
  the idle poses, the ruffle shader) and again each frame (to drive them). That is the build-time and run-time halves of one feature,
  not a duplicate test; folding them into one read would mean rebuilding models when a flag flips, which nothing does today. The
  kill switch `_all_flags_off` is the one place every flag is written.
- **The Rig found by name:** the "Rig" node is made in code by `_make_model` and the code bodies, never loaded from a scene, so a
  scene rename cannot break it; its name now lives in one constant (`LifeUtil.RIG`).
- **Other magic numbers:** the remaining ones are short easing rates and pose angles inside one function each (a shake's 42 rad/s,
  a stumble's 0.22 rad). They are described in the function's comment and its design note; moving them to a data file would not
  make them easier to tune than where they are. Species values (strides, colours, calls, sizes) are already in the data files.
- **The older print path (`prints_fx`):** kept beside `animal_sign`, which replaces it when on; dropping it waits for the PC check
  of the newer one.
- **Particle bodies:** each effect keeps its own amount, speeds and colours in its function; only the start and the free are shared.

## Size
`animal_view.gd` grew with the branch; it now holds about 30 look functions behind 21 flags. A split into one script per look
family (feet, coats, weather, hunting) is the natural next step once the PC check says which looks stay; it is not done here
because it would move every line and hide the behaviour review in a diff of moves.

## After the gate: one weather sampler (8 Nov 2026)
Checked how the animal looks read the weather against Kathleen's client code:
- **Air temperature:** both call the shared `Weather.air_c` (#620); the animals through terrain_client's `air_at`. One function, no copy.
- **Wind direction:** both read the same `terrain_client.weather` dictionary (`wind_dir`), which `wind_cue.gd` also reads; Kathleen's
  prevailing wind will feed that one field. One source.
- **Fog (updated):** Kathleen's #724 (head d733a6e5) adds `weather_look.visibility_m` (3 / the drawn fog density round the eye:
  rain, snow, storm, fog, valley fog, under water; 50 km when clear). terrain_client's `_animal_fog` now reads it whenever the
  weather look has it and falls back to the density otherwise, so the switch happens by itself when #724 merges; the fallback line
  can go after that. Before: the animals read the scene Environment's `fog_density` that her weather look sets, and the shared state's `mist`; her sky
  and sound code read her own smoothed `_s` values in weather_look.gd. Two readings of one thing: the animals' visibility is a
  guess from the density. **After the gate:** a `visibility_m` exposed by the weather look (asked of Kathleen in ANIMAL_FOG.md)
  becomes the one sampler for both, and `fog_now` reads only that.
- The animal side reads each source once a frame (`_refresh_frame`), so there is one cache per frame on this side whatever the source.

## pr18 to pr21 (fog, prevailing wind, cave air, drinking), read the same way (8 Nov 2026)
- **Flags:** `fog_looks`, `cave_air`, `drink_looks` are new, all false, in `LIFE_FLAGS` and the kill switch; pr19 reuses `wind_looks`
  (and `coat_ruffle` for feathers). `--life=` turns any of them on by name.
- **Samplers:** fog through `fog_now` (the scene fog density until Kathleen's `visibility_m`), cave air through `cave_c_at` (one rock
  ray per 2 m cell, cached 5 s), drinking through the existing `water_level`; all read once a frame or cached, none in a per-pair loop.
- **Duplicates:** none new. The cave's deep air uses the shared climate numbers; it becomes a call to Steve's `cave_climate.gd` when
  #715 merges (one formula). The trample patch reuses the sign pool and its generated shapes.
- **Magic numbers:** named at their sections (`FOG_M`, `THICK_FOG_M`, `FOG_SHINE_M`, `PREVAILING_TO`, `RUMP_WIND`, `RUMP_RAIN`,
  `GRAZE_WIND`); the drink and bathe timings are short ranges described in the function comment.
- **Static tools:** merge_check clear, doc links 0 dead, luck ok; `check_warnings.sh --changed` still only the two older
  terrain_client.gd lines that are not this branch's.
- **Left:** the fog sampler unification (above), the cave mouth blend (needs Steve's `cave_mouths` on the client), the fire list
  for drying (`fire_near` unset), and every server request in ANIMAL_FOG.md and ANIMAL_DRINK.md.

