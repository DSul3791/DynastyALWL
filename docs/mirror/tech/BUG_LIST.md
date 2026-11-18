# Bug list (Tyler keeps; newest first)

## BUG-001 Join screen hangs on first start after Pull (Dave 24 Oct 13:48 UTC, build 787)
- Symptom: first start after Fetch+Pull to 787 stuck on "Joining the game" step 3, "Loading the ground under you: 0 blocks still arriving, 83 s so far". Never opened. Close and restart fixed it. Protocol matched (77). Screenshot from Dave in the thread.
- Dave: "not acceptable".
- Owner: Steve investigating cause.
- Fix must include: a timeout and automatic retry of the ground request, so the join screen can never hang with 0 blocks arriving.
- Test: Mike repros on a fresh clone right after a Pull (first start, no cache).
- Gate: goes on the final-build checklist; no final bake merge without this fixed and tested.

## BUG-001 REOPENED / BUG-002 "The server is not sending ground" while ground is shown (Tyler, 25 Oct 01:55 UTC)
Symptom (Mike's runs, Dave's screenshot): the HUD says "The server is not sending ground" although the server is healthy and the picture already shows ground. The client keeps "waiting for ground" (no collision under the player yet) while the stream has gone quiet (pending 0, received 0); after a few watchdog restarts it shows the error. Slows every picture run. Matches Dave's first fresh start hang (BUG-001, fixed in build 788 by the ground watchdog).
Suspected: the watchdog (src/client/ground_watchdog.gd) decides on "no collision under the player" and "stream quiet", but the stream can be quiet because everything needed has arrived; collision under the player is built later (mesh/collider step), so the watchdog restarts a healthy stream. Not verified: needs Mike's log.
Owner: Steve (wrote the watchdog). Plan: one action plan, label RUNTIME. Needs from Mike: the client log from the run (lines with "ground", "watchdog", pending/received, timestamps, the HUD text, build number), the shot command, and the screenshot. From David3: the same from a box run.
Gate for the fix (BP-T57): fresh-clone join test on the box (David3) PLUS Mike's fresh start on Windows; the watchdog must not restart a stream that has delivered all requested blocks; the test --drop-ground-blocks must still pass (a real missing block still recovers); picture runs show no error text.
