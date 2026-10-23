








## hotbar-move | Is this how the hotbar should work: a tool dragged onto the hotbar MOVES there and leaves the pack grid (the hotbar is extra holding slots, not a copy, and it still counts for weight), and E over a hotbar slot with the inventory window open puts it back in the first free pack slot?
Note: Tyler recommends Yes because it already matches what you described, so nothing needs changing.
[check]

## blocks-from-log | A log from your pack, dropped on the ground and chopped with an axe, gives 4 wooden blocks (about 0.3 m long, 3.75 kg each)?
Note: Tyler recommends Yes because the pack log is the smaller log (about 15 kg), so 4 blocks of 3.75 kg add up. The big shoulder log gives more (next card).
[check]

## blocks-from-shoulder-log | A log from your shoulder, put on the ground and chopped with an axe, gives 12 wooden blocks?
Note: Tyler recommends Yes because it is the full-size log (about 45 kg) and 12 blocks matches your "quite a few".
[check]

## firewood-from-block | One wooden block used on the chopping block gives 1 firewood (3.5 kg) that falls beside the block, and the pieces merge into one heap (the pile look from 5 pieces is Kathleen's)?
Note: Tyler recommends Yes because one block makes one piece (simple to learn), and the heap uses the same pile rule as rocks.
[check]

## axe-wear-chop | The axe wears once for each log chop and once for each split at the chopping block?
Note: Tyler recommends Yes because both are real chopping, and one wear per action is easy to understand and to tune later.
[check]

## species-uses-1 | Should each kind of tree be good for different things, using four numbers per species (hardness, burn time, rot resistance, how easy it is to work)? For example oak for strong beams and posts, birch and beech for firewood, pine and spruce for planks, alder for piers in water, apple and cherry for tool parts.
Note: Full table: tech/items/TREE_SPECIES_USES_DRAFT.md.
Note: Tyler recommends Yes because it follows real wood, so players can learn it, and it needs only data (four numbers per tree).
[check]

## species-uses-2 | Recipes still accept "any log", but a better species gives a better result (stronger beam, less tool wear, longer-burning fire)?
Note: Tyler recommends Yes because nobody is blocked when the right tree is far away, and the good tree is a reward.
[check]

## species-uses-3 | Hard woods (oak, walnut) take more axe wear to chop, so they feel valuable?
Note: Tyler recommends Yes because cost is how a player feels value, and it is one number per species.
[check]

## species-uses-4 | Firewood and wooden blocks from different species stay in separate piles (no mixed piles), and piers and wet foundations need a rot-proof wood (oak, chestnut, alder)?
Note: Tyler recommends Yes because mixed piles are hard to take from and piers rotting would be unfair without a warning.
[check]

## logs-per-tree | A felled tree gives whole 8 ft (2.44 m) logs by its height, rounded down, at most 20 per tree (a 24 ft tree gives 3, a 9 ft tree gives 1)? The old bonus for thick trunks goes away.
Note: Tyler recommends Yes because it is easy to predict by looking at the tree, and it ties to the wooden blocks (4 per log) and species.
[check]

## small-tree-work | A small tree (under 8 ft) gives no whole log: working the trunk gives 3 blows of branches (sticks and leaves) and then 3 blows of firewood, kindling and sticks, then it is used up (no roots, no blocks)?
Note: Tyler recommends Yes because a small tree can never give a proper log, so it gives small useful things and is gone.
[check]

## log-names | Logs are named by the tree, written "Oak logs", "Beech logs" instead of "Oak_Logs" (item ids stay log_oak, log_beech and so on). Is that fine?
Note: Tyler recommends Yes because "Oak logs" reads naturally for players, and the underscore form stays only in the item ids.
[check]

## lake-rule-2 | Should any hollow hold water when enough rain can reach it, with no minimum size, and we fix places with unwanted lakes by changing how the generator makes the land?
Note: This is your own rule from your answer. Tyler's suggestion to make it work: a hollow gets water from the rain that falls on the land that drains into it (its catchment), and it dries to a smaller pond or nothing if the rain is too little for its size (evaporation). So a tiny hollow with a tiny catchment is only a puddle, and a big hollow with a big catchment is a lake.
Note: Tyler recommends Yes because it needs no extra rule beyond catchment and rain, and the stripe ponds from terrace steps disappear because they catch almost no rain.
[check]



## fix-merge-guard | Should we build a pre-merge check script first (it checks conflict markers, duplicate item numbers and action ids, next_number, crash logs, JSON and the warning count) and then run it automatically on GitHub (CI)?
Note: Tonight's merges needed three repair builds (699, 701 and a conflicted merge) that this script would have caught before merging. It also saves the round trip through MikeW's PC.
Note: Tyler recommends Yes because it removes the most expensive problem we had, and it is first on tomorrow's list either way.
[check]

## fix-id-claims | Should item numbers and action ids be claimed in one short file (or given fixed ranges per thread), so two threads can never pick the same number?
Note: Tonight two branches both took item number 234, and two wanted the same action ids.
Note: Tyler recommends Yes because a claim takes seconds and duplicates cannot happen.
[check]

## fix-team-tests | Confirm the rule that the team tests first (headless, look rig, showroom) and only human-judgment tests go to you?
Note: This is already in place as BP-T46 and BP-T45. This card is to confirm it.
Note: Tyler recommends Yes because most of tonight's 12 tests could be done by the team.
[check]

## fix-inbox | Should each thread get a short inbox file that the coordinator and Tyler write only the changes into, instead of long relays?
Note: Threads cannot message each other, so today everything goes through two relays.
Note: Tyler recommends Yes because it cuts repeated text and token use, but we will check that threads read it every turn.
[check]

## fix-slim-reading | Should we shrink what every thread reads at the start: a short first-jobs block at the top of HANDOFF.md (40 lines at most), old sections archived, and only the rules that apply to each thread?
Note: Today there are 83 documents and 46 rules in the best-practice file.
Note: Tyler recommends Yes because every thread reads this at every start, so a shorter version saves the most.
[check]

## small-tree-under-8ft | Is a tree under 8 feet 'small', giving only firewood, kindling and sticks?
Note: A tree 8 feet (2.44 m) or taller gives whole 8 ft logs, one per length. Shorter trees give no log: just firewood, kindling and sticks.
Note: Recommendation: Yes because it matches your rule that only whole 8 ft lengths become logs.
[check]
