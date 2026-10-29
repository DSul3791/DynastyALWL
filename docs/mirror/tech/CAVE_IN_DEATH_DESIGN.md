# Cave-in death sequence (Dave 03:13 UTC 23 Oct; design by Guru, no building tonight)
Today: inside a collapsing tunnel the screen goes black and says "you died". Dave: it worked, but boring. Wants a slow, dramatic death.
## Sequence (about 25 s, in this order)
1. 0-6 s THE FALL: the roof comes down slowly, not in one frame: dust, rumble, rocks drop in 3 to 5 waves. Damage lands in 3 to 5 chunks, one per wave; at each hit the player staggers, then drops to the ground and lies down on the last one. (Death still needs the 90 s warning rule first: BP collapse rule.)
2. 3-10 s VISION: the picture darkens and blurs, then fades to black over about 4 s.
3. 4-12 s HEARING: the cave-in rumble keeps going for about 3 s after the picture is dark, then the sound fades out too.
4. 12-16 s SKULL: a grey, translucent skull and crossbones fades in over a black screen, about 75% of the screen height.
5. 16-24 s VOICE: line 1 (sad): "I tried to warn you, but would you listen? Oh no..." Then a pause, then line 2 (jokey, a Jack Sparrow feel): "Oh well, now you're dead." Pause for effect. Line 3: "Better luck next time, eh?"
6. 24-28 s END: skull and text fade out slowly; the screen fades in on the next one (inheritance or character creation).
## Owners and how
- Steve: sequence controller (new death_cavein state: timing, chunked damage, stagger and lie-down, blackout, hand over to the next screen), server side only needs the cause "cave-in" with the death message. RUNTIME if client only.
- Kathleen: skull and crossbones art (grey, translucent, cartoon-grim but not gory; PNG with alpha), audio fades (rumble tail 3 s), voice and sting sounds.
- Voice: Kokoro is not built. v1 PLACEHOLDER: each line shows as large subtitle text under the skull, timed as above, with a short low horn sting at line 1 and a light comic sting at line 2. The real voice drops in later by swapping sound files; no code change.
- Death by other causes keeps today's simple screen until Dave asks otherwise.
## Test for Dave (after the build): dig a tunnel, let the 5 minute cave-in run, stay inside. Look for: damage in chunks, you lie down, picture fades, rumble continues then fades, skull, three lines, fade to next screen.
