# Torches and fire

**Last checked:** 2026-11-06 (web research by Jamie). **System owners:** Sal (items, fire rules), Kathleen (holding poses), Kathreen (look). **Related:** `src/shared/flame_rules.gd`, `data/items/items.json` (`torch`, `torch_doused`), `src/client/held_item.gd`, `flame_up.gd`, `flame_sounds.gd`, [caves.md](caves.md), [animal-behaviour.md](animal-behaviour.md).

## Lessons (read these first)

1. **Keep fire simple.** Dave's rule (5 Nov): a fire takes any wood, and any wood in it means E lights it. In rain it lights but goes out in a few seconds. The simple version (#439) is the one Dave says works great. Don't add kindling stages back.
2. **A torch is the brightest light with the best animal protection, but it is short.** A lantern is dimmer and lasts hours on oil, and waits for iron, glass and oil (Dave 6 Nov). The Long Dark makes the same trade: about 7.5 real minutes for a torch.
3. **Water and open rain put a torch out; caves and cover don't.** Under water at once; in open rain after a 5 s grace, so running to cover saves it (`flame_rules.gd`). The Long Dark also uses strong wind and waterfalls.
4. **Never strand the player in the dark.** A doused torch keeps its name and its hotkey lights it again (#466, #476). Caves are pitch black without a light (#447), so this matters.
5. **Fire scares most animals, not all.** Fire and torches keep animals off, except a bear at its den and a mother with young. In The Long Dark a wolf facing a torch stops and runs.
6. **Light count costs frames.** Every torch is a dynamic light. Godot's light and shadow limits (the forward renderer's per-object light cap and the shadow atlas) mean many placed torches should share or drop shadows. Check this before placing many torches in a camp.
7. **Prompts show only with inspect on** (Dave's 1 Nov rule).

## How ours works (6 Nov 2026)

- **Torch item** (`items.json`): tool class `torch`, held in the off hand, `light_m` 12 and `burn_s` 1800 (30 minutes) on main (checked 8 Nov), `rain_douses`, turns into `torch_doused` when put out. Right click places it in the ground or on a wall (`standing_torch`, `torch_sconce`, #362).
- **Douse rules** (`flame_rules.gd`): `RAIN_DOUSE` 0.2 rain strength, the same as the server's rain limit for open fires; `RAIN_GRACE_S` 5 s. The client watches its own hands and asks the server (`ACT_DOUSE`).
- **Relight:** E at a burning fire (#361); pressing the torch's hotbar key near a fire (#466); #476 (open) lets the hotkey light it anywhere and keeps the name. Sal's torch numbers (light 12 m, burn 1800 s, wolf protection 8 m) were proposed with it; light and burn time are on main now (8 Nov).
- **Fire:** any wood counts at once; E lights it; rain puts it out in seconds; a burnt-out fire is deleted after 5 minutes (on Dave's review list). The fire store shows only wood and food (#293). One fire sound loop (#314).
- **Third person:** the left-hand torch points forward and up in a fist (#451).
- **Torch carry pose (Dave's infographic, 6 Nov, `art/references/torch_carry_infographic_2026-11-06.jpg`):** the torch in the LEFT hand, full grip; upper arm down and a little out, elbow bent about 95 degrees (90-120), forearm forward and up so the hand is about 1.2 m up and 35 cm in front of the shoulder; wrist neutral; shoulders relaxed and level; the right hand free with its natural opposite swing; the torch upright with a small lean forward and out, flame above head height. Built as `idle_torch`, `walk_torch`, `jog_torch`, `run_torch` in `dynasty_body.gd` (`_torch_carry`: the clip's left arm replaced, everything else kept) and `held_item.gd _stand_torch_upright` (the torch stood upright in the world every frame). Crouching keeps Dave's own crouched torch clips.

## What we tried

| When | What | PR | Result |
|---|---|---|---|
| Oct-Nov | Early fire, fire heat, fire goals | #32, #85, #144, #198 | Worked; later simplified |
| 4 Nov | Fire store shows only wood and food, A to Z | #293 | Worked |
| 4 Nov | One fire loop, no doubled sound | #314 | Worked |
| 4 Nov | Torches go out under water and in open rain; E at a fire relights | #361 | Worked |
| 4 Nov | Torch placed in the ground or on a wall | #362 | Worked |
| 5 Nov | Simplified fire: any wood lights it | #439 | Dave: "works great" |
| 5 Nov | Torch held forward and up in a fist | #451 | Dino's shots from behind: flame at hip height, clear of the body. Lesson: the left-hand mount kept the old ragdoll body's 60 degree turn; on Dave's body a hand mount has +Y forward and +Z up the forearm (dynasty_body.gd _mount), so 60 degrees laid the torch along the arm and the hip hid its flame. Check both hands when the body changes |
| 5 Nov | Caves pitch black without a light | #447 | Worked; the torch is now essential |
| 6 Nov | Cave water lit by torchlight | #463 | Worked |
| 6 Nov | Doused torch relights from the hotbar near a fire | #466 | Merged |
| 6 Nov | Doused torch keeps its name, hotkey lights it anywhere; torch numbers | #476 | Open; PC queue |
| 6 Nov | Torch carry pose from Dave's infographic: left arm up, elbow ~95 degrees, torch upright, right arm swings | (this PR) | Waiting on the windowed look. Lesson from #451: a fixed angle on the hand mount follows the arm, so a torch tilts as the hand swings; standing it upright in world space each frame avoids that |

## What others do (with sources)

- **The Long Dark.** Lit from matches or a fire, can't be lit in strong wind, put out by harsh wind or a waterfall, burns about 7.5 real minutes, gives +3°C, a held torch makes a wolf stop and run, and torches pulled from a fire start at 20-50% condition and cost the fire 10 minutes. https://thelongdark.fandom.com/wiki/Torch
- **Godot torch shader.** A procedural flame with smoke and sparks in one shader, no particles needed. https://godotshaders.com/shader/procedural-torch-candle-shader-fire-smoke-sparks/
- **Godot lights and shadows.** Light and shadow limits per renderer and how the shadow atlas fills up; read before adding many placed torches. https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- **Flicker.** A common trick is to vary the light's energy and range with low-frequency noise instead of random jumps, so it breathes rather than strobes.

## Decided / next

1. #476 through the PC queue (relight anywhere, torch numbers).
2. Lantern later: dimmer, hours of oil, burns in rain behind glass, goes out under water (`flame_rules.gd` already allows for it).
3. Ideas worth a card if Dave wants them: wind putting torches out, a little warmth from a held torch, lighting a torch from a fire costing the fire some fuel (The Long Dark).

Open questions go on the QA page.
