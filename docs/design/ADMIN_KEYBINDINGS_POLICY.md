# Dynasty — Mandatory Admin & Debug Keyboard Shortcuts

**Authority:** Creator decision, 13 November 2026. **Status: APPROVED DESIGN — NOT YET APPLIED TO GAME CODE.** This governs the entire existing `Admin and debug` action group in `src/client/key_bindings.gd`, plus any other keyboard-triggered admin/debug action discovered in code. It does **not** change normal player controls.

## Hard rule

**Every admin/debug action must use Ctrl+Shift+<primary key>.** There must be **no** unmodified, Ctrl-only or Shift-only admin/debug shortcuts, including custom rebinds. Keep the current primary key whenever possible; reassign the primary key where two actions would otherwise share the same Ctrl+Shift chord. Both modifiers must be required and matched exactly. Apply admin permission checks as before; modifier requirements are NOT a substitute for authorization.

Normal gameplay shortcuts are **J** → Journal Index, **G** → Journal Goals and **M** → Journal Map. The inventory `store_all` action currently uses bare **G** in inventory context: preserve it in that context; no Journal input fall-through. Read `docs/design/PLAYER_JOURNAL_GOALS_UI.md`.

## Proposed nonconflicting default bindings (verify against the complete live keymap before changing code)

| Existing action ID | Required default chord | Notes |
|---|---|---|
| `fly` | **Ctrl+Shift+G** | Keep G as the Fly base key; resolves the present bare-G conflict |
| `quality` | **Ctrl+Shift+F2** |  |
| `debug_details` | **Ctrl+Shift+F3** |  |
| `sound_panel` | **Ctrl+Shift+F5** | Move from Shift+F3, since F3 is reserved for Debug details |
| `hud_text` | **Ctrl+Shift+F4** |  |
| `spring_up` | **Ctrl+Shift+=** | Verify keycode of '=' while Shift is held on supported keyboard layouts |
| `spring_down` | **Ctrl+Shift+-** | Verify physical-key behaviour on supported keyboard layouts |
| `starter_items` | **Ctrl+Shift+]** | Verify keycode while Shift is held |
| `admin_npc` | **Ctrl+Shift+N** |  |
| `admin_rabbit` | **Ctrl+Shift+R** |  |
| `admin_dig` | **Ctrl+Shift+X** |  |
| `admin_spyglass` | **Ctrl+Shift+L** |  |
| `jitter_test` | **Ctrl+Shift+J** | Releases plain J for the Journal Index |
| `gpu_probe` | **Ctrl+Shift+F9** | Move from Ctrl+Shift+G, now reserved for Fly |
| `water_hide` | **Ctrl+Shift+F7** | Already compliant; preserve |
| `water_debug` | **Ctrl+Shift+F8** | Already compliant; preserve |

The default proposal is a *primary-key map*: when inspection reveals an engine, keyboard-layout, game-input or editor conflict, choose a different unused primary key while preserving **mandatory Ctrl+Shift** and document the change. Never take away an admin/debug feature simply because it conflicts.

## Implementation details for Claude

1. Inspect **all** keyboard paths and actions, not only `ACTIONS` in `src/client/key_bindings.gd`: hardcoded `KEY_*` checks, _unhandled_input, key-down and key-up handlers, admin menus, debug tooling, screenshot/test runners, UI controls, prompts, scripts and manuals.
2. `KeyBindings.matches()` currently uses exact Ctrl/Shift comparison for non-held actions. Ensure every action covered by this policy is non-held, and both modifiers are enforced even after a user changes the primary key in **Esc → Settings → Controls**.
3. **Migrate or sanitize existing `user://key_bindings.json` custom admin/debug overrides** so old bare-G fly, Ctrl-only NPC actions, Shift-only Sound Panel, etc. cannot survive the migration. Retain a valid user-chosen primary key when possible, force both modifiers on admin/debug actions, and resolve collisions. Reset-to-default and swap/conflict detection must preserve this requirement; disabling an admin action remains permissible if already supported.
4. Ensure no normal gameplay inputs fire when their key is part of an admin chord, and no admin actions activate on plain keys; verify no unintended character movement/interaction in chord handling.
5. Maintain existing *admin role and server-side authority*; ordinary players must not acquire debug powers merely by knowing the shortcut.
6. Update `CONTROLS.md`, the built-in help, in-game Controls page, keybind labels, tests, and affected authoritative docs **in the same implementation PR**, once code actually changes. Do not document new chords as working before they are implemented.
7. Test each mapping above and all project-specific admin/debug paths in the running Godot editor, including keyboard layouts for =, - and ], inventory G, Journal G/J/M, Ctrl+Shift+G Fly vs Ctrl+Shift+F9 GPU Probe, F3 vs F5, conflicting custom rebinds, reconnect and saved settings.
8. Develop through the project's existing feature branch → independent review → `dev` integration workflow, keeping `main` untouched unless explicitly approved.

**Scope boundary:** This is a uniform shortcut-safety and discoverability rule, not permission to redesign admin functions, remove tooling, change admin privileges, or make the Journal/Goals feature a prerequisite for testing admin controls.
