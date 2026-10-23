









## kath-flora-thorn-shrubs | Do the wild rose and blackthorn look like the real shrubs?
Image: questions/img/thorn_shrubs.png
Note: Preview (offline preview with flat stand-in leaves; in the game the leaves carry the leaf texture and autumn colours hide the fruit).
Note: Raspberry: arching canes, red berries (some unripe yellow). Bramble: long arching thorny canes, black berries, white flowers. Wild rose: thorny canes, pink flowers, red hips. Blackthorn: dark twiggy canes, small leaves, blue sloes. Nettle: upright stems, paired leaves. Blueberry: small twiggy bush, blue berries.
Note: Recommendation: Yes, these are the simple accurate shapes; I will fine tune from your Why-not answers.
[check]

## kath-flora-small-plants | Do the nettle and blueberry look like the real plants?
Image: questions/img/small_plants.png
Note: Preview (offline preview with flat stand-in leaves; in the game the leaves carry the leaf texture and autumn colours hide the fruit).
Note: Raspberry: arching canes, red berries (some unripe yellow). Bramble: long arching thorny canes, black berries, white flowers. Wild rose: thorny canes, pink flowers, red hips. Blackthorn: dark twiggy canes, small leaves, blue sloes. Nettle: upright stems, paired leaves. Blueberry: small twiggy bush, blue berries.
Note: Recommendation: Yes, these are the simple accurate shapes; I will fine tune from your Why-not answers.
[check]

## kath-wolf-howl-compare | Does the new placeholder wolf howl sound any more like a wolf?
Note: 1. After Tyler merges the wolf-howl branch and you press Pull, open the folder questions\audio in your project folder. 2. Play wolf_howl_0_OLD.ogg (the one you disliked), then wolf_howl_0_NEW.ogg. 3. Answer Yes if NEW sounds closer to a wolf (even if not good enough), No if it is still fake; add what is wrong in Notes. Real clips will replace both either way.
Note: Recommendation: Keep NEW only as a placeholder until real wolf clips arrive, because synthesis cannot be trusted to sound like a real wolf and I cannot listen to it myself.
[test]

## kath-wolf-real-clips | Do the real wolf howl recordings (clip A and clip B) sound like a wolf?
Note: 1. After Pull, open the folder questions\audio in your project folder. 2. Play wolf_clip_A_universfield.ogg and wolf_clip_B_freesound.ogg (these two are what the game will use). 3. Spares if you dislike them: wolf_spare_02 and wolf_spare_04 (04 is titled haunting and may have echo). Answer Yes if A and B are good enough to keep, No if not, and say which clip is the problem.
Note: Recommendation: Yes, keep A and B because they are real recordings, clean (noise floor at or below -70 dB, no clipping) and each is a single howl; I could not listen myself, so your ear decides.
[check]

## kath-fox-real-clips | Do the real fox clips (a bark and a scream) sound like a fox?
Note: 1. After Pull, open the folder questions\audio. 2. Play fox_bark_clip.ogg, then fox_scream_clip.ogg. 3. Answer Yes if both are fine to keep, No if not, and say which one is wrong in Why-not.
Note: Recommendation: Yes, keep both because they are real recordings with a clean background (floor -60 dB or lower); I could not listen, so your ear decides.
[check]

## kath-deer-horse-real-clips | Do the real deer grunt and the two horse neighs sound right?
Note: 1. After Pull, open the folder questions\audio. 2. Play deer_clip.ogg, horse_clip_A.ogg and horse_clip_B.ogg. 3. Answer Yes if all three are fine, No if not, and say which one in Why-not.
Note: Recommendation: Yes, keep them because they are real recordings with almost no background noise; the deer grunt is short (under 2 seconds), which suits a grunt.
[check]

## kath-moose-standin | Use an elk bugle as the moose call for now?
Note: 1. After Pull, open the folder questions\audio and play moose_standin_elk_bugle.ogg. 2. Pixabay has no real moose call, so this is an elk. Answer Yes to use it for the moose until a real moose recording turns up, No to keep the synthetic moose sound.
Note: Recommendation: No, keep the synthetic moose for now, because an elk bugle is a different animal and a wrong sound will bother you more than a rough one.
[check]

## kath-bear-real-clips | Do the real bear growls (clip A and clip B) sound like a bear?
Note: 1. After Pull, open the folder questions\audio. 2. Play bear_clip_A.ogg, then bear_clip_B.ogg. 3. Answer Yes if both are fine, No if not, and say which one in Why-not.
Note: Recommendation: Yes, keep both because they are real growls, clean, and about 3 to 6 seconds long; I could not listen, so your ear decides.
[check]

## playtester-plan | Build a play-tester that plays the game and reports problems?
Note: Plan in 3 stages (tech/PLAYTESTER_IDEA.md). 1. Scripted runs: the look rig walks, digs, chops, crafts and takes pictures. 2. A bot with a goal list that reports pass or fail with screenshots. 3. A Claude session that looks at the screen and presses keys, only if the tools exist on your PC. Starts small with stage 1 by Steve and MikeW.
Note: Tyler recommends Yes: start with stage 1 now because it is cheap, safe and replaces many test cards you have been getting; decide stage 3 later.
Note: Rule from you: the bot gets exact steps from Tyler and Guru, and every step says what it expects to see. If something expected is missing, it stops at once and reports step, expected, seen and a screenshot so it gets fixed.
[check]
