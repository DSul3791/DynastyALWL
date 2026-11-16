# Implementation records

Built means traceable implementation exists; it does not mean tested, complete or player-verified. [DOC_MAP](docs/DOC_MAP.md) remains the index. Full design specifications are linked, never copied here.

## Natural fog

- **Design:** [approval/source record](Design_Ideas_Approved.md#natural-fog), linking the single full director instruction.
- **Implementation origin:** [d0a0053](https://github.com/DSul3791/DynastyALWL/commit/d0a00538473ab26cc1cd81b5661da186a5462c4b), 14 Nov 2026; integrated through [PR #1142](https://github.com/DSul3791/DynastyALWL/pull/1142), merge [bc65ecd](https://github.com/DSul3791/DynastyALWL/commit/bc65ecd2bd20c5bdfb5c72e947cccc90b1e39a33), 14 Nov 20:00:50 UTC. The source commit explicitly owed Godot/PC and Dave's look checks; integration alone did not discharge those checks.
- **Static observation:** at dev `83c4abfd7f3ac8fe815f1a96cf0784881b7721c4`, [weather_look.gd](src/client/weather_look.gd) preloads/calls [fog_look.gd](src/client/fog_look.gd), creates [fog_volume.gd](src/client/fog_volume.gd), computes depth fog and sky hiding, and dims the sun. This proves those code paths exist, not that all fog requirements work at runtime. Later tuning differs from the originating commit; use current code for actual values.
- **Tests:** [test_fog_above.gd](src/worldgen/tools/test_fog_above.gd) contains regression checks for layer/sky behavior. Test existence verified; execution NOT RUN by this audit. No current Godot PASS is established here.
- **Player/visual evidence:** [F6 checklist](docs/design/FOG_F6.md) says all needs player verification; its checkboxes are not passing evidence. Appearance, transitions, darkness/torch behavior, shelter, creature detection and performance remain unverified by this audit.
- **Working details/gaps:** [technical plan](docs/design/FOG_PLAN.md) and the F6 checklist retain subfeature work and checks. This is partial implementation evidence, not a complete-built claim.
