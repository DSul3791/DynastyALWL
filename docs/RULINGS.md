# Dave's rulings

One live line per subject. The line here beats any older text anywhere: designs, data notes, code comments, tests and Claude's own picks. Quotes are Dave's words; lines without quotes are a short summary of his ruling. Older approved specifications still live in their topic docs (`DOC_MAP.md`) where nothing here replaces them. Coordinator and thread picks are not rulings and do not go here.

**Recording a new ruling** (`ai-team/CONSTITUTION.md`, "Rulings"): in the same PR, (1) find the line here on the same subject and replace it, never add a second; (2) search the repo for the old rule (`git grep -i`) and change or delete every active line that still states it (designs, data notes, comments, tests, the bug list); (3) add the old rule's telltale phrase to `retired_rules.json`; (4) run `python3 tools/check_rulings.py`. Git history keeps the old wording; no "superseded" notes in the docs.

## Core
- **R-CORE-NO-DEATH** · 22 Nov 2026 · "once you hit one hp you dont't take anymore damage. remember at its core this game doesn't want you to die unless you do something really stupid to die on purpose like jump in lava." The goal: "let the player have many adventures and near death experiences and then live to old age watching their dynasty grow and flurish."
- **R-CORE-COLD** · 22 Nov 2026 · "Cold should cause you to fall to 1 point and then you pass out." You wake at the nearest camp, temple or the starter spawn with your pack kept.
- **R-CORE-CAVE-RESCUE** · 23 Nov 2026 · "if you are in a cave and end up getting rescued they should deposit you at the nearest civilization and for these purposes that means campfire for now."
- **R-CORE-NO-GATEKEEPING** · 23 Nov 2026 · "we are not gate keeping by limiting resources."
- **R-CORE-NOT-SPAWN** · 23 Nov 2026 · Nothing in the world is based on where the spawn is.
- **R-CORE-NEWER-WINS** · 23 Nov 2026 · "newer rules override older ideas." 25 Nov: "we need a system that removes old contradictory rules when new rules are established" (the procedure above).
- **R-CORE-FOCUS** · 23 Nov 2026 · "I want all of your focus on making the game incredibly smooth and comfortable." Basics first: movement, weights and fighting animals before extras like snow.
- **R-CORE-ROADMAP** · Nov 2026 · Order: the physical world right; a full crafting and survival play-through; NPCs living and working; only then the Dynasty layer.
- **R-CORE-NIGHT** · 25 Nov 2026 · "the night is big part of this game" (no shorter night).

## Animals and hunting
- **R-ANIMAL-REAL** · 25 Nov 2026 · Animals behave like the real animal (`design/ANIMAL_SCENARIOS.md`).
- **R-ANIMAL-FIRE** · 25 Nov 2026 · "Also remember fire keeps everything away from the players." No den, mother or pup exception.
- **R-ANIMAL-BEAR** · 25 Nov 2026 · "the bear really should be able to out run me. also a threatened bear should turn and fight back. first it should stand its ground and standup on its hind legs. then it should attack with its claws or mouth." "as a new person it should have made short work of me. but also It should have run away unless it was starving or trapped." "the goal will be to learn how to trap them." Bears are pretty silent.
- **R-ANIMAL-BEAR-FOOD** · 25 Nov 2026 · Bears mostly eat berries and fish at streams and rivers; a starving, dangerous bear only in early spring.
- **R-ANIMAL-FEEL** · 23 Nov 2026 · "they should look up and stare at the player before running away or growling before attacking. fight should not just be animals teleporting around almost impossible to hit." No sliding or passing through players; each model uses its own attack moves.
- **R-ANIMAL-BLEED** · 23 Nov 2026 · "I like the blood trails so keep those. I love the idea the animal is bleeding and if they bleed enough they die eventually."
- **R-HUNT-SIGNS** · 23 Nov 2026 · "When you look at animal signs like scat and foot prints and you press E it should highlight the sign and you get xp for it." Higher skill highlights more of the next tracks.
- **R-HUNT-GLOW** · 23 Nov 2026 · Sign glow starts at Tracking 25, "at a close distance say 10 meters even further at higher levels."
- **R-HUNT-TRAILS-MAP** · 23 Nov 2026 · "tracking trails at 10 is fine. till then we will learn to see them by eye." Trails are added to the map automatically at that level.
- **R-HUNT-TRAILS-LENGTH** · 23 Nov 2026 · "they really shouldnt have a distance on them. they should just exist wherever they exist."
- **R-HUNT-RUNS-SEEN** · 25 Nov 2026 · "when a players skill at tracking goes up they should get easier to see."
- **R-HUNT-SNARE-XP** · 23 Nov 2026 · "you should get xp for placing snares on trails."
- **R-HUNT-SNARE-CATCH** · 25 Nov 2026 · The caught animal lies in the snare; E collects it and resets the snare. Snares have no count limit; on a trail they catch by chance, off a trail never.

## Player, HUD and controls
- **R-HUD-LOW** · 23 Nov 2026 · "the goal is to try and keep all the hud down low and mostly minimalist."
- **R-HUD-STATUS** · 24 Nov 2026 · Status symbols in a row left of the hotbar: "I don't want any borders around it I just want the symbols in a row" (23 Nov). "food and water shouldn't show up until they are below 10%." Comfort is always shown: "we should always have some sort of a comfort meter" (23 Nov).
- **R-HUD-PROMPTS** · 25 Nov 2026 · E and F prompts show only in inspect mode (the "/" key, a rebindable toggle): "if you like a cleaner hud you can keep it off." New characters get a welcome card naming the inspect key, E and F.
- **R-CTRL-E-CLOSEST** · 21 Nov 2026 · "it should always effect whatever is closest to my reticle first."
- **R-COMFORT** · 23 Nov 2026 · Comfort 0 to 10 like Valheim, bonus level x 10%, drifts down by activity. Points: "being under shelter gives you 1, being warmed near a fire gives 1, having your food bar above 25% gives 1, above 50% gives 1, water above 50% gives 1. then we can add things like sleeping on a bed adds 1, your clothing quality can offer a point or two extra."
- **R-SLEEP-NIGHT-SKIP** · 24 Nov 2026 · When everyone sleeps at night the server skips to dawn.
- **R-FITNESS** · 21 Nov 2026 · Strain at fitness 50 is 100%, scaling to 50% at fitness 100; "being Idle can lower it below your start. that was not my rule. remove it."
- **R-SKILLS** · 23 Nov 2026 · "All skills have a range from 1-100 so Basic 1-24, Advanced 25-49, Expert 50-74, Master 75-100." A trainer is needed to pass 24, 49 and 74: "you have to earn your way to the previous level before the trainer will train you"; "it should be level 25 after your first training." "archery should have its own skill." Trainers come later. No skill is added or merged until Dave picks the list.

## Map
- **R-MAP-LOOK** · 23 Nov 2026 · Black and white, hand-drawn: water edges, ocean, rivers, roads and paths, campfires, cave mouths, bog iron, orchards, fishing spots, a goblin clan's face and name, half-broken resource rocks (gone once broken). "you" is a small all-black person stamp, "simple and obvious"; "be able to zoom in more."
- **R-MAP-AUTO** · 23 Nov 2026 · An automapping settings section with an on/off slider per item, mapping within 50 to 100 m. Not built yet.

## Items, crafting and resources
- **R-ITEM-WEIGHTS** · 23 Nov 2026 · Every item at its real-world weight ("they all seem extremely high and don't match anything in the real world"). Seeds: "typical seeds weigh 5-7mg so you really need to fix that for all seeds."
- **R-ITEM-SEEDS** · 14 Nov 2026 · All plants give seeds. Tall grass: one grain per tuft, 20 to 60 seeds (24 Nov).
- **R-CRAFT-KEPT-TOOL** · 24 Nov 2026 · "we should remove that requirement if you have a knife in you inventory or on your hotbar it should count." A kept tool counts anywhere in the pack or on the hotbar.
- **R-CRAFT-MAKING** · Nov 2026 · Things are made at a station or with a tool plus a blueprint; no kits.
- **R-CRAFT-SIZES** · 21 Nov 2026 · "I want most things to fit neatly into 3/4 or half of a foundation size so they can easily be arranged."
- **R-CRAFT-NAILS** · 21 Nov 2026 · A chest for each nail tier; copper nails for light work and copper cladding, bronze for chests, iron for construction, steel for fortification.
- **R-CRAFT-SMITHY-FUEL** · 21 Nov 2026 · "smithys should just take coal in a fuel slot. same for all smithys. dont need to be lit."
- **R-RES-COPPER-TIN** · 21 Nov 2026 · "both copper and tin should be placed along or close to rivers being more abundant and bigger near the mountains and smaller and less abundant closer to the ocean"; "very abundant if they are right over an ore vein of their type."
- **R-RES-ROCKS-SHRINK** · 21 Nov 2026 · A mined rock "should crack and start to shrink right from the first hit."
- **R-RES-ORE-PILES** · 21 Nov 2026 · "ore piles should stackup like stone piles do just with different colors and lumps."
- **R-STORE** · Nov 2026 · Storage in rows of 6, no storage weight limit, never a cap on items on the ground.
- **R-WATER-SEA** · 24 Nov 2026 · Sea water is "too salty. try to find some fresh water."
- **R-FARM-GRID** · 24 Nov 2026 · The till and plant grid has its bottom-left corner at the crosshair, Alt+Right and Alt+Forward grow it; one dot per seed, green if you have it, red if not. Sowing follows the real seasons.
- **R-NAME-FIBRE-BACKPACK** · 24 Nov 2026 · The fibre bag is "Fibre - Backpack".

## Goals
- **R-GOALS-ORDER** · 24 Nov 2026 · Goals can be done in order: make a stone knife, then fishing gear before catching a fish. One "make every tool" goal per tier (25 Nov).

## World, server and releases
- **R-WORLD-GENERATOR** · 23 Nov 2026 · "the server/generator the generator part should prebuild our entire world or the parts we are working with right now. the server doesnt build anything it just serves the prebuilt stuff up to the clients." Right now only the starting nine tiles.
- **R-WORLD-SEA-FLOOR** · 24 Nov 2026 · "I do plan on them diving on shipwrecks and exploring under sea caves and such." The sea floor stays real terrain.
- **R-WORLD-TUNNELS** · 23 Nov 2026 · Old tunnels are not checked at start-up; "the second somebody digs near them again they will become unstable."
- **R-SERVER-SCALE** · 23 Nov 2026 · "plan for thousands and be happy when it works for hundreds right now." The server's core count is a setting; the player cap stays 32 until Dave says.
- **R-RELEASE-CLEAN** · 25 Nov 2026 · "the server is always a clean install no keeping backups." A fresh world and characters each week is fine.
- **R-REPO-PUBLIC** · 22 Nov 2026 · "so we will keep it public." Bought models never go in the repo.
- **R-MAIN** · Nov 2026 · Nothing reaches `main` without the full gate and Dave's yes; wiping or updating the live server and public releases are his alone.
