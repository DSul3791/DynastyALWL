# Steve: Admin button "Go to spawn" (branch claude/steve-go-spawn)

Dave 24 Oct flew far out (x 54683 z 75053) and asked how to get back. No teleport, chat command or admin entry existed (only dying respawns).
Change (RUNTIME, client only, no protocol): Esc > Admin > "Go to spawn" calls terrain_client.go_to_spawn(): body to world["spawn"] (x 53301 z 68427) + 28 m up, velocity 0, waits for ground like a respawn, 10 s arrival protection (no fall damage), closes the menu.
Test: fly 500 m away, press it, land at spawn without damage.
