# GOALS-AUDIT workstream: Journal / HUD / placard / keyboard (ws_ui)

Specialist: Journal, HUD, placard and keyboard. Baseline: the `dev` checkout in `/home/user/DynastyALWL`, branch `claude/project-thread-d8jals`, 13 Nov 2026. **Audit only.** Nothing was changed except this file. Godot was not run and no tests were run. Every claim below is **CODE_VERIFIED** (read in code or data) unless it says otherwise. No claim is GAMEPLAY_VERIFIED. Where an existing test is named, it **was not run** in this audit.

Authority labels: CREATOR (Dave's explicit decision), CATALOG, IMPLEMENTED (code or data), PROPOSAL (not yet approved, or written by an AI).
- The Journal direction and the admin-keyboard rule are CREATOR (13 Nov). They are recorded in `docs/design/PLAYER_JOURNAL_GOALS_UI.md` and `docs/design/ADMIN_KEYBINDINGS_POLICY.md`.
- The policy's chord table is a PROPOSAL. Its own text says "verify against the complete live keymap".
- The goal order is a PROPOSAL (`PLAYER_GOALS_REWARDS_DRAFT.md:19`).

Severity levels: BLOCKER (must be fixed or decided before implementation), HIGH, MEDIUM, LOW, INFO.

---

## 1. Findings

### Journal and input routing

**U-01 (HIGH): J, G and M today.** IMPLEMENTED.
- **J** is `jitter_test` (`src/client/key_bindings.gd:65`). It is handled at `scenes/terrain_client/terrain_client.gd:4379-4380`.
- **G**: three uses.
  - Bare G is `fly` in the world (`key_bindings.gd:53`, handled at `terrain_client.gd:4405-4410`).
  - Bare G is `store_all` on the inventory screen (`key_bindings.gd:50`, handled through `inventory_view.gd:4958` and `5016-5020`).
  - Ctrl+Shift+G is `gpu_probe` (`key_bindings.gd:66`, handled at `terrain_client.gd:4320`).
  - A separate dev scene, `scenes/terrain_preview/terrain_preview.gd:228`, also hard-codes bare `KEY_G` for walk/fly.
- **M** is not used anywhere. There is no `KEY_M` in `src/` or `scenes/`, and no M row in `CONTROLS.md`.

Recommendation:
- Add `journal`, `journal_goals` and `journal_map` rows: CONTEXT_WORLD, non-held, group "Screens".
- Remove J and G from the admin rows in the same change (see U-20).
- `tools/check_controls.py` requires every new `KEY_*` constant to appear in `CONTROLS.md` (KEY_M, plus KEY_J and KEY_G for their new meanings). Update that file in the same PR.

**U-02 (MEDIUM): how input contexts are separated, and where the Journal must plug in.** IMPLEMENTED.
- All gameplay keys go through one `_unhandled_input` (`terrain_client.gd:4259-4410`).
  - Esc is checked first (4263-4274): spyglass, then the inventory search box, then `items.screen_open()` closes the open screen, else the Esc menu.
  - While the Esc menu is open, every other key is ignored (4276-4277).
  - I and Tab are checked before the screen test (4281-4287).
  - While any inventory-family screen is open (`inventory_view.gd:4954-4955`: pack, chest, character, dialogue, storage, food), the key goes **only** to `items.quick_key(event)`, and the handler then `return`s whether or not the key was used (4289-4293). **No world key falls through while a screen is open.**
  - Text fields (recipe search in `recipe_list.gd`, the storage code fields in `storage_dialogs.gd`) are GUI controls. A focused LineEdit takes the key before `_unhandled_input` runs, so typing "g" never reaches the game.
  - The rebinding page captures keys in `_input` and marks them handled (`key_capture.gd:31-35`).
  - There is **no chat box** and no other text entry in the HUD (no LineEdit outside the inventory, character and creator screens).
- **Plain G Store All is therefore safe by construction.** A Journal G placed after the `screen_open()` block can never fire while the inventory is open.

Recommendation:
- Make the Journal a screen in the same family: either `screen_open()` includes it, or there is an explicit `journal.open` check placed before the world chain.
- Add a Journal branch to the Esc chain (close the Journal first).
- Check only J and M before `screen_open()` if the creator wants them to switch from the inventory to the Journal. **Never check G there.**
- Inside the Journal: J goes to the Index, and J on the Index closes (CREATOR).
- G on the Goals page and M on the Map page are unspecified. Recommend toggle-to-close, matching I and Tab. This is a minor UX detail; list it in the PR.

**U-03 (HIGH): modified chords fire inventory-screen and held actions.** IMPLEMENTED.
- `KeyBindings.matches()` returns true for any row marked held/polled whatever modifiers are pressed (`key_bindings.gd:198-201`). Every inventory-screen row is marked that way (`key_bindings.gd:43-52`, column 8 = true).
- So while the inventory is open with a container:
  - **Ctrl+Shift+G runs Store All.**
  - Ctrl+Shift+R runs Repair.
  - Ctrl+Shift+D drops the stack.
- In the world, the held rows `interact` (E, line 28) and `lie` (Z, line 27) also ignore modifiers, and they sit inside the same if/elif chain (`terrain_client.gd:4362`, `4374`). A user who rebinds an admin action to Ctrl+Shift+E would get interact instead, because `interact` is tested before `jitter_test`, `debug_details`, `hud_text`, `quality` and `fly` (4374 vs 4379-4405).
- `conflict()` does not report this case. It treats a held action as clashing only with a *plain* use of its key (`key_bindings.gd:234-238`).
- This breaks both the creator's text ("Ctrl+Shift+G … never the Journal or Store All", `PLAYER_JOURNAL_GOALS_UI.md`) and policy item 4.

Recommendation: change `matches()` for held and inventory-screen rows to reject an event that has **both** Ctrl and Shift pressed.
- Keep Shift alone working, so Shift+D still drops one (asserted at `test_key_bindings.gd:45`).
- Make `conflict()` refuse admin chords whose base key is a held key.

**U-04 (MEDIUM): other contexts the Journal keys must respect.** IMPLEMENTED.
- **Hammer and build mode.** R calls `held.toggle_blueprints()` only when the inventory is closed (`terrain_client.gd:4397-4399`). Nothing closes the blueprint list when another screen opens; this is UNKNOWN beyond the call site, as `held_item.gd` was not traced. Recommendation: opening the Journal closes the blueprint list, or the Journal is refused while the list is open.
- **Photo camera (K).** `_toggle_photo` (`terrain_client.gd:4182-4199`) does not block other keys. I, G and F all still work in photo mode. Recommendation: refuse the Journal in photo mode, or leave photo mode first. The Journal needs a visible mouse, as inventory `toggle()` sets at `inventory_view.gd:457-459`, and that conflicts with the photo orbit.
- **Inspection mode (/).** It only toggles labels (`terrain_client.gd:4340-4346`). No conflict.
- **Dialogue.** `screen_open()` includes dialogue, and `quick_key` passes keys to `dialogue_key`, which uses E, Esc and 1-5 (`dialogue_view.gd:177-188`). The Journal is correctly blocked during talk.
- **Admin spyglass.** Esc lowers it first (4264-4266). Recommend the Journal is refused while it is up, the same as photo mode.

**U-05 (MEDIUM): no World Map exists.** IMPLEMENTED.
- Searching `src/` and `scenes/` for world_map, minimap, map_view and map_screen found no in-game map UI.
- The only map code is offline worldgen tooling (`src/worldgen/tools/ore_world.gd`, `dump_sketch_stages.gd`).
- The admin compass (`src/client/admin_compass.gd`) is a heading strip, not a map.
- CREATOR (`PLAYER_JOURNAL_GOALS_UI.md` item 6): embed the map "if it exists", and do not invent one.

Recommendation: M opens the Journal at a Map page that honestly says "No map yet". The alternative is to reserve M and leave the Map index entry inactive. Choosing between the two is a creator decision. Do not build map generation.

### Look and feel

**U-06 (HIGH): the referenced look documents are not what the live inventory uses.**
- The proposal says to reuse `dynasty_theme.gd` and `INVENTORY_CRAFTING_LOOK.md` (8 Nov). The live inventory window is built from **`src/client/ui/art_kit.gd`** to **`docs/ui/inventory_crafting_redesign.md` v4** (9 Nov):
  - `inventory_frame.gd:3-8` and `art_kit.gd:3-6` say so.
  - Panels are fixed rects on the 1920x1080 canvas: Pack (24,24,690x908), You (736,24,448x908), Craft (1206,24,690x908) (`art_kit.gd:15-24`).
  - There is a 14 px stitched leather frame (`FRAME`), a parchment field, brass corner plates and brass title plates (`draw_panel` 342-389, `draw_title_plate` 454).
  - It has its own palette (`art_kit.gd:28-65`): BACKDROP #17150F, LEATHER #3A2315, BRASS #C9A054, CREAM #F5E6BD, HEADING #F2C76B, and so on.
- `dynasty_theme.gd` holds a different palette (`WOOD_DARK` 0.12,0.075,0.05; `GOLD` 0.86,0.66,0.3; `dynasty_theme.gd:11-31`). It draws the **Esc menu** look (`panel_style` with a 3 px gold border and 10 px corners, lines 72-84).
- The LOOK doc's "2 px GOLD frame, 6 px corners" (§4) is `dynasty_theme.frame_style()` (88-92). The live inventory frame does not use it.
- Copying the docs as written would produce an Esc-menu look, not the inventory look the creator asked for.

Recommendation: the Journal draws only through `ArtKit`:
- `draw_backdrop`, `draw_panel`, `draw_title_plate`, `draw_rule`, `draw_well`, `draw_raised`
- `stylebox_well`, `stylebox_raised`, `stylebox_brass`
- `card` / `card_line` for parchment detail cards
- `ArtKit.font("cinzel_bold" | "garamond" | "garamond_semibold")`

Follow the `inventory_frame.gd` layout pattern: fixed canvas rects, columns under the title plates. Record in the PR that the 8 Nov LOOK doc §4 is superseded by redesign v4 on frame geometry. That is a documentation-authority note, not a new rule.

**U-07 (MEDIUM): the current inventory look is mostly code placeholders.**
- `ArtKit.art()` loads painted PNGs from `res://assets/ui/inventory/` and draws coded placeholders when they are missing (`art_kit.gd:3-6`, `108-116`, `342-389`).
- That folder holds only the `ghost_*.png` gear silhouettes. `frame_leather`, `field_parchment`, `panel_shadow` and the plate art are absent.
- If the Journal copies today's colours instead of calling ArtKit, it will drift from the inventory when the painted art lands.

Recommendation: call ArtKit and never copy its constants. Reuse these components:
- `recipe_list.gd`: a scrollable list with search and selected-row styling.
- `pinned_recipe.gd`: a parchment card.
- `info_strip.gd`.
- `item_slot.gd` / `InventoryLook.icon_for()` for item icons in prerequisite chains.
- `make_coin_label` / `fill_coin_line` for rewards (`inventory_view.gd:1964-1990`).

Keep the inventory text-size setting (`InventoryLook.unit_of(view)`, `inventory_look.gd:20-23`). Do not grow `inventory_view.gd` further (6,335 lines). Put the Journal in its own script.

**U-08 (LOW): minimum text size.** The redesign doc §1 sets 1920x1080 as the design canvas (confirmed `project.godot:32-36`, `display_settings.gd:18`), with 1366x768 as the floor. It says "Nothing below 18 px is allowed anywhere". Journal rows and the HUD must keep 18 canvas px or more.

### Goal data to the client

**U-09 (HIGH): the client gets nothing but notice text today.** IMPLEMENTED.
- A goal completion calls `_say(peer, "Goal done: <title>. You earn <coins>. Next: <title>. <hint>")` (`server_items.gd:15766-15789`).
- `_say` goes to `send_notice` (2043-2045), then the RPC `notice(text)` (`terrain_net.gd:863-866`).
- On the client, `_on_notice` puts the text in the centre `_prompt` label under the crosshair for 4 s (`inventory_view.gd:1464-1472`).
- `goals_state(peer)` (`server_items.gd:15825-15837`) returns `[[id, title, hint, state 0 locked / 1 open / 2 done]]` but is **never sent**. Its own comment says a protocol message is still needed (15627), and so does `PROTOCOL.md:193`.
- **Protocol is 118**: `terrain_net.gd:40` `const PROTOCOL_VERSION := 118`, with the changelog at `PROTOCOL.md:206`.
- The heading `PROTOCOL.md:1` still says "PROTOCOL_VERSION 56". That is document drift and should be fixed in the same PR.
- `src/shared/app_config.gd:5` `PROTOCOL_VERSION := 2` is an unrelated, older constant.

Recommendation (PROPOSAL, needs review): split static catalog text from per-character state.
- **Static catalog.** id, title, how-to, materials with counts, tools, station and level, prerequisite links (goal ids), reward_copper, display_order. About **107 KB of text** for the 651 draft rows, measured from `work/goals_parsed.json`. Sending that at every join would load the join path, which already has lag-run history.
  - Preferred: one approved catalog JSON under `res://data/` that both server and client load. The welcome check already refuses mismatched builds (`PROTOCOL_VERSION`, `server_build`; `terrain_server.gd:904-907`). The server stays authoritative for completion and payout.
  - Whether one shared file counts as "not a client duplicate" (CREATOR wording, `PLAYER_JOURNAL_GOALS_UI.md` item 5) is a lead or creator interpretation. The alternative is the server sending the catalog once at hello.
- **New RPCs**, all server to client and reliable; bump to 119 or the next free number at implementation time:
  - `goals_sync(rows: Array)`: the whole per-character state at join. Each row is `[id, state, progress, need]`, where state is 0 not yet / 1 in progress / 2 done. Around 20 KB for 651 rows. It could be compacted to done ids plus the rows that have progress.
  - `goal_progress(rows: Array)`: changed rows only, sent no more often than the slow goal tick (`_goals_tick`, 15792).
  - `goal_achieved(id: String, copper: int, reward_label: String)`: the single trigger for the placard.
- Add a `_sync_goals(peer)` call to the join sync block next to `sync_purse(peer)` (`server_items.gd:574-588`).

**U-10 (MEDIUM): progress is only reliable for some check kinds.** IMPLEMENTED, from `_goal_met`, `server_items.gd:15691-15737`:

| Check kind (runtime) | Source | Progress can be shown? |
|---|---|---|
| `event` counts (drink, tree_felled, fire_lit, ate_food, path_laid, carcass_worked, sold, wanted_order, fish_caught, dug_under, `placed`+what) | `goal_counts["event:…"]`, monotonic. Emitters at `server_items.gd:1103, 1109, 1139, 2335, 2679, 2894, 3212, 3829, 5900, 8499, 13554, 13623, 13825`; `server_trade.gd:145, 440` | Yes, n/need |
| `made_item` | `goal_counts["made:<id>"]`, +1 per **finished craft job**, not per item made (`_goal_made`, 15679-15688; single caller 17414) | Yes, as crafts done. Wrong if the how-to says "make 6 planks" and one job yields 6 |
| `made_item` + `or_have` | max(made, current pack count) (15716-15721) | Not monotonic |
| `have_item` / `have_item_any` | **current pack count** (15726-15735) | Not monotonic. Drops when items are used (the draft itself notes `fibre` at `PLAYER_GOALS_REWARDS_DRAFT.md:766`) |
| `worn_warmth` | live value vs min (15695-15696) | As a live fraction only |
| `talked` (Edda, hours) | `hit:<goal>` (15698-15699) | Binary |
| `moved_lit_night` | metres, float (15701-15702) | Yes |
| Draft `gather:*`, `activity:*` (medium_fire, bonfire, place_campfire, chop_log_blocks) | **No emitter exists.** There is no pickup/gather goal event in the list above | Not until signals exist (owned by the other workstreams) |
| Draft `build:*` | `placed` fires from `_after_built` (8478-8499), also for finished blueprint sites (`_finish_site` 8948-8956); an unfinished site does not count (8470-8472) | Yes per kind, if the structure `kind` ids match the goal keys |

Recommendation:
- Send `progress` only for monotonic kinds. Show "have N now" wording for possession checks.
- Leave progress out (state only) where it is binary.
- The `made:` unit (jobs vs items) must match the how-to text.

**U-11 (HIGH): reconnect must not replay placards, and a migration would flood them.**
- At join the client must rebuild its model only from `goals_sync`, and only `goal_achieved` may trigger a placard.
- Two edge cases:
  1. `_goals_check` can complete a goal during the join, because possession checks run every slow tick (15812-15813). That is a genuine first completion and should be announced once.
  2. If the client drops the instant a goal completes, its placard is lost while the coins are kept (`add_coins` 11228-11243). This is at-most-once and acceptable under "never replay".
- Recommendation: keep a per-session set of announced ids on the client, so a resent event is ignored. Do not persist "announced" flags on the server unless the creator wants at-least-once delivery.
- **Migration flood.** Events and crafts are counted from the start of the character (15623-15625, and the save `goals_done`/`goal_counts`, 18342-18343). When the approved catalog replaces runtime data, every existing character's history (`made:*`, `event:placed:*`) completes many goals at the first `_goals_check`, each with a coin grant and a placard. At about 5.1 s per placard (0.6 + 4 + 0.5), 50 goals is more than 4 minutes of placards.
- Recommendation: a **creator decision** between three options:
  - (a) completions caused by migration pay silently with one summary placard;
  - (b) they pay and show every placard;
  - (c) no back-pay.
- Either way the client queue needs a cap or coalescing rule, such as "N goals achieved" after K queued.

### HUD

**U-12 (MEDIUM): the upper-right corner is already occupied.** IMPLEMENTED.
- **Comfort / Rested label**: top-right anchor, x -420..-20, top 18, 26 px, shown whenever comfort or rested is above 0 (`inventory_view.gd:4746-4762`). It sits exactly where a Goals box would go.
- Other HUD pieces, for comparison:
  - Admin compass: top centre, 640x48 at y 6 (`admin_compass.gd:8-9, 35`), so x 640-1280 at 1920.
  - Link bars (`terrain_client.gd:1248`) and the debug text label (1330): top left.
  - GPU probe table: top left (`gpu_probe.gd:27`).
  - Sound panel: top left (`sound_panel.gd:52`).
  - Status icons: centred at 20 % height (`status_icons.gd:29-34`).
  - Notices / prompt: centre (`inventory_view.gd:351-366`).
  - Pickup feed: centre left (`pickup_feed.gd:22-25`).
  - **Pinned recipe card: centre right**, offset_right -24 (`pinned_recipe.gd:64-67`). A tall card could meet the bottom of a Goals box.
- Recommendation:
  - Put the Goals box under the comfort line (top at about 64 canvas px), or move comfort beneath the box. Moving comfort is a layout change and should be listed in the PR.
  - Width: about 480 px. The longest draft title is 40 characters ("Find limestone for advanced construction", "Build Engineered - Double arched doorway"); 32 of 651 titles are over 30. Use at least 18 px text and ellipsize or wrap to one extra line.
  - Decide whether F4 "All screen text on / off" (`key_bindings.gd:57`) hides the Goals HUD. Today it hides only the debug label (`terrain_client.gd:4383-4386`). Also decide whether the box hides in photo mode and while a screen is open. Both are minor UX decisions.
  - When nothing is unfinished, hide the box. The CREATOR rule covers 2 and 1 remaining but not 0.

**U-13 (HIGH): there is no rule for which two goals the HUD shows.** See the analysis in section 3. The draft's order is a PROPOSAL (`PLAYER_GOALS_REWARDS_DRAFT.md:19`). The draft has **no `after` column** (`work/goals_parsed.json` has no prerequisite field). The runtime does gate completion on `after` (`_goal_open` 15740-15746, used at 15763).

There is also a conflict to escalate, not resolve:
- The draft says "any valid earlier/out-of-order completion must earn the goal even if it is not shown in the HUD" (`PLAYER_GOALS_REWARDS_DRAFT.md:10`, PROPOSAL, under creator review).
- Under IMPLEMENTED gating, an out-of-order action earns nothing until the gate opens. For possession checks it can never earn at all if the items are gone by then.

### Placard

**U-14 (MEDIUM): dynamic text areas, font and long names.**
- The art was not inspected; the facts are the lead's (1448x1086 RGBA; "Goal Achieved" and "Reward" baked in). The pixel rects of the blank centre plate and the reward box are UNKNOWN. They must be measured on Dave's PC and stored as normalised rects (constants or a small JSON beside the asset).
- Font: the baked lettering style is UNKNOWN to this audit. Recommend Cinzel Bold in `ArtKit.HEADING` / `BRASS_HI` tones for the name, and Cinzel or EB Garamond SemiBold for the reward (`art_kit.gd:124-134`; the fonts are OFL, `assets/ui/fonts/FONTS_LICENSE.md`). Confirm visually against the baked banner.
- Long names: titles reach 40 characters. Cinzel is a wide capital face (about 0.7 em per glyph). At 48 px that is roughly 1,300 px, far wider than any plausible centre plate. Allow 2 lines and step the font size down with `Font.get_multiline_string_size` until it fits. Do not rely on an engine auto-fit; whether 4.7.2 has one is UNKNOWN.
- Test with "Build Engineered - Double arched doorway" and "Find limestone for advanced construction".

**U-15 (MEDIUM): coin denomination format, and the coin icon gap.**
- Runtime wording: server `_coin_words` (`server_items.gd:11260-11267`, using `purse_breakdown` 11212-11224) and client `coin_text` (`inventory_view.gd:1926-1941`) both produce "2 silver, 4 bronze", richest first (Dave, TEST-002). The ladder is `data/items/coins.json` "ladder": gold 1000, silver 100, bronze 10, copper 1.
- The draft's Reward column says "2 silver + 4 bronze" (for example `build:saw_mill`, 240 copper, the largest reward). That is a text mismatch.
- The placard must format from the integer copper using the client helper, never by parsing draft text.
- Coin icon gap (the Example has a stack icon; the Blank lacks it). Two usable sources exist:
  1. The client's `fill_coin_line`, which draws "4 (icon) 3 (icon)" with its procedural coin circles (`inventory_view.gd:1944-1990`). This matches how the purse is shown elsewhere.
  2. The baked 128x128 item icons `assets/ui/item_icons/coin_{gold,silver,bronze,copper}.png` (about 8 KB each).
- A gold "stack" icon like the Example's has **no asset**. Using per-denomination icons or plain text is a visual choice for Dave.
- Legacy runtime rewards are not all coins: `twine` gives 4 sticks, `fell` gives 3 kindling, `story` gives +1 reputation (`data/items/starter_goals.json`, `camp_goals.json`; handled at `server_items.gd:15771-15775`). Until the catalog is approved and replaces them, the placard's Reward line must also handle item and reputation rewards.

**U-16 (MEDIUM): queuing, duplicates, input and coin authority.**
- **Queue.** Use a client FIFO fed only by `goal_achieved`. Show one placard at a time and play one fanfare per placard, never overlapping. Hold the queue while the Esc menu or death screen is up. `_goals_check` can complete several goals in one pass (the loop at 15757-15789), so bursts are normal.
- **Input.** Put the placard on its own CanvasLayer. Use `mouse_filter = MOUSE_FILTER_IGNORE`, never `grab_focus`, and no `_input` or `_unhandled_input` handler. Animate with a Tween on `scale` and `rotation` around `pivot_offset` at the centre. Never set `get_tree().paused`, which would stop the multiplayer client.
- **Coins.** The server already pays in `_goals_check` (`add_coins(peer, …, "goal")`, 15770-15771), and the placard must stay presentation only.
  - `add_coins` also sends `received` rows to the pickup feed (11241-11243), so coins appear twice (feed and placard). That is a duplicate display, not a duplicate grant.
  - The existing "Goal done:" notice is a third display. The creator or lead decides whether to keep the notice (it is also the accessible text) or shorten it.
  - The `test_goals.gd` checks at 89-90 and 99 assert the notice wording and would need updating.
  - The purse is capped at `max_copper` (`add_coins` 11235-11237). This is negligible.

**U-17 (LOW): texture memory and weak hardware.**
- 1448x1086 RGBA8 = 6.0 MiB in VRAM, or about 8 MiB with mipmaps.
- The game's UI textures import lossless (`compress/mode=0`, for example `assets/ui/brain_icon.png.import:18` and every `assets/ui/title/*.import`), so they stay uncompressed RGBA8 in VRAM.
- The low-tier budget is "up to 1.5 GB video memory" on a 1050-class card (`ARCHITECTURE_BUDGET.md:38-42`). One placard is about 0.4 % of that, which is acceptable.
- The canvas is fixed at 1920x1080 (`project.godot:32-36`, stretch `viewport`), so pixels beyond the displayed size are wasted. Recommendations:
  - Crop the transparent surround.
  - Resample to the display size (for example 960 px wide, about 2.6 MiB; or 724x543, about 1.5 MiB). Changing the art's resolution needs Dave's approval of the result.
  - Disable mipmaps.
  - Do not use VRAM compression: the 1086 px height is not a multiple of 4, and block artefacts hurt lettering.
  - Decoding a 2.6 MB PNG on a SATA HDD at the first goal can hitch. Preload it threaded at join (`ResourceLoader.load_threaded_request`).
  - Import **only the Blank**. Keep the Example outside `res://` (or under a `.gdignore`), because Godot imports and exports every PNG in the project.

**U-18 (LOW): the art's alpha conflicts with an earlier creator rule.**
- The lead measured body alpha at mostly 240-254 (slightly translucent).
- Dave's 23 Oct rule says panels are solid: "nothing of the game shows through". It is cited in `dynasty_theme.gd:11` and `INVENTORY_CRAFTING_LOOK.md` §2/§12 "See-through panels".
- Both come from the creator. The new art is newer and specific to this placard. Ask Dave whether to keep the art's translucency or force the body to alpha 255 on import. Do not decide silently.

**U-19 (MEDIUM): there is no fanfare sound.**
- Searched `assets/` for fanfare, trumpet, achiev*, victory, success, jingle, level-up and goal file names: **none found**.
- `assets/audio/ui/` holds only `ui_click_*`, `ui_on_*`, `ui_off_*` and `ui_quality_*`. `assets/audio/skill/skill_tock_*` is a wooden tock.
- `docs/SOUND_MAP.md:44` lists "Goal done, hint: none?".
- Credits: `assets/audio/CREDITS.md` and `CREDITS.csv`. The UI and skill sounds are "own synthesis" made by the `make_*.py` scripts (for example the `skill/*` row in CREDITS.csv). Dave's supplied recordings are Pixabay-licensed, and several have unknown origin marked TODO.
- Requirement: a short (about 1.5-2.5 s) trumpet fanfare, either original (synthesised in a new `make_*.py`, as with the existing UI sounds, or recorded) or under a licence compatible with shipping inside the game. It needs a CREDITS.csv row checked by `check_credits.py`, loudness per `assets/audio/LOUDNESS.md`, and Dave's listen before use (the convention in `INVENTORY_CRAFTING_LOOK.md` §10).
- Until it exists, the placard must ship silent or with an existing UI sound, and **must not** use copyrighted music.

### Admin and debug keyboard

**U-20 (HIGH): defaults that break the creator's Ctrl+Shift rule today.** IMPLEMENTED (`key_bindings.gd:53-70`).
- 11 of the 16 `Admin and debug` rows lack Ctrl+Shift. Only `gpu_probe`, `water_hide` and `water_debug` comply. `admin_npc`, `admin_rabbit`, `admin_dig` and `admin_spyglass` are Ctrl-only, and `sound_panel` is Shift-only.
- Hard-coded checks outside `KeyBindings` also fire admin/debug behaviour **with no modifier at all**. **`terrain_client.gd:4347`** `event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD` raises the spring, and **`4349`** `KEY_KP_SUBTRACT` lowers it. These must be removed, or chorded and routed through `KeyBindings`. `CONTROLS.md:26` documents "+ / - (also numpad)".
- `scenes/terrain_preview/terrain_preview.gd:228` hard-codes bare `KEY_G` walk/fly in an offline dev scene (`--role=terrain`, header lines 1-12). It is not the game client. The policy's scope ("any keyboard-triggered admin/debug action discovered in code") arguably covers it: chord it, or have the lead record it as an exemption.
- No other hard-coded admin/debug key exists:
  - All `KEY_*` uses outside `key_bindings.gd` are listed in the grep.
  - The other hard-coded keys are gameplay or tests: `held_item.gd:2506` KEY_B shield block, `dialogue_view.gd:179-188` E/Esc/1-5, and the self-tests in `inventory_view.gd:5518-5534` and `6270`.
  - There is no `InputMap` or `is_action` use apart from `ui_accept` in `item_slot.gd:219`.
  - There are no other `_input` or `_unhandled_input` handlers with admin keys (`key_capture.gd`, `idle_timeout.gd`, `title_settings.gd`, `creator_proto.gd`, `character_select.gd` handle only Esc or capture).

**U-21 (HIGH): several admin actions have no server-side authority.** The policy (item 5) says "Maintain existing admin role and server-side authority". For several actions there is nothing to maintain. A modifier is not authorisation (CREATOR hard rule):

| Action | Enforcement found |
|---|---|
| `fly` | **None.** Client toggles `flying` (`terrain_client.gd:4405-4410`). The server trusts reported positions with no speed or fly check (`terrain_server.gd:993-1013`). Flying also turns on admin inspection details (`knowledge.admin = flying`, `terrain_client.gd:3678`) |
| `admin_npc` | **None.** Client sets its own position (`terrain_client.gd:2188-2201`) |
| `jitter_test` | **None.** Client teleports and sets `flying = true` (`src/debug/jitter_test.gd:41-46`) |
| `spring_up` / `spring_down` | **None.** `net.step_water_rate` (`terrain_net.gd:317-320`) leads to `_on_water_rate_requested`, which changes the **world's** spring rate for everyone with no admin test (`terrain_server.gd:1138-1144`) |
| `admin_dig` | Server checks `admin.is_admin` (`terrain_server.gd:1886-1889`) |
| `admin_rabbit` | Server checks it (`terrain_server.gd:2469-2472`) |
| `admin_spyglass` | Server `admin_ok` (`server_items.gd:1252-1263`) |
| `starter_items` | Client gates on `items.admin_craft` (`terrain_client.gd:4377`); server ACT_ADMIN_GIVE `admin_ok` (`server_items.gd:1232-1233`; `admin_ok` is wired at `terrain_server.gd:515`) |
| quality, debug_details, sound_panel, hud_text, gpu_probe, water_hide, water_debug | Local presentation or diagnostics only, no server effect |

Context:
- `data/items/admin_setting.json` has `"check_admin": false`, which makes everyone an admin today (`server_admin.gd:6-7, 33-35`).
- The game menu shows the Admin page to all players (`game_menu.gd:17` `SHOW_ADMIN := true`).

Recommendation:
- Add a server admin check to `_on_water_rate_requested`.
- Send the client a server-confirmed admin flag after hello (none exists; the welcome at `terrain_server.gd:904-922` is sent before the key is known). Gate fly, NPC teleport and jitter teleport on that flag.
- Record the remaining position-trust gap as a separate security item. Do not widen this PR's scope without the lead.

**U-22 (MEDIUM): the policy's chord map has no internal collisions, but some keys are layout-fragile.**
- In the world context, `matches()` compares Ctrl and Shift exactly for non-held rows (`key_bindings.gd:203`). So none of the proposed chords collide with each other or with the plain gameplay keys R (blueprints), X (sit), P (auto pickup), J (Journal), G (Journal), N or L (unused). See the table in section 2.
- Remaining risks:
  1. **Layout.** `=`, `-` and `]` use layout-dependent `keycode`. On German QWERTZ, `=` is Shift+0 (KEY_0, which `refusal()` refuses as a hotbar key, `key_bindings.gd:249-251`). `]` is AltGr+9, which Windows reports as Ctrl+Alt. So Ctrl+Shift+= and Ctrl+Shift+] **cannot be pressed** there. The policy allows another primary key in this case. A layout-safe example (PROPOSAL) is Ctrl+Shift+F9 / F10 for the spring and Ctrl+Shift+F6 for starter items. Avoid PageUp and PageDown, which are held photo keys that ignore modifiers.
  2. **Held movement during a chord.** Ctrl is the held `down` action and Shift the held `run` action (`key_bindings.gd:22, 24`, polled at `terrain_client.gd:4719-4724, 4769, 4964`). Every Ctrl+Shift chord descends while flying or swimming. Ctrl+Shift+G toggling fly on starts an immediate descent while Ctrl is still held. This is minor; options are to suppress `down`/`run` until the modifiers are released after a chord fires, or to accept it and document it.
  3. **Engine, OS and driver hotkeys.** Whether the Godot 4.7.2 editor's embedded game window intercepts F5 or F8, and whether GPU-overlay hotkeys (vendor tools often use Ctrl+Shift+letter) are set on Dave's PC, are UNKNOWN. They need the editor test the policy requires in item 7.
  4. The inventory-context cases in U-03.
- Labels: `OS.get_keycode_string` writes "Equal", "Minus" and "BracketRight", so the Controls page shows "Ctrl+Shift+Equal". Recommend friendlier labels.

**U-23 (HIGH): the saved-bindings loader and editor do not enforce the rule. Migration is required.**
- `ensure_loaded()` strips modifiers only for held rows and accepts any Ctrl/Shift combination for every other row (`key_bindings.gd:132-143`).
- `set_binding()` stores whatever modifiers were held at capture (`key_bindings.gd:260-284`, captured at `key_capture.gd:47-49`, applied at `key_bindings_page.gd:166-191`).
- `swap()` hands the other action this action's old modifiers (288-292), so a swap could move a plain key onto an admin row or a chord onto a gameplay row.
- `reset()` and `reset_all()` restore defaults (301-310), which will be compliant once the defaults change.
- `conflict()` and the swap prompt work per context only (217-240).
- `conflicts()` is not shown on the Controls page; only a test calls it.

Required changes (description only):
1. **Sanitise on load, the same way every time.** For every `Admin and debug` row in `_changed` with key ≠ KEY_NONE, force `ctrl = shift = true`. Keep KEY_NONE (disabled), because the policy allows disabling. If the forced chord collides with another admin row or with a new Journal default, reset that row to its default; if the default also collides, clear it and tell the player. Save if anything changed.
   - Only users who rebound admin rows have entries; defaults are not stored (`_changed` holds changed rows only).
   - Also scan for users who earlier bound a **gameplay** action to J, G or M, which now collide with the Journal defaults.
2. In `set_binding()`, for admin rows ignore the captured modifiers and always store Ctrl+Shift. The page prompt should say "Ctrl+Shift is added automatically".
3. `swap()` must refuse admin-to-non-admin swaps, or apply each row's group rule.
4. In `matches()`, for admin rows require `ctrl_pressed and shift_pressed` even if the file was hand-edited. For held and inventory-screen rows, apply the U-03 rejection.
5. Show `conflicts()` results when the Controls page opens.
6. Update `test_key_bindings.gd:43-47`: it asserts "Ctrl+R is the rabbit" and the label "Ctrl+R". `test_chest_column.gd:169` asserts Store All on G and must keep passing.

**U-24 (MEDIUM): help strings and docs that name the old keys must change in the same PR** (policy item 6).
- Hard-coded player-facing text:
  - `HELP_TEXT` at `terrain_client.gd:3475-3484`. It is already stale: "Walk or fly: G **or F**", although F is `open`.
  - `terrain_client.gd:6513`.
  - `gpu_probe.gd:204, 243`.
  - `sound_panel.gd:71` ("Shift+F3 closes").
  - `game_menu.gd:484` ("Ctrl+Shift+G").
  - Comments at `terrain_client.gd:113, 229, 270, 494, 2187, 2887, 3860, 4067-4069, 4088, 4184`, `spyglass.gd:4, 29, 64`, `flora_view.gd:718, 727`, `water_material.gd:46`, `liquid_surface.gd:59`.
- `CONTROLS.md` rows 22 (G), 26 (+/-), 36-38 and 40 (Ctrl+R/N/L/X), 41-49 (F2, F4, F3, Ctrl+Shift+G, F8, F7, J) and 79 (]).
- Sound panel Shift+F3 is **missing** from CONTROLS.md today. `check_controls.py` does not check modifiers.
- The Controls page lists defaults straight from `ACTIONS` (`key_bindings_page.gd:56-63`), so changing the defaults updates it. The "Default key list" page shows `HELP_TEXT` (`game_menu.gd:238-241`), which is hand-written.
- Recommendation: build those strings from `KeyBindings.label(id)`.

---

## 2. Key-conflict table

Contexts:
- **W**: world, the `_unhandled_input` chain at `terrain_client.gd:4319-4410`.
- **INV**: an inventory-family screen is open, so keys go only to `quick_key` (`inventory_view.gd:4965-5023`).
- **MENU**: Esc menu or Controls page.
- **TXT**: a focused LineEdit.
- **R-menu**: hammer blueprint list.
- **INSP**: inspection mode.
- **PHOTO**: photo camera.

"Exact" means `matches()` requires the same Ctrl and Shift (`key_bindings.gd:203`). "Held" means modifiers are ignored (`key_bindings.gd:200-201`).

| Key / chord | Today | Proposed | W | INV | MENU / TXT | R-menu / INSP / PHOTO | Verdict |
|---|---|---|---|---|---|---|---|
| J | jitter_test (`kb:65`) | Journal Index | Free once jitter moves; exact match | Swallowed (no INV action on J) | Ignored / typed | Fires today; for the Journal, decide to block in PHOTO and the spyglass (U-04) | OK after the move |
| G | fly (`kb:53`); store_all INV (`kb:50`) | Journal Goals (W); Store All (INV) | Free once fly moves | **Store All stays.** The INV branch returns first (`tc:4289-4293`) | Ignored / typed | As J | OK, no fall-through |
| M | — | Journal Map | Free | Swallowed | Ignored / typed | As J | OK |
| Ctrl+Shift+G | gpu_probe (`kb:66`) | fly | Exact; Journal G not fired | **Fires store_all** (held row, U-03) | Ignored | — | Needs the U-03 fix |
| Ctrl+Shift+P | — | gpu_probe | Exact; P auto_pickup (`kb:35`) not fired | No INV action on P | Ignored | — | OK |
| Ctrl+Shift+J | — | jitter_test | Exact; Journal J not fired | Swallowed | Ignored | — | OK |
| Ctrl+Shift+F2 / F3 / F4 | F2, F3, F4 plain (`kb:54-57`) | quality, debug_details, hud_text | Exact | Swallowed | Ignored | — | OK |
| Ctrl+Shift+F5 | — (sound panel is Shift+F3, `kb:56`) | sound_panel | Exact | Swallowed | Ignored | — | OK. Editor F5 is UNKNOWN (U-22) |
| Ctrl+Shift+F7 / F8 | water_hide / water_debug (`kb:69-70`) | unchanged | Exact | Swallowed | Ignored | — | OK. Editor F8 is UNKNOWN |
| Ctrl+Shift+= / - | `=`/`-` plain (`kb:58-59`) **plus hard-coded KEY_PLUS, KEY_KP_ADD, KEY_KP_SUBTRACT** (`tc:4347-4349`) | spring_up / down | Exact once the hard-coded keys are removed | Swallowed | Ignored | — | **Layout-fragile; hard-coded keys must go** (U-20, U-22) |
| Ctrl+Shift+] | `]` plain (`kb:60`) | starter_items | Exact | Swallowed | Ignored | — | **Layout-fragile** (U-22) |
| Ctrl+Shift+N | Ctrl+N (`kb:61`) | admin_npc | Exact | Swallowed | Ignored | — | OK |
| Ctrl+Shift+R | Ctrl+R (`kb:62`) | admin_rabbit | Exact; R blueprints (`kb:31`) not fired | **Fires repair_item** (held row R, `kb:46`) | Ignored | — | U-03 |
| Ctrl+Shift+X | Ctrl+X (`kb:63`) | admin_dig | Exact; X sit (`kb:26`) not fired | Swallowed | Ignored | — | OK |
| Ctrl+Shift+L | Ctrl+L (`kb:64`) | admin_spyglass | Exact | Swallowed | Ignored | Spyglass refuses in PHOTO (`tc:4077`) | OK |
| Ctrl and Shift held during any chord | — | — | **Held `down` and `run` act** (`kb:22, 24`) | — | — | — | Minor (U-22) |
| Ctrl+Shift+E / Z / any INV key (if a user rebinds an admin row there) | — | — | **interact / lie fire first** (held) | **INV quick key fires** | — | — | U-03 / U-23 |

`kb` = `src/client/key_bindings.gd`, `tc` = `scenes/terrain_client/terrain_client.gd`.

Among the 16 proposed admin chords themselves there is no duplicate: G, P, J, F2, F3, F4, F5, F7, F8, =, -, ], N, R, X and L are all distinct.

---

## 3. HUD ordering analysis ("the two earliest unfinished goals")

Data facts:
- `work/goals_parsed.json` has 651 rows: 118 `MAIN` (draft lines 28-145) and 533 `ADDITIONAL` (lines 155-757). The route changes **once**: all MAIN rows come before all ADDITIONAL rows. **So for this draft, (a) pure document order and (b) main-first-then-additional give identical results.**
- The draft has no `after` field. Only the 28 legacy runtime ids carry `after` (`starter_goals.json`, `camp_goals.json`).
- None of the legacy `after` links point to a goal later in draft order (checked: no backward edges).
- Legacy ids that sit in ADDITIONAL: sell, fish, spear, order, knife, fur_for_winter, story, torch_night, hoe, night_walk, dry_berries, path, jerky, salted_fish, smoke_fish, candle and winter_store (draft rows 134-386). Under (a) or (b) none of them reaches the HUD until all 118 main goals are done.

Option (c), "earliest unfinished whose `after` is met", is only defined where `after` exists. That means the legacy rows, or a prerequisite graph derived from the catalog. Two runtime interpretations matter:
- **L (legacy gating kept):** `_goal_open`. A met goal is not completed until its `after` goals are done. Counts persist, but possession checks are re-tested.
- **N (no award gating):** the draft line 10 reading. Out-of-order actions complete immediately.

Which interpretation applies is the open conflict in U-13.

Scenario S0, a brand-new player (empty pack; no starting kit was found in `server_items.gd`):

| Rule | HUD |
|---|---|
| (a) | • Gather sticks • Gather stones |
| (b) | • Gather sticks • Gather stones |
| (c) | • Gather sticks • Gather stones (neither has an `after`) |

Scenario S1, "built a lean-to first". The player:
- picked up sticks and stones;
- made twine in small batches, so never held 12 plant fibre at once (the legacy `fibre` check is have-12, `starter_goals.json`);
- made a stone knife and stone axe, felled a tree, took a log and chopped blocks;
- made a wooden hammer and built the lean-to;
- never drank, never made a pickaxe, never made a campfire.

| Rule | L (gating kept) | N (no gating) |
|---|---|---|
| Goals done | stick, stone, stone_knife, log, chop_blocks. **twine, axe, fell, hammer and shelter are met but blocked** behind `fibre` | stick, stone, twine, stone_knife, axe, fell, log, chop_blocks, hammer, shelter |
| (a)/(b) now | • Drink at the water • Gather plant fibre | • Drink at the water • Gather plant fibre |
| (a)/(b) after drinking | • Gather plant fibre • **Twist twine** (already done in play, so the HUD asks for something the player did) | • Gather plant fibre • Craft Stone - Pickaxe |
| (c) after drinking | • Gather plant fibre • Craft Stone - Pickaxe (twine skipped: `after` fibre unmet) | same as (a)/(b) |
| When 12 fibre are finally held | **Cascade**: fibre, twine, axe, fell and hammer complete at once (5 placards, 5 grants). Shelter stays blocked until `fire` | — |

Scenario S2, mid-game stall: main route done up to the Smithy, but the player has not found flint or a hide (`gather:hide` and `gather:flint`, main rows 45-46).
- (a), (b) and (c) all show "• Obtain hide • Find flint for a hide scraper" until they are done, because neither has an `after`. No option solves "currently hard to do". Alternatives belong in the Journal.

Scenario S3: all 118 main goals done.
- (a)/(b) show "• Craft Compost • Craft Fibre - Skirt" (the first ADDITIONAL rows, draft lines 155-156).

Recommendation (PROPOSAL):
- Use **(b) as an explicit `display_order` integer in the approved catalog**: main route first, then additional, in the creator's order. For the current draft it equals (a) and his literal two-goal rule. Both client and server can compute it from the synced state, and it does not depend on file line numbers.
- (c) only adds value if legacy award gating (L) is kept. In that case it hides "do what you already did" rows such as Twist twine in S1.
- The cleaner fix is in the catalog, not the HUD: count-based completion with no award gating (N), with `after` used only for Journal prerequisite navigation.
- **Choosing (c), or any rule other than "first and second unfinished in the approved display order", changes the creator's two-goal rule, so it is Dave's decision.** This audit does not change the rule.

---

## 4. Not checked or UNKNOWN

- The placard PNGs were not opened (per the brief). Text rect positions, the baked font style and alpha details come from the lead or are UNKNOWN.
- Whether the Godot 4.7.2 editor's embedded game captures F5 or F8, and OS or driver Ctrl+Shift hotkeys on Dave's PC: UNKNOWN. These need the policy item 7 playtest.
- The `held_item.gd` blueprint-list lifecycle when another screen opens: UNKNOWN (only the call site was read).
- Existing tests were not run: `test_key_bindings.gd`, `test_goals.gd`, `test_chest_column.gd`.
