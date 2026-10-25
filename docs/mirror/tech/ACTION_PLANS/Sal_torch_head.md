# Action plan: torch head, a wrapped head with a flame (Sal)
Branch claude/sal-torch-head (from generator-v2). Label RUNTIME, client look only: no protocol, save, ground or item change.
Why: Dave saw the held torch as a flat orange cone on a stick. It should be a stick with a wrapped head and a flame standing on it.
What: `_make_torch_model` in src/client/held_item.gd (Kathleen's file; this is inside one function only) now builds: the stick, a fatter dark wrapped head (tapered cylinder), two twine bands, a teardrop flame (sphere) with a lighter tongue above it, the same OmniLight as before (light_m from the item). The held and off-hand torch use it, and the lantern path is unchanged.
Test: parse_scan, warnings at baseline 233. David3 picture of the held torch lit and unlit, first person and off-hand, for Kathleen to critique (she owns the look).
Cost at Low: five small meshes instead of three, no new materials per frame; no shadows.
Ask: Tyler GO, then Kathleen can restyle the shapes on the same branch.
