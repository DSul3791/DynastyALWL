















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

## jamie-hills-375 | Terrain 53 (#375): taller, more frequent hills, rivers that no longer stop at ridges, spring caves. It passed the PC tests. Merge it?
Note: Recommendation: merge now, then look in game when you next play.
- Yes, merge it now (recommended)
- Wait, I will look in game first

## jamie-leanto-leaves | The lean-to needs 200 leaves, about 34 trees, which is roughly 9 of the first hour's 13 minutes (#386). Change it?
Note: Recommendation: 80 leaves, about one felled crown.
- Cut it to 80 leaves (recommended)
- Keep 200
- Another number: I will say

## jamie-foundations-hammer | Foundations: your 25 Oct note said made by hand, but your 4 Nov answer said hammer blueprint only (stacking is merged, #311). Settled as hammer only?
- Yes, hammer blueprint only (recommended)
- No, also by hand

## jamie-animal-meshes | Animals are code shapes that shaders can't improve. Model real animal meshes?
- Yes, but later at rank 6 (recommended)
- Yes, now
- No, keep the code shapes

## jamie-far-grass-fade | Far grass: start the fade at 0.25 of the draw distance instead of 0.5?
- Decide after the grass walk (recommended)
- Yes, 0.25
- No, keep 0.5

## jamie-cold-acclimation | Cold acclimation: how does a character get used to the cold?
- Slowly, from time spent in the cold, with a cap (recommended)
- Not at all
- Another way: I will say

## jamie-wet-clothes | Wet clothes: should clothes stay damp about 1 hour after rain or a swim and keep you less warm?
- Yes (recommended)
- No

## jamie-gravel-path | Add a gravel path mode to the hoe?
- Later, after roads are settled (recommended)
- Yes, now
- No

## jamie-torch-relight | A torch that went out (rain or water): how does it light again? Built now: E at a burning fire (#361).
- E at a burning fire, as built (recommended)
- Another way: I will say

## jamie-lantern-now | Lantern item (works in rain, goes out under water): add it now?
- Later (recommended)
- Now

## jamie-burnt-fire | A burnt-out fire is deleted after 5 minutes. Change it?
- Leave a cold fire that stays and can be relit (Dino's idea, recommended)
- Keep deleting it after 5 minutes

## jamie-raw-meat | Raw meat sickness feels harsh. Make it milder?
- Yes, milder (recommended)
- Keep it as is

## jamie-wildflower-size | Wildflower heads are drawn about 4 times real size (a dandelion head about 15 to 20 cm, real about 4 cm). What size?
Note: Recommendation (Kathleen): halfway keeps the meadow's colour from afar and stops them looking giant next to the body.
- Halfway, about 8 cm (recommended)
- Real size, about 4 cm
- Keep them as they are

## jamie-footstep-clip | Your two footstep recordings (step_gravel_left, step_stone_left) clip at +0.2 dB.
- Jason trims them with declip.py (recommended)
- I will re-export them

## jamie-storm-sound | Storm sound (BUG-001): what was the name of the sound you heard? (Shift+F3 lists playing sounds.)
[text]

## jamie-clear-tile-340 | Thatch floor, floor section and foundation section still clear a 5 m circle of plants. Make them clear only their own tile, like log, stone and brick floors (#340)?
- Yes, own tile only (recommended)
- No, keep the 5 m circle

## jamie-rain-warmth | Should rain make you colder at night than it does now?
Note: PC check, no clothes: about 45% warmth at 7 C, 56% at 10 C. It is one number in warmth.json.
Note: Recommendation (Steve): rain x1.5, which matches the code's own default.
- Rain x1.5: a rainy night is clearly colder, about 6 to 8 points (recommended)
- Keep as is (rain x1.2): a rainy night costs about 2 points more than a dry one at 10 C
- Rain x2.0: harsh, so shelter matters a lot

## kathreen-npc-clothes | Town NPCs on your body: how do they get their shirt and trousers?
- Wear the game's real tunic and trousers pieces in their own colours, as players do (recommended; a first try looked a bit blocky, so I'd smooth them first)
- Paint a flat shirt and trousers on the skin
- Wait for your skin and cloth mask texture from the body file

## kathreen-meadow-gain | Meadow grass tufts at noon: Sonny already toned them down a little (#416, gain 0.85 to 0.72). PC shots: /mnt/project-files/meadow421_compare_level_yaw90.png and meadow421_down30.png. How do they look now?
- They look fine, keep them (recommended)
- Still too pale or bright, tone down more (gain 0.6)
- Haven't looked yet, ask me again after I play

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
