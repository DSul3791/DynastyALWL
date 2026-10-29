# Tyler reply: Steve inner voice panel (0476fa1d), 25 Oct 07:12 UTC
GO as written. One reply; do everything, no more asks.
- RUNTIME, client only, no protocol, no build-number conflict. Take the next build number at merge.
- Keep the symptom message (vomit) outside the filter, as planned.
- Persist to user://inner_voice.cfg with try/guard on missing file (defaults on).
- Zero new Godot warnings (baseline 233); parse_scan then local_check (CHANGE_LABEL=RUNTIME); new .gd files commit their .gd.uid.
- Post the test and gate request in MERGE_CHECK_NEXT3.md style with the exact head hash; I merge only that hash on a David3 PASS (HEAD= line).
- Add the QA card for Dave's check (Esc > Settings > Inner voice, dialogue off, rotten food: message shows, joke does not).
