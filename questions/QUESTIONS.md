













## chars-per-player | How many characters can one player have?
Note: Sonny designs the character creator and needs this to shape the save data. It also touches the identity plan.
Note: Recommendation: One active character at a time, up to 3 saved slots. It keeps the account simple, still lets a player start over, and the data can grow later.
- One character per account, fixed
- One active character, up to 3 saved slots
- Unlimited characters per account

## bench-rule | What can a workbench craft?
Note: Your 25 Oct rule file (CRAFTING_STATIONS_RULE.md) says benches make weapons and tools only. You later told Sal that benches craft generally. Sal followed the newer words and left the old file alone.
Note: Recommendation: Tools, weapons and bench-class goods. It matches what you told Sal most recently, and cooking stations and hand crafting stay as they are. The old file would then be updated to match.
- Tools and weapons only (the 25 Oct rule)
- Tools, weapons and bench-class goods (what Sal did)
- Anything, with no limit

## vice-bench | Is the log workbench level 2 on its own, with a tool rack beside it giving level 3?
Note: You approved folding the vice into the log workbench on 25 Oct. Sal did it: the vice kit can no longer be crafted, and vices already placed keep working. This changes crafting access, so it needs your eye.
Note: Recommendation: Keep it as done. It follows your 25 Oct answer, no saves break, and it is one commit that can be reverted if you dislike it.
- Keep it: level 2 alone, tool rack makes level 3
- Undo it: bring back the separate vice add-on
- Make the log workbench level 3 on its own

## stone-wedge | Add a Stone wedge (stone plus stick, hand-made) that splits a log into 2 rough planks?
Note: Right now everything built from lumber waits on iron, and iron has no source in the game. So nails, chests, building sections, the ladder and the water wheel cannot be reached from a fresh start.
Note: The wedge would be a `future` item (not obtainable until released). The sawmill and hand saw stay as the faster iron-age route.
Note: Recommendation: Yes, add it. It removes the iron wall for the first builds, costs almost nothing to build, and is easy to remove later.
- Yes, add the Stone wedge
- No, keep iron required and make iron arrive early instead
- Both: the wedge now, and early iron later

## code-owner | Should a code session start now on the item jobs only a coder can do?
Note: Sal wrote ITEM_CODE_HANDOFF.md with six jobs: one Lumber and one Beam with a species tag, Clay Oven and Iron Stove, finishing the vice migration, gathering ore/flint/obsidian/coal in the world, the large and master forge, and quality grades.
Note: Nobody has taken them yet. Each job lists its files and tests.
Note: Recommendation: Start one with only the gathering job first (ore, flint, obsidian, coal). Without it nothing can be smelted or crafted, so it unblocks the most, and the other jobs can follow.
- Yes, start a code session for all six jobs
- Yes, but gathering (ore, flint, obsidian, coal) first
- Not yet

## rivers-on | Switch the new natural rivers on for the real world?
Note: The new river system lets the ground shape the water, and it works on the nine island tiles in a test world. Switching on means re-baking those nine tiles on your Man land PC and showing you pictures.
Note: I would not bake more than nine tiles and would not commit anything until you have seen the pictures.
Note: Recommendation: Yes, bake the nine tiles locally and show you pictures first. You can see the real result before anything is committed.
- Yes: bake the nine tiles locally, show pictures, commit only after you say yes
- Yes: bake and commit right away
- Not yet: tune the rivers more first

## lake-sources | How should we get more lakes?
Note: The island has very few lakes (about 0.3 percent of the land). Possible sources: a crater lake on the central volcano, hollows scooped by ice, lakes held back by rock ledges, and oxbow lakes left by river bends.
Note: Recommendation: Crater lake first. It is the cheapest and clearest win, and we can add the others afterwards if the island still feels dry.
- Crater lake only, for now
- Crater lake plus ice hollows and rock-ledge lakes
- Leave the lakes small

## art-vision-name | Rename ART_DIRECTION.md to ART_VISION.md?
Note: It would match GENERATOR_VISION.md, CHARACTER_DESIGN_VISION.md and BIOMES_VISION.md. Kathleen has already added proposals to the file, so the rename should wait until her branch is merged.
Note: Recommendation: Yes, rename it when her branch merges. A single naming rule is easier to remember.
- Yes, rename it when Kathleen's branch merges
- Yes, rename it now
- No, keep the current name

## ancestry-boons | Should fantasy peoples get small ancestry traits?
Note: Sonny's research says many games are moving numbers away from ancestry. He took a middle path that I approved for now: small, mostly physical traits for fantasy peoples only, bigger bonuses in backgrounds and traits, and skin tone and face stay cosmetic.
Note: Recommendation: Keep the middle path. It keeps fantasy peoples feeling different without making ancestry a power choice.
- Middle path: small physical traits for fantasy peoples only
- Put all bonuses in backgrounds and traits, none for ancestry
- No ancestry effects at all, cosmetic only

## pottage-five | May Hearty pottage and Roast Beast keep 5 ingredients?
Note: Your rule is a 3-ingredient maximum. Sal cut four dishes to 3 and left these two at 5 as special top-tier dishes. Food points are unchanged.
Note: Recommendation: Yes, keep them at 5. A few showpiece dishes give cooks something to aim for, and the rule still holds for everything else.
- Yes, keep both at 5 as exceptions
- No, cut both to 3
- Keep one at 5 and cut the other

## generated-body | Should the generated body become the default for players and NPCs?
Note: Sonny's new body works in the real game for walk, run, crouch, sit and lie, and NPCs can use it behind the --generated-body switch. Clothing fits it. 20 NPCs cost about 0.2 ms more per frame. The character creator screen is not connected yet.
Note: Recommendation: Not yet. Look at Sonny's in-game pictures first, then switch NPCs, then players. A switch you can flip back keeps this safe.
- Not yet: keep it behind the switch until you have seen the pictures
- NPCs first, players later
- Yes, make it the default for everyone

## merge-order | When should the three agents' branches go toward main?
Note: sal-items is all data and documents. kathleen-art is looks and some code (tree builders, materials). sonny-character is new files only, with one small merge fix noted. Main only takes code through pull requests and the normal gate.
Note: Recommendation: Open pull requests for Sal's and Kathleen's branches now, and hold Sonny's until you have seen the character in the game. Items and looks are low risk and the gate will catch problems.
- Open pull requests for Sal's and Kathleen's now, hold Sonny's
- Open pull requests for all three now
- Hold all three until you have reviewed them

## shield-offhand | Should a shield go in the off-hand slot?
Note: Sal's combat tier list (ITEM_COMBAT_TIER_LIST.md on branch sal-items) covers swords, maces, shields and armour across five tiers: wood/hide, stone, copper/bronze, iron and steel. Sal is already building these as `future` items (not obtainable yet), so this choice only decides how a shield is carried.
Note: Recommendation: Yes, use the off-hand slot. The game already has an off-hand slot, and a shield there leaves the main hand free for a weapon or tool, as players expect.
- Yes, a shield goes in the off-hand slot
- No, a shield is hand-held only

## top-tier-armour | What should happen to the plate cuirass and steel helm (4 ingredients each)?
Note: Your rule is a 3-ingredient maximum. Sal made these two the only exceptions, as special top-tier items, with 4 ingredients. They would be `future` items, so they would have no effect on the first island.
Note: Recommendation: Keep them as future items. They cost nothing now, steel is far down the progression, and they can be changed or removed before they are ever released.
- Keep them as future items with 4 ingredients
- Drop them for now

## log-inventory-link | How should the carried shoulder log show up in the inventory?
Note: Today the log you carry on your shoulder is stored on the character as a separate `shoulder` field, so it is not in any of the 36 bag slots. Q lays it down, death drops it where you fell, and it is saved with the character. You said you wish the log and an inventory item were tied together.
Note: Option A would add a read-only 'Carried' slot to the inventory window. It shows the log from a value the game client already has, so nothing changes on the server or in saves, and the existing drag-out and put-in-chest paths already work.
Note: Option B would make the log a real bag item that moves itself onto the shoulder. That changes slots, weight, the save format and the drop and death paths, so it is larger and riskier. Owners if you pick A: Sal for the slot, whoever owns `terrain_client.gd` for the keys.
Note: Recommendation: Option A, the read-only 'Carried' slot. It gives you the link you asked for, needs no server or save change, and Option B can still be done later if A does not feel right.
- A: a read-only 'Carried' slot in the inventory window
- B: make the log a real bag item that auto-equips to the shoulder
- Leave it as it is

## double-f-window | How fast must the second F press be to put the shoulder log down?
Note: You asked to press F twice to put the carried log down, like setting down a pet on your shoulder in Atlas. The first F shows a hint ('F again to put the log down'); the second F within the window puts it down. If a chest is in reach, F still opens the chest.
Note: Recommendation: 0.6 seconds. It is quick enough to avoid dropping the log by accident, and still easy to hit on purpose.
- 0.6 seconds
- 1.0 second
