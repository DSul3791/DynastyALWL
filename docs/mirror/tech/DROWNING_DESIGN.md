# Drowning and breath hold (River start thread, 2026-10-21) - DESIGN NOTE ONLY, one card for Dave

## State today
Swimming exists (build 377, src/shared/swim.gd): you float at the surface and can dive with Ctrl. Nothing limits time under water yet, so diving is free and falling into the sea is harmless. The camera already goes blue under the surface (`_update_underwater`), swim sounds exist (hold), and health, fall damage (safe 6 m, 8 health/m, never below 1, faint from 12 m) and fainting (exertion blackout) exist.

## Proposed model (server owns it, like vitals)
- **Breath:** a pool in seconds, full on the surface. Under water (eye below the surface) it drains in real time; at the surface it refills in about 4 s. Capacity BREATH_S (the card).
- **Drain multipliers (from existing numbers):** x2 while swimming hard (Shift) or diving with a pack past 80 percent of the carry limit, x1.5 while strain is over-exerted, x1 treading or sinking slowly; resting gets no bonus. Luck does not touch it.
- **Out of breath:** damage per second to health (card), a gasp and a dark vignette (Art, Sounds hold: heart and breath exist), movement not locked (you can always swim up).
- **Server data:** `breath` float per character in vitals.json (version bump, old files start full); one `vitals` field extension (breath per mille) in the existing vitals message (protocol bump, pre-approved). The server decides "eye below surface" the same way it prices swimming (`terrain_server._swim_state`, with the eye height), so a client cannot hold its breath forever.
- **Falling in:** no extra rule: fall damage into water is waived when the feet land in 1.3 m or deeper water (diving in is safe); landing in shallower water is a normal fall.
- **Under ice:** the swimmer drifts to open water and surfaces through the ice if there is none (already built), so breath is never lost to a trap.
- **Cost:** one float per player per server tick; nothing for dry players.

## The card for Dave (sent to the coordinator)
How long can a person hold their breath, and what happens when it runs out?
A. (recommended) 45 s at rest, half that swimming hard. Out of breath you lose 6 health a second and CAN die; surfacing refills in 4 s.
B. Gentle: 75 s. Out of breath you lose 4 health a second but never drop below 1; at 1 you black out and wash up on the nearest shore (like fall damage's never-below-1 rule).
C. Hard: 30 s, 10 health a second, you can die.
