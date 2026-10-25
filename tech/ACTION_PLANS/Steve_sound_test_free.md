# Steve: crash "Cannot call method 'queue_free' on a previously freed instance" in the sound test (branch claude/steve-sound-test-free)

Dave 24 Oct, from the Sound test list. Cause: ambience_slots.gd _run_group (Batch 2 test) awaits a timer, then calls player.queue_free(). A second press of "Sound test: Batch 2" runs test_press, which already frees every player in _test_players, so the waiting coroutine freed an instance that was gone. It is the only await in the client sound code. Fix (RUNTIME, one guard): is_instance_valid(player) before queue_free. The stale coroutine still stops at its token check on its next clip.
Test: press Batch 2 test, press again within a few seconds, repeatedly: no error.
