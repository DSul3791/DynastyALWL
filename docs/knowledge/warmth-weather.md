# Warmth and weather: cold, rain, wet, drying, fire heat

**Last checked:** 2026-11-06 (web research by Jamie). **System owner:** Steve. **Related:** `data/items/warmth.json`, `src/stream/server_items.gd` (the warmth tick), `docs/COMFORT_DESIGN.md` (shelter and Rested), `docs/SEASONS_DATA.md`, [torches-fire.md](torches-fire.md), [caves.md](caves.md).

## Lessons (read these first)

1. **Cold works like hunger.** Warmth is a vital from 0 to 100. Cold costs health slowly, down to 1, never straight to death (Dave, 21 Oct). Warnings come first: "You are getting cold", then "You are freezing".
2. **Model a felt temperature, not just a bar.** Air temperature (season, time of day, height), minus wind chill and rain, plus clothing and fire, gives what the body feels. Warmth moves toward it, cooling slowly (`tau_cool_h` 3 h) and warming fast (`tau_warm_h` 0.5 h). The Long Dark and Don't Starve both work this way.
3. **Wetness is its own state, not a fact about the rain falling now.** You stay wet after the rain stops, and the chill follows how wet you are. Don't Starve drops felt temperature in proportion to wetness (up to 30 degrees at full wet). Valheim keeps "Wet" for a while after the rain. Ours has a soak level from 0 to 1 (#491).
4. **Only shelter and fire dry you** (Dave's rain card, 5 Nov). In the open with no rain you stay wet; under a tree or roof you dry slowly; by a fire you dry fast. Valheim does the same: a roof stops it, and a fire only dries you when you are out of the rain.
5. **Leave room between "cold" and "warm again".** Use two thresholds (cold at 40, clear at 52; hurt at 20, clear at 32) so messages don't flicker at the edge.
6. **Water is colder than air.** Swimming soaks you right through, and water follows the air only partly (`water_follow` 0.7). Spring cave pools are icy at 2°C (#316, #410).
7. **Shelter must use one cover query everywhere.** Rain, beds, comfort and drying all ask the same Cover query (roofs plus grown trees). Two different rules for "sheltered" would confuse players.
8. **Keep old tests stable.** A player the tick hasn't reached yet falls back to the old rule, so existing warmth test numbers hold (#491).

## How ours works (6 Nov 2026)

- **Air:** comfort at 20°C; lapse of 0.0065°C per metre of height; daily swing by season (spring 9, summer 11, autumn 9, winter 5), low at 6:30 and high at 15:00.
- **Chill:** wind chill up to 6°C, cut to 30% under cover; rain chill × `rain_mult` (1.5 after #491), none under cover.
- **Heat:** a lit fire adds 20°C within 4 m; clothing insulation up to 0.85.
- **Wet** (#491): soak rises 4/h in open rain or snow, up to the rain's strength; swimming soaks you fully; dries 6/h within a fire's reach and 1/h under cover above 0.5.
- **Effects:** cold under 40, hurt under 20 at 0.15 health a second, shivering adds effort. Rested from comfort lowers cold stress (`COMFORT_DESIGN.md`).

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| 21 Oct | Warmth vital: cold costs health slowly, like hunger | | Worked; the base model |
| 4 Nov | Fire heat in the early-game guide | #198 | Worked |
| 4-5 Nov | Spring cave pools icy; the cold covers the whole basin | #316, #410 | Worked (BUG-008) |
| 5 Nov | Rain chill: Dave picked ×1.5 on his card | card | Answered |
| 6 Nov | Rain chill follows a soak level that dries only under shelter (1/h) or by a fire (6/h); `rain_mult` 1.2 to 1.5 | #491 | Worked: merged 6 Nov (110abbec), PC gate 112/0. Lesson: the first head broke test_warmth's "a built roof cuts the wind". After the test's snowfall the body stayed wet, as designed, so the roof check measured a soaked player. When adding a lasting state, check later tests that assume it's gone and reset it there on purpose. |

## What others do (with sources)

- **Valheim, Wet.** Rain or water above the waist makes you Wet for 120 s, and the timer resets while you stay exposed. It lowers health and stamina regeneration and blocks Rested and beds. A roof prevents it. Standing by a fire cuts the timer by 10 s a second, but only out of the rain. https://valheim.fandom.com/wiki/Wet
- **Don't Starve, wetness.** A 0 to 100 meter that builds in rain; leafy trees cut the rate by 35%; umbrellas and rain gear block 35-100%. Drying starts only once you stop getting wetter, faster by a fire. Felt temperature drops in proportion, 30 degrees at full wet. https://dontstarve.fandom.com/wiki/Wet_Items
- **The Long Dark, warmth.** A felt temperature from air, wind chill, clothing and fire; wet clothes lose warmth and can freeze; you dry them by a fire. Hypothermia risk builds over hours of cold. https://thelongdark.fandom.com/wiki/Hypothermia
- **Valheim, comfort and Rested.** Shelter plus nearby comfort pieces give Rested; our comfort design follows the same idea. https://wiki.indifferentbroccoli.com/en/Valheim/Comfort

## Decided / next

1. ~~#491 through the PC gate (test_warmth).~~ Done (merged 6 Nov).
2. Wet clothes (DAVE_TODO 7): clothes stay damp about 1 hour after rain or a swim and keep you less warm. The soak level from #491 is the natural place for it.
3. Cold acclimation (DAVE_TODO 6): the team suggests time spent in the cold, slowly, capped.
4. Worth a card if Dave wants it: rain gear and leafy trees that slow soaking, as in Don't Starve.

Open questions go on the QA page.
