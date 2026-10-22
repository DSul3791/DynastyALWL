# Skills and attributes: the first list (job 87; BUILT in build 413, protocol 37: Strength and Memory attributes, 6 skills + 6 groups, numbers in data/items/skills.json)

Built on what Dave already decided (DESIGN_IDEAS 5.4): a skill has an innate part, a trained part and practice; innate + trained is the base and about 20 percent of practice feeds it; unused skills decay but never under 20 percent of the best; attributes feed skills through a web of weights; skills form a tree and practice goes 80 percent to the specific skill and 20 percent to its parent group. What exists today: Luck and Fitness (attributes), and `skill_factor(peer, action)` hooks that return 1.0 until skills exist (data/items/skills.json).

## Attributes (what a character is born with; whole numbers)

| Attribute | Range | Built | What it changes now or first |
|---|---|---|---|
| Luck | -10 to +10, fixed at creation | yes | Every random roll: yields, drops, finds, the bonus stone from a boulder (items/LUCK_NUMBERS.md) |
| Fitness | -10 to +10 | yes | How fast exertion rises: +10 is winded after 1.65 times as long, -10 after 0.6 times |
| Strength | -10 to +10 | no | Carry limit (today 0.7 kg per kg of body weight for everyone), tool work speed, melee later |
| Dexterity | -10 to +10 | no | Craft time, throw accuracy later |
| Memory | -10 to +10 | no | Chance to recognise things on first inspection (+5 percent per point, already in the notes) |
| Wisdom | -10 to +10 | no | The "I know that I don't know" check in inspection mode |

Recommendation: build Strength and Memory next (they replace two placeholders that already exist); Dexterity and Wisdom with their first users.

## Skills (innate, trained and practice; level 0 to 100)

First list: the building-material trades Dave named, as one tree.

| Skill | Parent | Draws on | Changes (today's hook) | At level 100 |
|---|---|---|---|---|
| Foraging | Gathering | Memory, Luck | gather_plant: yield | about 1.5 times the plants per pick |
| Woodcutting | Woodwork | Strength | fell_tree, work_trunk, split_log: blows needed | about half the blows |
| Mining | Stonework | Strength, Fitness | mine_rock, boulder blows: blows needed | about half the blows |
| Digging | Earthwork | Strength, Fitness | dig pace and yield (new hook) | 1.5 times the shovelfuls |
| Jumping | Athletics | Strength, Fitness | fall damage (hook built, job 303): safe height 6 m times the skill factor, damage per metre beyond divided by it, faint height scaled too | about 4 times: 24 m safe |
| Crafting | Trades | Dexterity, Memory | craft: time | about 60 percent of the time |

The server already clamps a factor to 0.25..4, so a level never breaks pacing. Each skill's practice rises when the action succeeds (not on button presses), at about 10 successes per early point, slower later (tuning table to come, values in data). Fitness stays an attribute here, with a possible slow training (see the card).

## Inspection mode hooks
Inspection (the / key, brain icon) already has the memory and wisdom checks and a notebook of known and wrongly believed things. Two skills feed it when they exist: Horticulture (plants and fungi) and Geology (rock, ore, soil) raise the chance a character recognises a thing and shrink the error of a wrong guess. They sit under Gathering and Stonework in the same tree.

## What this needs when built
A skills record per character (save version bump, neutral default 0 for everything), one `skill_level(peer, skill)` function plugging into the existing hook, the Tab screen's skills section (already stubbed) listing level and practice, and a protocol field for the list. Cost at Low: nothing per frame; a few integers per player.
