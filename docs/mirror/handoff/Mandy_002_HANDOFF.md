# Mandy_002 handoff (Arts Director and sounds) -> Mandy_003

Rules as in Mandy_001_HANDOFF.md (branch claude/generator-v2 only, claim a build in tech/BUILD_LOG.md and terrain_client.gd BUILD, check_warnings, headless load, tech/TEST_QUEUE.md lines instead of asking Dave for tests, questions only in questions/QUESTIONS.md). Dave's rule 2026-10-22: focus on the present (movement, physics, water, tunnels, building), not the far future. Basic world sounds are mine.

## Done (all pushed)
- 607 grass: no blades in dug tunnels or over a hole mouth (dig list per grass cell in grass_view.gd).
- 626 wall/floor/roof timber look (generated board textures in piece_look.gd), place_timber sound (states 22-24).
- 627 sand footsteps 3 dB quieter (Dave: "beach a little loud", taken as sand; he never said which; ask if he meant waves).
- 630 foundation look (4x4x0.3 stone course, earth top) and place_foundation sound (state 25).
- 634 tunnel warning sounds: sound.placed.quake(stage, strength, at); Willy wired it in 635 (fires once bracing items exist).
- 639 campfire jet-engine roar removed (fire_small, fire_large; crackle unchanged).
- Dave approved: rock digging, tunnel echo/reverb, running on grass, fire crackle, fire placement green/red. Listed in sound/LISTEN_CHECKLIST.md.

## Parked (not pushed)
- Animal art (moose, horse, fox quadruped build with animations): /mnt/project-files/handoff/Mandy_002_animal_quads.patch (applies to src/client/animal_view.gd, loads headless, never seen on screen). Dave said not now.
- Dave's answers: no music; wolves howl only at night, far away, more in winter; other players' footsteps heard at 15 m; NPCs mutter rarely, short lines.
- Plan: sound/TUNNEL_WARNING_SOUND_PLAN.md (dust particles at the roof still to do).

## Waiting on
- Dave hearing: TEST_QUEUE lines 626, 630, 639 (look and sound). Nothing else.

## Traps
- make_*.py regenerates every ogg differently each run: after running one, `git checkout` the unchanged oggs and add only new ones. .import files are gitignored.
- Cloud engine is headless: no screenshots, no audio; measure files with ffmpeg/numpy.
- Engine for headless tests: xz -dc /mnt/project-files/engine/*.xz, then `godot --headless --path . --import` once.
