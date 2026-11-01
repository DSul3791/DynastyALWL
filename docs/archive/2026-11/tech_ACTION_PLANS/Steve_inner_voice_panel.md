# Steve: inner voice settings panel (branch claude/steve-inner-voice-panel)

Dave 24 Oct (EARLY_GAME_PRINCIPLES 45, QA_ANSWERS inner-voice-hints): the inner voice has its own settings panel for everyone: hints on/off and inner dialogue on/off. Hints = the up-front/after-a-mistake lines of the early game; dialogue = perception warnings, jokes, "that was a good day".
CHANGE_LABEL: RUNTIME (client only, no protocol, no server change). Today the server sends every line through `thought` (protocol 38) with a `kind`; the client shows a subtitle (inventory_view._on_thought) and plays the line (inner_voice_sounds.speak). Only the sickness jokes exist as kinds (vomit, diarrhea); hint kinds come with the early-game flow.
Change:
1. data/items/inner_voice_classes.json: kind -> class ("hint" or "dialogue"); a kind not listed, or starting with "hint_", resolves by prefix; everything else is dialogue. The early-game work only adds kinds here.
2. src/client/inner_voice_settings.gd (pure, RefCounted): `hints`, `dialogue` (both default on), `allows(kind)`, load/save to user://inner_voice.cfg (ConfigFile, same pattern as npc_voice.gd).
3. inventory_view._on_thought: `if not settings.allows(kind): return` before the subtitle and the sound. The symptom message itself (vomit) is separate and stays.
4. Esc > Settings gets an "Inner voice" page (game_menu.gd, same slide-switch rows as Gameplay): "Hints" and "Inner dialogue", with a one-line note under them, and its Back button. The switches follow the saved state each time the page opens.
Test: src/worldgen/tools/test_inner_voice_settings.gd (headless): defaults on; hints off blocks only hint kinds; dialogue off blocks only dialogue kinds (vomit, diarrhea); unknown kind counts as dialogue; "hint_x" prefix counts as hint; save and load round trip through a temp path. Plus the Audit line for the new buttons (tools/items_check.py ui audit if it lists settings pages).
Dave's check: Esc > Settings > Inner voice, switch Inner dialogue off, eat rotten food: the symptom message shows, the joke does not.
Risk: low; small client-only change. Cost: one dictionary lookup per thought.

## Build notes (Tyler GO)
Built: data/items/inner_voice_classes.json, src/client/inner_voice_settings.gd (+ .uid), inventory_view.inner_settings and the filter in _on_thought, game_menu "Inner voice" page (Hints and Inner dialogue switches, refreshed from the saved state), src/worldgen/tools/test_inner_voice_settings.gd (+ .uid). The sickness symptom message is outside the filter. Defaults on when the cfg is missing.
