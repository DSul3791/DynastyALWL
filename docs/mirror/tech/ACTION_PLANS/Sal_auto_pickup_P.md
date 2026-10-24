# Sal: P toggles auto pickup (short plan)
Goal (Dave 14:29 UTC 24 Oct): key P switches auto pickup on and off and says so as text slightly above screen centre in a reasonable font.

## What exists today
- **No auto pickup exists.** Nothing in src or data matches auto pickup. Picking up is manual: press E on what you look at (`inventory_view.gd` `_probe_pickup`, sends ACT_PICKUP with the world item id), or hold E to sweep nearby things (`_sweep_asked`).
- **Key P is free.** No KEY_P in src/client or scenes; project.godot has no input map entries. Used letters today: W A S D E Q R T V B C F G I J N X Z, digits, F2 to F4, Tab, Esc, Space, Shift, Ctrl. (Verify against any key handled through Input actions in the test.)
- **Existing text:** the bottom-of-centre prompt label (`_prompt`, font 30, anchored from the screen middle down) is the interact line and `show_notice(text)` shows 4 seconds of text in it. P's message must not reuse it (it is below centre and would fight the pickup prompt), so it gets its own label.

## Proposal
1. **Client-only setting** `auto_pickup` (bool), default OFF (a new player decides; Dave said toggle, not on). Saved in a small ConfigFile `user://input_settings.cfg` (same pattern as sound_settings.cfg and npc_voice), read at start, written on each press. Not saved on the server.
2. **Behaviour when ON:** each short tick (4 times a second) the client takes the world items within `interact.json` reach_m and in view, skips structures, trunks, fires, carcasses, boulders, scatter that needs a tool, and anything the server would refuse (too heavy, pack full), and sends the same ACT_PICKUP the E key sends, one per tick. The server rules (weight, ownership, tool needed) are unchanged and still decide. A pickup it cannot make is reported once per item, not every tick.
3. **Announce:** P shows "Auto pickup ON" or "Auto pickup OFF" as a centred label slightly above the middle (anchor_top 0.38), font size 36, outline for readability, fades out after 1.5 s. A second press resets it.
4. **Conflicts:** none found for P. Typing in a chat or dialogue box must ignore P (same guard the other letter keys use). P is ignored while the inventory or a chest screen is open.
5. **Wiring:** key handler beside the other letter keys in `inventory_view.gd`; label created next to `_prompt`; CONTROLS.md gets one line (P: toggle auto pickup).

## Test and Dave check
Headless: toggle sets and saves the value, reload keeps it, announce text is exact, and with auto on a stone within reach is picked up while a tree stump is not. Label CLIENT/RUNTIME, no restart of the server. Dave presses P near stones: text appears above centre, stones jump into the pack when ON.

## Open for Tyler (answer once)
Default OFF, fade 1.5 s, 4 pickups a second. Change any of these?
