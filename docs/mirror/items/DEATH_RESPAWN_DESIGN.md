# Death and respawn (rewritten 2026-10-21 to follow DESIGN_IDEAS.md 6.1)

The design is decided in DESIGN_IDEAS.md section 6.1 ("Danger, rescue and logging out" and "Remains"). This note only says what Items builds, in what order, and where it lives. The old option card (a to d) is withdrawn: full loss was wrong.

## Build 1 (build 400, protocol 34): remains and respawn
- Death: health reaching zero. Today only running out of air does that (vitals.json breath can_die is now true). Fall damage still stops at 1 health (Dave's rule). Every other cause calls `kill(peer, cause)` in server_items.gd.
- Remains: a server record on the surface where the character fell (structures.json "remains", row state 11 fresh, 12 after day 1). It holds the whole pack in a 30-slot container. Nothing can be put in; the owner takes things out.
- Timeline (real time, data/items/death.json): day 1 only the owner can open it; from day 2 anyone; at 7 days (day 8) the remains and what is left on them are cleaned up, no warning. The clock runs while the server is down.
- Never lost: the server finds the surface at death and rechecks every 30 s, putting the record back on the ground if a dig or fill moved it. The sinking is only a drawing offset (age sent with the row, 0.35 m at day 7, colour greying to bone).
- Respawn: at the spawn point, health 100, food and water full as a new character, energy 100, weight 75 kg, exertion 0. Luck, fitness and skills stay. Placed things stay. The client fades out and in over 4 s and sets the body down without fall damage.
- Save: world_items.json structure rows carry owner key and birth time (older files simply have no remains).

## Not yet built (in order)
1. Map death marker with countdown and the compass cue; remains for each tile capped at 50 sets, oldest to bones only.
2. Spawn at the last shelter slept in (lean-to), else the starter spawn.
3. Downed state (ARK-style: revive, carry, drag, timer runs offline) and the knocked-out-versus-downed choice, window by age and condition (open in 6.1).
4. Intelligent creatures taking gear into hoards (needs creatures).
5. Wizard retrieval (about 10 percent of gear value, minimum 1 gold, own and party NPC gear) once wizard towers and money exist.
6. Heir/child restart inheriting everything (needs families).
7. More causes: creatures and weapons, extreme cold or heat. Death by sickness stays rejected.

## Look
Placeholder body and pack boxes in inventory_view.gd `_make_remains`; Mandy to replace with the flat image facing the player (6.1).
