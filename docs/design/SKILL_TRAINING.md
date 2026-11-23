# Skill training and caps

Source: Dave, 23 Nov 2026 (about weapons, "and that works for all levels once we have trainers"):

> weapons training is slow naturally and you get a jump and a boost when you go to a trainer. a player can level from 1 to 24 without training but needs a trainer to get to 25-49. if they go to the trainer pre 25 they immediately jump to 25 after training.

This replaces the older tuning in the skills web design (items/SKILLS_WEB_DESIGN.md, Tyler's numbers), where training needed the skill within 5 of its cap and set the floor 5 over the old cap.

## The rule

- Every skill starts at 1 and rises slowly by use (the skills web cost curve, `data/items/skills.json` system `base_cost`, `growth`).
- **Untrained, a skill goes from 1 to 24.** Gains slow to nothing just under 25, and the skill screen shows "needs training to go further".
- **Each band past that needs a trainer:** 25 to 49 needs one training, 50 to 74 two, 75 to 100 three (`step` 25, caps 25, 50, 75, 100).
- **A training visit can come at any value in the band.** It jumps the skill straight to the next band's floor (25, 50, 75), opens the next band, and makes later gains faster (`train_speed` x1.2 per level). Going at 10 jumps to 25; going at 24 also jumps to 25.
- The floor covers the skill's family (it and its descendants read at least the floor), and decay never takes a skill under it.
- Weapon skills and Hand to hand follow the same rule as every skill. They open when Fighting reaches 15 (itself open at Athletics 15); until then their practice goes up to the nearest open parent, so nothing is lost.

## Where it lives

- Numbers: `data/items/skills.json` system: `step` 25, `floor_over_cap` 0, `train_near_cap` 25 (equal to `step`: no "near the cap" condition), `train_cooldown_days` 3, `teacher_margin` 10, `train_speed` 1.2.
- Code: `src/shared/skill_web.gd` (`cap_of`, `floor_of`, `train_problem`, `train`); the server's `train_skill` and `npc_train` in `src/stream/server_items.gd`.
- Kept from before: a 3 game day cooldown per skill between trainings, and a teacher at least 10 over the target and trained to that level. Trainer NPCs are not built yet.
- Tests: `src/worldgen/tools/test_skills.gd`.
