# Kathleen: goal 2 batch B (tools, campfire, chests)
Class: upgrade simple models to the next detail step, same node names and sizes.
1. Hand tools (axe, pickaxe, shovel, hoe, knife): head shape, haft taper, binding wraps; 150 tris each.
2. Campfire: ring stones (RockLook), log pile, ember glow; 200 tris.
3. Chests: slats, iron bands, hinge; 150 tris.
Test: one labelled showroom row per item, one picture each (Mike), before/after card to Dave.
Branch: claude/kathleen-goal2-b. Label RUNTIME. Tyler reply: see below (GO)

## Tyler reply (24 Oct 05:45 UTC) GO, branch claude/kathleen-goal2-b, label RUNTIME (answered once)
1. Keep what code and data rely on: node names, pivots (grip point of each tool, the fire's light and sound anchors, the chest lid hinge) and sizes stay exactly as now; new parts are children. The grip point matters most: worn_sync and worn-attach (Steve) place tools in the hand from it, so a moved pivot floats the axe. Add a test row that builds each item and checks the bounding box is within 5 percent of the old one.
2. Tri budget as a table test that fails above the limit (150 tools, 200 campfire, 150 chest as you wrote) and ONE shared mesh per item type, shared materials. Add a far version for crowds of dropped items (tools lying on the ground in a pile): half the triangles, no binding wraps.
3. Real references, 2 to 3 lines each in art/MODEL_INVENTORY.md: medieval axe head and haft (felling axe, Dane axe), tool socket and wedge, campfire stone ring proportions (ring 0.8 to 1.0 m across, stones 15 to 25 cm), strapped chest (slats, two iron bands, hasp). Use Wikimedia or museum photos (CC), cite the page in the doc.
4. Materials follow the item's material data (iron, wood, stone) and wear state, via the same look table as the items so a rusty axe and a new axe use different tints without new meshes. No new texture files unless needed.
5. Campfire: the glow and flames use ONE light with a cap (shadows off, range limited), the same as the torch, so six campfires in view cost the same as one. Ember glow flickers from a seed, not per-frame random. Test frame time with 6 fires (Steve's frametime row, tools/look_rig.sh --frametime).
6. Chest: lid can open (a hinge pivot) only if the code uses it; if not, keep a static lid but place the hinge at the right edge for later. No gameplay change (slots, weight, server ids).
7. Test as ONE showroom row per item (24-row showroom), one picture group (tools, fire, chests) before/after side by side, one card to Dave with a "Tyler recommends" line.
8. Commit per group (tools, campfire, chests) so a bad one reverts alone.
Go. Merge in the next hourly batch after each group passes the table test.
