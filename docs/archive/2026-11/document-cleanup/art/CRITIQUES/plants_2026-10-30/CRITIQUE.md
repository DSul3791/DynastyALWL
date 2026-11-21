# Critique: herbs, flowers, ferns and fungi in the real game (2026-10-30, Kathleen)

Rig: `tools/look_rig.sh --flora a,b,c,d --summer --agl 1.2 --views close:3:-12:0.8`, spawn point, 12:00 clear. Rows: r1 chamomile, dandelion, yarrow, lavender; r2 foxglove, heather, wild flax, alpine flowers; r3 fern, chanterelle, fly agaric, mushrooms. Severity 1 minor, 2 should fix, 3 must fix.

| Plant | Picture | Flaw | Sev | Action |
|---|---|---|---|---|
| Chamomile, yarrow, lavender, heather, wild flax | row_r1, row_r2 | read as what they are: stems with the right heads and colours | - | none |
| Dandelion | row_r1_close.jpg | the flower is one large flat yellow plate (24 cm) lying over the plant like a pancake; a dandelion head is about 4 cm | 2 | fixed: head size 0.12 to 0.05, 6 stems, 18 petals (not re-shot yet) |
| Alpine flowers | row_r2_close.jpg | the leaf mat is tan (the table colour was a yellow-tan), so it looks like a dry lump with tiny flowers on top | 2 | fixed: flora.json colour changed to the leaf green used by the other flowers (not re-shot yet) |
| Foxglove | row_r2_close.jpg | pink diamonds in a clump low on the plant, not a tall spire of hanging bells; half hidden by the NPC in this shot | 1 | open: needs a re-shot away from the NPC, then a taller spike |
| Fly agaric, mushrooms | row_r3_close.jpg | recognisable red-capped and tan mushrooms, correct scale | - | none |
| Chanterelle | row_r3_close.jpg | invisible at 3 m (the plant is 5 to 12 cm tall) | 1 | open: acceptable for real size; check at 1 m |
| Fern | row_r3_close.jpg | seen almost edge-on from a low camera and half behind the NPC: only flat green strips and fiddleheads showed | 1 | open: re-shoot from higher up before judging |

Note: the rig's NPCs (Hob, Edda) stand near the spawn and can hide the first plant of a row; use `--at` away from them next time.

Re-shoot at 53330,68450 (row_r4): a large white boulder stood in front of the dandelion and alpine flowers, so the two fixes above are still **unverified**; foxglove showed as three stems with hanging pink diamonds and no leaf rosette (severity 1 stays open: it needs leaves at the foot and a denser spike). Next time use a spot with clear ground (try 53301,68460 or ask the rig for a flat tile).

Verification (row_r5_verify.jpg, 53270,68440, a shaded slope by water): dandelion now shows small yellow heads on thin stems (fix confirmed, severity 2 closed). Alpine flowers are no longer tan: the leaf mat is dark green (fix confirmed, closed); in this shaded spot every mat looks darker than on open meadow, so judge brightness only on open ground. Foxglove still lacks a leaf rosette (severity 1 open). The fern frond stack at the right edge looks like flat sheets seen from below on a slope (severity 1, check on level ground).

## Herbs row 1 (2026-10-30, Kathleen; plan 1 of kathleen_next_plans_6.md)

Picture: herbs_row1_yarrow_plantain_chamomile_lavender.jpg (`--flora yarrow,plantain,chamomile,lavender --summer --cam-above 0.5 --dist 3 --pitch -10`, noon, clear).

| Plant | Flaw | Sev | Action |
|---|---|---|---|
| Lavender | reads as lavender: purple spikes on a grey-green mound | 0 | none |
| Chamomile | reads as chamomile: small white and yellow daisies on a feathery mound; flowers a little sparse | 1 | open |
| Ribwort plantain | almost invisible: a few tiny brown spikes, no leaf rosette | 2 | open: add a flat rosette of narrow ribbed leaves (the `plantain` row in tree_builder.gd already sets low leaves, so check why the cards do not show) |
| Yarrow | hidden behind the standing rig character in this frame (flat white umbels visible at its feet) | n/a | re-shoot with the row offset from the body |

## Flora batch 1 for the flora-density session (2026-10-30, Kathleen; real game, noon, summer, my branch's models, which match theirs: no model changes yet on flora-density-v2)

Picture: flora_b1_tallgrass_nettle_reeds_flax.jpg (`--flora tall_grass,nettle,reeds,flax --summer --cam-above 0.6 --dist 4 --pitch -8 --wait 120`; the rig body stands in front of the first plant).

| Plant | Critique | Rating | Next to improve |
|---|---|---|---|
| Tall grass | knee-high spiky tufts, pale yellow-green; seed heads are small tan flecks; not clearly taller than ground blades (flora wants 1.3 to 1.8 m patches) | 2 | taller, arching blades in a fan, darker green at the base fading to straw at the tips, a seed head (oval, drooping) on every third stem; keep it one cheap card cluster |
| Nettle | serrated oval leaves stacked on stems read as nettle; the stems are black wires standing above and between the leaves, so it looks like a plant on poles | 2 | green stems (darker than the leaves, not black), shorter, leaves in opposite pairs, a few pale flower tassels near the top |
| Reeds | good clump: tall green blades, dark brown seed heads on stiff stalks; the yellow flag triangles in the middle look odd | 3 | drop or shrink the yellow triangles; heads a little smaller |
| Wild flax | blue five-petal flowers on thin stems read as flax; small, grey-green mound base is a blotch | 2 | slimmer taller stems, a few more flowers, base of narrow leaves along the stem instead of the grey mound |

### Flora batch 1, after my fixes (2026-10-31; real game on the corrected terrain, summer noon)

Picture: flora_b1_after_nettle_tallgrass_flax_thatch.jpg. Done in src/flora/tree_builder.gd (the flora session agreed I make model fixes; it only changes placement): tall_grass and thatch_grass got a lower blade mass (blade_h 0.8, 0.85) under taller seed stems (reach 1.2, 1.1), a dark green base fading to straw tips, and bigger drooping seed heads; nettle stems are green-brown (no black wires) and the top leaf pair sits at the stem top; flax has 8 stems with 7 flower beads each and one basal clump instead of three. The flora budget test passes (0 over budget).

| Plant | Rating | Now | Next to improve |
|---|---|---|---|
| Tall grass | 3 | clearly above the ground blades, tan drooping seed heads, darker base | the small yellow triangles (flags) beside the seed heads look like paper: find which card draws them (also on thatch grass and reeds) |
| Thatch grass | 3 | fuller, taller, golden clump, reads "pick me" | same yellow triangles |
| Nettle | 3 | stacked serrated leaf pairs on green-brown stems, no black wires | pale flower tassels at the top |
| Wild flax | 3 | many blue flowers on slim stems; the grey-green base is smaller | narrow leaves along the stem instead of the grey clump |
