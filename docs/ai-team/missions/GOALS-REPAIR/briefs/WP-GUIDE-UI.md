# WP-GUIDE-UI — goal-state sync, Journal, HUD, Goal Achieved placard (separate thread)

**Goal:** the approved player guide interface in PLAYER_JOURNAL_GOALS_UI.md, which is authoritative and must be followed exactly. It works from the existing server goal system, extended. Read [COMMON.md](COMMON.md) first.

**Baseline evidence:** [../baseline/GOALS_UI_KEYS_1382118.md](../baseline/GOALS_UI_KEYS_1382118.md).
- There are 28 goals (starter 18 + camp 10). `goals_done`/`goal_counts` are saved per character with the coins in characters.json.
- `after` is a hard gate at ~15740. It must become display order only (GA-40).
- `_goals_tick` polls inventory snapshots, and GA-41/49 want this event-driven.
- `goals_state` (~15825) returns `[id,title,hint,state]` and nothing consumes it.
- There is no admin/free-craft exclusion (GA-54), no prompt save after a payout (GA-55), and no Journal or goal UI. The Comfort/Rested label sits top-right in inventory_view.gd ~4736.
- The Inventory/Crafting look is in src/client/ui/dynasty_theme.gd and src/client/ui/inventory/.

**Dependencies:**
- The admin Ctrl+Shift shortcut package WP-KEYS (lead thread) frees plain J and G. Do not merge J/G/M handling until WP-KEYS is in `dev`. Ask the lead for its SHA.
- Live goal content stays the current 28 approved goals until the corrected 651-row catalog passes creator review. The lead owns R7 content. The UI must render whatever catalog the server sends.

**Shared-file ownership (granted by the lead):**
- In server_items.gd, the goals section only: `_goals_data`, `_goals_check`, `_goals_tick`, `_goal_event`, `_goal_made`, `goals_state`, and the add_coins call from goals.
- PROTOCOL_VERSION bump 118 → 119 (owner of the next bump) plus PROTOCOL.md.
- terrain_client.gd routing for the Journal, after WP-KEYS merges.
- New client files: journal_view.gd, goals_hud.gd, goal_placard.gd, or similar.

**PR sequence:**
1. **Server goal model and sync (protocol 119).**
   - A full ordered catalog plus per-character state goes to the client on join, silently. It includes the reward in coins, the authored display order, and the hint/how-to text.
   - A reliable `goal_done(id, reward)` event for genuinely new completions only.
   - Remove `after` as an award gate.
   - Completion and the coin payout are once per character and atomic, with a prompt save.
   - Exclude admin-granted items and free crafts or builds from goal credit (GA-54).
   - No replay on reconnect. Tests: test_goals.gd plus new cases for out-of-order completion, reconnect, double events and save/restart.
2. **Journal shell and Goals page.** One window matching Inventory/Crafting. J opens the Index, G opens Goals, M opens Map. Esc closes. Plain G in the inventory still does Store All. The goal list is scrollable and shows completed and unfinished goals. Goal details show the How-to and clickable prerequisite links. Selection is view-only. The Map page is a transparently labelled interim state until WP-MAP lands. Do not claim the interim page is the final design.
3. **Upper-right HUD.** Thin border, heading "Goals", and the first two unfinished titles in authored order (one when only one remains). It must sit clear of the Comfort/Rested label.
4. **Goal Achieved placard.**
   - Dave's art is at `C:\Users\david\Downloads\GoalAchieved` on his PC. Folder access for this project was granted 14 Nov. The lead copies the blank template into the Library at `/mnt/project-files/goals-repair/assets/` for you.
   - Runtime text: the actual goal name and the actual coins (copper/bronze/silver/gold, 10:1) on the blank template.
   - Animation: rotating entrance ~0.6 s, ~4 s hold, exit ~0.5 s. Completions are queued with no overlap. It takes no input and never pauses the game.
   - Fanfare: no licensed fanfare exists in the repo (CREDITS.csv). Use a short original synthesized trumpet fanfare made in-repo (the repo's own-made synth convention, with a credits row). If quality cannot be judged headless, record it as NEEDS PLAYER VERIFICATION. Never copyrighted audio.

**Done means:** every item in the "Runtime integration and testing" section of PLAYER_JOURNAL_GOALS_UI.md is tested or listed for Dave's F6 check, and each PR is reported to the lead.
