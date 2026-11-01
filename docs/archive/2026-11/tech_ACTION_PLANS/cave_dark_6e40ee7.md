# Action plan: caves and tunnels go dark by day

Branch: claude/project-thread-yttwff, commit 6e40ee7 (base generator-v2 f14bd5b). CHANGE_LABEL: RUNTIME (no bake).

Cause: weather_look.gd set sun and ambient light only from weather and clock. Rock enclosure was measured only for sound (cave_sounds.gd), so caves stayed bright.

Changed:
- src/client/cave_sounds.gd: new `rock_enclosure` (smoothed like `enclosure`, without the building floor, so houses are not dimmed).
- src/client/weather_look.gd: `cave_light()`; sun and ambient energy multiplied by it (4% left from rock enclosure 0.1 to 0.6, lightning flash included).
- tools/check_cave_light.gd: headless test, 4 checks.

Mike's checks:
1. `godot --headless --path . --script res://tools/check_cave_light.gd` -> expect "Cave light check: 5 pass, 0 fail".
2. Parse scan, local_check as usual.
3. One daytime still inside a tunnel/cave (e.g. `--cave=1` or real cave) and one outside: tunnel dark, outside unchanged.

Follow-up (Tyler, GO): light eases out over 1 s going in, 2.5 s coming out; Settings button "Cave darkness: Dark / Normal" (4 vs 12 percent, saved in display_settings.cfg); sun shadow off below 5 percent light; torches and held lights are separate lights and are not multiplied. Test now expects 5 pass.

Limit: an open-top pit (sky overhead, no rock ceiling) is not dimmed; only covered holes and tunnels.
Not run in cloud (no Godot binary).
