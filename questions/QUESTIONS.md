















## pic-felled-bark-after | In the real game: do the stump and the cut log now look like brown bark (before: dark grey smooth, card pic-fh-felled-trunk)?
Image: questions/img/felled_bark_after.png
Note: Real game rig shot, same spot as the guide picture. The cause was missing warm shading; fixed with a brightness lift on the bark shader. Kathleen rates it 3.5 of 5: brown and textured; the stump side still looks smooth and the log is a plain block.
- Yes
- No

## berries-stew-cook | Food: do berries (4 kcal) stew in a pot, and does the campfire refuse plants?
Note: 1. Pick 3 berries and hold water. Put a berry in the campfire: it should not cook (campfire cooks only meat and fish).
Note: 2. Place a clay pot on the campfire (6 clay, then 3 sticks and 3 twine), put in 3 berries and water.
Note: 3. Note whether you get Stewed berries and whether the hint about the pot appeared once.
[test]

## pic-flora-orchard-rows | In the real game: do the orchard trees read as rows of fruit trees?
Image: questions/img/flora_orchard_rows.jpg
Note: Real game rig shot at noon from the south edge of the orchard, (53376,68535). The rows read, but it is dark under the crowns and no fruit is visible from this height. Flora rates it 3 of 5; fruit visibility is a look question for Kathleen.
- Yes
- No

## jason-clear-hiss | Please test this: in clear, calm weather in a forest, do you hear a rain-like hiss?
Note: Blocked: the PC sound-log run hasn't happened yet. SOUND_AUDIT.md suspects the tree-wind loops (leaves, pine).
Note: 1. Start the latest build, wait for clear weather (F3 shows rain 0.00). 2. Walk into a forest and stand still for 30 s. 3. Then walk into open meadow for 30 s.
Note: Look for: a steady hiss like rain in the forest that stops in the meadow. If you hear it, open F3 and write the loudest sound line in the Notes box.
[test]

## mikew-pixabay-animal-calls | Sounds: when you have time, can you download Pixabay calls for boar, grouse, seal and seabird?
Note: Neither the cloud nor the PC thread can download from Pixabay, so this needs your hands (MikeW). On pixabay.com/sound-effects, 2 or 3 real field recordings per animal, no music or voices, nothing labelled AI or synthesized.
Note: Search: boar "wild boar grunt", "boar squeal"; grouse "grouse call", "black grouse", "ptarmigan"; seal "seal bark", "grey seal"; seabird "seagull", "herring gull", "gull colony".
Note: Drop them in the project folder at sound/incoming/<animal>/ (boar, grouse, seal, seabird), with a short urls.txt listing each clip's Pixabay page link. Jason then cuts and levels them.
[test]

## claude-leanto-cost | You said no to 32 sticks, 8 leaves, 4 twine for the lean-to. Too much or too little?
Note: Your earlier OK was 24 sticks, 6 leaves, 4 twine. It was raised to 32 / 8 / 4. The "No" does not say which way.
Note: Recommendation: too much for the first hour. Go to 16 sticks, 4 leaves, 2 twine, about 10 minutes of gathering.
[A] Lighter: 16 sticks, 4 leaves, 2 twine
[B] Heavier than now
[C] Back to 24 / 6 / 4

## roads-early-goals | Early goals: add "make a hoe" and "tread a path from camp to water", right after the fire goal?
Note: The first-hour goal list has no hoe or path step today, so new players may never find the road and path tools (#136, #137, #161).
Note: Recommendation: A, because a short path from camp to water is a quick, visible win that teaches the hoe early.
- A: Yes, both goals right after the fire goal
- B: Yes, but later (after the lean-to and bed)
- C: No, leave the hoe for players to discover

## jason-audio-listen-1103 | Please listen once after you pull: are the forest sounds right now (no wobble, no rain-on-leaves when sunny, night quiet by the fire)?
Note: Changed in the last day, none of it heard by me (no Godot or ears here): the night hush is 18 dB quieter (#115), the winter tree creaks lost their wobble (#115), tree wind is silent in calm weather (#131), the leaves loop patters less (#184), and Shift+F3 now opens a list of every playing sound with a mute switch (#134).
Note: If something still sounds bad, press Shift+F3, switch sounds off one at a time, and tell me the name that made it stop.
[A] All good now
[B] Still a bad sound: I will send the name from Shift+F3
[C] Better, but one thing is still off: I will say which

## dynasty-hair-female | Dave's body: hair, beard and a female body need real meshes. Can you export them like the base male (rigged GLB on the same Mixamo skeleton)?
Note: 1. The creator now shapes your body (PR #195), but the head is bald and every frame, feminine included, uses the male body.
Note: 2. Code-made hair on your 55k-triangle body would look plastic and low-poly, which the art direction rules out.
Note: 3. Wanted: a few hair styles and beards as separate rigged meshes on the Head bone, plus Dynasty_Base_Female.glb on the same 24 bones. Drop them in assets/character/Humanoid/ and I will wire them into the creator.
Note: Recommendation: Yes, export them. Until then the body stays bald and male, and the creator says so.
[text]

## jason-cave-den-sounds | What lives in the cave side-branch dens, and how should they sound as you get close?
Note: Sonny's spring caves have 1 to 3 side branches, each ending in a den "where creatures live" (#170). There is no spec yet for which animals, so I have not built den sounds. The existing pack has wolf, fox, boar, bat-free cave drips and breathing (no snarl or growl clips).
Note: Recommendation: A. Quiet until about 12 m from the den mouth, then a slow low breathing and the occasional shuffle, never a growl, so it reads as "something sleeps here" and not as a jump scare.
[A] Sleeping-animal breathing and shuffles only, from about 12 m, no growls
[B] Same, plus a low warning growl when you come within 4 m
[C] Nothing yet, wait for the animal spawns to be decided

## jason-first-night-soundscape | First-night sound: is what exists calm enough?
Note: Read from code, not heard. On a first night in the forest by the fire you should have: the fire crackle (wind, surf and the night bed now drop about 9 dB near a lit fire, #115), a very quiet night hush (cut 18 dB), crickets on warm nights, and an owl hoot every 30 to 70 s from 40 to 110 m away that sometimes answers itself (in winter and spring more often).
Note: Recommendation: A. It is already calm; only tune after you have listened once.
[A] Leave it as it is, I will tell you after I listen
[B] Fewer owl hoots: every 60 to 120 s
[C] No owl on the very first night

## jason-skill-chime | A soft sound when a skill goes up?
Note: Skills rise silently now: no text and no sound. The client sees each skill's level arrive (skills message), so a sound is easy to hook.
Note: Recommendation: A. A very soft, short wooden tock, at most once every 20 s, so it tells you that practice is working without feeling like an arcade game.
[A] Soft wooden tock, at most once per 20 s
[B] Only when a skill reaches a training cap (25, 50, 75)
[C] No sound for skills

## npc-dynasty-body | Should town NPCs use your new body (Dave's mesh) too?
Note: The player has used your body since 1 Nov. NPCs still use the older generated body.
Note: With #254 (clothes on your body) and #195 (proportion sliders), NPCs could use your body, each with its own shape and skin, in their merchant and guard clothes.
Note: Yes: I build it. No: NPCs stay on the old body.
Note: Recommendation: Yes, once #195 and #254 are merged and pictured
[text]
