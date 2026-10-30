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
