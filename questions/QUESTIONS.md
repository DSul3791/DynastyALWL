















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

## tyler-windowed-checks-1103 | Please test this, after you pull: do the new water, hoe, road and grass changes look right and run without hitches?
Note: These were merged on cloud tests only; they need your eyes in the real game. One pull covers all of them.
Note: 1. Pull, close the game fully, press Play.
Note: 2. Brooks (#167): stand at x 53480 z 68825 and look east, then at x 53521 z 68882 and look east. The hillside stream should be one flowing body with no gaps or patches.
Note: 3. Hoe (#136): dig a few path squares. The path decal should show, with no pause on the click and no SHADER ERROR in the console.
Note: 4. Roads (#137): with the hoe, Shift + right click to drop marker A, walk about 15 m over bumpy ground, then drop B. A road should build by itself with no hitches.
Note: 5. Grass (#140): stand in tall grass in first person, then press the third-person key. No flat green carpet around your feet in either view.
Note: 6. Lag (#157, #155, #158): walk past a felled log and kick it. If anything pauses, copy the HITCH and FREEZE lines from the console into the Notes box.
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

## sal-bed-hammer | Should the rough bed be built from the wooden hammer (a blueprint) instead of crafted by hand?
Note: You said: make our own rough bed in our own lean-to using the wooden hammer. Today it is a hand craft (10 thatch, 4 sticks, 2 twine) placed as a kit.
Note: A blueprint would also need the feather and canopy beds changed, because they upgrade the bed kit.
Note: Recommendation: No, keep it a hand craft placed in the lean-to, because it works today and the hammer needs a chopped wooden block first, which slows the first hour.
[check]

## creator-proportions-pr195 | Creator: does Dave's body change shape when you move Height, Legs, Arms, Head and Shoulders (PR #195)?
Note: 1. Check out PR #195 and run tools/run_tests.sh --fast test_dynasty_proportions test_dynasty_body.
Note: 2. Open the character creator and drag Height, Legs, Arms, Head and Shoulders from end to end.
Note: 3. The body should reshape at once while the feet stay on the floor. Then press Play and check that the body in game has the same shape.
Note: Recommendation: Yes if it reshapes cleanly. Width and face sliders are not done yet.
[check]
