# Weight audit, 24 Oct 2026 (Sal; data only, label RESTART, branch claude/sal-weight-audit)

Dave: weights are over the top; a standard steel spade is about 3.8 kg. Real-world check of every item that is carried often or weighs over 0.1 kg. Everything not listed is unchanged (fruit, herbs, leaves, dishes and so on were already at real weights: 20 g leaf handful, 50 g berries, 300 g dish).

Rules used: a kit and its placed form weigh what their ingredients weigh (never heavier than before); hand goods cut to realistic loads; spades set to your 3.8 kg standard for the medium steel and iron spade (small 2.4, large 5.0).

Dave 20:57: real weights now, no fudging (game-logic carrying later); herbs and plants ultra light. Plant changes: thatch 0.1, bedding 0.1, straw 0.05, reed stems 0.05, roots 0.1, bulbs 0.05, bark 0.15, withies/vines/canes 0.03-0.05, stuffing 0.02, fodder 0.3. Four QA cards ask Dave for weights I cannot check (fantasy materials, big workshop pieces, wood/stone units, spade sizes).

Kept on purpose: stone stays 1.0 kg (a hand stone is 0.5 to 1 kg, and boulders make stones by mass, so lowering it would multiply the stones in the world: tests show 7,700 instead of 4,600 per metre boulder); species logs 26/32/45 kg (shoulder carry); beams 12, lumber 4, bricks 2.7, cut stone block 25.

## Current and proposed (kg per item)

| item | now | new |
|---|---|---|
| stone_forge_kit | 45 | 40 |
| stone_forge | 45 | 40 |
| foundation_section_kit | 40 | 8.2 |
| woodworking_table_kit | 40 | 36.6 |
| woodworking_table | 40 | 36.6 |
| plank_chest_kit | 25 | 24 |
| timber_set_kit | 22 | 12.3 |
| campfire_kit | 18 | 15 |
| timber_prop_kit | 18 | 15 |
| workbench_kit | 12 | 3 |
| workbench | 12 | 3 |
| doorway_section_kit | 10 | 9 |
| window_section_kit | 10 | 9 |
| vice_kit | 9 | 6 |
| vice | 9 | 6 |
| tool_rack_kit | 6 | 2.6 |
| tool_rack | 6 | 2.6 |
| iron_spade_large | 5.6 | 5 |
| steel_spade_large | 5.6 | 5 |
| timber | 5 | 4 |
| chest_kit | 4.1 | 2.6 |
| driftwood | 4 | 2.5 |
| saw_blade | 4 | 2 |
| wooden_block | 3.75 | 3 |
| stone_spade_large | 3.6 | 2.6 |
| firewood | 3.5 | 2.5 |
| lean_to_kit | 3.5 | 2.2 |
| mortar | 3.5 | 2.5 |
| rough_plank | 3.5 | 3 |
| iron_spade_medium | 3.2 | 3.8 |
| steel_spade_medium | 3.2 | 3.8 |
| poles | 3 | 2.5 |
| wooden_block_soft | 3 | 2.2 |
| firewood_soft | 2.8 | 1.8 |
| fine_board | 2.5 | 2.2 |
| cobblestone | 2.5 | 2 |
| wooden_spade_large | 2.2 | 1.7 |
| stone_spade_medium | 2.1 | 1.6 |
| iron_spade | 2 | 2.4 |
| steel_spade | 2 | 2.4 |
| hide | 2 | 1.5 |
| hide_cloak | 1.8 | 1.2 |
| iron_hoe | 1.8 | 1.5 |
| steel_hoe | 1.8 | 1.5 |
| iron_ingot | 1.5 | 1 |
| steel_ingot | 1.5 | 1 |
| bucket | 1.5 | 1.2 |
| stone_hammer | 1.4 | 1.2 |
| stone_spade | 1.3 | 1 |
| wooden_spade_medium | 1.3 | 1 |
| coconuts | 1.2 | 1 |
| clay_pot | 1.2 | 1 |
| stone_hoe | 1.2 | 1 |
| palm_fronds | 1 | 0.5 |
| stone_axe | 1 | 0.9 |
| hide_leggings | 1 | 0.7 |
| tar | 1 | 0.6 |
| hide_boots | 0.9 | 0.7 |
| spear | 0.8 | 0.7 |
| hand_saw | 0.8 | 0.7 |
| wooden_spade | 0.8 | 0.7 |
| wooden_hoe | 0.8 | 0.7 |
| stone_shingle | 0.8 | 0.6 |
| tree_roots | 0.6 | 0.4 |
| grass_cloak | 0.5 | 0.4 |
| stick | 0.4 | 0.25 |
| bark | 0.3 | 0.15 |
| bedding | 0.3 | 0.2 |
| kindling | 0.3 | 0.2 |
| thatch | 0.3 | 0.15 |
| straw | 0.2 | 0.1 |

## Carry capacity
Cap is 0.7 x body weight (a 75 kg body carries 52.5 kg); nothing slows you up to 80 percent (42 kg), then speed falls to 25 percent at the cap. A real fit adult marches 25 to 30 kg. With the cuts above a campfire kit goes from 18 to 15 kg (3.3 kg once the cheaper 6 sticks + 3 stones recipe lands), a camp bench from 12 to 3 kg, a foundation kit from 40 to 5 kg, a lean-to from 3.5 to 2.2 kg, a firewood bolt 3.5 to 2.5, a stick 0.4 to 0.25. No retune of the cap is needed; a full backpack of firewood and stones is now about 30 percent lighter. Dave can lift the cap factor in weights.json (carry_kg_per_body_kg) at any time.
