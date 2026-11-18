# A craft ends with its product or a reason

Dave, 17 Nov 2026 (build 826, dev d3957a5f): a Wooden - Shovel made from the pack at the river, with his supplies on the ground round him, ran its countdown, took nothing and gave nothing; up the hill the same craft worked. And: "it gives me a count down of seconds but then its stops at zero and keeps me waiting longer."

## Causes found (code reading; not reproduced in a running game)

1. **Kept items were checked two ways.** The Wooden - Shovel keeps a Stone. Queuing a craft counts kept items in the whole craft stock (the pack, loose stacks within 12 m, own containers within 12 m). The finish asked for every kept item in the pack. With the stone on the ground and none in the pack, the craft queued, took the sticks, ran its countdown, then cancelled and gave the sticks back. The pack ended as it started. The only sign was a short notice: "was cancelled: a tool is missing".
2. **The countdown and the finish could read different times.** The client is sent the time left when the queue changes. The server re-worked the craft's time on every tick from the current pace: skill, the Rested buff and cold. When the pace slowed during the craft, the end moved past zero. Cold setting in at the river's edge is one way that happens, and the Rested buff running out is another. The client was not told.

These are separate causes, so the fixes are separate too.

## What changed

- The finish uses the queue's rule. A kept hand tool (knife, saw, needle and the like: CraftStock.hand_tools) must still be in the pack. Any other kept item may lie on the ground or in the player's containers within reach.
- When a kept item is gone at the end, the notice names it: "Wooden - Shovel was cancelled: a stone it keeps is no longer with you or close by. Nothing was used."
- A craft's time is fixed when it starts. The countdown the client gets and the server's finish read the same number.

Test: `src/worldgen/tools/test_craft_finish.gd`.

## For Dave (provisional, assumed from his rulings)

| Id | Choice | Why |
|---|---|---|
| CF-1 | A kept item that is not a hand tool (the shovel's Stone) may lie on the ground or in your own chest nearby, start to finish. | Crafting already draws on the ground and nearby containers (wood-system rulings), and the queue already allowed it. |
| CF-2 | A craft's time is set when it starts. Cold, the Rested buff or a skill step during the craft change the next craft, not this one. | The countdown has to be truthful ("make the item arrive when the countdown ends"). |
