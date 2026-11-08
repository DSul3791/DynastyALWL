# Animals asleep: bedded down, not frozen grazing (MikeW, 8 Nov 2026; client side, built on the eye-placement branch)

## What the server already does
Outside its active hours (its row's `active` chance for the day, dusk or night period at or under `rest.below`, 0.1) an animal **beds down** (`server_animals.gd` `resting`): it stops wandering, stays put far longer, and wakes at `rest.spook_share` (0.6) of its spook distance: a sleeping deer lets you closer than an awake one. The wire still says state 0 (graze), so the client draws it grazing: a deer "grazing" all night in one spot.

Steve's den life (goblin_den_life_design.md and the bear's den) keeps its own rules: goblins bed down at the cave mouth by day, the bear sleeps at its den. Those use the same resting test, so this note covers them too.

## Client: draw it asleep
1. **Knowing it sleeps, without a wire change:** the client loads `data/animals/animals.json` too (the same file), knows the game hour (the sky already does), and applies the same test: state 0 and the species' activity for this period at or under `rest.below` means asleep. A wire bit later (state 0 vs a new "resting" state) would be exact; this is right whenever the server's rule is, which is always today.
2. **How each kind sleeps** (model row `sleep` {clip, pose, where}):
   | Kind | How | Clip in our files |
   |---|---|---|
   | deer, elk, moose, pronghorn, cattle, goats, sheep, camel | lying, legs folded, head up or tucked | `Lying_Breathing_01`, `Sitting_*`, `Idle2Sitting` loops (most WildMesh grazers have one) |
   | horse, donkey | standing asleep, head low, one hind hoof cocked | no clip: `state_poses`-style pose (head and neck down, one hind leg bent) |
   | wolf, fox, dog, cat, lynx, big cats, hyena, raccoon | curled, tail over the nose | `Lying_*`, `idle_lay_*`, `rest_idle_*`, `interact_bed_sleep_exist_01` (dog) |
   | bears | lying flat, at the den | `Lying` clips; the brown bear's den is its bed |
   | rabbit, rat, mink | in the burrow (already hidden) or crouched | `Lying*` or rest pose |
   | birds | perched, head tucked | crow and pheasant rest clips; ducks and geese float with heads tucked |
   | goblins | curled by the den fire | their own idle until Dave's model has a lie clip |
3. **Breathing** (built) runs slower when asleep: half the rate, a little deeper.
4. **Ears** still swivel to a sound within the wake distance (a sleeping deer's ear flicks before it wakes); head tracking is off while asleep.
5. **Waking:** the server's state change (alert or flee) ends the sleep pose at once; the clip's own get-up transition plays if the row names one (`wake_clip`, e.g. `LyingToStand`), else the alert clip cuts in.
6. **Night look:** a bedded herd lies close together (the server keeps them together already); eye shine only shows if the head is up and facing the torch.

## Data
`"sleep": {"clip": "Lying_Breathing_01", "wake_clip": "LyingToStand"}` per row, or `"sleep": {"pose": {...state_poses shape...}}` where the file has no lying clip. The species list and clips are read from the files the same way as the other clips.

## Check
A creature check `--role=sleep` strip, and one night picture of a deer herd and a wolf pack bedded down (Kathleen's section 11 night shots).

**Built:** sleep clips for 30 species read from the model files (lying or resting loops), get-up clips for 12; horse and donkey doze standing (pose); the asleep test, half-rate breathing, no head glances while asleep, and a lying clip is never refused as flat.
