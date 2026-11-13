# Dynasty — Full-Game Tutorial, Journal, Goals, HUD and Goal Achieved Placard

**Status:** Creator-approved UI direction / implementation handoff; the full-game tutorial sequence, instruction text, per-goal completion conditions, and goal-and-reward amounts are **DRAFT FOR REVIEW** until explicitly approved in [PLAYER_GOALS_REWARDS_DRAFT.md](PLAYER_GOALS_REWARDS_DRAFT.md).
**Date:** 13 November 2026.
**Implementation target:** Godot 4.7.2, `dev` integration workflow, existing server-owned goal and purse systems.

## Authoritative player decisions

1. The Journal is **one window**, with a table-of-contents/index as its home page. **J** opens the Index, **G** opens the same Journal to **Goals**, and **M** opens the same Journal to **Map**. In the Journal, J returns to the Index; from Index J may close. Esc closes. Clicking the index entries navigates identically. Do not open three overlapping windows.
2. The Journal and its Goals page must **look and feel like the current Inventory/Crafting page**: comparable layout, trim, palette, panel geometry, typography, theme, corners and interaction feedback. Reuse the actual `src/client/ui/dynasty_theme.gd`, Inventory/Crafting UI components, and `docs/design/INVENTORY_CRAFTING_LOOK.md` as visual references. Do not invent a competing parchment-book skin.
3. The gameplay Goals HUD is a deliberate **minimalist exception**. In the **upper-right**, a thin-line rectangle with just the heading **Goals** and two bullet-point titles: the first and second unfinished goals in the approved display order. Show one when only one remains. No ornate Inventory/Crafting trim, decorative icons, progress bar, coin amounts, long hints, buttons, or reward panel in the HUD.
4. **All goals are automatic.** No accepting, starting, manually selecting to track, activating, submitting, or claiming. Every eligible goal keeps progressing regardless of whether it is visible. The Journal's selected row is *view-only*. The server automatically grants the correct once-per-character coin reward on completion. Never award again for journal viewing, reloading, reconnecting, or popup animation.
5. The Goals page is the **complete, accurate interactive tutorial and progression guide for the entire game**, not a brief onboarding checklist. Every goal must explain the actual steps needed to reach and complete it: where and how to get its materials, which tool or station to build first, the correct recipe and quantities, how to activate the relevant game UI, and what action proves completion. Examples: harvest plant fibre from tall grass/nettles before making Twine; chop logs into wooden blocks; use a Chopping Block to make firewood; add 3 pieces of firewood for a medium campfire and 3 logs for a bonfire (with no cooking pot hung); build the Smelter and then the Smithy before the Iron Saw, which enables hand-cut Planks and Hardwood Boards. Continue this sequence through Engineered and Fortified top-tier construction. The Goals page shows each approved name, genuinely current completion state, verified instructional text and real progress where reliable, and its exact coin reward. Include completed goals and unfinished goals in a scrollable list; details open by selecting a row. **Goal data and coin values come from the approved goal catalog and server authority**, not a client duplicate.
6. The existing World Map may be embedded under Map if it exists and is compatible. This scoped feature must not invent terrain/map generation, fog-of-war, or map exploration mechanics simply to populate the page.

## Input collisions that must be resolved carefully

As of `dev` review on 13 Nov, `src/client/key_bindings.gd` maps G to Admin Fly in World context, G to Store All in inventory context, Ctrl+Shift+G to GPU probe, and J to a jitter-test control. **Creator's new rule (13 Nov): every action in the `Admin and debug` binding group must require both Ctrl and Shift plus its action key.** The authoritative implementation mapping is [ADMIN_KEYBINDINGS_POLICY.md](ADMIN_KEYBINDINGS_POLICY.md). The full keymap, saved user rebindings, input routing, and modal focus must be inspected.

- **All admin/debug controls:** move every `Admin and debug` action to **Ctrl+Shift+key**, including Admin Fly, NPC/debug actions, probes, HUD/debug text, sound panel, spring controls, starter items, water visualization and jitter test. Keep each feature functioning and admin permissions intact; include the actual default combinations in the game's Controls screen. Ordinary gameplay controls must remain usable without these modifiers.
- **Proposed collision-free mapping:** Admin Fly = Ctrl+Shift+G; GPU Probe = Ctrl+Shift+P (it currently occupies Ctrl+Shift+G); Jitter Test = Ctrl+Shift+J; Sound Panel = Ctrl+Shift+F5 to avoid the F3 collision. For all other exact default chords and resolution rules, use [ADMIN_KEYBINDINGS_POLICY.md](ADMIN_KEYBINDINGS_POLICY.md). If any combination conflicts, choose an available alternative and document it rather than assigning two actions the same chord.
- **Migration and enforcement:** update default bindings, any hard-coded input checks/help strings and persisted custom bindings where they would leave admin/debug actions without both modifiers. The current key-binding loader accepts arbitrary Ctrl/Shift combinations, so the requirement must be enforced for the admin group as well as reflected in defaults. Preserve user-customizable *base keys* where feasible, but admin combinations must always require both modifiers. Protect against accidental firing from held/polled movement or Inventory shortcuts.
- Preserve **Store All** on plain G when the Inventory/Crafting screen has keyboard focus, since it uses an independent input context. The G Journal shortcut applies in gameplay/the Journal, and must not steal this inventory shortcut or allow input fall-through. Ctrl+Shift+G triggers Admin Fly only where admin actions are permitted, never the Journal or Store All.
- Make M a single Journal Map action after verifying no existing collision. Any other conflicts must be documented and repaired.

## Goal Achieved placard — separate celebratory UI

Every automatically completed goal receives an ornate fantasy achievement **placard**, visually distinct from the minimalist HUD. It spins/rotates and scales into the screen (target ~0.6 seconds), stays readable for ~4 seconds, then spins/shrinks away (~0.5 seconds), with a short triumphal **trumpet fanfare**. It must not pause multiplayer gameplay, require a click, duplicate the coin grant, or steal combat/movement inputs. Queue simultaneous goal completions so each earned announcement is shown once; avoid overlapping fanfares.

**Placard layout:**
- Fixed title: **Goal Achieved**
- Dynamic center text: the *actual achieved goal name*
- Fixed subheading: **Reward**
- Dynamic bottom text: the actual automatic coin payout (copper, bronze, silver, gold; 10:1 each)
- The placard is presentation only. The server is already responsible for awarding the coins.

**Asset location on Dave's PC:**
`C:\Users\david\Downloads\GoalAchieved`

That local Windows directory contains **two transparent-background PNG designs provided by Dave**: a **blank-center / blank-reward** runtime template and a **placeholder-text** visual example. Claude must inspect the real filenames, dimensions and alpha channels on the PC. **Use the blank version for runtime dynamic text**; do not bake placeholders or example amounts into shipping UI. Import the approved art to a stable repo asset path under `res://assets/ui/`, respecting existing conventions. Preserve aspect ratio and use responsive sizing. The original concept illustration's sample reward is not an approved goal reward.

Sound must be a genuinely usable original/appropriately licensed short fanfare (not assumed to exist merely because the trumpets are drawn). If no approved audio exists, flag the dependency rather than silently substituting copyrighted music.

## Runtime integration and testing

- Grounding: `src/stream/server_items.gd` currently loads `data/items/starter_goals.json` and `camp_goals.json`, tracks `goals_done` and `goal_counts` on the character, and calls the existing coin purse on completion. It has `goals_state(peer)` with basic fields but the client needs a real synchronized model including rewards; extend it rather than parsing transient text notifications or inventing a duplicate goal engine.
- Preserve legitimate earlier/out-of-order events and one-time completion. **Every nontrivial completed goal needs a real server-observable condition**; if a proposed tutorial step (e.g., fire reaches medium or bonfire size) lacks a goal event, implement the missing signal as part of the reviewed guide rather than pretend that a crafted item proves the action. The default goal order in the first complete draft is in [PLAYER_GOALS_REWARDS_DRAFT.md](PLAYER_GOALS_REWARDS_DRAFT.md); **do not replace runtime goal data or payouts until the creator approves that list**.
- Journal and HUD must refresh on server updates; reconnect/load must reconstruct goals, including completed, without replaying placards. Multi-goal bursts require ordered reliable announcements.
- Test open/close/nav J/G/M/Esc, conflicting Inventory G, mandatory Ctrl+Shift admin/debug chords (including saved custom bindings), admin flight and debug rebinding, visual comparison against the live Inventory/Crafting screen, small and large resolutions, the HUD's exactly-two-unfinished rule, coin denomination display and no duplicate payouts.
- Maintain the existing `main` protection and the scoped dev feature-branch/PR, independent review, and practical Godot playtest requirements.

## Full-game guide completeness rule (creator clarification, 13 Nov 2026)

This is one continuously relevant **Tutorial / Guide / Goals / Rewards** system, spanning the entirety of currently implemented gameplay from the first sticks and stones through the final high-tier manufactured and constructed outputs. Remove the 'first hour' framing from all new UI names, labels, mission prose and authoritative guide documentation. Old runtime filenames such as `starter_goals.json` remain technical migration references only, not the name or conceptual limit of the guide.

The two-column authoritative review catalog is `docs/design/PLAYER_GOALS_REWARDS_DRAFT.md`: **Goal** (name and detailed How-to within the same cell) and **Reward** (coin denomination). No steps may silently depend on an unmentioned station, ingredient source, tool, recipe, fire size, addon, or higher-tier intermediate product. Source facts from the current master items catalog and live JSON; show discrepancies as audit blockers, not as made-up tutorial guidance. Keep the goal pipeline automatic and user-independent of GUI selection.
