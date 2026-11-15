# Parked art work (11 Nov 2026 handoff)

Written and approved by the coordinator, but not opened as PRs because of the handoff's no-new-work rule. Neither has been run in Godot or gated. Full status: `docs/handoff/HANDOFF_KATHLEEN.md`, under "Unfinished work".

- `lantern_horn.patch` is commit 28596b75. It changes `held_item._make_lantern_model`: the horn glow shader, a flame core and a hand light. Apply it with `git apply -3`.
- `bog_show.patch` draws the bog iron patch in the world (`inventory_view._show_bog`). It applies cleanly to main bd3146aa.
