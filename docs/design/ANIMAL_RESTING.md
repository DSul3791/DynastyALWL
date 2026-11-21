# Animals lie down to rest, and rabbits keep together (21 Nov 2026)

Dave, 21 Nov 2026: "list each animal and look up how they should naturally behave in situations like, relaxing, eating, being
approached by a human, being attacked". The coordinator's decision D-ANIM-1 (21 Nov 2026, under Dave's rule that agents' questions
are answered from research and recorded): build the resting stage, protocol 148, and rabbit groups. The per-species research is in
`docs/design/ANIMAL_BEHAVIOUR.md` (PR #1467).

## Lying down (protocol 148)

Most animals spend their off hours bedded down: deer and elk lie in cover by day, boar in a bed of leaves, big cats and bears
sleep for hours, cattle lie down to chew the cud. The server already had this as resting (`resting(def)`, the `rest` block in
`animals.json`: outside its active hours an animal stays put and lets a player closer before it runs), but it was sent as grazing
(state 0), so it stood grazing all day.

- **Server** (`server_animals._wire_state`): a grazing animal that is resting is sent as state 19, `LIE`, the state a companion
  already uses when it lies down at heel. Drinking (21) and standing out the rain (20) come first. Birds and flocks are left as they
  are: they perch or float.
- **Client** (`animal_view.gd`): role 19 takes the model's lying clip, found by name (`lying_breathing`, `lying_idle`, `lying`,
  `sleep`, `lay`), never a change of pose (`Idle_to_Lying`) or a death or hit clip. A lying clip may be as low as a fifth of the
  standing height (`LIE_FLAT_SHARE`); a flatter one is a broken clip and refused. A model with no lying clip keeps its standing clip
  (role 0). The code-built bodies (quad, wolf) fold their legs and put the body down. A companion dog at heel now lies too.
- Files seen in Dave's game log with lying clips: the deer files (`Lying_Breathing_01`, `Lying_Idle_02`), pronghorn, elephant
  (`Lying_00-IP`, `Lying_01-IP`), dog (`idle_lay_*`). Others are found the same way when their files have one.
- Protocol 148: client and server must be updated together. Cost: one `resting` test per grazing animal per row sent.

## Rabbit groups (HB-4, provisional)

Wild European rabbits live in warrens and feed in loose groups near cover at dawn and dusk; one that bolts thumps and the others run.
The rabbit row now has `herd` [2, 4], `herd_pull_m` 8, `group_spacing_m` 2 and `alarm_s` [0.1, 0.6], so they appear in small groups,
graze near each other, and one bolting sets the rest off. Each keeps its own burrow.

A herd member was spread up to 6 m round the group's spot with no check against players, so one could be made inside
`never_within_m`. Members are now never made inside it (all herd species).

Tests: `test_animals` (the rabbit share can be topped by the last group, up to its size less one), `test_animal_spawn_wiring`
(a group spreads a few metres round the near-share spot).

## Not done

Animals at the edge of the nearest 30 sent to a player can vanish and reappear when they swap places in that list. The client also
treats a body that leaves the list as possibly killed (the fall), so holding it a moment longer needs care. Left for later.
