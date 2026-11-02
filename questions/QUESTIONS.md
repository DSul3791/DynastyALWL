















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

## pic-p2-leanto-bed | Do the lean-to and the rough bed look like something you would shelter and sleep in?
Image: questions/img/p2_leanto_bed.jpg
Note: Real client, third person, lean-to left, rough bed right (the rig sets them in a row, the bed is not inside the lean-to here). Guide rates it 3.5 of 5: lean-to reads as a thatch frame; the bed is a yellow mattress on a frame.
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
