















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

## jason-first-night-soundscape | First-night sound: is what exists calm enough?
Note: Read from code, not heard. On a first night in the forest by the fire you should have: the fire crackle (wind, surf and the night bed now drop about 9 dB near a lit fire, #115), a very quiet night hush (cut 18 dB), crickets on warm nights, and an owl hoot every 30 to 70 s from 40 to 110 m away that sometimes answers itself (in winter and spring more often).
Note: Recommendation: A. It is already calm; only tune after you have listened once.
[A] Leave it as it is, I will tell you after I listen
[B] Fewer owl hoots: every 60 to 120 s
[C] No owl on the very first night

## jamie-storm-sound | Storm sound (BUG-001): what was the name of the sound you heard? (Shift+F3 lists playing sounds.)
[text]

## sal-cookpot-ghost | Cookpot: when it will not place, what does the red ghost text say? Can you send a screenshot in the thread?
Note: I could not reproduce it from the code, and a screenshot of the red text shows me which rule blocks it.
Note: Recommendation: A. I will wait for the screenshot and then fix it.
- A: Yes, I will send a screenshot
- B: It places fine now, close the bug
- C: Skip it until it happens again

## sal-net-windowed | Fishing net duplicate (BUG-022): will you try the net once in the windowed game?
Note: It did not reproduce on land or in water in tests.
Note: Recommendation: B. Only tell me if you see it duplicate on your own.
- A: Yes, I will try it and say what happens
- B: Skip it, I will tell you if I see it

## mikew-bear-threat-ranges | Bear PR #480: how close before an animal charges instead of fleeing? Built: bear 15 m at its den and 9 m elsewhere, moose 8, boar 6, deer 3.5, horse 3, fox 2.
- Keep these ranges (recommended)
- Change them: I will say how

## mikew-cornered-attack | Bear PR #480: do deer, horses and foxes attack when cornered or surprised that close?
- Yes, with weak hits of 4 to 10 damage (recommended)
- No, they only flee

## mikew-bear-numbers | Bear PR #480: a bear hit does 35 damage, it charges at 12 m/s, has 120 HP, wanders up to 80 m from its den, and half its trips go fishing at the river.
- Keep these numbers (recommended)
- Change them: I will say how

## mikew-bear-poses | Bear PR #480: fishing, foraging and sleeping poses. For now the bear only walks to those spots.
- Later (recommended)
- Now
