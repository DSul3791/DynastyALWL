# Ponytail rules (for the Dynasty water build)

Source: github.com/DietrichGebert/ponytail (README). Dave asked that the new water system is built under these rules.

## Decision ladder (stop at the first rung that holds)
1. Does this need to exist?
2. Is it already in this codebase?
3. Does Godot or the standard library do it?
4. Is there a native platform feature?
5. Is there an installed dependency?
6. Can it be one line?
7. Only then write the minimum that works, plus one small test if it has logic.

Run the ladder after you understand the problem: read the code the change touches and trace the real flow first. Lazy about the solution, never about reading.

## Hard rules
- Never cut trust-boundary validation, data-loss handling, security or accessibility.
- The aim is not fewest tokens or lines; it is writing only what the task needs.
- Logic with a branch, loop, parser, money or security concern gets one small test.
- Every report ends by saying what was skipped or not checked, and any risk.
- A deliberate shortcut gets a `shortcut:` comment saying when to revisit it.

## Dynasty notes
- Reuse before writing: baked tiles, `TileFile`/`TerrainTile`, the water shader, `ShoreRules`, existing test helpers.
- Keep the new code under `src/water2/`; no copy-paste of the old live sim.
