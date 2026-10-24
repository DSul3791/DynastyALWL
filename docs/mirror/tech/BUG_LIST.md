# Bug list (Tyler keeps; newest first)

## BUG-001 Join screen hangs on first start after Pull (Dave 24 Oct 13:48 UTC, build 787)
- Symptom: first start after Fetch+Pull to 787 stuck on "Joining the game" step 3, "Loading the ground under you: 0 blocks still arriving, 83 s so far". Never opened. Close and restart fixed it. Protocol matched (77). Screenshot from Dave in the thread.
- Dave: "not acceptable".
- Owner: Steve investigating cause.
- Fix must include: a timeout and automatic retry of the ground request, so the join screen can never hang with 0 blocks arriving.
- Test: Mike repros on a fresh clone right after a Pull (first start, no cache).
- Gate: goes on the final-build checklist; no final bake merge without this fixed and tested.
