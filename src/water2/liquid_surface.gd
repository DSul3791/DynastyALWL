extends MeshInstance3D

# Liquid surface (Sonny, 2 Nov 2026; Dave: "think liquid not squares... reinvent your own that actually flows like liquid water").
# One continuous sheet over the live water window, not 8 m cells switched on and off. Every vertex takes its height from the simulated water surface
# (water_flow_texture.gd: R surface, G/B flow, A depth), sampled smoothly between cells, so a stream is one body that runs down its bed, a fall is the
# water itself bending over the lip, and a pond is level. The shore is decided per pixel from the depth: the sheet thins to nothing where the water
# does, so banks are curved and soft. Ripples and foam are carried along the simulated flow (two offset phases blended, the usual flow-map trick),
# so the surface visibly travels downstream at the sim's speed.
# The grid look (water_material.gd) steps aside inside the window; outside it nothing changes.

const SHEET_STEP_M := 4.0       # vertex spacing of the sheet (the sim cell is 8 m; the texture is filtered between). Was 2 m: 250,000 quads over the 1 km window, lag near rivers (Dave 2 Nov 2026)
const FINE_STEP_M := 1.0        # vertex spacing of a fine sheet (Sullivan water's 2 m cells; a 96 m tile is 9216 quads)
const FINE_THIN_LIFT_M := 0.05  # a fine sheet's lift for thin water (the live window's thin_lift is for 8 m cells over bumpy ground)
const FADE_CELLS := 1.0         # > 0: this sheet is the live window and fades in at its edge (over the shader's blend_m band, not one cell any more)

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform sampler2D liquid : filter_linear, repeat_disable;   // R surface (m), G flow east, B flow south (m/s), A depth (m)
uniform vec2 cells = vec2(128.0);                           // texels across
uniform float fade_cells = 1.0;                            // 0: no fade at the sheet's edge (a chunk sheet meets its neighbours)
uniform float point_grid = 0.0;                            // 1: texels sit on the sheet's corners and edges (a chunk's grid points), 0: on cell centres (the live window)
uniform vec4 hole = vec4(0.0);                             // world x, z, size x, size z of the live window: a chunk sheet steps aside there
uniform float hole_inset = 8.0;                           // no longer used: chunk sheets crossfade over blend_m (BUG-006)
uniform float cell_m = 8.0;                                // metres between texels
// Dave 4 Nov 2026 ("the game knows there is water there ... but its not showing water"): inside the live window a chunk sheet gave way to the live
// sheet everywhere, so where the sim had run a baked river dry (a ledge damming it) neither drew while the chunk grid, the prompt and the steps still
// said water. A chunk sheet now reads the live window's texture and gives way only as much as the live sheet itself draws there.
uniform sampler2D live : filter_linear, repeat_disable;      // the live window's texture (chunk sheets only)
uniform float has_live = 0.0;                              // 1 when `live` is set
// Dave's QA list 3 Nov 2026 (BUG-006, "a sharp, straight-line boundary separates calm and active water"): the live window and the chunk sheets
// around it crossfade over a wide, wandering band instead of switching one cell in. Both sides use live_blend(), so they always add up.
uniform float blend_m = 64.0;                              // the crossfade band, metres in from the window's edge (was 24: Dave 6 Nov 2026, x 52986 z 68328, the rippled live water met the calmer baked water in a line)
uniform float blend_wander_m = 24.0;                       // the band's inner side wanders this far in and out (no straight line)
uniform vec3 shallow_color : source_color = vec3(0.16, 0.38, 0.34);   // Kathreen 3 Nov 2026 (art direction: vibrant, not grey): greener shallows, was 0.17, 0.33, 0.33
uniform vec3 deep_color : source_color = vec3(0.03, 0.18, 0.28);   // bluer depths, was 0.04, 0.17, 0.24
uniform vec3 foam_color : source_color = vec3(0.80, 0.84, 0.82);
uniform vec3 sky_color : source_color = vec3(0.55, 0.64, 0.74);
uniform float clear_m = 1.1;        // water this deep hides about two thirds of the bed
uniform float edge_m = 0.06;        // the sheet fades in over this much depth at the shore
uniform float daylight = 1.0;
uniform float mud = 0.0;            // 0..1: brown runoff after storms or at high flow (flora_view.gd, as the grid look)
uniform vec3 mud_color : source_color = vec3(0.30, 0.24, 0.15);
uniform float rain = 0.0;           // 0..1 (weather_look.gd): raindrop rings on the surface
uniform float look_v2 = 1.0;        // 1: water after rain (docs/design/water_look_after_rain.md): clarity after rain, white water by Froude number, foam lines
uniform vec2 turbid = vec2(0.0);    // with look_v2: the cloud after rain in running and in still water, 0 clear .. 1 (weather_look.gd)
uniform float foam_supply = 0.6;    // with look_v2: how much foam the river makes (season, recent rain)
uniform float contact_m = 0.35;     // the sheet fades in over this much water along the view ray where it meets the ground (no hard line on a bank)
uniform float chunk_lift = 0.25;    // chunk sheets only: running water is drawn this much higher (see vertex)
uniform float thin_lift = 0.3;      // live window only: thin water is drawn this much higher (see vertex)
uniform float lap_m = 0.6;          // a thin lapping foam line where the water is shallower than this against the bank
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Sullivan water (Sonny, 7 Nov 2026; docs/water/fine_drawing_2m.md): the dig regions' 2 m water has its own fine sheets. An 8 m sheet (the live
// window or a chunk) steps aside inside each of up to 8 rectangles, over the same wandering band the fine sheet fades in on, so the two add up.
uniform vec4 fine_holes[8];         // world x, z, size x, size z
uniform int fine_count = 0;
uniform float fine_sheet = 0.0;     // 1: this is a fine sheet; its edge fades in over fine_blend instead of the live window's band
uniform float debug_sheet = 0.0;   // Ctrl+Shift+F8 or --water-debug: live window magenta, a 2 m chunk sheet yellow, an 8 m one orange, dark lines on the texel borders, darker where the sheet is steep, red seen from behind, cyan where fall white water is on
// Frozen water (docs/design/frozen_water_look.md, Kathleen 8 Nov 2026; client): src/client/frozen_water.gd works the numbers out, set_ice_all
// hands them to every sheet. Off (frozen_on 0) the sheet draws no ice, as before.
uniform float frozen_on = 0.0;
uniform vec4 ice_look = vec4(0.0);  // open (Ice.cover at 3 m), shore (at 1 m), thaw 0..1 (the shore moat first), snow 0..1 (lying snow)
uniform vec4 ice_springs[8];        // x, z, open radius m (Sonny's x0): a spring's brook stays open within it
uniform int ice_spring_count = 0;
uniform vec4 ice_holes[8];          // x, z, radius m, age 0..1 (a skin grows back over the last sixth)
uniform int ice_hole_count = 0;

varying vec2 tex_uv;
varying float depth_v;
varying vec2 flow_v;

// Smooth sampling (Dave 6 Nov 2026, x 54101 z 69709, a steep brook below a cave: "these should look like water not diamond shaped squares"). Straight
// bilinear reads of the 8 m cells drew a steep stream as flat tilted plates with diamond-shaped shores and white patches: the creases run along the cell
// edges and the mesh's diagonals. A cubic B-spline over the 4 x 4 texels round the point (four filtered reads) bends smoothly across the cells, with no
// creases. Only the live window: a chunk sheet must meet its neighbour exactly at their shared grid points, which bilinear does.
vec4 sample_smooth(sampler2D tex, vec2 uv) {
	vec2 p = uv * cells - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / cells;
	vec2 h1 = (i + 1.5 + w3 / g1) / cells;
	return g0.y * (g0.x * textureLod(tex, vec2(h0.x, h0.y), 0.0) + g1.x * textureLod(tex, vec2(h1.x, h0.y), 0.0))
		+ g1.y * (g0.x * textureLod(tex, vec2(h0.x, h1.y), 0.0) + g1.x * textureLod(tex, vec2(h1.x, h1.y), 0.0));
}

vec4 sample_liquid(vec2 uv) {
	return point_grid > 0.5 ? textureLod(liquid, uv, 0.0) : sample_smooth(liquid, uv);
}

// Per pixel every sheet reads smoothly (Dino's shots 6 Nov: the steep brook at x 54101 z 69709 is drawn by chunk sheets, not the live window, and kept its
// diamond facets). Only the vertices of a chunk sheet keep the plain reads, so its edges still meet the next sheet's; the shore, depth and white water,
// which made the diamonds, follow the smooth surface on every sheet.
// A chunk sheet's per-pixel reads blend the four texels round the point by hand (texelFetch). A 32-bit float texture is not filtered on every GPU: on
// Dave's PC the reads between texels came back nearest, so the current, the depth and everything worked out from them stepped texel by texel, and the
// ripples dragged by the current jumped at every 2 m texel edge: square panes, then a square lattice (Tyler and Dino 6 Nov 2026, x 54101 z 69709).
vec4 fetch_bilinear(sampler2D tex, vec2 uv) {
	ivec2 size = textureSize(tex, 0);
	vec2 p = uv * vec2(size) - 0.5;
	vec2 f = fract(p);
	ivec2 i0 = clamp(ivec2(floor(p)), ivec2(0), size - 1);
	ivec2 i1 = clamp(i0 + ivec2(1), ivec2(0), size - 1);
	vec4 a = mix(texelFetch(tex, i0, 0), texelFetch(tex, ivec2(i1.x, i0.y), 0), f.x);
	vec4 b = mix(texelFetch(tex, ivec2(i0.x, i1.y), 0), texelFetch(tex, i1, 0), f.x);
	return mix(a, b, f.y);
}

vec4 sample_pixel(vec2 uv) {
	return point_grid > 0.5 ? fetch_bilinear(liquid, uv) : sample_smooth(liquid, uv);
}

// The least depth that still draws: 4 mm for slow water, half a millimetre where it runs fast (a fall face, a chute).
float wet_min(vec4 t) {
	return mix(0.004, 0.0005, smoothstep(0.6, 2.0, length(t.gb)));
}

void vertex() {
	// UV across the window: the plane spans the texture exactly (texel centres on the sim cells).
	tex_uv = point_grid > 0.5 ? (vec2(0.5) + UV * (cells - vec2(1.0))) / cells : UV;
	vec4 t = sample_liquid(tex_uv);
	depth_v = t.a;
	flow_v = t.gb;
	// Dry ground: the sheet tucks under the bed, so it never floats over a dry channel; the per-pixel fade hides the seam. Fast water counts as wet when
	// much thinner (down a fall the sim's water runs fast and only millimetres deep: Dave 2 Nov 2026, "no water coming down the waterfalls at all").
	VERTEX.y = t.a > wet_min(t) ? t.r : t.r - 0.4;
	// The live window has only its 8 m cells: thin running water (a brook down a hillside, 10 to 30 cm) is lifted a little so the ground's bumps between
	// cells do not break it into puddles (Dave 3 Nov 2026: "need to be close enough together to overlap so they don't show ground"); the soft contact fade
	// hides where it meets the bank. Chunk sheets are laid on the ground at 2 m instead (_lay_fine).
	if (point_grid < 0.5 && t.a > wet_min(t)) {
		VERTEX.y += thin_lift * (1.0 - smoothstep(0.15, 0.5, t.a));
	}
	// A chunk sheet's running water is laid on the ground at 2 m (_lay_fine), 4 cm over it, but the ground the player sees is its own mesh: between the
	// points the sheet's flat triangles went in and out of the bumps, so a steep brook showed as separate flat panes with straight edges (Dino's shots
	// 6 Nov, x 54101 z 69709, the "diamond shaped squares" Dave saw). Running water is lifted chunk_lift clear of the bumps; the contact fade hides the
	// lift at the banks. Still water (ponds, lakes) keeps its level.
	if (point_grid > 0.5 && t.a > wet_min(t)) {
		VERTEX.y += chunk_lift * smoothstep(0.3, 1.0, length(t.gb));
	}
}

// An integer hash of the noise cell (Tyler and Dino 6 Nov 2026, the steep brook at x 54101 z 69709: panes, then tiles, then straight "cracked ice"
// lines that turned with the noise). Float hashes of the world's big coordinates (a cell number near 40,000) lose their low bits, and the GPU rounds
// the same corner differently from the two cells that share it, so the noise jumped at every cell edge: the ripples and foam came in tiles with hard
// borders. Integers hash exactly, whatever the coordinates.
float hash(vec2 p) {
	uint qx = uint(int(floor(p.x))) * 1597334673u;
	uint qy = uint(int(floor(p.y))) * 3812015801u;
	uint n = (qx ^ qy) * 1597334673u;
	n ^= n >> 16u;
	return float(n >> 8u) / 16777216.0;
}

// Quintic blend between the cells (was the cubic smoothstep): the ripples' normals come from this noise's slope, and the cubic's slope creased along
// every cell edge, which a strong chop showed as a checkerboard of 0.5 to 1 m tiles on a fast brook (Tyler and Dino 6 Nov 2026, x 54101 z 69709).
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The live window's share of the water at a point `d_m` metres inside the window's edge: 0 at the edge, 1 from blend_m + blend_wander_m in.
// Sin-free hash so the band is the same on every GPU at large world coordinates (the same text is in water_material.gd).
float blend_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float live_blend(float d_m, vec2 world) {
	vec2 p = world / 37.0;
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(blend_hash(i), blend_hash(i + vec2(1.0, 0.0)), u.x), mix(blend_hash(i + vec2(0.0, 1.0)), blend_hash(i + vec2(1.0, 1.0)), u.x), u.y);
	return smoothstep(0.0, blend_m, d_m - n * blend_wander_m);
}

// The fine sheet's share at a point d_m metres inside its rectangle: 0 at the edge, 1 from FINE_BAND_M plus up to FINE_WANDER_M in.
// An 8 m sheet takes 1 minus this, so the two always add up and the meeting line wanders (BUG-006).
const float FINE_BAND_M = 6.0;
const float FINE_WANDER_M = 2.0;

float fine_blend(float d_m, vec2 world) {
	vec2 p = world / 9.0;
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(blend_hash(i), blend_hash(i + vec2(1.0, 0.0)), u.x), mix(blend_hash(i + vec2(0.0, 1.0)), blend_hash(i + vec2(1.0, 1.0)), u.x), u.y);
	return smoothstep(0.0, FINE_BAND_M, d_m - n * FINE_WANDER_M);
}

// An 8 m sheet's share against the fine sheets: 1 outside them, 0 well inside.
float coarse_share(vec2 world) {
	float share = 1.0;

	for (int n = 0; n < fine_count && n < 8; n++) {
		vec4 r = fine_holes[n];
		vec2 inside = world - r.xy;
		float d_in = min(min(inside.x, inside.y), min(r.z - inside.x, r.w - inside.y));

		if (d_in > 0.0) {
			share = min(share, 1.0 - fine_blend(d_in, world));
		}
	}

	return share;
}

// How strongly the live sheet draws a texel's water (its discard and its shore fade in fragment below), so a chunk sheet takes the rest.
float live_draws(vec4 t) {
	if (t.a < wet_min(t)) {
		return 0.0;
	}

	return max(smoothstep(0.0, edge_m, t.a), smoothstep(0.6, 2.0, length(t.gb)) * smoothstep(0.0005, 0.004, t.a));
}

// How fully the live sheet covers a point: the least of live_draws here and one live cell to each side. The live sheet tucks under the bed at its first
// dry cell, so over the last cell before it the water it draws is under the ground; a chunk sheet that gave way there left a straight strip of bare
// bed between the two sheets along a live block's edge (Dave 6 Nov 2026, x 52986 z 68328: "here is another weird line"). Now the chunk sheet keeps
// drawing up to a cell into the live water, so the two overlap there instead of leaving a gap.
float live_cover(vec2 uv) {
	vec2 px = vec2(1.0) / vec2(textureSize(live, 0));
	float c = live_draws(textureLod(live, uv, 0.0));
	c = min(c, live_draws(textureLod(live, uv + vec2(px.x, 0.0), 0.0)));
	c = min(c, live_draws(textureLod(live, uv - vec2(px.x, 0.0), 0.0)));
	c = min(c, live_draws(textureLod(live, uv + vec2(0.0, px.y), 0.0)));
	return min(c, live_draws(textureLod(live, uv - vec2(0.0, px.y), 0.0)));
}

// Small waves: two octaves, as a height for the normal.
// The two octaves are turned against each other and against the world's axes, so no cell grid lines up.
float waves(vec2 p) {
	return noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p) * 0.65 + noise(mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * p * 2.3 + 7.1) * 0.35;
}

void fragment() {
	vec4 t = sample_pixel(tex_uv);   // per pixel: the shore follows the depth between cells, not the cell edges (smoothly in the live window)
	float depth = t.a;

	if (depth < wet_min(t)) {
		discard;
	}

	vec2 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;

	float chunk_share = 1.0;   // a chunk sheet gives way to the live window across the blend band (BUG-006)

	if (hole.z > 0.0) {
		vec2 inside = world - hole.xy;
		float d_in = min(min(inside.x, inside.y), min(hole.z - inside.x, hole.w - inside.y));

		if (d_in > 0.0) {
			chunk_share = 1.0 - live_blend(d_in, world) * (has_live > 0.5 ? live_cover(inside / hole.zw) : 1.0);

			if (chunk_share < 0.002) {
				discard;
			}
		}
	}

	float fine_share = fine_sheet > 0.5 ? 1.0 : coarse_share(world);

	if (fine_share < 0.002) {
		discard;
	}

	// A still pond in the sim still sloshes at a few cm/s, and a block at rest reads exactly 0: below CALM_MS the water counts as still, so the look does
	// not step at the sim's 128 m block edges (PR #91 pond shot, 2 Nov 2026: dark rectangles in a light pond).
	vec2 vel = t.gb;

	// A chunk sheet's look follows the current averaged over about 12 m, not the current at the pixel (Tyler and Dino 6 Nov 2026, the steep brook at
	// x 54101 z 69709): the ripples are dragged by the current, so where it changed from texel to texel (a fast steep brook, and the 2 m texels' blend
	// creases along every row and column) the dragged pattern tore along the texel grid, a lattice of squares, and the foam and chop followed it.
	if (point_grid > 0.5) {
		vec2 reach = vec2(3.0) / cells;
		vel = (vel + sample_pixel(tex_uv + vec2(reach.x, 0.0)).gb + sample_pixel(tex_uv - vec2(reach.x, 0.0)).gb
			+ sample_pixel(tex_uv + vec2(0.0, reach.y)).gb + sample_pixel(tex_uv - vec2(0.0, reach.y)).gb) / 5.0;
	}

	float raw_speed = length(vel);
	vel *= smoothstep(0.15, 0.45, raw_speed);
	float speed = length(vel);

	// Flow map: the ripple pattern is dragged downstream at the water's own speed; two copies half a cycle apart cross-fade so it never stretches.
	float cycle = 2.0;
	float ph0 = fract(TIME / cycle);
	float ph1 = fract(TIME / cycle + 0.5);
	float mixk = abs(1.0 - 2.0 * ph0);
	// The ripples are dragged at most 1.5 m/s: on a steep brook the current runs at several m/s and changes fast from point to point, and dragging the
	// pattern that hard squeezed it into a mottled, frosted look instead of ripples (Tyler 6 Nov 2026).
	vec2 drift = vel * min(1.0, 1.5 / max(speed, 0.001)) * cycle;
	vec2 p0 = world / 1.6 - drift * ph0 / 1.6;
	vec2 p1 = world / 1.6 - drift * ph1 / 1.6 + 3.7;
	float e = 0.15;
	float h0 = waves(p0);
	float h1 = waves(p1);
	float hx = mix(waves(p0 + vec2(e, 0.0)), waves(p1 + vec2(e, 0.0)), mixk) - mix(h0, h1, mixk);
	float hz = mix(waves(p0 + vec2(0.0, e)), waves(p1 + vec2(0.0, e)), mixk) - mix(h0, h1, mixk);
	// Faster water is choppier; still water nearly glassy.
	float chop = 0.08 + 0.17 * smoothstep(0.3, 2.5, speed);   // at most a river's chop (was up to 0.58: a fast brook's ripples tiled, Tyler 6 Nov 2026)
	vec3 n_world = normalize(vec3(-hx / e * chop, 1.0, -hz / e * chop));

	// Rain: each 0.6 m cell gets a drop now and then (more cells as the rain grows); its ring spreads and fades in under a second.
	if (rain > 0.01) {
		vec2 rp = world / 0.6;
		vec2 rc = floor(rp);
		vec2 centre = vec2(hash(rc + 1.7), hash(rc + 9.2)) * 0.6 + 0.2;
		float phase = fract(TIME * 1.3 + hash(rc + 4.4));
		vec2 off = (fract(rp) - centre) * 0.6;
		float r = length(off);
		float front = phase * 0.28;
		// A soft ring (no fine sine: it aliased into bright bricks at a distance, Dave 2 Nov 2026), faded out beyond 25 m where it cannot be seen.
		float dr = (r - front) / 0.035;
		float ring = -dr * exp(-dr * dr) * (1.0 - phase);
		float drops = step(hash(rc + floor(TIME * 1.3 + hash(rc + 4.4)) * 0.37), rain);
		float near_eye = 1.0 - smoothstep(8.0, 25.0, length(VERTEX));
		n_world = normalize(n_world + vec3(off.x, 0.0, off.y) / max(r, 0.001) * ring * drops * 0.35 * near_eye);
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// How much water the eye looks through to the ground behind (the scene's depth): soft where the sheet meets the bank, deeper colour where the
	// view runs a long way through the water.
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float through = max(VERTEX.z - behind.z, 0.0);
	// A chunk sheet's running water is lifted chunk_lift over the ground (vertex), so the eye looks through only that gap, and the gap followed how the
	// sheet's flat 2 m quads sat over the ground's own triangles: the colour and the see-through changed quad by quad, square panes with dark edges
	// where the ground came close (Tyler's water-debug run 6 Nov 2026, x 54101 z 69709: one smooth 2 m sheet, the panes were its quads). Over running
	// water the gap is taken from the water's own depth plus the lift instead, smooth across the quads.
	float lifted = point_grid > 0.5 ? smoothstep(0.3, 1.0, length(t.gb)) * smoothstep(0.0, 0.05, depth) : 0.0;
	through = mix(through, depth + chunk_lift, lifted);
	float contact = smoothstep(0.0, contact_m, through);

	// Colour by depth, a sky reflection by angle.
	// The cloud after rain clears on its own curve, running water faster than still (water_look_after_rain.md 1).
	float mud_here = look_v2 > 0.5 ? max(mud, mix(turbid.y, turbid.x, smoothstep(0.1, 0.5, speed))) : mud;
	float thick = 1.0 - exp(-min(through, depth * 3.0 + 0.2) / (clear_m * (1.0 - 0.6 * look_v2 * mud_here)));
	vec3 water = mix(mix(shallow_color, deep_color, thick), mud_color * (1.0 - 0.4 * thick), mud_here * 0.8);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	// Foam where it runs fast and shallow (rapids, the lip and foot of a fall), streaked along the flow.
	float streak = mix(noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p0 * 2.5), noise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p1 * 2.5), mixk);
	float rough = clamp((speed - 0.9) / 2.5, 0.0, 1.0) * clamp(1.0 - depth / 2.0, 0.0, 1.0);   // BUG-010: white from 0.9 m/s (was 1.2)
	// White water needs a jump: the Froude number, not the speed alone (water_look_after_rain.md 3): waves with little white below
	// about 1.7, white crests from 2, a full roller from 4.5. A deep fast river stays dark and smooth.
	float froude = speed / sqrt(9.81 * max(depth, 0.02));
	if (look_v2 > 0.5) {
		rough = smoothstep(1.5, 4.5, froude);
	}
	// In streaks over about half the surface, not all of it (Tyler 6 Nov 2026: once the noise worked at the world's coordinates, a fast shallow brook
	// came out white all over, "like snow"; the broken old noise had hidden how strong this was).
	float foam = smoothstep(0.6, 0.9, streak + rough * 0.15) * rough * 0.7;
	// Lapping at the bank: a broken foam line that comes and goes where the water thins against the ground.
	float lap = (1.0 - smoothstep(0.05, lap_m, through)) * smoothstep(0.55, 0.9, 0.5 + 0.5 * sin(TIME * 1.1 + noise(world * 0.35) * 9.0)) * noise(world * 1.3 + TIME * 0.2);
	foam = max(foam, lap * 0.7);
	// Falls: where the surface itself drops steeply (only between wet texels; a shore texel's level is the bank), the water turns white, in long
	// streaks that pour down the face, faster than the river above.
	vec2 px = vec2(1.0) / cells;
	// The slope from smooth reads too: bilinear differences step at every cell, so the white water came in diamond patches down a steep brook.
	vec4 ex0 = sample_pixel(tex_uv - vec2(px.x, 0.0));
	vec4 ex1 = sample_pixel(tex_uv + vec2(px.x, 0.0));
	vec4 ez0 = sample_pixel(tex_uv - vec2(0.0, px.y));
	vec4 ez1 = sample_pixel(tex_uv + vec2(0.0, px.y));
	vec2 grad = vec2(
		min(ex0.a, ex1.a) > 0.0005 ? (ex1.r - ex0.r) / (2.0 * cell_m) : 0.0,
		min(ez0.a, ez1.a) > 0.0005 ? (ez1.r - ez0.r) / (2.0 * cell_m) : 0.0);
	float drop = length(grad);
	// Foam lines (water_look_after_rain.md 4): flecks riding the flow that gather on the seam between fast and slow water, where the
	// speed changes most from cell to cell, white where fresh and tan where old in slow water; more in autumn and after rain. None on still water.
	float foam_line = 0.0;
	float foam_age = 0.0;
	if (look_v2 > 0.5 && speed > 0.05) {
		float shear = (abs(length(ex1.gb) - length(ex0.gb)) + abs(length(ez1.gb) - length(ez0.gb))) / (2.0 * cell_m);
		float seam = smoothstep(0.06, 0.25, shear) * smoothstep(0.08, 0.3, speed) * (1.0 - smoothstep(1.5, 3.0, speed));
		float fleck = mix(noise(p0 * 4.0 + 11.0), noise(p1 * 4.0 + 11.0), mixk) * 0.7 + mix(noise(p0 * 9.0 + 3.0), noise(p1 * 9.0 + 3.0), mixk) * 0.3;
		foam_line = seam * smoothstep(0.58, 0.78, fleck) * foam_supply * 0.65;
		foam_age = 1.0 - smoothstep(0.3, 1.5, speed);
	}
	float fall = smoothstep(0.55, 1.1, drop);   // from about 30 degrees (was 20: with the noise fixed, a steep brook at x 54101 z 69709 read as snow, Tyler 6 Nov 2026)

	if (fall > 0.01) {
		// Dave 2 Nov 2026: no lines. Churning white water: round billows (no stretched streaks) that tumble downhill.
		vec2 down = -grad / max(drop, 0.0001);
		mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));   // off the world's axes (see waves)
		down = turn * down;
		vec2 c = turn * world * 0.7 - down * TIME * 2.2;
		float churn = noise(c) * 0.55 + noise(c * 2.1 + 5.3 - down * TIME * 1.3) * 0.3 + noise(c * 4.3 + 1.7) * 0.15;
		foam = max(foam, fall * smoothstep(0.1, 0.85, churn));   // soft-edged billows (hard-edged ones read as white tiles down a steep brook)
	}

	// The shore: the sheet thins out with the water; the window's edge fades to the grid look.
	vec2 in_cells = tex_uv * cells;
	float in_edge_m = min(min(in_cells.x, in_cells.y), min(cells.x - in_cells.x, cells.y - in_cells.y)) * cell_m;
	float edge = fine_sheet > 0.5 ? fine_blend(in_edge_m, world) : (fade_cells > 0.0 ? live_blend(in_edge_m, world) : chunk_share) * fine_share;
	// A thin fast sheet (a fall face) is not a shore: it shows at full strength from a few millimetres.
	float shore = max(smoothstep(0.0, edge_m, depth), smoothstep(0.6, 2.0, raw_speed) * smoothstep(0.0005, 0.004, depth));

	vec3 foam_tint = foam_color;
	if (foam_line > foam) {
		foam_tint = mix(foam_color, vec3(0.78, 0.70, 0.55), foam_age);
		foam = foam_line;
	}
	ALBEDO = mix(mix(water, sky_color, fresnel * 0.6), foam_tint, foam);
	EMISSION = foam_tint * foam * 0.15 * daylight;
	ROUGHNESS = 0.06 + 0.35 * foam;
	SPECULAR = 0.5;
	// Dave's QA list BUG-010 (3 Nov 2026): river and fall water read almost invisible. Running water is stirred up and catches the light, so it
	// gets body with its speed; a fall face is near opaque. Still water keeps the clear look of the art direction (you see the bed).
	float running = 0.75 * smoothstep(0.5, 2.0, speed) * smoothstep(0.05, 0.4, depth);
	ALPHA = clamp(max(max(0.35 + 0.6 * thick, running), max(foam, fall * 0.85)), 0.0, 1.0) * shore * edge * contact;

	// Frozen water (docs/design/frozen_water_look.md). Where: the shallows first (shore cover under 0.3 m, the deep cover from 2 m); a sheet only on water
	// under 0.5 m/s (USACE), border ice along the bank up to 0.9 m/s, open water above and on falls; none within a spring's open length. Look: black
	// skim under 2.5 cm (cover 0.125), grey film to 10 cm, a grey-white solid sheet from 10 cm (bears: you need a hole); snow on 5 cm or more, slush
	// on thinner; in a thaw the shore moat opens first and the sheet greys. Flat and still: no ripples, foam or rain rings on ice.
	float ice_sheet = 0.0;

	if (frozen_on > 0.5 && max(ice_look.x, ice_look.y) > 0.001) {
		float shallow = 1.0 - smoothstep(0.3, 2.0, depth);
		float ice_here = mix(ice_look.x, max(ice_look.x, ice_look.y), shallow);
		float slow = 1.0 - smoothstep(0.3, 0.5, raw_speed);
		float border = (1.0 - smoothstep(0.5, 0.9, raw_speed)) * (1.0 - smoothstep(0.15, 0.15 + 1.5 * ice_here, depth));
		ice_here *= max(slow, border) * (1.0 - fall);

		for (int i = 0; i < ice_spring_count; i++) {
			// Open within the spring's reach, then the ice at half thickness for 30 m past it (Jamie #739: thin ice within 10 to 30 m of a
			// spring mouth or inflow) before it reaches its full cover.
			float r = max(ice_springs[i].z, 1.0);
			float ds = distance(world, ice_springs[i].xy);
			ice_here *= smoothstep(0.95 * r, r, ds) * mix(0.5, 1.0, smoothstep(r, r + 30.0, ds));
		}

		float thaw = ice_look.z;
		float moat = thaw > 0.02 ? 1.0 - smoothstep(1.6 * thaw, 1.6 * thaw + 0.3, depth) : 0.0;
		float ice_patch = noise(world / 7.0 + 3.7);
		float grown = ice_here * 1.25 + shallow * 0.5 * (1.0 - thaw) - ice_patch * 0.5 - 0.05;
		float sheet = smoothstep(0.0, 0.25, grown) * step(0.002, ice_here) * (1.0 - moat);

		// Holes: open dark water inside, a ragged rim of white chips, loose chips round it; a black skin grows back over the last sixth of its life.
		float hole_open = 0.0;
		float chips = 0.0;

		for (int i = 0; i < ice_hole_count; i++) {
			float r = ice_holes[i].z;
			float d = distance(world, ice_holes[i].xy) * (1.0 + 0.12 * (noise(world * 9.0) - 0.5));
			float skin = smoothstep(5.0 / 6.0, 1.0, ice_holes[i].w);
			hole_open = max(hole_open, (1.0 - smoothstep(0.9 * r, r, d)) * (1.0 - skin) * step(0.002, ice_here));   // a fishing hole, or skim broken by a wader (ice_walk_feel.md)
			chips = max(chips, smoothstep(r, 1.05 * r, d) * (1.0 - smoothstep(1.3 * r, 1.6 * r, d)) * step(0.35, noise(world * 14.0))
				+ (1.0 - smoothstep(1.6 * r, 2.2 * r, d)) * step(1.6 * r, d) * step(0.78, noise(world * 11.0 + 5.1)));
		}

		chips *= step(0.125, ice_here);   // skim leaves no chips, only open water
		sheet *= 1.0 - hole_open;
		float cm = ice_here * 20.0;
		float grey = smoothstep(2.0, 3.0, cm);              // black skim to grey film at 2.5 cm
		float solid = smoothstep(9.0, 11.0, cm);            // grey film to the solid sheet at 10 cm
		float cr1 = 1.0 - smoothstep(0.0, 0.03, abs(noise(world / 3.1) - 0.5));
		float cr2 = 1.0 - smoothstep(0.0, 0.05, abs(noise(world / 1.1 + 9.0) - 0.5));
		float cracks = clamp(cr1 + 0.5 * cr2 * grey, 0.0, 1.0);
		vec3 black = water * 0.45 + sky_color * 0.08;
		vec3 ice_col = mix(black, vec3(0.58, 0.64, 0.68) * mix(0.9, 1.08, noise(world / 1.7)), grey);
		ice_col = mix(ice_col, vec3(0.80, 0.85, 0.88), solid);
		ice_col = mix(ice_col, mix(vec3(0.86, 0.90, 0.93), vec3(0.42, 0.47, 0.50), solid), cracks * 0.6);   // white cracks in clear ice, darker in white
		float rim = (1.0 - smoothstep(0.02, 0.15, depth)) * (1.0 - grey) * (1.0 - thaw);   // frost crystals where the skim meets the bank
		ice_col = mix(ice_col, vec3(0.88, 0.91, 0.94), rim * 0.8);
		ice_col = mix(ice_col, vec3(0.42, 0.46, 0.48), 0.7 * thaw * grey);                   // rotten, wet grey
		// Snow lies on 5 cm or more, in drifts across the wind; on thinner ice it turns to grey slush.
		float drift = noise(vec2(world.x * 0.18, world.y * 0.45) + 1.3);
		float snow = smoothstep(0.35, 0.6, ice_look.w + 0.45 * drift - 0.3) * smoothstep(4.0, 6.0, cm);
		float slush = smoothstep(0.2, 0.5, ice_look.w) * (1.0 - smoothstep(4.0, 6.0, cm)) * smoothstep(0.45, 0.6, drift);
		ice_col = mix(ice_col, vec3(0.55, 0.58, 0.60), slush * 0.8);
		ice_col = mix(ice_col, vec3(0.92, 0.94, 0.96), snow);
		ice_col = mix(ice_col, vec3(0.90, 0.92, 0.94), chips);
		float lit = mix(0.55, 1.0, daylight);
		float glint = (1.0 - snow) * (1.0 - grey * 0.6) * fresnel;
		ALBEDO = mix(ALBEDO, mix(ice_col * lit, sky_color, glint * 0.5), sheet);
		ALBEDO = mix(ALBEDO, ALBEDO * 0.5, hole_open);
		EMISSION = mix(EMISSION, vec3(0.0), max(sheet, hole_open));
		ROUGHNESS = mix(ROUGHNESS, mix(mix(0.06, 0.35, solid), 0.9, max(snow, chips)) * mix(1.0, 0.4, thaw), sheet);
		SPECULAR = mix(SPECULAR, mix(0.8, 0.3, max(snow, solid)), sheet);
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, max(sheet, hole_open) * 0.95));
		ALPHA = max(ALPHA, max(sheet * mix(0.6, 0.98, max(grey * 0.6 + solid * 0.4, max(snow, rim))), chips) * shore * edge);
		ice_sheet = sheet;
	}

	// From under the water (Dave 2 Nov 2026: "being under the water looking up looks fake"): the surface is a mirror of the dark water
	// below, except a round window overhead (Snell's window, about 49 degrees from the vertical) where the sky shows, bent and shaken by
	// the ripples, with a bright ring at its rim. The fog (the water itself) dims it with distance.
	if (!FRONT_FACING) {
		vec3 ray = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
		float c = clamp(dot(ray, n_world), 0.0, 1.0);
		float window = smoothstep(0.62, 0.70, c) * (1.0 - 0.85 * ice_sheet);   // under a sheet of ice the sky hardly shows
		float rim = exp(-pow((c - 0.67) / 0.035, 2.0));
		vec3 overhead = sky_color * mix(0.8, 1.3, smoothstep(0.7, 1.0, c)) * (0.85 + 2.5 * length(n_world.xz));
		vec3 below_col = mix(deep_color * 0.5, overhead, window) + vec3(0.85, 0.95, 1.0) * rim * 0.3;
		below_col = mix(below_col, foam_color * 0.85, foam * 0.6);
		ALBEDO = vec3(0.0);
		EMISSION = below_col * mix(0.12, 1.0, daylight);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = mix(0.96, 0.82, window) * shore * edge;
	}

	// Which sheet draws a spot, and its texels (Tyler 6 Nov 2026: square see-through panes with dark borders in the brook at x 54101 z 69709).
	if (debug_sheet > 0.5) {
		vec2 grid = point_grid > 0.5 ? tex_uv * cells - 0.5 : tex_uv * cells;   // a chunk sheet: lines through its grid points (the mesh quads), the live window: its cell squares
		vec2 to_line = min(fract(grid), 1.0 - fract(grid)) / max(fwidth(grid), vec2(0.0001));
		float line = 1.0 - smoothstep(0.5, 1.5, min(to_line.x, to_line.y));
		vec3 sheet = point_grid < 0.5 ? vec3(0.9, 0.1, 0.8) : (cell_m < 4.0 ? vec3(0.95, 0.85, 0.1) : vec3(0.95, 0.45, 0.05));
		// The sheet's own geometry (Tyler 6 Nov 2026: the panes are in the water drawing, not the ground): shaded by the triangle's real slope, so a step or
		// wall in the sheet shows dark; seen from behind (a fold) red; where the fall white water switches on, cyan.
		vec3 world3 = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 geo = normalize(cross(dFdy(world3), dFdx(world3)));
		sheet *= mix(0.25, 1.0, abs(geo.y));
		sheet = mix(sheet, vec3(0.1, 0.85, 0.9), 0.6 * fall);
		sheet *= 0.75 + 0.25 * sin(raw_speed * 6.0);   // bands of the current's speed: smooth curves if the reads blend, squares if they step
		sheet = FRONT_FACING ? sheet : vec3(0.9, 0.05, 0.05);
		ALBEDO = mix(sheet * mix(0.6, 1.0, clamp(depth, 0.0, 1.0)), vec3(0.05), line);
		EMISSION = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 0.9 * (point_grid > 0.5 ? chunk_share : edge);
	}
}
"""

const FINE_SUB := 4             # water_grid.gd FINE_SUB: a fine cell carries (FINE_SUB + 1)^2 surface heights over its 8 m square
const CHUNK_STEP_M := 8.0       # vertex spacing of a chunk sheet (many of them stand at once): one vertex per grid point, the shore and colour are per pixel anyway
const SHORE_DEPTH_M := 0.3      # a chunk sheet's depth at wet points next to the shore (no ground on the client): it thins to 0 at the shore point
const OPEN_DEPTH_M := 1.0       # and further in

static var _shader: Shader = null

static var debug_on: int = -1   # -1: not read yet (then --water-debug on the command line turns it on)

# Frozen water (docs/design/frozen_water_look.md): the numbers every sheet draws its ice from, kept here so a sheet made later starts
# with them (no flash of open water on a frozen pond while it waits for the next update).
static var _ice_on: bool = false
static var _ice_look: Vector4 = Vector4.ZERO
static var _ice_springs: PackedVector4Array = PackedVector4Array()
static var _ice_holes: PackedVector4Array = PackedVector4Array()

var _material: ShaderMaterial = null
var _cells: Vector2i = Vector2i.ZERO
var _step_m: float = SHEET_STEP_M


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER

	_material = ShaderMaterial.new()
	_material.shader = _shader

	if debug_on < 0:
		debug_on = 1 if AppConfig.has_flag("water-debug") else 0

	_material.set_shader_parameter("debug_sheet", float(debug_on))
	_apply_ice()
	visible = false


# The debug colours (see debug_sheet in the shader), for this sheet and every one made after.
func set_debug(on: bool) -> void:
	debug_on = 1 if on else 0
	_material.set_shader_parameter("debug_sheet", float(debug_on))


# A chunk's settled water (water_grid.gd decode: count x count points `spacing` apart from the chunk's corner) as a liquid image: R surface, G/B the current,
# A a depth stand-in (the client has no ground here): OPEN_DEPTH_M inside, SHORE_DEPTH_M next to a dry point, 0 on shore and dry points. Shore points
# (`edge`) carry their own level; dry points take the mean of their wet neighbours' levels so the sheet tucks under the bank there. null when dry.
static func image_from_grid(grid: Dictionary) -> Image:
	var count: int = int(grid.get("count", 0))
	var levels: PackedFloat32Array = grid.get("levels", PackedFloat32Array())

	if count < 2 or int(grid.get("wet", 0)) == 0 or levels.size() != count * count:
		return null

	var edge: PackedFloat32Array = grid.get("edge", PackedFloat32Array())
	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())
	var im: Image = Image.create(count, count, false, Image.FORMAT_RGBAF)

	for j in range(count):
		for i in range(count):
			var n: int = j * count + i
			var level: float = levels[n]

			if not is_nan(level):
				var open: bool = true

				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var a: int = i + d.x
					var b: int = j + d.y

					if a >= 0 and b >= 0 and a < count and b < count and is_nan(levels[b * count + a]):
						open = false

				var vx: float = vel[n * 2] if vel.size() == levels.size() * 2 else 0.0
				var vz: float = vel[n * 2 + 1] if vel.size() == levels.size() * 2 else 0.0
				im.set_pixel(i, j, Color(level, vx, vz, OPEN_DEPTH_M if open else SHORE_DEPTH_M))
				continue

			var near: float = 0.0
			var seen: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var a: int = i + di
					var b: int = j + dj

					if a >= 0 and b >= 0 and a < count and b < count and not is_nan(levels[b * count + a]):
						near += levels[b * count + a]
						seen += 1

			var here: float = edge[n] if not edge.is_empty() and not is_nan(edge[n]) else (near / float(seen) - 0.4 if seen > 0 else -1000.0)
			im.set_pixel(i, j, Color(here, 0.0, 0.0, 0.0))

	_paint_falls(im, grid, count)
	return _lay_fine(im, grid, count)


# Running water on the real ground (Dave 3 Nov 2026: a brook on a steep hillside showed as separate puddles with clay and grass between them). The
# server lays running water on the ground at 2 m (water_grid.gd _fine_cells: (FINE_SUB + 1)^2 surface heights per 8 m cell, ground + water + 4 cm),
# but the liquid sheet only took the 8 m levels, so a thin stream between two points ran under the ground where it bulged and floated where it dipped.
# With any fine cell the image is FINE_SUB times finer: everything is first spread bilinearly from the 8 m points, then each fine cell's own heights
# replace the surface over its square (the shore fade and the current stay the spread ones).
static func _lay_fine(coarse: Image, grid: Dictionary, count: int) -> Image:
	var fine: Dictionary = grid.get("fine", {})

	if fine.is_empty():
		return coarse

	var sub: int = FINE_SUB
	var side: int = (count - 1) * sub + 1
	var im: Image = Image.create(side, side, false, Image.FORMAT_RGBAF)

	for b in range(side):
		@warning_ignore("integer_division")
		var j: int = mini(b / sub, count - 2)
		var v: float = float(b - j * sub) / float(sub)

		for a in range(side):
			@warning_ignore("integer_division")
			var i: int = mini(a / sub, count - 2)
			var u: float = float(a - i * sub) / float(sub)
			var c00: Color = coarse.get_pixel(i, j)
			var c10: Color = coarse.get_pixel(i + 1, j)
			var c01: Color = coarse.get_pixel(i, j + 1)
			var c11: Color = coarse.get_pixel(i + 1, j + 1)
			im.set_pixel(a, b, c00.lerp(c10, u).lerp(c01.lerp(c11, u), v))

	var fside: int = sub + 1

	for cell in fine:
		var heights: PackedFloat32Array = fine[cell]

		if heights.size() != fside * fside:
			continue

		var ci: int = int(cell) % count
		@warning_ignore("integer_division")
		var cj: int = int(cell) / count

		for b in range(fside):
			for a in range(fside):
				var x: int = ci * sub + a
				var y: int = cj * sub + b
				var px: Color = im.get_pixel(x, y)
				px.r = heights[b * fside + a]
				im.set_pixel(x, y, px)

	_soften_steps(im, side)
	return im


# Where an 8 m cell laid on the ground (fine) meets one that is not, the surface stepped by up to a metre at the cell's edge, and a steep brook showed
# square panes with straight edges (Dino's shots of #465, 6 Nov 2026, x 54101 z 69709). Two passes of a 3 x 3 mean over the wet texels round off those
# steps into slopes a few metres long. The border texels stay as they are: the next chunk's sheet shares them.
const SOFTEN_PASSES := 2

static func _soften_steps(im: Image, side: int) -> void:
	for pass_index in range(SOFTEN_PASSES):
		var levels: PackedFloat32Array = PackedFloat32Array()
		levels.resize(side * side)
		var wet: PackedByteArray = PackedByteArray()
		wet.resize(side * side)

		for y in range(side):
			for x in range(side):
				var px: Color = im.get_pixel(x, y)
				levels[y * side + x] = px.r
				wet[y * side + x] = 1 if px.a > 0.0 else 0

		for y in range(1, side - 1):
			for x in range(1, side - 1):
				if wet[y * side + x] == 0:
					continue

				var sum: float = 0.0
				var count: int = 0

				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n: int = (y + dy) * side + x + dx

						if wet[n] == 1:
							sum += levels[n]
							count += 1

				var px: Color = im.get_pixel(x, y)
				px.r = sum / float(count)
				im.set_pixel(x, y, px)


# Falls (water_falls.gd chains, chunk-local points from the lip down to the pool): a fall face's grid points are dry in the settled levels, so the sheet
# tucked under the cliff and no water came down (Dave 2 Nov 2026). Each point of a chain is drawn wet at the chain's own height, running down the chain
# fast, so the sheet bends over the lip and the shader's fall white water shows on the face.
static func _paint_falls(im: Image, grid: Dictionary, count: int) -> void:
	var spacing: float = float(grid.get("spacing", 8.0))

	for fall in grid.get("falls", []):
		var points: PackedVector3Array = fall.get("points", PackedVector3Array())

		for k in range(points.size()):
			var p: Vector3 = points[k]
			var i: int = int(round(p.x / spacing))
			var j: int = int(round(p.z / spacing))

			if i < 0 or j < 0 or i >= count or j >= count:
				continue

			var ahead: Vector3 = points[mini(k + 1, points.size() - 1)] - points[maxi(k - 1, 0)]
			var run: Vector2 = Vector2(ahead.x, ahead.z).normalized() * 3.0
			var old: Color = im.get_pixel(i, j)

			if old.a < SHORE_DEPTH_M:
				im.set_pixel(i, j, Color(p.y, run.x, run.y, SHORE_DEPTH_M))


# A chunk's sheet: `corner` is the world x, z of grid point (0, 0); the texels sit on the grid points, the sheet spans them exactly (no overlap with the
# next chunk's sheet).
func show_points(im: Image, corner: Vector2, spacing: float) -> void:
	var cells: Vector2i = Vector2i(im.get_width(), im.get_height())
	var size: Vector2 = Vector2(cells - Vector2i.ONE) * spacing
	_step_m = minf(CHUNK_STEP_M, spacing)   # one vertex per texel: 2 m where running water is laid on the ground (_lay_fine), else 8 m

	if cells != _cells:
		_cells = cells
		_set_plane(size)

	position = Vector3(corner.x + size.x * 0.5, 0.0, corner.y + size.y * 0.5)
	_material.set_shader_parameter("liquid", ImageTexture.create_from_image(im))
	_material.set_shader_parameter("cells", Vector2(cells))
	_material.set_shader_parameter("fade_cells", 0.0)
	_material.set_shader_parameter("point_grid", 1.0)
	_material.set_shader_parameter("cell_m", spacing)
	visible = true


# The live window's rectangle (world corner, size): a chunk sheet does not draw there, from `inset` metres in, where the window's own sheet has faded in.
func set_hole(corner: Vector2, size: Vector2, inset: float) -> void:
	_material.set_shader_parameter("hole", Vector4(corner.x, corner.y, size.x, size.y))
	_material.set_shader_parameter("hole_inset", inset)


# A chunk sheet: the live window's texture (the one the live sheet draws), so it gives way only where the live water is drawn. null: everywhere in the hole.
func set_live(texture: Texture2D) -> void:
	_material.set_shader_parameter("live", texture)
	_material.set_shader_parameter("has_live", 1.0 if texture != null else 0.0)


func _set_plane(size: Vector2) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(int(size.x / _step_m) - 1, 1)
	plane.subdivide_depth = maxi(int(size.y / _step_m) - 1, 1)
	plane.material = _material
	mesh = plane
	# The surface heights move every publish: the bounds must hold any of them.
	custom_aabb = AABB(Vector3(-size.x * 0.5, -200.0, -size.y * 0.5), Vector3(size.x, 2400.0, size.y))


# The newest window from the server (water_flow_texture.unpack): `origin` is the world x, z of cell (0, 0).
# `texture`: the same image already uploaded (terrain_client.gd reuses one texture for every publish), else one is made here.
func show_window(im: Image, origin: Vector2, cell_m: float, texture: Texture2D = null) -> void:
	var cells: Vector2i = Vector2i(im.get_width(), im.get_height())
	var size: Vector2 = Vector2(cells) * cell_m

	if cells != _cells:
		_cells = cells
		_set_plane(size)

	# The texture covers the cells' squares: from half a cell before cell (0, 0). A PlaneMesh is centred on its node and its UV runs 0..1 from -x, -z.
	var corner: Vector2 = origin - Vector2(0.5, 0.5) * cell_m
	position = Vector3(corner.x + size.x * 0.5, 0.0, corner.y + size.y * 0.5)
	_material.set_shader_parameter("liquid", texture if texture != null else ImageTexture.create_from_image(im))
	_material.set_shader_parameter("cells", Vector2(cells))
	_material.set_shader_parameter("fade_cells", FADE_CELLS)
	_material.set_shader_parameter("cell_m", cell_m)
	visible = true


# Sullivan water: the dig regions' rectangles (Vector4 world x, z, size x, size z; at most 8). This 8 m sheet steps aside inside them.
func set_fine_holes(holes: PackedVector4Array) -> void:
	var n: int = mini(holes.size(), 8)
	var padded: PackedVector4Array = holes.slice(0, n)
	padded.resize(8)
	_material.set_shader_parameter("fine_holes", padded)
	_material.set_shader_parameter("fine_count", n)


# Sullivan water: this sheet draws one dig region's 2 m water (docs/water/fine_drawing_2m.md). Same texture form as show_window, 1 m vertices,
# thin water barely lifted (the 2 m cells follow the ground, unlike the 8 m window's), edge faded over fine_blend.
func show_fine(im: Image, origin: Vector2, cell_m: float) -> void:
	_step_m = FINE_STEP_M
	_material.set_shader_parameter("fine_sheet", 1.0)
	_material.set_shader_parameter("thin_lift", FINE_THIN_LIFT_M)
	show_window(im, origin, cell_m)


func set_mud(value: float) -> void:
	_material.set_shader_parameter("mud", value)


func set_rain(value: float) -> void:
	_material.set_shader_parameter("rain", value)


# Water after rain (docs/design/water_look_after_rain.md): on or off, the cloud after rain in running and still water, the foam supply.
func set_look(on: bool, turbid: Vector2, foam_supply: float) -> void:
	_material.set_shader_parameter("look_v2", 1.0 if on else 0.0)
	_material.set_shader_parameter("turbid", turbid)
	_material.set_shader_parameter("foam_supply", foam_supply)


func set_daylight(value: float) -> void:
	_material.set_shader_parameter("daylight", value)


# Frozen water for every liquid sheet (terrain_client._update_frozen_water): `look` is FrozenWater.look's (open, shore, thaw, snow), `springs` and
# `holes` FrozenWater's lists (8 each at most). on false: no ice drawn.
static func set_ice_all(tree: SceneTree, on: bool, look: Vector4, springs: PackedVector4Array, holes: PackedVector4Array) -> void:
	_ice_on = on
	_ice_look = look
	_ice_springs = springs
	_ice_holes = holes

	if tree != null:
		for sheet in tree.get_nodes_in_group("liquid_sheet"):
			if sheet.has_method("_apply_ice"):
				sheet._apply_ice()


func _apply_ice() -> void:
	_material.set_shader_parameter("frozen_on", 1.0 if _ice_on else 0.0)
	_material.set_shader_parameter("ice_look", _ice_look)
	_material.set_shader_parameter("ice_springs", _padded(_ice_springs))
	_material.set_shader_parameter("ice_spring_count", mini(_ice_springs.size(), 8))
	_material.set_shader_parameter("ice_holes", _padded(_ice_holes))
	_material.set_shader_parameter("ice_hole_count", mini(_ice_holes.size(), 8))


static func _padded(list: PackedVector4Array) -> PackedVector4Array:
	var out: PackedVector4Array = list.slice(0, 8)

	while out.size() < 8:
		out.append(Vector4.ZERO)

	return out
