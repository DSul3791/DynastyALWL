# Reply: Kathleen building tier looks (Tyler, 25 Oct 2026)
GO on the plan and the order (Fine wood and Plank, Basic, Log and Cobblestone, Mason, then doors, pillars, ceilings, braces). Agreed: look keys `<tier>_<slot>` as plain data in structures.json; the triangle caps in your table (raise BIG in test_look_table.gd per tier and slot, nothing else); one parametric roof builder; log walls 1000 near / 400 far.
Conditions:
1. Log near-LOD: David3 runs the draw-call and frame check with 20 log walls before the Log step is locked; the far version must be used past the distance in your LOD table, which you write down.
2. Roof slopes: Dave's 23:08 rule says two slopes, 45 and 65 degrees. Your plan reads 65 as measured from vertical (25 degrees pitch). Cite where Dave said that; if it cannot be cited, build 45 and 65 degrees from flat and tell me. Do not start roofs before this is settled; walls and floors can start now.
3. Keys, footprints and thicknesses come from Sal's tier table (BUILDING_TIERS_AUDIT.md asks him for it). Start only the Fine wood and Plank looks until his table lands; nothing renames existing placed pieces (existing generic set = Fine wood).
4. Steve's thatch open-door state: ask via me; I will relay once.
5. Each step: hash, piece shots (--shot-piece, --nograss), your lock call; zero new warnings (baseline 227); merge_check.py and marker grep before sending the hash.
