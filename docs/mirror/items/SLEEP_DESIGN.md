# Sleep and rest (Items job 68, design note only, 2026-10-21)

Status: note for Technical direction; no code. Builds on what exists: stances (C crouch, X sit, Z lie), strain that falls faster sitting (x2) and lying (x3), fainting, vitals (stomach, weight, health).

## Proposal (recommended first version)
- **Sleep is lying down with eyes closed, started by holding Z (lie) for 3 s or pressing a Sleep button on the lie prompt.** Server-owned state `asleep` next to stance (stance 3 plus a flag), so it needs one new field in the strain() RPC (stance becomes 0..3 plus bit 4 = asleep): protocol bump, bundled with the next one.
- **Effects while asleep:** strain falls at 6 times the standing pace (lie is 3 times now); health regeneration doubles; hunger drains at the resting rate only (no exertion term); the clock is not skipped (24:1 stays; nobody is waited for).
- **Where:** anywhere lying is allowed, but quality differs by cover and ground: under a lean-to or roof (Cover.at > 0.5) full effect; open ground dry 60 %; open ground in rain or snow 20 % and the player wakes at once if rain falls on them (rain never falls through roofs, existing rule). A bed or sleeping roll item later raises it to 120 % (design with the building thread).
- **Waking:** moving, a hit, being near a fire going out is not a wake; the player wakes on any movement key, damage, a loud sound nearby (creature threat cue) or when strain is zero for 10 s (so you do not sleep your life away). Waking from fainting is unchanged.
- **Safety:** asleep players are visible (lying pose) and take full damage; no invulnerability. Creatures and later NPCs may notice sleepers more easily (stealth factor 0.5 of standing). A lean-to's cover hides nothing from creatures.
- **No fatigue bar yet.** There is no tiredness drive in the first version: sleep only recovers strain and health. A later fatigue value could make long wakefulness slow reactions (Dave's call, see below).

## Cost and checks
Server: one flag per player and a branch in the existing 4 Hz strain tick (no extra work). Client: a 1 Hz check for the wake rules; the sleep picture reuses the faint vision fade at 60 % depth (Art). Tests: sleeping drops strain 6x faster than standing, rain wakes an open sleeper but not one under a roof, movement wakes, damage wakes, hunger drain stays at rest rate.

## Questions for Dave (one card, recommendation first)
1. Is there tiredness that only sleep fixes? (a) no, sleep only helps strain and health (recommended for now); (b) yes, a fatigue bar that slows you after about 2 game days awake; (c) later.
2. Should sleeping outside in rain or cold hurt you (a cold system does not exist yet)? Recommended: no, only weaker rest.
