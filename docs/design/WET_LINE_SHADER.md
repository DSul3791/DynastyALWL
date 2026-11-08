# The wet line: a dark band where the water reached (MikeW, 8 Nov 2026)

Follows the whole-coat wet look (`_wet_look`, #590 stack) and Kathleen's art_animals.md 7.1: "only the wet part is wet". A wading moose is dark to the belly line and dry above; a deer that crossed a stream has dark legs.

## What the shader must do
- Below the water line: albedo darkened by `wet_dark`, roughness eased to `wet_rough`, a little specular (0.45), the fur lying flat (no change in geometry, only the rim term weaker).
- A soft edge 5 cm tall, so the line is a band, not a cut.
- Above the line: the dry coat exactly as now.
- As it dries, the line sinks and the darkness fades, from the top down (drying starts where the fur is thinnest and highest).

## How
1. **Uniforms on every coat material:** `wet` (0 to 1), `wet_line` (height in the model's own space, metres above its feet), `wet_dark`, `wet_rough`.
2. **Shader:** a small spatial shader that takes the model's albedo texture and roughness and adds the band; we cannot set a uniform on a StandardMaterial3D, so the coat materials from `_model_materials` become ShaderMaterials built from one shared shader (one compile for all animals). The vertex stage passes the model-space height of each vertex (`VERTEX.y` before the model transform); the fragment computes `band = smoothstep(wet_line + 0.05, wet_line, height) * wet` and mixes the dry and wet values by it.
3. **Skinned meshes:** the model-space height must come after skinning, or a walking leg carries its rest height. Godot gives `VERTEX` after skinning in the vertex function, so the height is correct per frame.
4. **Setting the line (client, `_wet_look`):** in water, `wet_line` = water surface height minus the animal's feet height (its root's y), capped at the body's standing height (a swimmer is wet all over); `wet` = 1. Out of water: `wet_line` falls by 1 cm a second and `wet` by 1/180 a second (three minutes to dry).
5. **Birds** (`wet_shed`) keep the dry shader; only the head goes wet after a dabble (later: a head-only band from the head bone).
6. **Cost:** one shader for every animal, two extra uniforms per material, a few ALU per pixel. At most `MAX_DRAWN` animals; no texture reads beyond the albedo already read.

## Test
- Creature check option `--wet=0.5` that sets the line at half the standing height on every column, so the strip shows the band.
- Live: Kathleen's section 11 shots (a moose wading, a seal hauled out, a duck dabbling).

## Order
After #590 (swimmers) and the whole-coat wet look are merged; then this replaces the whole-coat darkening with the band.
