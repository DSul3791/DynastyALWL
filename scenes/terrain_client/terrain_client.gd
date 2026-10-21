extends Node

# Terrain client (plan steps 15 and 16): connects to a terrain server,
# streams the blocks around the player and keeps them in a disk cache, and
# draws the trees and plants the server sends.
#
#   godot --path . res://scenes/terrain_client/terrain_client.tscn -- --server=127.0.0.1
#
# Options (after "--"):
#   --server=HOST     server address (default 127.0.0.1)
#   --port=N          server port (default 24600)
#   --cache-mb=N      disk cache size (default 2048)
#   --cache=DIR       cache folder (default user://terrain_cache/<world name>)
#   --frames=N        headless check: run N frames, print what arrived, quit
#   --move=M          with --frames: fly east at M m/s, 20 m above the ground
#   --fly             with --move: in flying mode (no ground is built while moving),
#                     stopping after 30 s to check the ground then loads under the player;
#                     prints when each detail level of the block under the stop point loaded
#   --swim            with --frames: 20 s in, play a scripted swim (splash, strokes, dive, surface)
#   --creatures       with --frames: 18 s in, play every creature call in every mood, then calls by zone
#   --interior        with --frames: 18 s in, go inside and use a door, a chest and furniture
#   --spear-sounds    with --frames: 18 s in, a spear sound jab, then a throw into each material
#   --gear            with --frames: wear plate and iron boots from the start (checks the gear layers on the walk)
#   --flood           with --frames: 18 s in, start 80 tool hits at once and check the voice cap sheds the farthest and quietest
#   --ui              with --frames: 18 s in, play the interface cues one every 0.5 s
#   --dig             with --frames: 20 s in, ask the server to dig a hole under the spawn
#   --water-step      with --frames: 12 s in, press + twice (the server re-settles the water)
#   --cut             with --frames: 25 s in, ask the server to cut the tree nearest the spawn
#   --walk            with --frames: 15 s in, drop to the ground, walk east for 30 s, then
#                     walk into the nearest tree, and print what happened
#   --no-block-line   blocks over the game connection only (no direct block line)
#   --wait=S          keep trying to connect for S seconds (the "play" launcher
#                     uses 120 while its own server starts)
#
# Controls (see CONTROLS.md): mouse look, W A S D, Space and Ctrl, walk WASD,
# jog double-tap W, run Shift+W, G or F fly or walk, Esc opens the options menu.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const Probe := preload("res://src/debug/frame_probe.gd")
const CompassScript := preload("res://src/client/admin_compass.gd")
const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const NpcViewScript := preload("res://src/client/npc_view.gd")
const NpcVoiceScript := preload("res://src/client/npc_voice.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")
const DialogueViewScript := preload("res://src/client/dialogue_view.gd")
const HeldItemScript := preload("res://src/client/held_item.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const WeatherScript := preload("res://src/shared/weather.gd")
const IceScript := preload("res://src/shared/ice.gd")
const OceanIceScript := preload("res://src/client/ocean_ice.gd")
const SwimScript := preload("res://src/shared/swim.gd")
const ICE_POND_DEPTH_M := 3.0           # a typical pond's depth for its freezing speed
const CoverScript := preload("res://src/shared/cover.gd")
const StanceScript := preload("res://src/client/stance.gd")
const StatusIconsScript := preload("res://src/client/status_icons.gd")
const DebugHudScript := preload("res://src/client/debug_hud.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")
const JitterTestScript := preload("res://src/debug/jitter_test.gd")
const MachineProbeScript := preload("res://src/debug/machine_probe.gd")
const GpuProbeScript := preload("res://src/debug/gpu_probe.gd")
const WeatherLookScript := preload("res://src/client/weather_look.gd")
const FaintEffectScript := preload("res://src/client/faint_effect.gd")
const FallMistScript := preload("res://src/client/fall_mist.gd")
const ShotRunnerScript := preload("res://src/debug/shot_runner.gd")
const FallGrowthScript := preload("res://src/client/fall_growth.gd")
# Shown on the HUD. Owner (2026-10-19): raise it by one with every push.
const BUILD := 540
var _npc_view: Node3D = null            # NPC bodies, for the Ctrl+N shortcut
var _npc_voice_button: Button = null
var _npc_voice: Node = null             # NPC speech (npc_voice.gd), switched in Settings
const AirBandsCheck := preload("res://src/client/air_bands.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const SkyClouds := preload("res://src/client/sky_clouds.gd")
const LookSettings := preload("res://src/client/look_settings.gd")
const KnowledgeScript := preload("res://src/client/inspection_knowledge.gd")
const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const BlockLinkScript := preload("res://src/stream/block_link.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const WaterVolume := preload("res://src/shared/water_volume.gd")
const HotbarStripScript := preload("res://src/client/hotbar_strip.gd")
const PickupFeedScript := preload("res://src/client/pickup_feed.gd")
const WaterFallsScript := preload("res://src/worldgen/runtime/water_falls.gd")
const FloraViewScript := preload("res://src/flora/flora_view.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileBakeScript := preload("res://src/admin/tile_bake_launcher.gd")
const GrassViewScript := preload("res://src/client/grass_view.gd")
const SoundStageScript := preload("res://src/client/sound_stage.gd")
const GroundMaterialScript := preload("res://src/client/ground_material.gd")
const HarvestScript := preload("res://src/client/harvest.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")

const VIEW_DISTANCE := 2048

# Quality presets (ARCHITECTURE_BUDGET.md): ground view distance, how far trees,
# shrubs and plants are drawn as a share of their full distance, and shadows.
# Low is the minimum machine (GTX 1050 class, 8 GB RAM). F2 cycles; --quality=N.
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const QUALITY_VIEW := [768, 1280, 2048, 2048]
const QUALITY_FLORA := [0.4, 0.7, 1.0, 1.0]
const QUALITY_GRASS_M := [40.0, 80.0, 120.0, 160.0]       # grass drawn this far around the player
const QUALITY_LITTER_M := [10.0, 18.0, 26.0, 34.0]       # forest litter (leaves, dead branches) under tree crowns, drawn this far
const QUALITY_LITTER_CAP := [3000, 20000, 40000, 60000]       # hard limit on litter cards drawn at once (nearest cells get them first)
const QUALITY_LITTER_AMOUNT := [0.3, 1.0, 1.5, 2.0]      # share of the litter cards per ground sample (Low: a small fraction, no branches below 0.35 chance scale)
const QUALITY_SHORE_M := [8.0, 20.0, 30.0, 40.0]         # shore pebbles and reeds drawn this far
const QUALITY_SHORE_AMOUNT := [0.3, 1.0, 1.5, 2.0]       # share of the shore cards per ground sample (Low: a few pebbles, reeds off below 1.0 per sample)
const QUALITY_GRASS_POINTS := [5, 5, 6, 7]               # ground samples per 6 m cell side
const QUALITY_GRASS_DENSITY := [1.0, 2.6, 3.0, 3.4]     # cards per ground sample, times the layers' own counts
const QUALITY_SHADOW_M := [0.0, 45.0, 60.0, 90.0]    # 0 = no shadows
const QUALITY_CACHE_MB := [1024, 4096, 10240, 10240]    # ground cache limit on disk
const FLY_SPEED := 30.0
const INCOMING_USEC := 3000           # most time a frame puts arrived chunks in the scene (one at least)
const WATER_HOLD_MSEC := 2000        # water refreshes wait this long while ground loads
const SURFACE_WAIT_MSEC := 1500       # stopped in the air: wait this long for the server to say where the ground is
const LOD_COUNT := 7
const STAGE_VIEW_M := 128            # the ground view distance in that time
const STAGE_VERTICAL := 0.25         # and this share of it up and down
const STAGE_LODS := 1                # after a stop high up only this many detail levels are built until the ground under the player has a collider
const STAGE_MIN_HEIGHT_M := 40.0      # staged only when the player is this far above the ground
const STAGE_STEP_MIN_MSEC := 600
const STILL_MSEC := 3000              # flying: ground loads again after staying still this long
# Natural speeds (Dave 2026-10-21, Tyler Report 13): walk, jog and run in m/s. The ONE place to tune them; the server
# reads effort from data/items/exertion.json effort_by_speed, so change those anchors to the same numbers.
const SPACE_WAKE_S := 1.0               # hold Space this long to wake from sleep early
const WALK_SPEED := 1.4
const FAST := 3.0                     # flying: Shift multiplier
const JOG_SPEED := 3.2
const RUN_SPEED := 6.0
# Walking camera (all tuning is here; each list is [walk, jog, run]). A footfall
# is the lowest point of the bob and the far end of the sway: left foot, camera
# down and leaning left; midway it rises back to the middle; right foot, down
# and leaning right. The bob therefore repeats every step and the sway every
# two steps.
const STEP_M := [0.75, 1.2, 2.0]         # metres per step: longer strides when faster (about 1.9, 2.7 and 3.0 steps a second at the natural speeds)
const BOB_M := [0.040, 0.052, 0.064]     # how far the camera dips at a footfall
const SWAY_M := [0.012, 0.016, 0.020]    # sideways shift at a footfall
const SWAY_DEG := [0.10, 0.13, 0.16]     # roll toward the stepping side at a footfall
const DOUBLE_TAP_MSEC := 300          # second W press within this starts jogging
const GRAVITY := 20.0
const MOUSE_SENSITIVITY := 0.002

var _tables
var net
var stream
var cache
var terrain: VoxelLodTerrain
var body: CharacterBody3D
var camera: Camera3D
var hud: Label
var _breath_label: Label             # the seconds of air left, shown with the oxygen symbol
var debug_hud = DebugHudScript.new()   # F3 or Esc > Settings: the long list of diagnostic lines; threads add lines with debug_hud.add_line(name, callable)
var _last_sound: String = ""
var _quality_buttons: Array = []         # Esc > Settings, one per tier; the active one is marked
var _last_sound_seen: Dictionary = {}
var compass                         # temporary admin compass (AdminCompass)
var sea: MeshInstance3D
var flying: bool = false
var underwater: bool = false
var _ground_quality: int = -1       # quality the ground texture array was built for
var _z_down_msec: int = -1             # when Z went down while lying (hold to sleep), -1 when not held
var _z_slept: bool = false             # the hold already asked for sleep
const SLEEP_HOLD_S := 3.0              # data/items/sleep.json hold_s
var stance = StanceScript.new()       # standing, crouching (C), sitting (X), lying (Z); client.stance.stance and its `changed` signal
var _shape: CollisionShape3D          # the player's collision capsule (resized by stance)
var jogging: bool = false             # double-tapped W; ends when W is released
var running: bool = false             # Shift held with W
var _last_w_msec: int = -1000
var _bob_phase: float = 0.0           # walking head bob
var _bob_amount: float = 0.0
var waiting_for_ground: bool = false
var _was_waiting: bool = false
var arrival_protect_until_msec: int = 0   # no fall damage report until then (Dave 2026-10-21: arriving must not hurt)
const ARRIVAL_HEIGHT_M := 0.5             # the body is set this far above the ground when the ground first appears
const ARRIVAL_PROTECT_MS := 6000
var _tint: ColorRect
var _aim_msec: int = 0
var _aim_pos: Vector3 = Vector3.ZERO
var _mode_label: Label
var status_icons                      # StatusIcons: the symbol row (brain, house, ...); other threads add with status_icons.add_icon
var test_water_step: bool = false   # headless check: press + twice 12 s in
var _water_label: Label             # the water flow rate readout, shown for 3 seconds after + or -
var _water_label_until_msec: int = 0
var _inspect_label: Label            # what the player is looking at (inspection mode)
var inspecting: bool = false
var test_clear: bool = false          # --test-clear: press Clear saved ground 12 s after the welcome
var _test_clear_done: bool = false
var test_start: Vector3 = Vector3.INF   # --start=x,y,z: put the player there (tests)
var _test_probe_msec: int = 0
var test_dump: bool = false           # --dump-test: 14 s after the welcome dump the ground under the feet (prints the dump)
var _test_dump_done: bool = false
var menu_open: bool = false          # the Esc options menu
var _menu: Control
var _menu_pages: Dictionary = {}     # page name -> VBoxContainer
var _menu_note: Label
var knowledge = KnowledgeScript.new()   # what this character knows (placeholder stats)
var test_inspect: bool = false       # --inspect: start with inspection on and print what it names
var _last_inspected: String = ""
var _inspect_msec: int = 0
var _environment: Environment
var pitch: float = 0.0
var frames_left: int = -1
var test_speed: float = 0.0
var _surface_asked_msec: int = 0      # stopped in the air: when the ground height was asked for (0 = not asked)
var _surface_answered_msec: int = 0
var _ground_below_y: float = NAN      # the answer: the ground height under _ground_below_xz
var _ground_below_xz: Vector2 = Vector2.ZERO
var _viewer_ground_y: float = NAN     # the streaming viewer's height while it stands on the ground below a high player (NAN = at the player)
var _stage_done: bool = false         # the staged ground view has been started for this stop
var _stage_view: float = 0.0          # above 0 while only the finest ground is built after a stop high up
var _stage_next_msec: int = 0
var test_fly: bool = false
var test_route: Vector2 = Vector2(1.0, 0.0)   # --route=east|south|diag: heading of the --fly test
var test_fly_msec: int = 30000                # --flytime=seconds: how long the --fly test moves
var hole_probe: bool = false                  # --hole-probe: count missing ground colliders around the player every second (stress test)
var _hole_next_msec: int = 0
var _hole_since: Dictionary = {}              # grid cell -> msec it first had no ground under it
var _hole_worst_msec: int = 0
var _hole_worst_cell: Vector2i = Vector2i.ZERO
var _hole_max_count: int = 0
var _hole_samples: int = 0
var _hole_settled: bool = false
var _hole_max_after: int = 0
var _hole_missing_total: int = 0
var test_fly_alt: float = 0.0          # --fly check: fly level at this height above sea level (0 = the spawn height)
var _fly_ground_msec: int = 0         # --fly check: when a collider first showed under the player after stopping
var _fly_stop_msec: int = 0           # --fly check: when the flight stopped (0 = not yet)
var _anchor: Vector3 = Vector3.ZERO    # where the ground and plants are loaded around (the viewer)
var _anchor_set: bool = false
var _last_pos: Vector3 = Vector3.ZERO
var _still_since_msec: int = 0
var _building_paused: bool = false    # flying and moving: no ground is asked for
var run_speed: float = 0.0            # with --walk: ground speed in m/s instead of the walking pace
var _wait_frames: int = 0             # walk test: frames spent waiting for ground
var _space_wake_s: float = 0.0
var _slowest_frame: float = 0.0       # walk test: longest frame (s)
var rescued: int = 0                   # times the player was lifted back above the ground
var _floor_msec: int = 0               # last time the player stood on something
var test_walk: bool = false
var _walk_phase: int = 0               # 0 wait, 1 falling, 2 walking, 3 into a tree, 4 done
var _walk_msec: int = 0
var _walk_dir: Vector3 = Vector3.ZERO
var _walk_stats: Dictionary = {}
var test_dig: bool = false
var test_swim: bool = false
var test_ui: bool = false
var test_flood: bool = false
var test_gear: bool = false
var test_spear_sounds: bool = false
var test_fire: bool = false
var test_fire_world: bool = false      # --fire-world: a fake world row goes through states 8, 9, 1, 9, 8 (loaded, lit, rained out, emptied)
var _fire_world_step: int = 0
var test_ui_sounds: bool = false       # --ui-sounds: hotbar ticks and the chest screen cue (job 58)
var _ui_step: int = 0
var test_lake: bool = false            # --lake: soft laps from stand-in still-water squares (job 62)
var test_voice_priority: bool = false  # --voice-priority: shed order at the voice cap (job 64)
var test_sweep: bool = false           # --sweep: 8 hours x 4 seasons, calls and voices per cell (job 66)
var _sweep_step: int = -1
var _sweep_peak: int = 0
var _sweep_max: int = 0
var test_emitters: bool = false        # --emitter-test: fake server events and loops through sound.emitters (job 65)
var test_mix_levels: bool = false      # --mix-levels: per-bus peak table over the run (job 67)
var test_landing: bool = false         # --landing: drops of 1, 3 and 7 m through sound.landing (job 68)
var _hurts: Array = []
var test_stepfx: bool = false          # --stepfx: wade, then dry steps: squelch and cloth layers
var test_swing: bool = false           # --swing-test: tool whooshes (job 71)
var test_insects: bool = false         # --insect-test: summer insect bed levels by season and hour (job 72)
var _lake_calm_laps: int = 0
var test_variety: bool = false         # --variety-test: bird kinds by season and hour, no repeats within a minute (job 92)
var test_town: bool = false            # --town-sounds: a busy town around the player for the voice audit (job 87)
var _test_town_bell: int = 0
var test_meters: bool = false          # --meters-test: F3 sound meters (job 86)
var test_splash: bool = false          # --splash-test: single rain drops per ground (job 83)
var test_reverb: bool = false          # --reverb-test: the one cave reverb on bus World, by tier and enclosure (job 81)
var test_air: bool = false             # --air-test: distance and cover dulling by band bus (job 82)
var test_flush: bool = false           # --flush-test: variety of the bird take-off sounds (Dave 2026-10-20)
var test_reject: bool = false          # --reject-test: refused-action cue and its rate limit (job 73)
var test_step_levels: bool = false     # --step-levels: the step loudness table loads and can be overridden (job 76)
var test_night: bool = false           # --night-test: owl answers, the night insect bed, wolves by season (job 77)
var test_stance: bool = false          # --stance: stand, crouch, sit, lie and rise in turn (job 56)
var _stance_step: int = 0
var _lake_start_msec: int = 0
var test_windhole: bool = false        # --wind-hole: wind through gaps (job 89): open, lean-to, cave mouth, tunnel, calm
var _windhole_report: Array = []
var test_ice: bool = false             # --ice-test: a frozen pond (job 88): groans, cracks, no laps, thaw
var _ice_start_msec: int = 0
var _ice_report: String = ""
var test_merge: bool = false           # --merge-check: far fires and far falls share voices (job 53)
var _merge_step: int = 0
var test_faint: bool = false           # --faint: the scripted over-exertion, faint and waking run (breath_sounds.demo)
var test_load_all_sounds: bool = false # --load-all-sounds: load every sound file once and report the memory (job 52 audit)
var _fire_sync_left: float = 0.0
var _tree_sync_left: float = 0.0
var _item_sync_left: float = 0.0
var test_levels: bool = false
var test_placed: bool = false
var test_structures: bool = false
var test_cooking: bool = false
var test_workshop: bool = false
var _test_workshop_t: float = -1.0
var test_treewind: bool = false
var _test_treewind_t: float = -1.0
var test_wear: bool = false
var _test_wear_t: float = -1.0
var test_distant: bool = false
var test_craft_sounds: bool = false
var _test_craft_t: float = -1.0
var test_flame: bool = false
var _test_flame_t: float = -1.0
var test_exertion: bool = false
var _test_exertion_t: float = -1.0
var _sound_exertion_at: int = -1
var _test_fire_at: int = 0
var _test_fire_step: int = 0
var _sound_fire_at: int = -1
var _test_spear_step: int = 0
var _test_spear_at: int = 0
var _sound_spear_at: int = -1
var test_interior: bool = false
var _test_interior_step: int = 0
var _test_interior_at: int = 0
var _sound_interior_at: int = -1
var _sound_gear_at: int = -1
var test_items: bool = false
var test_gather: bool = false
var test_strain_run: bool = false       # --strainrun: with --walk --runspeed=11, the server strain must climb while running
var test_arrival: bool = false         # --arrival: after the ground appears, health must still be 100 (arriving is not a fall)
var test_leanto: bool = false
var test_chest: bool = false
var test_eat: bool = false
var test_quickkeys: bool = false
var test_texttest: bool = false
var test_plantpick: bool = false
var test_spear: bool = false
var test_chop: bool = false
var test_creatures: bool = false
var _test_creature_at: int = 0
var _test_creature_step: int = 0
var _sound_creature_at: int = -1
var _quality_cued: int = -1
var _test_ui_next: int = 0
var _test_ui_step: int = 0
var cache_mb: int = 0                 # 0 = by quality preset; --cache-mb= overrides
var cache_mb_from_quality: bool = false
var clear_cache: bool = false         # --clear-cache wipes the saved ground before starting
var cache_dir: String = ""
var started_msec: int = 0
var connected_msec: int = 0
var settled_msec: int = 0
var world: Dictionary = {}
var _budget_check_msec: int = 0
var _cache_task: int = -1               # WorkerThreadPool task doing the cache flush and size check
var _cache_tile: Vector2i = Vector2i.ZERO
var _cache_removed: int = 0
var _report_msec: int = 0
var dig_applied: int = 0
var test_dig_check: bool = false      # --dig-check: read the ground where --dig cut a hole in an earlier run (the hole must still be there)
var flora                             # FloraView
var ocean_ice                         # OceanIce (floes over a frozen sea)
var swimming: bool = false            # in deep water, feet under the surface (src/shared/swim.gd)
var _climb_until_msec: int = 0        # pulling out of the water onto a bank or floe until then
var _under_ice_next_msec: int = 0
var _ice_gap: Vector3 = Vector3.ZERO  # the way out from under a floe or ice sheet (zero when not under one)
var fall_mist                         # FallMist: spray at the foot of the nearest waterfalls
var fall_growth                       # FallGrowth: ferns around the foot of the nearest waterfall
var items                             # InventoryView: inventory panel (I), pick-up (E)
var harvest                           # Harvest: E prompt, tap to pick, hold to sweep
var pickup_feed                       # PickupFeed: "+3 Firewood" notices on the left of the screen
var hotbar_strip                      # HotbarStrip: keys 1 to 0 on screen, drag items into the first ten slots
var held                              # HeldItem: hotbar keys 1 to 8, spear jab and throw
var grass                             # GrassView
var faint                             # FaintEffect: tunnel vision, blur and black-out (set_state)
var sound                             # SoundStage: wind, footsteps, grass swish
var _commit: String = GitStamp.short_commit()   # which checkout is running
var _render_scale: float = 1.0            # 3D resolution scale now (render_scale.gd)
var _jitter_test                      # float-precision test, J or Esc > Advanced
var _machine_probe                    # "Measure this machine" run for the minimum-spec test (Esc > Advanced)
var _gpu_probe                        # GPU cost per piece of the scene, Ctrl+Shift+G
var weather_look                      # WeatherLook: clouds, rain, snow, fog, lightning from `weather`
var _bake = TileBakeScript.new()      # admin: background tile bake
var _bake_check_msec: int = 0
var _bake_status: String = ""
var _bake_alert_until: int = 0
var _bake_alert_at: Vector3 = Vector3.ZERO   # where the player stood when the finished notice came up
var _bake_done_note: String = ""          # the bake's own finished message, shown once the ground reloads
var display = DisplaySettingsScript.new()   # saved window, VSync and quality choices
var quality: int = 2                  # index into QUALITY_NAMES; High is the default
var _flora_view_full: PackedFloat32Array = PackedFloat32Array()
var _flora_near_full: PackedFloat32Array = PackedFloat32Array()
var _viewer: VoxelViewer
var _sun: DirectionalLight3D
var _frame_ms: Array = []             # recent frame times for the HUD readout
var test_cut: bool = false
var _flora_asked: Dictionary = {}     # chunk -> true asked or held in full, false trees only
var _flora_check_msec: int = 0
var link = null                       # direct block line (block_link.gd)
var _in_queue: Array = []             # chunks from the server being unpacked, in arrival order
var _in_mutex: Mutex = Mutex.new()
var _in_generation: int = 0           # raised when the plants are dropped (a bake): older chunks are ignored
var under_cover: float = 0.0          # 1 under a tree's canopy, else 0 (Cover.at at the player, once a second)
var weather: Dictionary = {}          # the weather here and now (WeatherScript.state): the same on every client, no network traffic; rendering and sounds read it
var _weather_next_msec: int = 0
var game_clock = GameClockScript.new()   # copy of the server's game clock, set at the welcome
var _sound_test_at: int = -1          # Esc > Settings "Sound test time"; -1 follows the game clock
var _sound_town_on: bool = false
var _sound_hit_at: int = -1
var _sound_weather_at: int = -1         # Esc > Settings "Sound test weather"; -1 follows the weather state
var _water_dirty: bool = false        # the server said the water moved; not asked for yet
var _water_asked_msec: int = 0
var _flora_chunks: int = 0
var _flora_bytes: int = 0
var _flora_cuts: int = 0
var _flora_done_msec: int = 0
var _host: String = "127.0.0.1"
var _port: int = 24600
var _wait_until_msec: int = 0


func _ready() -> void:
	net = $TerrainNet
	display.load_saved()

	if display.quality >= 0:
		quality = clampi(display.quality, 0, QUALITY_NAMES.size() - 1)

	display.apply(get_window())

	for shot_argument in OS.get_cmdline_user_args():
		if shot_argument.begins_with("--shots="):
			var shot_runner = ShotRunnerScript.new()
			shot_runner.name = "ShotRunner"
			add_child(shot_runner)
			shot_runner.setup(self, OS.get_cmdline_user_args())
			break
	var host: String = "127.0.0.1"
	var port: int = 24600

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--server="):
			host = argument.trim_prefix("--server=")
		elif argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--cache-mb="):
			cache_mb = int(argument.trim_prefix("--cache-mb="))
		elif argument.begins_with("--cache="):
			cache_dir = argument.trim_prefix("--cache=")
		elif argument.begins_with("--frames="):
			frames_left = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--move="):
			test_speed = float(argument.trim_prefix("--move="))
		elif argument.begins_with("--route="):
			var route: String = argument.trim_prefix("--route=")
			test_route = Vector2(0.0, 1.0) if route == "south" else (Vector2(0.7071, 0.7071) if route == "diag" else Vector2(1.0, 0.0))
		elif argument.begins_with("--flytime="):
			test_fly_msec = int(float(argument.trim_prefix("--flytime=")) * 1000.0)
		elif argument == "--hole-probe":
			hole_probe = true
		elif argument == "--fly":
			test_fly = true
		elif argument.begins_with("--flyalt="):
			test_fly_alt = float(argument.trim_prefix("--flyalt="))
		elif argument.begins_with("--wait="):
			_wait_until_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--wait=")) * 1000.0)
		elif argument == "--clear-cache":
			clear_cache = true
		elif argument.begins_with("--quality="):
			quality = clampi(int(argument.trim_prefix("--quality=")), 0, QUALITY_NAMES.size() - 1)
		elif argument == "--test-clear":
			test_clear = true
		elif argument.begins_with("--start="):
			var xyz: PackedStringArray = argument.trim_prefix("--start=").split(",")
			test_start = Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))
		elif argument == "--no-ground-check":
			ground_check = false
		elif argument == "--dump-test":
			test_dump = true
		elif argument == "--inspect":
			inspecting = true
			test_inspect = true
		elif argument == "--walk":
			test_walk = true
		elif argument.begins_with("--runspeed="):
			run_speed = float(argument.trim_prefix("--runspeed="))
		elif argument == "--water-step":
			test_water_step = true
		elif argument == "--dig-check":
			test_dig_check = true
		elif argument == "--dig":
			test_dig = true
		elif argument == "--cut":
			test_cut = true
		elif argument == "--swim":
			test_swim = true
		elif argument == "--ui":
			test_ui = true
		elif argument == "--flood":
			test_flood = true
		elif argument == "--gear":
			test_gear = true
		elif argument == "--exertion":
			test_exertion = true
		elif argument == "--flame":
			test_flame = true
		elif argument == "--craft-sounds":
			test_craft_sounds = true
		elif argument == "--distant":
			test_distant = true
		elif argument == "--wear-sounds":
			test_wear = true
		elif argument == "--treewind":
			test_treewind = true
		elif argument == "--workshop":
			test_workshop = true
		elif argument == "--cooking":
			test_cooking = true
		elif argument == "--placed":
			test_placed = true
		elif argument == "--levels":
			test_levels = true
		elif argument == "--fire":
			test_fire = true
		elif argument == "--ui-sounds":
			test_ui_sounds = true
		elif argument == "--lake":
			test_lake = true
		elif argument == "--wind-hole":
			test_windhole = true
		elif argument == "--ice-test":
			test_ice = true
		elif argument == "--stance":
			test_stance = true
		elif argument == "--night-test":
			test_night = true
		elif argument == "--step-levels":
			test_step_levels = true
		elif argument == "--variety-test":
			test_variety = true
		elif argument == "--town-sounds":
			test_town = true
		elif argument == "--meters-test":
			test_meters = true
		elif argument == "--splash-test":
			test_splash = true
		elif argument == "--reverb-test":
			test_reverb = true
		elif argument == "--air-test":
			test_air = true
		elif argument == "--flush-test":
			test_flush = true
		elif argument == "--reject-test":
			test_reject = true
		elif argument == "--insect-test":
			test_insects = true
		elif argument == "--swing-test":
			test_swing = true
		elif argument == "--stepfx":
			test_stepfx = true
		elif argument == "--landing":
			test_landing = true
		elif argument == "--mix-levels":
			test_mix_levels = true
		elif argument == "--emitter-test":
			test_emitters = true
		elif argument == "--sweep":
			test_sweep = true
		elif argument == "--voice-priority":
			test_voice_priority = true
		elif argument == "--merge-check":
			test_merge = true
		elif argument == "--faint":
			test_faint = true
		elif argument == "--load-all-sounds":
			test_load_all_sounds = true
		elif argument == "--fire-world":
			test_fire_world = true
		elif argument == "--spear-sounds":
			test_spear_sounds = true
		elif argument == "--interior":
			test_interior = true
		elif argument == "--items":
			test_items = true
		elif argument == "--plantpick":
			test_plantpick = true
		elif argument == "--texttest":
			test_texttest = true
		elif argument == "--quickkeys":
			test_quickkeys = true
		elif argument == "--eat":
			test_eat = true
		elif argument == "--chest":
			test_chest = true
		elif argument == "--leanto":
			test_leanto = true
		elif argument == "--gather":
			test_gather = true
		elif argument == "--strainrun":
			test_strain_run = true
		elif argument == "--arrival":
			test_arrival = true
		elif argument == "--spear":
			test_spear = true
		elif argument == "--chop":
			test_chop = true
		elif argument == "--creatures":
			test_creatures = true

	net.welcome_received.connect(_on_welcome)
	net.blocks_received.connect(_on_blocks)
	net.tile_changed_received.connect(_on_tile_changed)
	net.dug_received.connect(_on_dug)
	net.filled_received.connect(_on_filled)
	net.flora_received.connect(_on_flora)
	net.flora_cut_received.connect(_on_flora_cut)
	net.water_rate_received.connect(_on_water_rate)
	net.water_changed_received.connect(_on_water_changed)
	net.ground_reset_received.connect(_on_ground_reset)
	net.died_received.connect(_on_died)
	net.water_received.connect(_on_water_received)
	net.surface_received.connect(_on_surface_received)
	net.dump_received.connect(_on_dump_received)
	_host = host
	_port = port

	# Started by the "play" launcher, whose server may still be loading.
	if AppConfig.get_command_line_value("role", "") == "play" and _wait_until_msec == 0:
		_wait_until_msec = Time.get_ticks_msec() + 120000
	multiplayer.server_disconnected.connect(func(): print("Terrain client: server left"); _finish(1))
	multiplayer.connection_failed.connect(_on_connection_failed)
	started_msec = Time.get_ticks_msec()
	_connect()


func _connect() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(_host, _port)

	if error != OK:
		push_error("Terrain client: cannot connect to %s:%d (%s)" % [_host, _port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	print("Terrain client: connecting to %s:%d" % [_host, _port])


# While a --wait is running, a server not up yet is tried again.
func _on_connection_failed() -> void:
	if Time.get_ticks_msec() < _wait_until_msec:
		multiplayer.multiplayer_peer = null
		get_tree().create_timer(1.0).timeout.connect(_connect)
		return

	print("Terrain client: connection failed")
	_finish(1)


func _on_welcome(info: Dictionary) -> void:
	var tw: int = Probe.start()
	_welcome_body(info)
	Probe.stop("welcome", tw)


func _welcome_body(info: Dictionary) -> void:
	if int(info.get("protocol", 0)) != NetScript.PROTOCOL_VERSION:
		push_error("Terrain client: server speaks protocol %s, this client %d" % [str(info.get("protocol")), NetScript.PROTOCOL_VERSION])
		_finish(1)
		return

	world = info
	game_clock.sync(float(info.get("game_seconds", game_clock.seconds)))
	connected_msec = Time.get_ticks_msec()

	if cache_dir == "":
		# One folder per terrain version and set of tile files, so older blocks are never mixed in.
		cache_dir = "user://terrain_cache/%s/v%d_%s" % [str(info["world_name"]).validate_filename(), int(info.get("terrain_version", 1)), str(info.get("tiles_stamp", ""))]

	cache = CacheScript.new()
	if cache_mb <= 0:
		cache_mb = QUALITY_CACHE_MB[quality]
		cache_mb_from_quality = true

	if clear_cache:
		var folder: String = ProjectSettings.globalize_path(cache_dir)

		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + "/" + file)

		print("Terrain client: cleared the saved ground cache")

	cache.setup(cache_dir, info, info["revisions"], cache_mb)
	var seeded: int = cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))
	_starter_seeded = seeded

	if seeded > 0:
		cache.set_revisions(info["revisions"])
		print("Terrain client: first run, copied the starter ground for the spawn (%d tile)" % seeded)
	stream = StreamScript.new()
	stream.cache = cache
	link = BlockLinkScript.new()
	link.stream = stream
	link.open(_host, 0 if OS.get_cmdline_user_args().has("--no-block-line") else int(info.get("block_port", 0)), multiplayer.get_unique_id())
	stream.link = link
	var root: Node3D = Node3D.new()
	root.name = "World"
	add_child(root)
	var t1: int = Probe.start()
	_tables = TableSetScript.new()
	_tables.load_directory()
	Probe.stop("welcome: tables", t1)
	terrain = VoxelLodTerrain.new()
	terrain.format = Layout.make_format()
	terrain.stream = stream
	var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_SINGLE_S4
	terrain.mesher = mesher
	terrain.lod_count = LOD_COUNT
	terrain.view_distance = VIEW_DISTANCE
	terrain.mesh_block_size = 32
	terrain.generate_collisions = true
	terrain.collision_lod_count = 4
	# Not the clipbox streaming system (tried in build 61): it loads the fine ground under the
	# player first, but makes no collision until every coarser level is loaded too, so the
	# player had no ground to stand on for most of a minute (owner, 2026-10-20).
	var t2: int = Probe.start()
	terrain.material = GroundMaterialScript.make(_tables, quality)
	Probe.stop("welcome: ground material", t2)
	_ground_quality = quality
	root.add_child(terrain)
	_make_player(root, test_start if test_start.is_finite() else info["spawn"] + Vector3(0.0, 28.0, 0.0))
	flora = FloraViewScript.new()
	flora.name = "Flora"
	var t3: int = Probe.start()
	flora.setup(_tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
	Probe.stop("welcome: flora setup", t3)
	root.add_child(flora)
	flora.ground_ready = func(x: float, z: float) -> bool: return stream != null and stream.column_loaded(x, z)
	ocean_ice = OceanIceScript.new()
	ocean_ice.name = "OceanIce"
	ocean_ice.seed_value = int(info.get("master_seed", 0))
	ocean_ice.ground_below = _ground_below
	root.add_child(ocean_ice)
	fall_mist = FallMistScript.new()
	fall_mist.name = "FallMist"
	fall_mist.setup(quality)
	root.add_child(fall_mist)
	fall_growth = FallGrowthScript.new()
	fall_growth.name = "FallGrowth"
	fall_growth.setup(terrain, flora, quality)
	root.add_child(fall_growth)
	_flora_view_full = flora.view_m.duplicate()
	_flora_near_full = flora.near_m.duplicate()
	grass = GrassViewScript.new()
	grass.name = "Grass"
	root.add_child(grass)
	grass.setup(terrain, flora, _tables)
	_jitter_test = JitterTestScript.new()
	add_child(_jitter_test)
	_jitter_test.setup(self)
	_machine_probe = MachineProbeScript.new()
	add_child(_machine_probe)
	_machine_probe.setup(self)
	_gpu_probe = GpuProbeScript.new()
	add_child(_gpu_probe)
	_gpu_probe.setup(self)
	weather_look = WeatherLookScript.new()
	add_child(weather_look)
	weather_look.setup(self)
	weather_look.set_quality(quality)
	sound = SoundStageScript.new()
	sound.name = "Sound"
	root.add_child(sound)
	sound.ground_below = _ground_below
	var t4: int = Probe.start()
	sound.setup(terrain, flora, grass)
	stance.changed.connect(func(new_stance: int): sound.stance.set_stance(["stand", "crouch", "sit", "lie"][clampi(new_stance, 0, 3)]))
	Probe.stop("welcome: sound setup", t4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--floor="):
			sound.set_floor(argument.get_slice("=", 1))

	if test_gear:
		sound.gear.set_worn(["plate", "cloth", "iron"])
	var t5: int = Probe.start()
	debug_hud.add_line("ground check", func() -> String: return "%d samples, %d mismatches, %d zeroed blocks refused, last %s" % [check_samples, check_mismatches, stream.zeroed_blocks, check_last])
	debug_hud.add_line("video memory", func() -> String:
		return "video memory %.0f MB (textures %.0f, buffers %.0f), objects %d, nodes %d (orphans %d), script memory %.0f MB, primitives %d" % [
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	debug_hud.add_line("quality tier", func() -> String:
		return "tier %s: ground view %d, flora view trees %.0f shrubs %.0f plants %.0f m, impostors from %.0f m, shadows %.0f m, grass %d m density %.2f" % [
			QUALITY_NAMES[quality], terrain.view_distance, flora.view_m[0], flora.view_m[1], flora.view_m[2], flora.impostor_m,
			float(QUALITY_SHADOW_M[quality]), int(grass.radius_m), grass.density])
	_make_environment(root)
	_apply_quality()

	if OS.get_cmdline_user_args().has("--print-tier"):
		print("Terrain client: ", debug_hud.text())
	Probe.stop("welcome: environment", t5)
	get_window().size_changed.connect(_apply_render_scale)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0.05, 0.25, 0.4, 0.55)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.visible = false
	layer.add_child(_tint)
	faint = FaintEffectScript.new()
	add_child(faint)
	faint.setup(layer)      # over-exertion and fainting picture (faint.set_state), hidden while normal
	_mode_label = Label.new()
	_mode_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 48)
	_mode_label.add_theme_constant_override("outline_size", 8)
	_mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_mode_label)
	_inspect_label = Label.new()
	_inspect_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inspect_label.offset_top = 90.0
	_inspect_label.add_theme_font_size_override("font_size", 40)
	_inspect_label.add_theme_constant_override("outline_size", 8)
	_inspect_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_inspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_inspect_label)
	_water_label = Label.new()
	_water_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_water_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_water_label.offset_top = 150.0
	_water_label.add_theme_font_size_override("font_size", 36)
	_water_label.add_theme_constant_override("outline_size", 8)
	_water_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_water_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_water_label)
	# Oxygen countdown (Dave 2026-10-21): the seconds of air left, under the bubble symbol, only with the head under water.
	_breath_label = Label.new()
	_breath_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_breath_label.anchor_top = 0.2
	_breath_label.anchor_bottom = 0.2
	_breath_label.offset_top = 52.0
	_breath_label.offset_bottom = 112.0
	_breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_breath_label.add_theme_font_size_override("font_size", 44)
	_breath_label.add_theme_constant_override("outline_size", 8)
	_breath_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_breath_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath_label.visible = false
	layer.add_child(_breath_label)
	status_icons = StatusIconsScript.new()
	layer.add_child(status_icons)
	status_icons.add_icon("inspection", _load_brain_icon(), func() -> bool: return inspecting, 0.85)
	status_icons.add_icon("thirst", StatusIconsScript.drop_texture(), func() -> bool: return items.thirst <= 15, 0.85)
	status_icons.add_icon("oxygen", StatusIconsScript.bubble_texture(), func() -> bool: return items.breath_ds >= 0, 0.9)
	status_icons.add_icon("cover", StatusIconsScript.house_texture(), func() -> bool: return under_cover > 0.0)
	_build_menu(layer)
	hud = Label.new()
	hud.position = Vector2(12.0, 12.0)
	hud.add_theme_font_size_override("font_size", 52)
	hud.add_theme_constant_override("outline_size", 8)
	hud.add_theme_constant_override("shadow_offset_x", 3)
	hud.add_theme_constant_override("shadow_offset_y", 3)
	hud.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	hud.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	layer.add_child(hud)
	compass = CompassScript.new()
	layer.add_child(compass)
	var npc_view: Node3D = NpcViewScript.new()
	npc_view.name = "Npcs"
	add_child(npc_view)
	_npc_view = npc_view
	net.npc_roster_received.connect(npc_view.on_roster)
	net.npcs_received.connect(npc_view.on_rows)
	var animal_view: Node3D = AnimalViewScript.new()
	animal_view.name = "Animals"
	add_child(animal_view)
	net.animals_received.connect(animal_view.on_rows)
	net.blood_received.connect(animal_view.on_blood)
	items = InventoryViewScript.new()
	items.name = "Items"
	add_child(items)
	items.setup(net, layer, root, func(): return body.global_position, _ground_below)
	var dialogue_view: Node = DialogueViewScript.new()
	dialogue_view.name = "Dialogue"
	add_child(dialogue_view)
	dialogue_view.setup(net, items, npc_view, layer, func(): return body.global_position)
	var npc_voice: Node = NpcVoiceScript.new()
	npc_voice.name = "NpcVoice"
	add_child(npc_voice)
	_npc_voice = npc_voice

	if _npc_voice_button != null:
		_npc_voice_button.text = "NPC voice: %s" % ("on" if npc_voice.enabled else "off")

	dialogue_view.voice_line = func(voice_id: String, text: String):
		var talker: Dictionary = npc_view.nearest(body.global_position, npc_voice.hear_m)

		if not talker.is_empty():       # nobody in earshot is talking: no voice (the text still shows)
			npc_voice.speak(voice_id, text, talker["pos"])
	items.knowledge = knowledge
	items.max_lights = func(): return [1, 2, 3, 3][clampi(quality, 0, 3)]
	items.is_inspecting = func(): return inspecting
	items.stance_event = _on_stance_from_server
	items.cover_index = flora.cover
	items.text_scale = display.TEXT_SCALES[display.text_index]
	items.sort_index = display.sort_index
	items.sort_changed = func(index):
		display.sort_index = index
		_save_display()
	items.text_step = func(direction):
		display.text_index = clampi(display.text_index + direction, 0, display.TEXT_SCALES.size() - 1)
		_save_display()
		items.set_text_scale(display.TEXT_SCALES[display.text_index])
	items.eat_event = func(item_id): sound.itemfx.eat(item_id)
	items.boulder_budget = func(): return [24, 48, 80, 120][clampi(quality, 0, 3)]
	items.fuel_event = func(): sound.itemfx.fuel_pressed()
	items.reject_event = func(reason): sound.itemfx.reject(reason)
	items.thought_event = func(line_id, kind): sound.inner.speak(line_id, kind)
	items.heart_bpm = func(): return sound.breath.bpm_now
	items.view_direction = func(): return -camera.global_transform.basis.z
	sound.landing.hurt.connect(func(drop_m, severity):
		if Time.get_ticks_msec() >= arrival_protect_until_msec:
			items.report_fall(drop_m, severity))
	items.strain_event = func(strain, _state, _fade):
		var shown: Array = items.faint_state()
		faint.set_state(shown[0], strain, shown[1])
	items.chest_event = func(what, at): sound.placed.chest(what == "open", at) if what in ["open", "close"] else sound.placed.container(what == "put", at)
	items.tool_event = func(what): sound.placed.tool_break(body.global_position) if what == "broke" else sound.placed.tool_repair(body.global_position)
	harvest = HarvestScript.new()
	harvest.setup(self, items, net)
	items.register_interactable("drink", 35, func():
		if _water_ahead() and items.held_container_has_room():
			return {"prompt": "Press E to fill", "tap": items.drink}

		return {"prompt": "Press E to drink", "tap": items.drink} if items.thirst < 100 and _water_ahead() else {})
	items.register_interactable("drink_held", 36, func():
		return {"prompt": "Press E to drink", "tap": func(): items.eat_slot(items.held_container_slot())} if items.thirst < 100 and items.held_container_has_water() else {})
	items.register_interactable("plant", 40, func():
		return {} if items.plant_hint == "" else {"prompt": items.plant_hint, "tap": harvest.tap})
	held = HeldItemScript.new()
	held.name = "Held"
	add_child(held)
	held.setup(items, net, camera, root, layer, _ground_below, sound, _tree_trunk_near, _cover_here)
	held.held_light_budget = func(): return quality >= 1
	items.equip_requested = func(slot): held.equip_toggle(slot)
	items.held_slot_now = func(): return held.held_slot if held.holding else -1
	hotbar_strip = HotbarStripScript.new()
	hotbar_strip.setup(items, layer, held)
	items.hotbar_strip = hotbar_strip
	pickup_feed = PickupFeedScript.new()
	pickup_feed.setup(items, layer)

	# The server's one "received" event for every gain (pickup, quest reward, craft, harvest); Items adds the RPC.
	if net.has_signal("item_received"):
		net.connect("item_received", func(item_id: String, count: int, _source: String): pickup_feed.push_id(item_id, count))

	if test_items:
		items.run_test()

	if test_strain_run:
		items.run_strain_test(self)

	if test_arrival:
		items.run_arrival_test(self)

	if test_gather:
		items.run_gather_test(self)

	if test_leanto:
		items.run_leanto_test(self)

	if test_chest:
		items.run_chest_test(self)

	if test_eat:
		items.run_eat_test(self)

	if test_quickkeys:
		items.run_quickkey_test(self)

	if test_texttest:
		items.run_text_test(self)

	if test_plantpick:
		items.run_plant_test(self)

	if test_spear:
		held.run_test()

	if test_chop:
		items.run_chop_test(self)
	print("Terrain client: welcome after %d ms; world %s; spawn %s; cache %s (%d MB)" % [
		connected_msec - started_msec, str(info["world_name"]), str(info["spawn"]), cache_dir, cache_mb
	])



func _on_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	if stream != null:
		var t: int = Probe.start()
		stream.deliver(keys, payloads)
		Probe.stop("blocks in", t)


func _on_tile_changed(tile: Vector2i, revision: int) -> void:
	if cache != null:
		cache.set_revision(tile, revision)

	if stream != null:
		stream.forget_prefetch()

	print("Terrain client: tile %s is now revision %d" % [str(tile), revision])


# Applies an edit to the terrain already loaded; blocks loaded later come
# from the server with the edit in them.
func _on_dug(center: Vector3, radius: float) -> void:
	if terrain == null:
		return

	if sound != null and sound.dig != null and body != null:
		sound.dig.dug(center, radius, body.global_position)        # before the ground changes: it hears what was there

	var tool: VoxelTool = terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.do_sphere(center, radius)
	dig_applied += 1

	if grass != null:
		grass.ground_changed(center, radius)

	print("Terrain client: applied a %.1f m dig at %s; ground value there now %.2f (above 0 is open)" % [
		radius, str(center), tool.get_voxel_f(Vector3i(center.round()))
	])


# A fill (a dam, a filled hole): the same sphere put back as ground, the grass under it buried.
func _on_filled(center: Vector3, radius: float, _material: int) -> void:
	if terrain == null:
		return

	var tool: VoxelTool = terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_ADD
	tool.do_sphere(center, radius)

	if grass != null:
		grass.ground_changed(center, radius)


# Placed things clear the ground around them (data/look/placed_clearing.json): grass and litter in grass_view, shrubs and small plants in
# flora_view. The spots are read from the world items the inventory view already holds (a fire, shelter, chest, bench, forge...; loose
# sticks, felled trunks, boulders, remains and carcasses do not count). Updated when the set changes.
const PLACED_CLEARING := "res://data/look/placed_clearing.json"
const CLEARING_NOT := [0, 2, 3, 4, 10, 11, 12, 19]
var _cleared_key: int = 0
var _cleared_cfg: Dictionary = {}


func _sync_cleared() -> void:
	if items == null or grass == null or flora == null:
		return

	if _cleared_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACED_CLEARING))
		_cleared_cfg = parsed if parsed is Dictionary else {"radius_m": 5.0, "edge_m": 1.5}

	var spots: Array = []
	var key: int = 0

	for id in items._world:
		var row: Dictionary = items._world[id]

		if int(row.get("state", 0)) in CLEARING_NOT:
			continue

		var pos: Vector3 = row["pos"]
		spots.append(Vector3(snappedf(pos.x, 0.01), pos.y, snappedf(pos.z, 0.01)))
		key = key ^ hash(Vector2(pos.x, pos.z)) ^ int(id)

	if key == _cleared_key:
		return

	_cleared_key = key
	var radius: float = float(_cleared_cfg.get("radius_m", 5.0))
	grass.set_cleared(spots, radius, float(_cleared_cfg.get("edge_m", 1.5)))
	flora.set_cleared(spots, radius)


# Water within a stride of the feet or a step or two ahead (where you look, flat): what the E-to-drink prompt needs.
func _water_ahead() -> bool:
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.ZERO

	for step in [0.0, 1.0, 2.0]:
		var spot: Vector3 = body.global_position + forward * step
		var surface: float = flora.water_surface_at(spot.x, spot.z)

		if not is_nan(surface) and WaterVolume.depth(surface, _ground_below(spot)) >= WaterVolume.MIN_DEPTH_M:
			return true

	return false


# The body glides high above the spawn until the ground under it has collision. When it does, set it down just above the
# surface and protect it for a few seconds, so arriving is not a fall (Dave 2026-10-21: damage and a faint every landing).
func _arrive_on_ground() -> void:
	var ground: float = _ground_below(body.global_position)

	if not is_nan(ground) and body.global_position.y - ground > ARRIVAL_HEIGHT_M + 0.2:
		body.global_position.y = ground + ARRIVAL_HEIGHT_M
		body.velocity = Vector3.ZERO

	arrival_protect_until_msec = Time.get_ticks_msec() + ARRIVAL_PROTECT_MS
	sound.forget_fall(body)


# The character died (protocol 34): the server already holds the remains and the reset vitals; put the body back at the spawn
# high up and let it settle on the ground the way a first arrival does (no fall, a few seconds of protection).
# Ctrl+N (admin): stand next to the nearest NPC that is drawn (they are sent within 120 m); press E there to talk.
func _go_to_npc() -> void:
	var near: Dictionary = _npc_view.nearest(body.global_position, 100000.0) if _npc_view != null else {}

	if near.is_empty():
		if items != null:
			items.show_notice("No NPC drawn (roster %d, drawn %d). You are at x %.0f z %.0f; Hob stands at x 53304 z 68431." % [_npc_view.roster.size(), _npc_view.drawn_count(), body.global_position.x, body.global_position.z])

		return

	if items != null:
		items.show_notice("Next to %s (roster %d, drawn %d)" % [str(near["name"]), _npc_view.roster.size(), _npc_view.drawn_count()])

	body.global_position = near["pos"] + Vector3(2.0, 1.5, 0.0)


func _on_died(_cause: String, spawn_point: Vector3) -> void:
	if body == null:
		return

	body.global_position = spawn_point + Vector3(0.0, 28.0, 0.0)
	body.velocity = Vector3.ZERO
	_was_waiting = true
	arrival_protect_until_msec = Time.get_ticks_msec() + 10000


func _on_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool) -> void:
	if flora == null:
		return

	# A late trees-only answer for a chunk already held in full.
	if not full and flora.holds_full(chunk):
		return

	_flora_chunks += 1
	_flora_bytes += bytes.size() + water.size()
	_flora_done_msec = Time.get_ticks_msec() - connected_msec
	_queue_in({"kind": "flora", "chunk": chunk, "bytes": bytes, "water": water, "full": full})


# Owner (2026-10-20, 100 ms frames while ground and plants load): chunks from the server are
# unpacked and their water drawing built on a worker thread, and put in the scene in arrival
# order within INCOMING_USEC a frame (at least one). Decoding and building them on the main
# thread cost up to 16 ms and 23 ms a call, several in one frame after a water update.
func _queue_in(job: Dictionary) -> void:
	# Every key is set before the task starts: adding a key while the worker writes the
	# result would race on the dictionary.
	job["done"] = false
	job["result"] = null
	job["task"] = -1
	job["gen"] = _in_generation
	job["chunk_m"] = flora.chunk_m
	_in_queue.append(job)
	var material: Material = flora.water_material()
	job["task"] = WorkerThreadPool.add_task(_decode_in.bind(job, material))


func _decode_in(job: Dictionary, material: Material) -> void:
	var result: Dictionary = {}

	if job["kind"] == "flora":
		result["items"] = PlacerScript.decode(job["bytes"], Vector2(job["chunk"]) * float(job["chunk_m"]))
		result["grid"] = WaterGridScript.decode(job["water"])
	else:
		result["grid"] = WaterGridScript.decode(job["water"])

	var grid: Dictionary = result["grid"]

	if int(grid.get("wet", 0)) > 0:
		grid["mesh"] = WaterGridScript.build_mesh(grid, material)

		if flora.DRAW_FALL_RIBBONS and not grid.get("falls", []).is_empty():
			grid["falls_mesh"] = WaterFallsScript.build_mesh(grid["falls"], flora.fall_cap)

	_in_mutex.lock()
	job["result"] = result
	job["done"] = true
	_in_mutex.unlock()


# On exit: lets the unpacking tasks finish (they would run into the engine shutting down).
func _drain_incoming() -> void:
	for job in _in_queue:
		if int(job["task"]) >= 0:
			WorkerThreadPool.wait_for_task_completion(job["task"])

	_in_queue.clear()


func _apply_incoming() -> void:
	var started: int = Time.get_ticks_usec()
	var applied: int = 0

	while not _in_queue.is_empty():
		_in_mutex.lock()
		var job: Dictionary = _in_queue[0]
		var done: bool = job["done"]
		_in_mutex.unlock()

		if not done or (applied > 0 and Time.get_ticks_usec() - started > INCOMING_USEC):
			break

		_in_queue.pop_front()
		# A pool task keeps its record (and its bound job) until it is waited on; it has just
		# finished, so this returns at once. Without it memory grew about 24 MB a minute.
		WorkerThreadPool.wait_for_task_completion(job["task"])

		if flora == null or int(job["gen"]) != _in_generation:
			continue

		applied += 1
		var chunk: Vector2i = job["chunk"]
		var result: Dictionary = job["result"]

		if job["kind"] == "flora":
			var t: int = Probe.start()
			var full: bool = job["full"]

			if not full and flora.holds_full(chunk):
				Probe.stop("flora chunk in", t)
				continue

			if flora.has_chunk(chunk):
				flora.replace_items(chunk, result["items"], _anchor, full)
			else:
				flora.set_chunk(chunk, result["items"], _anchor, result["grid"], full)

			Probe.stop("flora chunk in", t)
		else:
			var tw: int = Probe.start()
			flora.set_water(chunk, result["grid"])
			Probe.stop("water in", tw)


# Weather from the game clock, the world seed, the zone of the tile the player is in and their
# altitude (town spirit is a neutral placeholder until it exists). Once a second; it is only a
# few noise lookups.
func _update_weather() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _weather_next_msec or world.is_empty():
		return

	_weather_next_msec = now + 1000
	var tile_m: float = float(world.get("tile_size_m", 15360))
	var row: int = int(floor(_anchor.z / tile_m))
	var group: String = WeatherScript.zone_group(world.get("zones", []), int(world.get("equator_row", 0)), row)
	under_cover = CoverScript.at(_anchor, flora.cover) if flora != null else 0.0
	weather = WeatherScript.state(int(world.get("master_seed", 0)), game_clock.seconds, group, _anchor.y, 0.0)

	# Ice on ponds and lakes: a pure function of the clock, zone and altitude (src/shared/ice.gd), so
	# every client and the server agree with no traffic. Recomputed once a game minute.
	var ice_now: float = IceScript.cover(game_clock.seconds, group, maxf(_anchor.y, 0.0), ICE_POND_DEPTH_M)

	if flora != null:
		flora.set_ice_cover(ice_now)

	if ocean_ice != null:
		# Salt water freezes harder to start: the sea only shows floes once the ice is well on.
		ocean_ice.update(_anchor, maxf(IceScript.cover(game_clock.seconds, group, 0.0, 12.0) * 1.0 - 0.05, 0.0))

	if sound != null and sound.weather != null:
		sound.weather.ice_cover = ice_now

	if _sound_weather_at < 0 and sound != null and sound.weather != null:
		sound.weather.apply_state(weather)


func _on_water_rate(rate: float, busy: bool, spring_m3_s: float) -> void:
	# 1 m3 is about 264.17 US gallons.
	_water_label.text = "Water flow rate: x%.2f = %.1f m3/s per spring (%s gal/min)%s" % [
		rate, spring_m3_s, _thousands(int(round(spring_m3_s * 264.17 * 60.0))), "  (running...)" if busy else ""]
	_water_label_until_msec = Time.get_ticks_msec() + 3000

	if flora != null:
		flora.set_flow_rate(rate)


# Admin tool (owner, 2026-10-19, testing water against digging): X digs a 2 m hole
# where the crosshair meets the ground, up to 80 m away.
func _admin_dig() -> void:
	var origin: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * 80.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		net.dig.rpc_id(1, hit["position"], 2.0)


# Ctrl+R (admin): a rabbit on the ground where the crosshair points, up to 40 m away (testing animals).
func _admin_rabbit() -> void:
	var origin: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin - camera.global_transform.basis.z * 40.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		net.admin_place.rpc_id(1, "animal", hit["position"], "rabbit")


func _thousands(value: int) -> String:
	var text: String = str(value)
	var out: String = ""

	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)

	return text + out


# The server's water moved: ask again for the water of every flora chunk held.
func _on_water_changed() -> void:
	_water_dirty = true


# Asks again for the water of the chunks held. While ground is still loading this waits up
# to WATER_HOLD_MSEC: each answer costs the server main-thread time and shares the line with
# the ground blocks, and the server says the water moved about twice a second.
func _send_water_request(now: int) -> void:
	if not _water_dirty or flora == null:
		return

	if stream.pending() > 0 and now - _water_asked_msec < WATER_HOLD_MSEC:
		return

	_water_dirty = false
	_water_asked_msec = now
	var chunks: PackedInt32Array = PackedInt32Array()

	for chunk in flora.held_chunks():
		chunks.append_array(PackedInt32Array([chunk.x, chunk.y]))

	print("Terrain client: the water moved, asking again for %d chunks" % (chunks.size() / 2))

	if not chunks.is_empty():
		net.request_water.rpc_id(1, chunks)


func _on_water_received(chunk: Vector2i, water: PackedByteArray) -> void:
	if flora != null:
		_queue_in({"kind": "water", "chunk": chunk, "water": water})


func _on_flora_cut(chunk: Vector2i, id: int) -> void:
	if flora == null:
		return

	# The server names the chunk in its own (wrapped) coordinates; any copy
	# of it this client holds is the same chunk.
	var period: int = int(round(float(world["tiles_per_side"]) * float(world["tile_size_m"]) / flora.chunk_m))

	for held in _flora_asked:
		if posmod(held.x - chunk.x, period) == 0 and posmod(held.y - chunk.y, period) == 0:
			flora.remove_item(held, id, _anchor)

	_flora_cuts += 1
	print("Terrain client: flora item %d in chunk %s was cut" % [id, str(chunk)])


# Asks for flora chunks coming into view and forgets ones far behind. Far chunks
# are asked for with their trees only, near ones in full (owner, 2026-10-19).
func _update_flora() -> void:
	var p: Vector3 = _anchor
	var falls: Array = flora.fall_list()
	GroundMaterialScript.set_falls(terrain.material as ShaderMaterial, falls, p)

	if fall_mist != null:
		fall_mist.update(falls, p)

	if fall_growth != null:
		fall_growth.update(falls, p)

	for chunk in flora.update(p):
		_flora_asked.erase(chunk)

	var wanted: PackedInt32Array = PackedInt32Array()

	for chunk in flora.wanted_chunks(p):
		var full: bool = flora.needs_full(chunk, p)

		if not _flora_asked.has(chunk) or (full and not _flora_asked[chunk]):
			_flora_asked[chunk] = full
			wanted.append_array(PackedInt32Array([chunk.x, chunk.y, 1 if full else 0]))

	if not wanted.is_empty():
		net.request_flora.rpc_id(1, wanted)


# Owner (2026-10-19): while flying and moving no ground or plants are built (requests are
# held); after the player has stayed still for STILL_MSEC the ground is built around them
# again, nearest first. On foot (landed) the ground always follows the player.
func _update_anchor(now: int, delta: float) -> void:
	var here: Vector3 = body.global_position
	var speed: float = here.distance_to(_last_pos) / maxf(delta, 0.001)
	_last_pos = here

	if speed > 0.5:
		_still_since_msec = now
		_surface_asked_msec = 0
		_stage_done = false

	var follow: bool = not flying or not _anchor_set or now - _still_since_msec >= STILL_MSEC

	# Stopped in the air (Dave, 2026-10-21): the ground straight below is built first. The server says where the
	# ground is under the player (protocol 45), the streaming viewer goes down to it and only the finest level is built
	# to a short distance until the ground under the player has a collider; then the rest follows.
	if follow and flying and _anchor_set and not is_nan(_ground_below_y) and absf(_ground_below_xz.x - here.x) < 2.0 and absf(_ground_below_xz.y - here.z) < 2.0:
		pass
	elif follow and flying and _anchor_set:
		if _surface_asked_msec == 0:
			_surface_asked_msec = now
			_ground_below_y = NAN
			net.request_surface.rpc_id(1, here.x, here.z)

		# Held until the answer (a round trip), or 1.5 s.
		follow = not is_nan(_ground_below_y) or now - _surface_asked_msec >= SURFACE_WAIT_MSEC

	var was_paused: bool = _building_paused
	_building_paused = not follow
	stream.paused = _building_paused

	if was_paused and not _building_paused:
		stream.drop_unsent_prefetch()

	if follow:
		if flying and _anchor_set and _anchor.distance_to(here) > 1.0:
			print("Terrain client: stopped flying at %s, loading the ground here" % str(here.round()))

		_anchor = here
		_anchor_set = true

		_viewer_ground_y = NAN

		if flying and not is_nan(_ground_below_y) and _ground_below_y < here.y - STAGE_MIN_HEIGHT_M:
			_viewer_ground_y = _ground_below_y + 2.0

			# Only when the ground below has no collider yet: staging drops every coarse level, so over ground that is
			# already loaded it only made patches of it disappear and come back (Dave, 2026-10-21, hovering at 460 m).
			if _stage_view == 0.0 and not _stage_done:
				_stage_done = true

				if not _collider_below(here):
					_set_stage_view(1.0)
		elif _stage_view > 0.0:
			_set_stage_view(0.0)

	# The coarse levels follow once the ground under the player can be stood on.
	if _stage_view > 0.0 and not _building_paused and now >= _stage_next_msec and _collider_below(here):
		_set_stage_view(0.0)

	if _viewer != null:
		# The viewer stands on the ground under a player who stopped high up; everything else keeps the player's own anchor.
		_viewer.global_position = _anchor if is_nan(_viewer_ground_y) else Vector3(_anchor.x, _viewer_ground_y, _anchor.z)


# A collider under the player within 3000 m (the ground there has loaded).
func _collider_below(p: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + Vector3(0.0, -3000.0, 0.0))
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_surface_received(x: float, z: float, y: float) -> void:
	if is_finite(_check_pending.x) and absf(_check_pending.x - x) < 0.01 and absf(_check_pending.y - z) < 0.01:
		_check_pending = Vector2(NAN, NAN)
		_ground_check_compare(x, z, y)
		return

	_ground_below_xz = Vector2(x, z)
	_ground_below_y = y
	_surface_answered_msec = Time.get_ticks_msec()
	print("Terrain client: ground under (%.0f, %.0f) is at %.1f m" % [x, z, y])


# After a stop high up only the finest STAGE_LODS levels are built (the engine builds the coarsest first, so
# with all of them the ground under the player came last); 0 = all levels again.
func _set_stage_view(value: float) -> void:
	_stage_view = value
	terrain.lod_count = STAGE_LODS if value > 0.0 else LOD_COUNT
	var view: int = STAGE_VIEW_M if value > 0.0 else QUALITY_VIEW[quality]
	terrain.view_distance = view

	if _viewer != null:
		_viewer.view_distance = view
		_viewer.view_distance_vertical_ratio = STAGE_VERTICAL if value > 0.0 else 1.0

	_stage_next_msec = Time.get_ticks_msec() + STAGE_STEP_MIN_MSEC
	print("Terrain client: ground detail levels %d" % terrain.lod_count)


# Cover.at at a point, for the campfire blueprint colour.
func _cover_here(point: Vector3) -> bool:
	return CoverScript.at(point, flora.cover) > 0.0


# [chunk, id] of the standing tree whose trunk is within 1.3 m (flat distance) of the point, else [].
func _tree_trunk_near(point: Vector3) -> Array:
	for chunk in flora._chunks:
		var held_items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(held_items["ids"].size()):
			if flora._species.get(held_items["ids"][n] >> 16, {}).get("kind", 2) == 0 and Vector2(held_items["positions"][n].x - point.x, held_items["positions"][n].z - point.z).length() < 1.3:
				return [chunk, held_items["ids"][n]]

	return []


# E with nothing on the ground in reach: ask to gather the nearest plant or shrub within 2.5 m.
# The server decides whether it gives anything (data/items/drops.json) and removes it.
func _gather_nearest() -> void:
	var here: Vector3 = body.global_position
	var best: Array = []

	for chunk in flora._chunks:
		var held: Dictionary = flora._chunks[chunk]["items"]

		for n in range(held["ids"].size()):
			if flora._species.get(held["ids"][n] >> 16, {}).get("kind", 0) == 0:
				continue

			var d: float = Vector2(held["positions"][n].x - here.x, held["positions"][n].z - here.z).length()

			if d <= 2.5 and (best.is_empty() or d < best[0]):
				best = [d, chunk, held["ids"][n]]

	if not best.is_empty():
		net.cut_flora.rpc_id(1, best[1], best[2])


# Headless check: cut the tree nearest the spawn.
func _cut_nearest_tree() -> void:
	var spawn: Vector3 = world["spawn"]
	var best: Array = []

	for chunk in flora._chunks:
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			if flora._species.get(items["ids"][n] >> 16, {}).get("kind", 2) != 0:
				continue

			var d: float = (items["positions"][n] - spawn).length()

			if best.is_empty() or d < best[0]:
				best = [d, chunk, items["ids"][n]]

	if best.is_empty():
		print("Terrain client: no tree to cut")
		return

	print("Terrain client: asking to cut tree %d in chunk %s, %.0f m from the spawn" % [best[2], str(best[1]), best[0]])
	net.cut_flora.rpc_id(1, best[1], best[2])


func _make_player(root: Node3D, start: Vector3) -> void:
	body = CharacterBody3D.new()
	body.collision_mask = 3                # the ground (1) and ice sheets and floes (2)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	_shape = shape
	body.add_child(shape)
	root.add_child(body)
	body.global_position = start
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 0.7, 0.0)
	body.add_child(camera)
	# The eye node (`camera`) stays where the eyes are: aim, interaction rays, the held item and the sounds
	# all read it. What is drawn comes from a child camera that sits on the eye in first person and swings
	# up and back in third person (_update_view).
	view_cam = Camera3D.new()
	view_cam.far = 6000.0
	camera.add_child(view_cam)
	view_cam.current = true
	_load_view()
	var viewer: VoxelViewer = VoxelViewer.new()
	viewer.view_distance = VIEW_DISTANCE
	viewer.requires_collisions = true
	# Placed by _update_anchor, not carried by the player (owner 2026-10-19: no new ground
	# while flying). Starts at the player: left at the world origin for the first frame,
	# Voxel Tools queued about a thousand far blocks around (0, 0) that were loaded first.
	viewer.top_level = true
	viewer.position = start
	body.add_child(viewer)
	_viewer = viewer

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Applies the current quality preset to ground view distance, flora distances
# and shadows.
func _apply_quality() -> void:
	for n in range(_quality_buttons.size()):
		_quality_buttons[n].text = QUALITY_NAMES[n] + ("  (active)" if n == quality else "")

	if sound != null and sound.ambient != null:
		if _quality_cued >= 0 and _quality_cued != quality:
			sound.ui.play("ui_quality")

		_quality_cued = quality

		sound.set_quality(quality)

	var view: int = QUALITY_VIEW[quality]
	_stage_view = 0.0
	terrain.lod_count = LOD_COUNT
	terrain.view_distance = view

	if cache != null and cache_mb_from_quality:
		cache_mb = QUALITY_CACHE_MB[quality]
		cache.budget_bytes = cache_mb * 1024 * 1024

	if _viewer != null:
		_viewer.view_distance = view

	for n in range(_flora_view_full.size()):
		flora.view_m[n] = _flora_view_full[n] * float(QUALITY_FLORA[quality])

	for n in range(_flora_near_full.size()):
		flora.near_m[n] = _flora_near_full[n] * float(QUALITY_FLORA[quality])

	flora.set_quality(quality)
	if weather_look != null:
		weather_look.set_quality(quality)
	grass.points_per_side = QUALITY_GRASS_POINTS[quality]
	grass.density = QUALITY_GRASS_DENSITY[quality]
	grass.set_merge(4 if quality == 0 else 2)    # cells per MultiMesh side: fewer draw calls at Low (TD audit 2026-10-21)
	grass.set_radius(QUALITY_GRASS_M[quality])
	if terrain != null:
		GroundMaterialScript.set_grass_far(terrain.material as ShaderMaterial, QUALITY_GRASS_M[quality])
	grass.set_trample_rate(200 if quality == 0 else 100)   # the trample map upload: 5 Hz at Low, 10 Hz above
	grass.set_litter(QUALITY_LITTER_M[quality], QUALITY_LITTER_AMOUNT[quality], QUALITY_LITTER_CAP[quality])
	grass.set_shore(QUALITY_SHORE_M[quality], QUALITY_SHORE_AMOUNT[quality])
	if fall_mist != null:
		fall_mist.set_quality(quality)
	if fall_growth != null:
		fall_growth.set_quality(quality)

	if _environment != null:
		SkyClouds.set_quality(_environment.sky, quality)

	if sea != null:
		WaterMaterial.apply_quality(sea.material_override as ShaderMaterial, quality)

	if flora != null:
		flora.set_water_quality(quality)

	if _sun != null:
		_sun.shadow_enabled = float(QUALITY_SHADOW_M[quality]) > 0.0
		_sun.directional_shadow_max_distance = maxf(float(QUALITY_SHADOW_M[quality]), 1.0)
		# Two cascades instead of four at Medium and High: every cascade draws the casters again
		# (Godot's own shadow docs), and 100 m of range does not need four. A smaller shadow map at Medium.
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_split_1 = 0.3 if quality >= 3 else 0.1      # Ultra: two cascades (0 to 27 m, then to 90 m), not four (build 453)
		RenderingServer.directional_shadow_atlas_set_size(2048 if quality <= 1 else 4096, true)

	if terrain != null and quality != _ground_quality:
		_ground_quality = quality
		GroundMaterialScript.apply_quality(terrain.material as ShaderMaterial, quality)

	if _environment != null:
		LookSettings.apply(_environment, _sun, get_viewport(), quality)
		_apply_render_scale()
		_environment.fog_density = 0.05 if underwater else LookSettings.FOG_DENSITY


# Tells what the display setting really did, a moment later when the window had time to change:
# the window size the system gave us and the 3D size drawn. Inside the editor's Game tab the
# editor owns the window, so only the 3D size changes.
func _report_display(prefix: String = "") -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var win: Vector2i = get_window().size
	var render: Vector2i = Vector2i(Vector2(display.BASE) * _render_scale)
	var text: String = "%s3D picture %dx%d" % [prefix, render.x, render.y]

	if display.embedded():
		text += " (window %dx%d). The game runs inside the editor, which owns the window: it cannot be resized or made fullscreen from here, only the 3D size changes. To change the real window size, resize the Game tab or turn embedding off (Project > Run without embedding)." % [win.x, win.y]
	elif display.fullscreen:
		text += " in a fullscreen windowed screen of %dx%d." % [win.x, win.y]
	elif win != display.size():
		text += ". The system kept the window at %dx%d (asked for %s)." % [win.x, win.y, display.size_text()]
	else:
		text += ", window %dx%d." % [win.x, win.y]

	_menu_note.text = text


# Saves the window, VSync and quality choices (display_settings.gd).
func _save_display() -> void:
	display.quality = quality
	display.save()


# The 3D picture is the chosen size (Low at most 720p, Ultra a third larger), always 16:9.
func _apply_render_scale() -> void:
	if DisplayServer.get_name() == "headless":
		return

	# Owner (2026-10-20): the 3D picture is always the chosen size, 16:9, whatever shape the
	# window or the editor's Game tab has (display_settings.gd): a share of the fixed 2880x1620
	# canvas, scaled to the window with bars. Taller or smaller than the window is fine.
	_render_scale = float(display.render_size(quality).x) / float(display.BASE.x)
	var viewport: Viewport = get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if _render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = _render_scale


# The thinking-brain icon, a white outline with a gray inside. Loaded as an
# imported texture, or straight from the file if the editor has not imported it yet.
func _load_brain_icon() -> Texture2D:
	var path: String = "res://assets/ui/brain_icon.png"

	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D

		if imported != null:
			return imported

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null


# ------------------------------------------------------------------ options menu

# The Esc menu: Resume, Settings, Advanced (clear saved ground), Quit game.
func _build_menu(layer: CanvasLayer) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	layer.add_child(_menu)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	_menu.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)

	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "Dynasty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var main: VBoxContainer = _menu_page(column, "main")
	_menu_button(main, "Resume", func(): _set_menu(false))
	_menu_button(main, "Settings", func(): _show_menu_page("settings"))
	_menu_button(main, "Controls (every hotkey)", func(): _show_menu_page("controls"))
	_menu_button(main, "Advanced", func(): _show_menu_page("advanced"))
	_menu_button(main, "Quit game", func(): get_tree().quit())

	var controls: VBoxContainer = _menu_page(column, "controls")
	var controls_text: Label = Label.new()
	controls_text.text = HELP_TEXT
	controls_text.add_theme_font_size_override("font_size", 26)
	controls_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_text.custom_minimum_size = Vector2(1500.0, 0.0)
	controls.add_child(controls_text)
	_menu_button(controls, "Back", func(): _show_menu_page("main"))

	var settings: VBoxContainer = _menu_page(column, "settings")
	var quality_title: Label = Label.new()
	quality_title.text = "Quality"
	quality_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.add_child(quality_title)

	for n in range(QUALITY_NAMES.size()):
		var index: int = n
		var tier_button: Button = _menu_button(settings, QUALITY_NAMES[n], func():
			quality = index
			_apply_quality()
			_save_display()
			_menu_note.text = "Quality: %s (saved; the HUD shows it after the build number)" % QUALITY_NAMES[index])
		_quality_buttons.append(tier_button)

	_npc_voice_button = _menu_button(settings, "NPC voice: on", func():
		if _npc_voice != null:
			_npc_voice.set_enabled(not _npc_voice.enabled)
			_npc_voice_button.text = "NPC voice: %s" % ("on" if _npc_voice.enabled else "off"))
	_menu_button(settings, "Debug details (F3): on or off", func():
		debug_hud.enabled = not debug_hud.enabled
		_menu_note.text = "Debug details %s" % ("on" if debug_hud.enabled else "off"))
	_menu_button(settings, "VSync: change", func():
		display.vsync_index = (display.vsync_index + 1) % display.VSYNC_MODES.size()
		display.apply(get_window())
		_save_display()
		_menu_note.text = "VSync is now %s. On snaps to 60 or 30; adaptive avoids the halving; off shows the true speed." % display.VSYNC_NAMES[display.vsync_index])
	_menu_button(settings, "Resolution: change", func():
		display.size_index = (display.size_index + 1) % display.SIZES.size()
		display.apply(get_window())
		_apply_render_scale()
		_save_display()
		_report_display())
	_menu_button(settings, "Crafting screen text size: change", func():
		display.text_index = (display.text_index + 1) % display.TEXT_SCALES.size()
		items.set_text_scale(display.TEXT_SCALES[display.text_index])
		_save_display()
		_menu_note.text = "Crafting screen text: %s (saved)" % display.TEXT_NAMES[display.text_index])
	_menu_button(settings, "Reset display to default", func():
		display.reset()
		items.set_text_scale(display.TEXT_SCALES[display.text_index])
		quality = 2
		display.apply(get_window())
		_apply_quality()
		_save_display()
		_report_display("Display reset: High, windowed 1920x1080, VSync on. "))
	_menu_button(settings, "Window: windowed or fullscreen windowed", func():
		display.fullscreen = not display.fullscreen
		display.apply(get_window())
		_apply_render_scale()
		_save_display()
		_report_display())
	for level in [["master", "Master volume"], ["effects", "Effects volume (steps, tools, items, fire)"], ["ambient", "Ambient volume (wind, nature, weather)"], ["interface", "Interface volume"]]:
		_menu_slider(settings, level[1], float(sound.levels[level[0]]), func(value: float):
			sound.set_level(level[0], value)
			_menu_note.text = "%s %d %%" % [level[1].get_slice(" (", 0), roundi(value * 100.0)])
	for group in ["wind", "nature", "steps"]:
		_menu_button(settings, "%s volume: change" % group.capitalize(), func():
			var share: float = sound.mix_step(group)
			_menu_note.text = "%s sounds are off" % group.capitalize() if share <= 0.0 else "%s volume %d %%" % [group.capitalize(), roundi(share * 100.0)])
	_menu_button(settings, "Sound test time: change", func():
		var order: Array = [["day", 14.0, "autumn"], ["dawn", 6.0, "autumn"], ["dusk", 18.4, "autumn"], ["night", 23.0, "autumn"], ["winter day", 12.0, "winter"], ["summer dawn", 5.0, "summer"], ["spring night", 22.0, "spring"], ["clock runs", -1.0, "autumn"], ["world clock", -2.0, ""]]
		_sound_test_at = (_sound_test_at + 1) % order.size()
		var pick: Array = order[_sound_test_at]
		if float(pick[1]) == -2.0:
			_sound_test_at = -1
			_menu_note.text = "Nature sounds follow the world clock again."
			return

		sound.ambient.conditions["season"] = pick[2]
		sound.ambient.clock_runs = float(pick[1]) == -1.0

		if float(pick[1]) >= 0.0:
			sound.ambient.conditions["hour"] = pick[1]

		_menu_note.text = "Nature sounds now play as: %s (a test setting; the sky does not follow)" % pick[0])
	_menu_button(settings, "Sound test: town sounds", func():
		_sound_town_on = not _sound_town_on
		var here: Vector3 = body.global_position
		sound.town.set_sources([
			{"id": 1, "kind": "fire", "at": here + Vector3(6, 0, 0), "strength": 1.0},
			{"id": 2, "kind": "hammering", "at": here + Vector3(0, 0, 25), "strength": 1.0},
			{"id": 3, "kind": "crowd", "at": here + Vector3(-20, 0, 0), "strength": 1.0},
			{"id": 4, "kind": "bell", "at": here + Vector3(0, 20, -60), "strength": 1.0},
		] if _sound_town_on else [])

		if _sound_town_on:
			sound.town.ring_bell(here + Vector3(0, 20, -60), 3)

		_menu_note.text = "Town sounds %s (a test: a fire, a smith, a crowd and a bell placed around you)" % ("on" if _sound_town_on else "off"))
	_menu_button(settings, "Sound test: creature calls", func():
		var kinds: Array = sound.creatures.KINDS.keys()
		var moods: Array = ["idle", "alert", "threat"]
		_sound_creature_at = (_sound_creature_at + 1) % (kinds.size() * moods.size())
		var kind: String = kinds[_sound_creature_at / moods.size()]
		var mood: String = moods[_sound_creature_at % moods.size()]
		var distance: float = (float(sound.creatures.KINDS[kind]["dist"][0]) + float(sound.creatures.KINDS[kind]["dist"][1])) * 0.5
		var played: bool = sound.creatures.call_nearby(kind, mood, distance)
		_menu_note.text = "Creature call: %s, %s, about %.0f m away%s (press again for the next)" % [kind, mood, distance, "" if played else " (did not play)"])
	_menu_button(settings, "Sound test: spear", func():
		_sound_spear_at = (_sound_spear_at + 1) % 6
		var eye: Vector3 = camera.global_position
		var ahead: Vector3 = -camera.global_transform.basis.z

		if _sound_spear_at == 0:
			sound.spear.jab(eye + ahead * 1.0)
			_menu_note.text = "Spear jab (press again: throws into wood, stone, soil, flesh, then hits right here)"
		elif _sound_spear_at <= 4:
			var material: String = sound.spear.MATERIALS[_sound_spear_at - 1]
			sound.spear.throw(eye + ahead, eye + ahead * 30.0, 28.0, material)
			_menu_note.text = "Spear thrown 30 m ahead into %s" % material
		else:
			sound.spear.hit("wood", eye + ahead * 2.0, 1.0)
			_menu_note.text = "Spear hits wood two metres ahead")
	_menu_button(settings, "Sound test: fire", func():
		_sound_fire_at = (_sound_fire_at + 1) % 7
		_menu_note.text = _fire_test_step(_sound_fire_at, body.global_position + -camera.global_transform.basis.z * 3.0) + " (press again for the next)")
	_menu_button(settings, "Sound test: exertion", func():
		_sound_exertion_at = (_sound_exertion_at + 1) % 7
		var levels: Array = [0.0, 0.35, 0.6, 0.9, 1.0, 1.6]
		var notes: Array = ["Rested: silent", "Light exertion: soft slow breaths", "Hard exertion: clear quick breaths, heartbeat starts", "Severe exertion: gasps and a strong heartbeat", "Exhausted: fastest gasps (then it follows your running again)", "Over-exerted: racing heart, great chest heaves", "Faint demo, 27 s: over-exertion, forced slow-down, faint (world fades, only the heart, gone in 3 s), waking with the heart racing"]

		if _sound_exertion_at == 6:
			sound.breath.demo()
		else:
			sound.breath.set_exertion(levels[_sound_exertion_at])
		_menu_note.text = "%s (press again for the next)" % notes[_sound_exertion_at])
	_menu_button(settings, "Sound test: interior", func():
		_sound_interior_at = (_sound_interior_at + 1) % 5
		var here: Vector3 = body.global_position + -camera.global_transform.basis.z * 2.0
		var step: int = _sound_interior_at
		var notes: Array = ["Inside a house (press again: door open, door close, chest, then back outside)", "Door opens", "Door closes", "Chest opens", "Back outside"]
		var objects: Array = ["", "door_open", "door_close", "chest_open", ""]

		if step == 0:
			sound.interior.set_inside(1.0, "house")
		elif step == 4:
			sound.interior.set_inside(0.0)
		else:
			sound.interior.object(objects[step], here)

		_menu_note.text = notes[step])
	_menu_button(settings, "Sound test: gear", func():
		var sets: Array = [[], ["cloth"], ["leather", "hobnail"], ["chain", "iron"], ["plate", "iron"]]
		_sound_gear_at = (_sound_gear_at + 1) % sets.size()
		sound.gear.set_worn(sets[_sound_gear_at])
		_menu_note.text = "Gear worn: %s (walk to hear it on every step)" % (", ".join(sets[_sound_gear_at]) if not sets[_sound_gear_at].is_empty() else "none"))
	_menu_button(settings, "Sound test: swimming", func():
		sound.swim.demo()
		_menu_note.text = "A scripted swim: a splash, strokes, going under, surfacing (10 s; a test of the sounds)")
	_menu_button(settings, "Sound test: tool hit", func():
		_sound_hit_at = (_sound_hit_at + 1) % (sound.hits.TOOLS.size() * sound.hits.MATERIALS.size())
		var tool: String = sound.hits.TOOLS[_sound_hit_at / sound.hits.MATERIALS.size()]
		var material: String = sound.hits.MATERIALS[_sound_hit_at % sound.hits.MATERIALS.size()]
		sound.hits.hit(tool, material, body.global_position + -camera.global_transform.basis.z * 2.0, 1.0)
		_menu_note.text = "Tool hit: %s on %s (press again for the next; a test of the sounds, no tools exist yet)" % [tool, material])
	_menu_button(settings, "Sound test weather: change", func():
		var kinds: Array = sound.weather.KINDS.keys()
		_sound_weather_at += 1

		if _sound_weather_at >= kinds.size():
			_sound_weather_at = -1
			_menu_note.text = "Weather sounds follow the game's weather"
			return

		sound.weather.set_weather(kinds[_sound_weather_at], 1.0)
		_menu_note.text = "Weather sounds now play: %s (a test setting; the sky, ground, rain and snow follow it too). Press again until it follows the game's weather." % kinds[_sound_weather_at])
	_menu_button(settings, "Back", func(): _show_menu_page("main"))

	var advanced: VBoxContainer = _menu_page(column, "advanced")
	_menu_button(advanced, "Clear saved ground", func():
		_ask_clear_cache())
	_menu_button(advanced, "Dump ground at the crosshair (and copy it)", func():
		_dump_ground_here())
	_menu_button(advanced, "Show my player key (and copy it)", func():
		var key: String = items.player_key() if items != null else ""
		DisplayServer.clipboard_set(key)
		_menu_note.text = "Your player key (copied): %s\nPut it in data/admin.json as {\"keys\": [\"%s\"]}" % [key, key])
	_menu_button(advanced, "Admin: Bake starter tiles", func():
		var problem: String = _bake.start()
		_menu_note.text = "Baking the starter tiles in the background (about 5 to 10 minutes). The game stays usable; the result shows here." if problem == "" else problem)
	_menu_button(advanced, "Jitter test (next spot, or J)", func():
		_jitter_test.next_spot()
		_set_menu(false))
	_menu_button(advanced, "GPU breakdown (stand still; or Ctrl+Shift+G)", func():
		_set_menu(false)
		_gpu_probe.toggle())
	_menu_button(advanced, "Measure this machine (about 1 min)", func():
		_set_menu(false)
		_machine_probe.toggle())
	_menu_button(advanced, "Back", func(): _show_menu_page("main"))

	_menu_note = Label.new()
	_menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_note.custom_minimum_size = Vector2(380.0, 0.0)
	column.add_child(_menu_note)
	_show_menu_page("main")


# A labelled slider row for the menu (0 to 1); `changed` gets each new value.
func _menu_slider(parent: VBoxContainer, text: String, value: float, changed: Callable) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 24.0)
	slider.value_changed.connect(changed)
	parent.add_child(slider)


func _menu_page(parent: VBoxContainer, page_name: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.visible = false
	parent.add_child(page)
	_menu_pages[page_name] = page
	return page


func _menu_button(parent: VBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380.0, 52.0)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	button.pressed.connect(func(): sound.ui.play("ui_click") if sound != null else null)   # after the action: a cue it plays itself wins
	parent.add_child(button)
	return button


func _show_menu_page(page_name: String) -> void:
	for name in _menu_pages:
		_menu_pages[name].visible = name == page_name

	_menu_note.text = ""


func _set_menu(open: bool) -> void:
	menu_open = open
	_menu.visible = open

	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_menu_page("main")
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# "Clear saved ground": this client drops its own saved copy and reloads the
# terrain. The server's own saved ground is the server's business (its
# --clear-generated option); a client never clears it.
# Debug (Dave 2026-10-21, a solid block standing in the lake that goes away with Clear saved ground): what this client
# and the server's stores hold for the ground voxel the crosshair points at (Esc, Advanced, Dump ground; look at it first):
# the dump aims where the screen centre pointed when the menu opened. The text is printed, shown and copied.
var _dump_client: String = ""
var _starter_seeded: int = 0
var _ground_line: String = ""
var _ground_line_msec: int = 0
# Ground self-check (Dave's floating block and tan slab in the lake, 2026-10-21): every few seconds one point near
# the player is asked of the server (surface height from the generator) and the client's own ground there is found by
# a ray from above; ground more than GROUND_CHECK_TOLERANCE_M above the server's is logged with the coordinates
# (user://ground_mismatch.log), and the server's dump of that cell is logged next to it. --no-ground-check turns it off.
const GROUND_CHECK_EVERY_MSEC := 4000
const GROUND_CHECK_TOLERANCE_M := 3.0
const GROUND_CHECK_RINGS := [6.0, 15.0, 30.0, 50.0, 80.0]
var ground_check: bool = true
var _check_next_msec: int = 0
var _check_ring: int = 0
var _check_pending: Vector2 = Vector2(NAN, NAN)
var _check_dump_msec: int = 0
var check_samples: int = 0
var check_mismatches: int = 0
var check_last: String = "none yet"
var _check_dump_at: Vector3 = Vector3.INF


func _dump_ground_here(at: Vector3 = Vector3.INF) -> void:
	var from: Vector3 = view_cam.global_position if view_cam != null else camera.global_position
	var forward: Vector3 = -(view_cam if view_cam != null else camera).global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + forward * 400.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if at.is_finite():
		hit = {"position": at, "normal": Vector3.UP}

	if hit.is_empty():
		_menu_note.text = "Nothing solid under the crosshair within 400 m: look at the odd ground and try again"
		return

	var inside: Vector3 = hit["position"] - hit["normal"] * 0.5
	var voxel: Vector3i = Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("client: build %d, crosshair hit at (%.1f, %.1f, %.1f), voxel %s, normal %s" % [BUILD, hit["position"].x, hit["position"].y, hit["position"].z, str(voxel), str(hit["normal"])])
	var tool: VoxelTool = terrain.get_voxel_tool()
	lines.append("client: the terrain's voxel here: sdf %.2f (negative = solid)" % tool.get_voxel_f(voxel))
	var block: Vector3i = Vector3i(floori(float(voxel.x) / 16.0), floori(float(voxel.y) / 16.0), floori(float(voxel.z) / 16.0))
	var saved: VoxelBuffer = Layout.make_buffer(16)

	if cache != null and cache.load_block(saved, block, 0):
		var lx: int = voxel.x - block.x * 16
		var ly: int = voxel.y - block.y * 16
		var lz: int = voxel.z - block.z * 16
		lines.append("client: saved copy of block %s: sdf %.2f, soil %d, rock %d" % [str(block), saved.get_voxel_f(lx, ly, lz, Layout.CHANNEL_SDF), saved.get_voxel(lx, ly, lz, Layout.CHANNEL_SOIL), saved.get_voxel(lx, ly, lz, Layout.CHANNEL_ROCK)])
	else:
		lines.append("client: no saved copy of block %s at LOD 0" % str(block))

	lines.append("client: world tiles stamp %s, terrain version %s" % [str(world.get("tiles_stamp", "")), str(world.get("terrain_version", ""))])
	_dump_client = "\n".join(lines)
	net.request_dump.rpc_id(1, inside.x, inside.y, inside.z)
	_menu_note.text = _dump_client + "\n(asking the server...)"


func _on_dump_received(text: String) -> void:
	var all: String = _dump_client + "\n" + text
	print("Terrain client: ground dump\n" + all)

	if _check_dump_at.is_finite():
		_ground_check_log(all)
		_check_dump_at = Vector3.INF
	DisplayServer.clipboard_set(all)

	if _menu_note != null:
		_menu_note.text = all + "\n(copied to the clipboard)"


# Asks the server for the ground height at one point near the player (the rings rotate, the angle is random).
# --hole-probe: every second a 7 x 7 grid (50 m apart, 150 m each way) around the player is tested with rays straight
# down; a cell with no ground collider is a hole. Prints the count each second and a summary line with the worst hole.
func _hole_probe_step(now: int) -> void:
	if not hole_probe or now < _hole_next_msec or connected_msec <= 0 or body == null:
		return

	_hole_next_msec = now + 1000
	var centre: Vector2i = Vector2i(roundi(body.global_position.x / 50.0), roundi(body.global_position.z / 50.0))
	var missing: int = 0
	var seen: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state

	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var cell: Vector2i = centre + Vector2i(dx, dz)
			var top: Vector3 = Vector3(float(cell.x) * 50.0, body.global_position.y + 50.0, float(cell.y) * 50.0)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -1500.0, 0.0))
			q.exclude = [body.get_rid()]
			seen[cell] = true

			if space.intersect_ray(q).is_empty():
				missing += 1

				if not _hole_since.has(cell):
					_hole_since[cell] = now
			elif _hole_since.has(cell):
				var lasted: int = now - int(_hole_since[cell])

				if lasted > _hole_worst_msec:
					_hole_worst_msec = lasted
					_hole_worst_cell = cell

				_hole_since.erase(cell)

	for cell in _hole_since.keys():
		if not seen.has(cell):
			_hole_since.erase(cell)

	if _fly_stop_msec > 0 and not _hole_settled:
		_hole_max_after = maxi(_hole_max_after, missing)

		if missing == 0:
			_hole_settled = true
			print("Terrain client: hole probe: all 49 cells have ground %.1f s after the stop (worst %d missing right after it)" % [float(now - _fly_stop_msec) / 1000.0, _hole_max_after])

	_hole_samples += 1
	_hole_missing_total += missing
	_hole_max_count = maxi(_hole_max_count, missing)
	print("Terrain client: holes %d of 49 at %s; worst so far: %d cells missing at once, one cell missing %.1f s (cell %s); average %.1f" % [missing, str(body.global_position.round()), _hole_max_count, float(_hole_worst_msec) / 1000.0, str(_hole_worst_cell * 50), float(_hole_missing_total) / float(_hole_samples)])


func _ground_check_step(now: int) -> void:
	if not ground_check or now < _check_next_msec or connected_msec <= 0 or body == null:
		return

	_check_next_msec = now + GROUND_CHECK_EVERY_MSEC

	if _building_paused or is_finite(_check_pending.x):
		_check_pending = Vector2(NAN, NAN)
		return

	var ring: float = GROUND_CHECK_RINGS[_check_ring % GROUND_CHECK_RINGS.size()]
	_check_ring += 1
	var angle: float = randf() * TAU
	var x: float = snappedf(body.global_position.x + cos(angle) * ring, 0.5)
	var z: float = snappedf(body.global_position.z + sin(angle) * ring, 0.5)
	_check_pending = Vector2(x, z)
	net.request_surface.rpc_id(1, x, z)


func _ground_check_compare(x: float, z: float, server_y: float) -> void:
	var top: Vector3 = Vector3(x, server_y + 120.0, z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -400.0, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		check_last = "no collider yet at %.0f, %.0f" % [x, z]
		return

	check_samples += 1
	var client_y: float = hit["position"].y
	check_last = "%.0f, %.0f: client %.1f, server %.1f" % [x, z, client_y, server_y]

	if OS.has_environment("GROUND_CHECK_VERBOSE"):
		print("Terrain client: ground check " + check_last + ", column loaded " + str(stream.column_loaded(x, z)))

	if client_y - server_y <= GROUND_CHECK_TOLERANCE_M:
		return

	check_mismatches += 1
	var inside: Vector3 = hit["position"] - hit["normal"] * 0.5
	var line: String = "%s build %d GROUND MISMATCH at x %.1f z %.1f: client ground %.1f m, server %.1f m (%.1f m too high); player %s; voxel %s; lod_count %d, view %d; digs near: see the server dump" % [Time.get_datetime_string_from_system(true), BUILD, x, z, client_y, server_y, client_y - server_y, str(body.global_position.round()), str(Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))), terrain.lod_count, terrain.view_distance]
	print("Terrain client: " + line)
	_ground_check_log(line)

	if Time.get_ticks_msec() - _check_dump_msec > 20000:
		_check_dump_msec = Time.get_ticks_msec()
		_check_dump_at = inside
		_dump_ground_here(inside)

		# A picture of what Dave sees at that moment, next to the log (user://ground_mismatch_N.png).
		if DisplayServer.get_name() != "headless":
			var image: Image = get_viewport().get_texture().get_image()

			if image != null:
				image.save_png("user://ground_mismatch_%d.png" % check_mismatches)


func _ground_check_log(text: String) -> void:
	var file: FileAccess = FileAccess.open("user://ground_mismatch.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://ground_mismatch.log") else FileAccess.WRITE)

	if file != null:
		file.seek_end()
		file.store_line(text)
		file.close()


# Esc > Controls: every hotkey on one screen (CONTROLS.md has the full rules; keep this in step with it).
const HELP_TEXT := """Move: W A S D   Jog: double-tap W   Run: Shift+W   Jump / fly up: Space   Fly down: Ctrl   Walk or fly: G or F
Crouch C   Sit X   Lie down Z (hold Z 3 s to sleep)   Mouse wheel: third-person camera
E: gather, drink, fill, talk, open (hold E for the long action)   Left click: use held item   Right click: aim or eat
I: crafting and inventory   Tab: character screen   1 to 9, 0: hotbar   Split S, Drop D, Use E, Repair R, Transfer T (inventory)
/: inspection mode   + and -: spring flow (tuning)
F2: quality   F3: debug details   Ctrl+Shift+G: GPU probe table (press again to close)   J: jitter test
Admin: Ctrl+N nearest NPC   Ctrl+R rabbit   Ctrl+X dig hole   ]: starter items   Esc > Advanced > Dump ground: crosshair ground report
Esc: this menu"""


# One line for screenshots: terrain version, tile stamp, starter ground, saved ground (size, hits, misses) and the guards' counts.
func _ground_health_line() -> String:
	var now: int = Time.get_ticks_msec()

	if now - _ground_line_msec > 5000 and cache != null and stream != null:
		_ground_line_msec = now
		_ground_line = "ground v%s  tiles %s  starter %s\nsaved %.0f MB  %d hit  %d miss  refused %d" % [str(world.get("terrain_version", "?")), str(world.get("tiles_stamp", "?")), ("seeded" if _starter_seeded > 0 else "none"), float(cache.size_bytes()) / 1048576.0, cache.hits, cache.misses, stream.zeroed_blocks + stream.bad_blocks + stream.timeouts]

	return _ground_line


func _ask_clear_cache() -> void:
	_reload_ground()
	_menu_note.text = "Done. The ground is reloading."
	print("Terrain client: cleared the saved ground and reloaded the terrain")


# The server made its ground again from new tile files (a bake finished): drop the
# saved ground and the plants and load them again, and close the menu.
func _on_ground_reset(tiles_stamp: String, starter_stamp: String) -> void:
	world["tiles_stamp"] = tiles_stamp
	world["starter_stamp"] = starter_stamp
	_reload_ground()

	_in_generation += 1

	if flora != null:
		for chunk in flora.held_chunks():
			flora.drop_chunk(chunk)

		_flora_asked.clear()

	_set_menu(false)
	_bake_status = _bake_done_note if _bake_done_note != "" else "Finished: new tiles loaded, the ground and plants are reloading"
	_bake_done_note = ""
	# Owner (2026-10-19): the finished notice stays until the player moves.
	_bake_alert_until = 1 << 62
	_bake_alert_at = body.global_position if body != null else Vector3.ZERO
	print("Terrain client: the tile files changed on the server; reloaded the ground and plants")


func _reload_ground() -> void:
	cache.clear_all()
	stream.close()
	stream = StreamScript.new()
	stream.cache = cache
	stream.link = link
	link.stream = stream
	terrain.stream = stream
	cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))


# Inspection mode (the / key): names whatever the crosshair points at. Checked
# ten times a second with one physics ray, so it costs next to nothing.
func _update_inspect() -> void:
	_set_inspect_text_from(_inspect_target())

	if test_inspect and _inspect_label.text != _last_inspected:
		_last_inspected = _inspect_label.text
		print("Terrain client: inspect -> '%s'" % _last_inspected)


func _set_inspect_text_from(text: String) -> void:
	if text != "<wait>":
		_inspect_label.text = text


func _inspect_target() -> String:
	var now: int = Time.get_ticks_msec()

	if now < _inspect_msec:
		return "<wait>"

	_inspect_msec = now + 100
	knowledge.admin = flying
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 30.0)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return ""

	var collider: Object = hit["collider"]
	var species: int = -1

	# A tree trunk: its shape number says which species it is.
	if collider != null and collider.has_meta("species_ids"):
		var ids: PackedInt32Array = collider.get_meta("species_ids")
		var index: int = int(hit["shape"])

		if index >= 0 and index < ids.size():
			species = ids[index]

	var point: Vector3 = hit["position"]

	if species < 0:
		species = flora.species_near(point, 1.3)

	if species >= 0:
		return knowledge.reveal("f%d" % species, flora.label_of(species), flora.familiarity_of(species), "horticulture", flora.lookalikes(species))

	var lying: String = items.world_item_name_near(point, 1.2)

	if lying != "":
		return lying

	return _ground_name(point - hit["normal"] * 0.4)


# The ore, rock or soil at a point in the ground, as this character knows it. Owner
# (2026-10-20): the label must match what the player sees. Ore sits in the resource channel
# all the way up to the surface, but under soil cover (grass, dirt, mud: the material
# channel is a soil, not rock) the ore is buried and must not be named; only ore in bare rock
# (material is rock) is exposed.
func _ground_name(point: Vector3) -> String:
	var tool: VoxelTool = terrain.get_voxel_tool()
	var cell: Vector3i = Vector3i(point.floor())
	tool.channel = Layout.CHANNEL_MATERIAL
	var material: int = tool.get_voxel(cell)

	if material < Layout.MATERIAL_ROCK:
		return _known_from_table("soils", "s", material)

	tool.channel = Layout.CHANNEL_RESOURCE
	var resource: int = tool.get_voxel(cell)

	if resource > 0:
		return _known_from_table("resources", "o", resource)

	return _known_from_table("rocks", "r", material - Layout.MATERIAL_ROCK)


func _known_from_table(table: String, prefix: String, id: int) -> String:
	var label: String = ""
	var familiarity: int = 50
	var others: Array = []

	for entry in _tables.get_entries(table):
		var name: String = str(entry.get("display", entry["name"]))

		if int(entry["id"]) == id:
			label = name
			familiarity = int(entry.get("familiarity", 50))
		elif int(entry["id"]) > 0:
			others.append(name)

	if label == "":
		return "Ground"

	return knowledge.reveal("%s%d" % [prefix, id], label, familiarity, "geology", others)


func _make_environment(root: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	# Long parallel stripes on ground and water were shadow acne: bigger biases (2026-10-18, judged from screenshots only).
	sun.shadow_bias = 0.3
	sun.shadow_normal_bias = 3.0
	sun.directional_shadow_blend_splits = true
	_sun = sun
	root.add_child(sun)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = SkyClouds.make_sky(quality)
	environment.fog_enabled = true
	environment.fog_density = 0.0004
	# The fog used to paint the whole sky grey (owner, 2026-10-19: "the sky has nothing");
	# the sky shader hazes its own horizon, and the fog colour matches that horizon.
	environment.fog_sky_affect = 0.0
	environment.fog_light_color = SkyClouds.HORIZON
	_environment = environment
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	sea = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	sea.mesh = plane
	sea.material_override = WaterMaterial.make()   # the same look as the rivers
	root.add_child(sea)



# Third-person view (Dave, 2026-10-21): scroll out from first person to look at yourself from up and back
# of the shoulders; scrolling out more pulls the camera further away, scrolling in comes back and, past
# the nearest distance, returns to first person. The distance is remembered between sessions.
const VIEW_FILE := "user://view.txt"
const VIEW_MIN_M := 1.6
const VIEW_MAX_M := 7.0
const VIEW_STEP_M := 0.4
const VIEW_HEIGHT := 0.12              # camera rise per metre of distance
const VIEW_CLEAR_M := 0.25             # how far short of a wall or trunk the camera stops

var view_cam: Camera3D
var third_person: bool = false
var debug_pace: float = -1.0                              # shot runner only: pretend to move at this speed (m/s) so the walk animation plays
var _view_m: float = 3.0
var _view_now: float = 0.0             # the distance drawn now (eases out and in, and shortens when blocked)
var _avatar                                               # the ragdoll body (src/client/ragdoll_body.gd), feet on the ground under the capsule


func _load_view() -> void:
	if FileAccess.file_exists(VIEW_FILE):
		_view_m = clampf(float(FileAccess.get_file_as_string(VIEW_FILE)), VIEW_MIN_M, VIEW_MAX_M)


func _save_view() -> void:
	var file: FileAccess = FileAccess.open(VIEW_FILE, FileAccess.WRITE)

	if file != null:
		file.store_string("%.2f" % _view_m)


# Wheel steps: out (down) enters third person at the saved distance and then pulls further; in (up) comes
# closer and, at the nearest distance, goes back to first person.
func _scroll_view(out: bool) -> void:
	if out:
		if not third_person:
			third_person = true
		else:
			_view_m = minf(_view_m + VIEW_STEP_M, VIEW_MAX_M)
	elif third_person:
		if _view_m - VIEW_STEP_M < VIEW_MIN_M - 0.001:
			third_person = false
		else:
			_view_m -= VIEW_STEP_M

	_save_view()


# Each drawn frame: place the drawn camera, keep it out of walls and trunks, and show the ragdoll body.
func _update_view(delta: float) -> void:
	if view_cam == null or body == null:
		return

	if _avatar == null:
		_avatar = _make_avatar()
		body.add_child(_avatar)

	var want: float = _view_m if third_person else 0.0
	var eye: Vector3 = camera.global_position
	var aim: Vector3 = camera.global_transform.basis * Vector3(0.0, VIEW_HEIGHT, 1.0)

	if third_person and want > 0.0:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + aim * want)
		query.exclude = [body.get_rid()]
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

		if not hit.is_empty():
			want = maxf(eye.distance_to(hit["position"]) - VIEW_CLEAR_M, 0.0)

	# Pull in at once when blocked, ease out otherwise.
	_view_now = want if want < _view_now else lerpf(_view_now, want, clampf(delta * 10.0, 0.0, 1.0))

	if absf(_view_now - want) < 0.01:
		_view_now = want

	view_cam.position = Vector3(0.0, VIEW_HEIGHT, 1.0) * _view_now
	_avatar.visible = _view_now > 0.5

	if held != null:
		held.set_first_person(_view_now <= 0.5)
	_avatar.animation_player.active = _avatar.visible      # no animation cost in first person
	# Feet on the ground whatever the stance (the capsule's bottom stays put; the body origin is its standing middle).
	_avatar.position.y = -float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5

	if _avatar.visible:
		var pace: float = Vector2(body.velocity.x, body.velocity.z).length() if debug_pace < 0.0 else debug_pace
		var clip: String = ["idle", "crouch", "sit", "lie"][stance.stance]

		if stance.stance == StanceScript.STAND and pace > 0.6:
			# Walk, jog or run by the real speed, with a margin so the clip does not flicker at a limit; the playback speed keeps the
			# stride on the ground (natural speeds 1.4, 3.2 and 6.0 m/s, see ragdoll_body.gd).
			var current_clip: String = _avatar.current()
			var jog_from: float = 2.2 if current_clip != "jog" and current_clip != "run" else 1.8
			var run_from: float = 5.0 if current_clip != "run" else 4.4
			clip = "run" if pace > run_from else ("jog" if pace > jog_from else "walk")

		if _avatar.current() != clip and not _avatar.is_one_shot_playing():
			_avatar.play(clip, 1.0, 0.25)

		_avatar.animation_player.speed_scale = clampf(pace / 1.4, 0.5, 1.7) if clip == "walk" else (clampf(pace / 3.2, 0.8, 1.6) if clip == "jog" else (clampf(pace / 6.0, 0.8, 2.0) if clip == "run" else 1.0))

		# Lean into a slope: uphill by the slope angle (up to 25 degrees), downhill a little back (Tyler's table).
		var tilt: float = 0.0

		if body.is_on_floor() and pace > 0.6 and clip != "idle":
			var n: Vector3 = body.global_transform.basis.inverse() * body.get_floor_normal()
			var angle: float = atan2(n.z, maxf(n.y, 0.1))
			tilt = clampf(angle, -0.1, 0.44) if angle > 0.0 else clampf(angle * 0.4, -0.1, 0.0)

		_avatar.rotation.x = lerpf(_avatar.rotation.x, -tilt, minf(1.0, 6.0 * get_process_delta_time()))


# The plain ragdoll character (owner, 2026-10-21): body, head, arms, legs and hands, no features.
func _make_avatar() -> Node3D:
	var avatar: Node3D = RagdollScript.new()
	avatar.visible = false
	return avatar


func _unhandled_input(event: InputEvent) -> void:
	if body == null:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if items != null and items.screen_open():
			items.close()
			return

		_set_menu(not menu_open)
		return

	if menu_open:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I and items != null:
		items.toggle()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and items != null:
		items.toggle_character()
		return

	if items != null and items.screen_open():
		if event is InputEventKey and event.pressed and not event.echo:
			items.quick_key(event)

		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scroll_view(event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held != null and held.mouse_button(event.button_index, event.pressed):
		pass
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and not event.pressed and event.keycode == KEY_E and items != null:
		items.release_e()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			var now: int = Time.get_ticks_msec()

			if now - _last_w_msec <= DOUBLE_TAP_MSEC:
				jogging = true

			_last_w_msec = now
		elif event.keycode == KEY_SLASH:
			inspecting = not inspecting
			status_icons.tick(0.0, true)
			sound.ui.play("ui_on" if inspecting else "ui_off")

			if not inspecting:
				_inspect_label.text = ""
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
			net.step_water_rate.rpc_id(1, 1)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			net.step_water_rate.rpc_id(1, -1)
		elif event.keycode == KEY_X and event.ctrl_pressed:
			_admin_dig()
		elif event.keycode == KEY_N and event.ctrl_pressed:
			_go_to_npc()
		elif event.keycode == KEY_R and event.ctrl_pressed:
			_admin_rabbit()
		elif event.keycode == KEY_C and not flying:
			_set_stance(StanceScript.CROUCH, true)
		elif event.keycode == KEY_X and not flying:
			_set_stance(StanceScript.SIT, true)
		elif event.keycode == KEY_Z and not flying:
			if stance.stance == StanceScript.LIE and items != null and not items.asleep:
				_z_down_msec = Time.get_ticks_msec()   # lying: hold Z to sleep, tap to get up (decided on release, see _check_sleep_hold)
				_z_slept = false
			elif items != null and items.asleep:
				items.request_sleep(0)
			else:
				_set_stance(StanceScript.LIE, true)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9 and held != null:
			held.press_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0 and held != null:
			held.press_slot(9)
		elif event.keycode == KEY_E and items != null:
			items.press_e()
		elif event.keycode == KEY_BRACKETRIGHT and items != null:
			items.admin_give_test_set()
		elif event.keycode == KEY_J and _jitter_test != null:
			_jitter_test.next_spot()
		elif event.keycode == KEY_G and event.ctrl_pressed and event.shift_pressed:
			_gpu_probe.toggle()
		elif event.keycode == KEY_F3:
			debug_hud.enabled = not debug_hud.enabled
		elif event.keycode == KEY_F2:
			quality = (quality + 1) % QUALITY_NAMES.size()
			_apply_quality()
			_save_display()
		elif event.keycode == KEY_G or event.keycode == KEY_F:
			flying = not flying
			body.velocity = Vector3.ZERO


# Owner (2026-10-20): movement felt jerky. The game draws about 30 frames a second but
# physics ticked 60 times a second, so a drawn frame covered 1, 2 or 3 ticks (per-frame
# speed 6 to 58 m/s at an 11 m/s jog). The player now moves once per drawn frame by the
# real frame time (called first thing in _process), so every frame moves by the same
# amount of time that passed since the last one.
func _step_player(delta: float) -> void:
	if body == null:
		return

	delta = minf(delta, 0.1)
	_check_sleep_hold()
	var t: int = Probe.start()
	_move_player(delta)
	Probe.stop("player move", t)
	var ts: int = Probe.start()
	# The real exertion from Items (strain climbs past 1 to over-exertion, faint and waking, server-owned); the
	# stand-in body estimate only runs without it and in the sound tests.
	if items != null and not test_exertion and not test_faint and sound.breath._demo_t < 0.0:
		var shown: Array = items.faint_state()
		faint.set_state(shown[0], items.strain, shown[1])      # every frame: the picture eases toward it, so it is smooth (Dave 2026-10-21)
		# Asleep or just woken from sleep: the world sound follows the picture's black (sleeping, then waking as it clears).
		var heard: String = shown[0]
		var heard_progress: float = shown[1]

		if heard == "sleeping":
			heard_progress = faint.blackout
		elif heard == "normal" and faint.blackout > 0.02:
			heard = "waking"
			heard_progress = faint.blackout

		sound.breath.set_server_heart(float(items.body_bpm), items.body_phase)
		sound.breath.set_body(items.strain, heard, heard_progress)

	var tsd: int = Probe.start()
	if swimming:
		sound.forget_fall(body)   # landing in deep water breaks the fall: no height is carried on to the shore

	sound.update(delta, body, flying, underwater)
	Probe.stop("sound", tsd)

	if items != null:
		items.character_update(delta)

	_item_sync_left -= delta

	if _item_sync_left <= 0.0:
		_item_sync_left = 0.1
		sound.itemfx.watch(items)
		sound.itemfx.watch_vitals(items.hunger, 0.1)
		sound.breath.set_exertion(items.strain)   # the server's real strain replaces the stand-in
		_sync_cleared()

	_fire_sync_left -= delta

	if _fire_sync_left <= 0.0 and items != null:
		_fire_sync_left = 0.25

		if not test_fire and not test_fire_world and not sound.fire.manual_active():
			sound.fire.sync_world(items._world, _cover_here)

		sound.placed.watch_world(items._world, body.global_position)
		sound.placed.watch_open(items._world, body.global_position)

	_tree_sync_left -= delta

	if _tree_sync_left <= 0.0 and items != null:
		_tree_sync_left = 0.25
		sound.trees.watch(items._world)

	Probe.stop("sound", ts)


# Changes the stance (a toggle when `toggle`); standing up is refused under a low roof.
func _set_stance(wanted: int, toggle: bool = false) -> void:
	var target: int = StanceScript.STAND if toggle and stance.stance == wanted else wanted

	if target < stance.stance and not _room_to_rise(target):
		_menu_note.text = "Not enough room to stand up here"
		return

	if stance.set_stance(target):
		stance.apply_shape(_shape)
		status_icons.tick(0.0, true)

		if items != null:
			items.request_stance(stance.stance)   # the server: sitting and lying bring exertion down


# The server's answer (or its own change: fainting forces lying, walking off stands you up).
# Lying and holding Z for sleep.json hold_s asks to sleep; letting go sooner gets you up like before.
func _check_sleep_hold() -> void:
	if _z_down_msec < 0:
		return

	if not Input.is_key_pressed(KEY_Z):
		if not _z_slept:
			_set_stance(StanceScript.LIE, true)

		_z_down_msec = -1
	elif not _z_slept and items != null and float(Time.get_ticks_msec() - _z_down_msec) / 1000.0 >= SLEEP_HOLD_S:
		_z_slept = true
		items.request_sleep(1)


func _on_stance_from_server(confirmed: int) -> void:
	if confirmed != stance.stance and stance.set_stance(confirmed):
		stance.apply_shape(_shape)
		status_icons.tick(0.0, true)


# True when a capsule of the taller stance fits where the player is.
func _room_to_rise(target: int) -> bool:
	var taller: CapsuleShape3D = CapsuleShape3D.new()
	taller.radius = 0.33
	taller.height = float(StanceScript.SHAPE_HEIGHT[target])
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = taller
	var feet_y: float = body.global_position.y - float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5
	query.transform = Transform3D(Basis.IDENTITY, Vector3(body.global_position.x, feet_y + float(StanceScript.SHAPE_HEIGHT[target]) * 0.5 + 0.05, body.global_position.z))
	query.exclude = [body.get_rid()]
	return get_viewport().world_3d.direct_space_state.intersect_shape(query, 1).is_empty()


func _move_player(delta: float) -> void:
	if menu_open:
		body.velocity = Vector3.ZERO
		return

	var input: Vector3 = Vector3(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		0.0,
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if items != null and items.screen_open():
		input = Vector3.ZERO   # the inventory's quick keys (S split) are not walking

	var direction: Vector3 = body.global_transform.basis * input

	# Any movement key stands the player up from sitting or lying; those stances do not move.
	var sleeping_now: bool = items != null and items.asleep

	if sleeping_now and Input.is_key_pressed(KEY_SPACE) and input == Vector3.ZERO:
		# Dave 2026-10-21: holding Space wakes a sleeper early (not fully rested: the energy stays where it was).
		_space_wake_s += delta

		if _space_wake_s >= SPACE_WAKE_S:
			_space_wake_s = 0.0
			items.request_sleep(0)
	else:
		_space_wake_s = 0.0

	if input != Vector3.ZERO or (Input.is_key_pressed(KEY_SPACE) and not sleeping_now):
		if stance.stance >= StanceScript.SIT:
			_set_stance(StanceScript.STAND)

	stance.step(delta)

	if test_walk:
		_walk_step()
		direction = _walk_dir
	var fast: float = FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var forward: bool = Input.is_key_pressed(KEY_W)
	var strain_cap: float = items.move_cap() if items != null and not flying else 0.0

	# Gaits (CONTROLS.md): walk is plain WASD, jog is a double-tap of W, run is
	# Shift with W. Letting go of W ends both.
	if not forward:
		jogging = false

	running = forward and Input.is_key_pressed(KEY_SHIFT) and strain_cap == 0.0

	if strain_cap != 0.0:
		jogging = false
	var pace: float = RUN_SPEED if running else (JOG_SPEED if jogging else WALK_SPEED)

	if not flying and stance.stance != StanceScript.STAND:
		running = false
		jogging = false
		pace = WALK_SPEED * float(StanceScript.SPEED[stance.stance])

	if items != null and not flying:
		pace *= items.speed_factor() * items.over_pace_factor()

		if strain_cap > 0.0:
			pace = minf(pace, strain_cap)
		elif strain_cap < 0.0:
			pace = 0.0   # fainted or waking: no control

	if test_speed > 0.0 and frames_left > 0:
		if test_fly:
			flying = true

			if Time.get_ticks_msec() - connected_msec > test_fly_msec:
				test_speed = 0.0
				_fly_stop_msec = Time.get_ticks_msec()
				stream.watch_xz = Vector2(body.global_position.x, body.global_position.z)
				stream.watch_on = true

		if test_fly and test_fly_alt > 0.0:
			body.global_position.y = test_fly_alt

		body.global_position.x += test_speed * delta * test_route.x
		body.global_position.z += test_speed * delta * test_route.y
	elif test_fly and _fly_stop_msec > 0 and _fly_ground_msec == 0:
		var below: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(body.global_position, body.global_position + Vector3(0.0, -3000.0, 0.0))
		below.exclude = [body.get_rid()]

		if not body.get_world_3d().direct_space_state.intersect_ray(below).is_empty():
			_fly_ground_msec = Time.get_ticks_msec()
	elif flying:
		direction.y += float(Input.is_key_pressed(KEY_SPACE)) - float(Input.is_key_pressed(KEY_CTRL))
		body.global_position += direction * FLY_SPEED * fast * delta
	else:
		var velocity: Vector3 = direction.normalized() * (run_speed if run_speed > 0.0 and test_walk else pace)

		# Gravity only applies once there is ground below to land on. Fresh
		# or far-off ground has no collision yet, so wait for it; a player who
		# already fell below it is lifted back to the surface.
		# Without ground to land on yet, glide level instead of falling or
		# standing frozen: the ground appears as collision loads.
		var tq: int = Probe.start()
		waiting_for_ground = not _ground_ready()
		Probe.stop("p ground_ready", tq)

		if test_walk and _walk_phase == 2:
			_slowest_frame = maxf(_slowest_frame, delta)

			if waiting_for_ground:
				_wait_frames += 1

		if _was_waiting and not waiting_for_ground:
			_arrive_on_ground()

		_was_waiting = waiting_for_ground

		# The --runspeed walk test measures running (strain), not swimming: it crosses the pond east of the spawn on dry-land rules.
		var water: Dictionary = {} if waiting_for_ground or (test_walk and run_speed > 0.0) else _water_here()
		swimming = not water.is_empty() and SwimScript.swimming(body.global_position.y, float(water["surface"]), float(water["ground"]))

		if waiting_for_ground:
			velocity.y = 0.0
		elif swimming:
			velocity = _swim_velocity(velocity, direction, pace, fast > 1.0, strain_cap, float(water["surface"]), delta)
		else:
			velocity.y = body.velocity.y - GRAVITY * delta

			# Wading: water over the knees slows a walker.
			if not water.is_empty() and body.is_on_floor():
				var slow: float = SwimScript.wade_factor(WaterVolume.depth(float(water["surface"]), float(water["ground"])))
				velocity.x *= slow
				velocity.z *= slow

		if not swimming and body.is_on_floor() and Input.is_key_pressed(KEY_SPACE) and strain_cap >= 0.0:
			velocity.y = 7.0
			sound.footstep(body, 1, -3.0, "right")        # the push off the ground (job 61: a jump had no sound, only the landing)

		body.velocity = velocity
		var tm: int = Probe.start()
		body.move_and_slide()
		Probe.stop("p slide", tm)

		if body.is_on_floor():
			_floor_msec = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _floor_msec > 1200 and _under_the_ground():
			rescued += 1

		var tb: int = Probe.start()
		_update_bob(delta)
		Probe.stop("p bob", tb)

	if flying:
		_bob_amount = 0.0
		camera.position = Vector3(0.0, 0.7, 0.0)
		camera.rotation.z = 0.0

		if stance.stance != StanceScript.STAND:
			_set_stance(StanceScript.STAND)

	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)
	_update_underwater()


# The water at the player: {"surface", "ground"} when they are in or over water deeper than a film
# (a lake or river level from the water grid, or the sea at 0 m), else {}. One ray down, only when
# water is near the player.
func _water_here() -> Dictionary:
	var here: Vector3 = body.global_position
	var surface: float = flora.water_surface_at(here.x, here.z) if flora != null else NAN

	if is_nan(surface) and here.y > 2.0:
		return {}

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 0.5, 0.0), here + Vector3(0.0, -250.0, 0.0), 1)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	var ground: float = float(hit["position"].y) if not hit.is_empty() else NAN

	if is_nan(surface):
		if is_nan(ground) or ground >= 0.0:
			return {}

		surface = 0.0

	return {"surface": surface, "ground": ground}


# The swimmer's velocity: strokes at the swim pace (never more than the walking pace the player's
# load and strain allow), buoyancy and Space/Ctrl up and down, and the pull-out onto a bank or floe
# edge (walking into a ledge up to CLIMB_MAX_M above the water climbs it).
func _swim_velocity(wanted: Vector3, direction: Vector3, pace: float, hard: bool, strain_cap: float, surface: float, delta: float) -> Vector3:
	var now: int = Time.get_ticks_msec()
	var velocity: Vector3 = wanted
	var horizontal: Vector3 = direction.normalized() * minf(pace, SwimScript.pace(hard)) if direction != Vector3.ZERO else Vector3.ZERO

	if strain_cap < 0.0:
		horizontal = Vector3.ZERO

	var up: bool = Input.is_key_pressed(KEY_SPACE) and strain_cap >= 0.0
	var down: bool = Input.is_key_pressed(KEY_CTRL) and strain_cap >= 0.0
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = SwimScript.vertical_speed(body.global_position.y, surface, body.velocity.y, up, down, delta, items.breath_ds >= 0 and items.breath_ds < 100)

	# Under a floe or an ice sheet: with no stroke given, drift gently out to the nearest open water.
	if now >= _under_ice_next_msec:
		_under_ice_next_msec = now + 250
		_ice_gap = _under_ice_way_out()

	if _ice_gap != Vector3.ZERO:
		velocity.y = minf(velocity.y, 0.0)

		if horizontal == Vector3.ZERO:
			velocity.x = _ice_gap.x * 2.0
			velocity.z = _ice_gap.z * 2.0

	# Pull-out: pressing on into a bank or floe edge a little above the water.
	if now < _climb_until_msec:
		velocity.y = SwimScript.CLIMB_SPEED
		velocity.x = direction.normalized().x * 2.0
		velocity.z = direction.normalized().z * 2.0
	elif horizontal != Vector3.ZERO and body.is_on_wall() and _ledge_ahead(direction.normalized(), surface):
		_climb_until_msec = now + 450

	return velocity


# Whether a ledge the swimmer can climb lies just ahead: solid ground whose top is within
# CLIMB_MAX_M above the water, with room to stand.
func _ledge_ahead(forward: Vector3, surface: float) -> bool:
	var here: Vector3 = body.global_position
	var ahead: Vector3 = here + forward * SwimScript.CLIMB_REACH_M
	var top: Vector3 = Vector3(ahead.x, surface + SwimScript.CLIMB_MAX_M + 0.6, ahead.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -2.0, 0.0), 3)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return false

	var ledge: float = float(hit["position"].y)
	return Vector3(hit["normal"]).y > 0.6 and ledge > surface - 0.3 and ledge <= surface + SwimScript.CLIMB_MAX_M


# Unit vector (zero when not under ice) toward the nearest open water when a floe or an ice sheet is
# overhead: looks straight up for a collider on the ice layer, then in 8 directions out to 28 m for a
# spot with open sky above the water.
func _under_ice_way_out() -> Vector3:
	var here: Vector3 = body.global_position
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 0.9, 0.0), here + Vector3(0.0, 4.0, 0.0), 2)

	var overhead: Dictionary = space.intersect_ray(query)

	if overhead.is_empty():
		return Vector3.ZERO

	for distance in [4.0, 8.0, 16.0, 28.0]:
		for step in range(8):
			var angle: float = float(step) * TAU / 8.0
			var way: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
			var from: Vector3 = here + way * distance + Vector3(0.0, 0.9, 0.0)
			var probe: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, 4.0, 0.0), 2)

			if space.intersect_ray(probe).is_empty():
				return way

	# A frozen pond with no way out (frozen over while swimming under it): no stuck states, so the
	# swimmer comes up through the ice onto it.
	body.global_position.y = float(overhead["position"].y) + SwimScript.BODY_HEIGHT_M * 0.5 + 0.05
	body.velocity = Vector3.ZERO
	return Vector3.ZERO


# A very small up-and-down camera bob while walking on the ground. Its speed
# follows the pace and its height grows only a little, to avoid motion sickness.
func _update_bob(delta: float) -> void:
	var pace: float = Vector2(body.velocity.x, body.velocity.z).length()
	var moving: bool = body.is_on_floor() and pace > 1.0
	_bob_amount = move_toward(_bob_amount, 1.0 if moving else 0.0, delta * 6.0)
	var gait: int = 2 if running else (1 if jogging else 0)

	if moving:
		# One full turn of the phase is one step (a footfall at 0, then at TAU).
		var before: float = _bob_phase
		_bob_phase = fposmod(_bob_phase + delta * pace / float(STEP_M[gait]) * TAU, 2.0 * TAU)

		if floor(before / TAU) != floor(_bob_phase / TAU):
			sound.footstep(body, gait, 0.0, "left" if _bob_phase < TAU else "right")

	var dip: float = 0.5 * (1.0 + cos(_bob_phase))            # 1 at a footfall, 0 mid-stride
	var side: float = cos(_bob_phase * 0.5)                   # +1 left foot, -1 right foot
	camera.position.y = stance.eye_y - float(BOB_M[gait]) * dip * _bob_amount
	camera.position.x = -float(SWAY_M[gait]) * side * _bob_amount
	camera.rotation.z = deg_to_rad(float(SWAY_DEG[gait])) * side * _bob_amount


# One step of the fire sound test (button and --fire): returns what it did.
func _fire_test_step(step: int, at: Vector3) -> String:
	sound.fire.hold_manual(12.0)
	var fire := {"id": 1, "at": at, "size": 0.3, "lit": true, "open": true}
	var note: String = ""

	if step == 0:
		fire["lit"] = false
		sound.weather.set_weather("clear", 1.0)
		sound.fire.set_fires([fire])
		note = "Unlit fire placed three metres ahead (silent)"
	elif step == 1:
		sound.fire.set_fires([fire])
		note = "Fire lit: small embers"
	elif step == 2:
		fire["size"] = 1.0
		sound.fire.set_fires([fire])
		note = "Fire grows to a bonfire"
	elif step == 3:
		fire["size"] = 1.0
		sound.weather.set_weather("rain", 1.0)
		sound.fire.set_fires([fire])
		note = "Rain starts on the open fire (sizzle)"
	elif step == 4:
		fire["lit"] = false
		sound.fire.set_fires([fire])
		note = "Fire put out (hiss)"
	elif step == 5:
		sound.weather.set_weather("clear", 1.0)
		sound.fire.set_fires([fire])
		note = "Fire lit again, rain gone"
	else:
		sound.fire.set_fires([])
		note = "Fire removed (fades)"

	return note


func _process(delta: float) -> void:
	if pickup_feed != null:
		pickup_feed.update(delta)

	var tp: int = Probe.start()
	_step_player(delta)
	Probe.stop("step player", tp)
	tp = Probe.start()
	_update_view(delta)
	Probe.stop("update view", tp)
	tp = Probe.start()

	if harvest != null:
		harvest.update(delta, Input.is_key_pressed(KEY_E) and not items.open)
	game_clock.tick()
	_update_weather()
	Probe.stop("harvest, clock, weather", tp)

	if _sound_test_at < 0 and sound != null and sound.ambient != null:
		sound.ambient.set_conditions(game_clock.hour(), game_clock.season())

	if _water_label != null and _water_label.text != "" and Time.get_ticks_msec() > _water_label_until_msec:
		_water_label.text = ""

	_frame_ms.append(delta * 1000.0)
	Probe.frame(delta)

	if compass != null and camera != null:
		compass.heading = CompassScript.heading_of(camera)

	if _frame_ms.size() > 120:
		_frame_ms.pop_front()

	if stream == null:
		return

	if test_start.is_finite() and Time.get_ticks_msec() - _test_probe_msec > 10000 and connected_msec > 0:
		_test_probe_msec = Time.get_ticks_msec()
		var probes: PackedStringArray = PackedStringArray()

		for east in [60.0, 110.0, 220.0, 600.0]:
			var top: Vector3 = Vector3(test_start.x + east, 900.0, test_start.z)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top, top + Vector3(0.0, -1300.0, 0.0))
			var h: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(q)
			probes.append("+%dm east: %s" % [int(east), ("ground at %.0f" % h["position"].y) if not h.is_empty() else "NO GROUND"])

		print("Terrain client: probe %d s after the welcome, player at %s: %s" % [(Time.get_ticks_msec() - connected_msec) / 1000, str(body.global_position.round()), ", ".join(probes)])

	_ground_check_step(Time.get_ticks_msec())
	_hole_probe_step(Time.get_ticks_msec())

	if test_dump and not _test_dump_done and Time.get_ticks_msec() - connected_msec > 14000:
		_test_dump_done = true
		_dump_ground_here(body.global_position + Vector3(0.0, -1.0, 0.0))

	if test_clear and not _test_clear_done and Time.get_ticks_msec() - connected_msec > 12000:
		_test_clear_done = true
		_ask_clear_cache()

	var ta0: int = Probe.start()
	_update_anchor(Time.get_ticks_msec(), delta)
	Probe.stop("anchor", ta0)
	# Owner (2026-10-19): while a bake runs, ask only for the ground the game is waiting on
	# right now, not the extra ground around it (it is all thrown away when the bake ends).
	stream.only_urgent = _bake.running
	link.pump()
	var wanted: Array = [PackedInt32Array(), 0] if _building_paused else stream.take_requests()

	if not wanted[0].is_empty() and not link.send_request(wanted[0], wanted[1]):
		net.request_blocks.rpc_id(1, wanted[0], wanted[1])

	var now: int = Time.get_ticks_msec()

	# Tell the server where we are heading so it makes that ground first.
	if now - _aim_msec >= 200:
		var here: Vector3 = _anchor
		var seconds: float = float(now - _aim_msec) / 1000.0

		if _aim_msec > 0:
			net.report_position.rpc_id(1, here, (here - _aim_pos) / seconds)

		_aim_msec = now
		_aim_pos = here

	if now >= _budget_check_msec:
		# Writing the pending blocks and counting the cache folder's size are disk work (on a
		# slow disk, tens to hundreds of ms): a worker thread does it, one run at a time.
		_budget_check_msec = now + 15000

		if _cache_task >= 0 and not WorkerThreadPool.is_task_completed(_cache_task):
			_budget_check_msec = now + 2000
		else:
			if _cache_task >= 0:
				WorkerThreadPool.wait_for_task_completion(_cache_task)

				if _cache_removed > 0:
					print("Terrain client: cache over %d MB, removed %d far tiles" % [cache_mb, _cache_removed])

			var p: Vector3 = body.global_position
			_cache_tile = cache.tile_of_block(Vector3i(int(floor(p.x / 16.0)), 0, int(floor(p.z / 16.0))), 0)
			_cache_removed = 0
			_cache_task = WorkerThreadPool.add_task(_cache_upkeep)

	settled_msec = stream.last_load_msec - connected_msec

	var ti: int = Probe.start()
	_send_water_request(now)
	_apply_incoming()
	Probe.stop("incoming", ti)

	if now >= _flora_check_msec:
		_flora_check_msec = now + 500
		var tf: int = Probe.start()
		_update_flora()
		Probe.stop("flora update", tf)

	if flora != null:
		var ta: int = Probe.start()
		flora.apply_built()
		Probe.stop("flora apply", ta)

	if not flying and body != null:
		var tg: int = Probe.start()
		grass.update(body.global_position)

		# Stamped behind the player, out of view, so no grass is seen dropping flat in front of the camera
		# (owner, 2026-10-20: "popping in and out of existence right in front of me").
		var walk: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)

		if body.is_on_floor() and walk.length() > 0.5:
			grass.stamp(body.global_position - walk.normalized() * 1.3)
		Probe.stop("grass", tg)

	if _bake.running and now >= _bake_check_msec:
		_bake_check_msec = now + 2000
		_bake_status = _bake.status()

		if menu_open:
			_menu_note.text = _bake_status

		var finished: String = _bake.poll()

		# The ground reloads (and the finished notice shows) when the server sees the new tiles.
		if finished != "":
			_bake_done_note = finished
			_bake_status = "The bake is done; the ground reloads in a few seconds"
			_menu_note.text = _bake_status
			print("Terrain client: ", finished)

	if test_water_step and now - connected_msec > 12000:
		test_water_step = false
		net.step_water_rate.rpc_id(1, 1)
		net.step_water_rate.rpc_id(1, 1)

	if test_cut and now - connected_msec > 25000:
		test_cut = false
		_cut_nearest_tree()

	# Headless check: every creature call in every mood, then by zone.
	if test_creatures and now - connected_msec > 18000 and now >= _test_creature_at:
		_test_creature_at = now + 400
		var kinds: Array = sound.creatures.KINDS.keys() + ["bird"]
		var moods: Array = ["idle", "alert", "threat"]
		var step: int = _test_creature_step
		_test_creature_step += 1

		if step < kinds.size() * moods.size():
			var kind: String = kinds[step / moods.size()]
			var at: Vector3 = body.global_position + Vector3(30.0, 2.0, 0.0)
			print("Terrain client: creature test %s %s -> %s" % [kind, moods[step % moods.size()], sound.creatures.call_at(kind, at, moods[step % moods.size()])])
		elif step < kinds.size() * moods.size() + 8:
			print("Terrain client: creature zone test -> %s" % sound.creatures.call_in_zone(["forest", "meadow", "highland", "water"][step % 4], "idle"))
		else:
			test_creatures = false
			sound.creatures.wild = true                              # then the natural far calls run on their own

	# Headless check: exertion steps (rested, light, hard, severe) a few seconds each.
	if test_exertion and now - connected_msec > 18000:
		if _test_exertion_t < 0.0:
			_test_exertion_t = 0.0

		_test_exertion_t += get_process_delta_time()
		var step: int = int(_test_exertion_t / 5.0)
		var levels: Array = [0.0, 0.35, 0.6, 0.9]

		if step >= levels.size():
			test_exertion = false
			print("Terrain client: exertion check done: %d breaths, %d heartbeats, last %s" % [sound.breath.breaths_played, sound.breath.beats_played, sound.breath.last])
		else:
			sound.breath.set_exertion(levels[step])
			if fmod(_test_exertion_t, 5.0) < get_process_delta_time():
				print("Terrain client: exertion %.2f: %d breaths, %d heartbeats so far" % [levels[step], sound.breath.breaths_played, sound.breath.beats_played])

	# Headless check: hold a real torch, then rain on it, then put it away.
	if test_flame and now - connected_msec > 18000:
		if _test_flame_t < 0.0:
			_test_flame_t = 0.0
			net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, items.table.number_of("torch"), 0, 1, Vector3.ZERO)

		var before: float = _test_flame_t
		_test_flame_t += get_process_delta_time()

		if before < 2.0 and _test_flame_t >= 2.0:
			for slot in range(8):
				if items.inventory.numbers[slot] == items.table.number_of("torch"):
					held.select(slot)

		if before < 5.0 and _test_flame_t >= 5.0:
			print("Terrain client: flame held '%s', loops %d, last %s" % [sound.flame.held, sound.flame._loops.size(), sound.flame.last])
			sound.weather.set_weather("rain", 1.0)

		if before < 9.0 and _test_flame_t >= 9.0:
			print("Terrain client: flame in rain: loops %s" % str(sound.flame._loops.keys()))
			held.select(7)

		if before < 12.0 and _test_flame_t >= 12.0:
			print("Terrain client: flame put away: held '%s', loops %d" % [sound.flame.held, sound.flame._loops.size()])
			test_flame = false

	# Headless check: make cordage (twine), a stone axe (knap) and a campfire (stack) through the panel's craft timer.
	if test_craft_sounds and now - connected_msec > 18000:
		if _test_craft_t < 0.0:
			_test_craft_t = 0.0
			items.admin_give_test_set()

		var before: float = _test_craft_t
		_test_craft_t += get_process_delta_time()

		for at in [[2.0, 1], [6.0, 2], [11.0, 4]]:
			if before < at[0] and _test_craft_t >= at[0]:
				items._start_craft(at[1])
				print("Terrain client: craft %d started, can_make %s, queue %d" % [at[1], items.recipes.can_make(at[1], items.inventory), items.craft_entries.size()])

		for at in [5.0, 10.0, 16.0]:
			if before < at and _test_craft_t >= at:
				print("Terrain client: craft work sounds %d, last %s" % [sound.itemfx.work_played, sound.itemfx.last_work])

		if _test_craft_t > 16.5:
			test_craft_sounds = false

	# Headless check: strikes at 300, 1000 and 2500 m take the plain, mid and far thunder buses with a scaled, capped delay.
	if test_distant and now - connected_msec > 18000:
		test_distant = false

		for metres in [300.0, 1000.0, 2500.0]:
			sound.weather.strike(metres)
			print("Terrain client: thunder %s" % sound.weather.last_thunder)

	# Headless check: an axe in the bag is worn out client-side, then mended; the tool break and repair sounds follow.
	if test_wear and now - connected_msec > 18000:
		if _test_wear_t < 0.0:
			_test_wear_t = 0.0
			net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, items.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

		var before_wear: float = _test_wear_t
		_test_wear_t += get_process_delta_time()
		var axe_slot: int = items.inventory.numbers.find(items.table.number_of("stone_axe"))

		if before_wear < 1.5 and _test_wear_t >= 1.5 and axe_slot >= 0:
			var life: int = int(items.table.entry("stone_axe").get("durability", 0))
			items.inventory.wear[axe_slot] = int(float(life) * 0.85)      # condition 0.15: under the warning line

		if before_wear < 3.0 and _test_wear_t >= 3.0 and axe_slot >= 0:
			items.tool_event.call("broke")

		if before_wear < 5.0 and _test_wear_t >= 5.0 and axe_slot >= 0:
			items.tool_event.call("repaired")

		if _test_wear_t > 7.0:
			test_wear = false
			print("Terrain client: wear sounds %s, last %s" % [str(sound.placed.played), sound.placed.last])

	# Headless check: the tree counts around the player and the wind-in-trees loops they start.
	if test_treewind and now - connected_msec > 18000:
		var before_tw: float = _test_treewind_t
		_test_treewind_t = maxf(_test_treewind_t, 0.0) + get_process_delta_time()

		for at in [4.0, 12.0, 20.0]:
			if before_tw < at and _test_treewind_t >= at:
				print("Terrain client: tree wind: conifer %.2f, broadleaf %.2f, wind %.2f, playing %s" % [sound.treewind._density["conifer"], sound.treewind._density["broadleaf"], sound.wind_strength, sound.treewind.summary])

		if _test_treewind_t > 20.5:
			test_treewind = false

	# Headless check: a chopping block, a plank drop and two saw mills (one running, one idle) beside the player.
	if test_workshop and now - connected_msec > 18000:
		var before_ws: float = _test_workshop_t
		_test_workshop_t = maxf(_test_workshop_t, 0.0) + get_process_delta_time()
		var at_ws: Vector3 = body.global_position + Vector3(4.0, 0.0, 0.0)

		if before_ws < 1.0 and _test_workshop_t >= 1.0:
			sound.workshop.chop(at_ws, false)
			sound.workshop.chop(at_ws, true)
			sound.workshop.plank_drop(at_ws)
			sound.workshop.set_saws([{"id": 1, "at": at_ws, "running": true}, {"id": 2, "at": at_ws + Vector3(0.0, 0.0, 5.0), "running": false}])

		if before_ws < 4.0 and _test_workshop_t >= 4.0:
			print("Terrain client: workshop sounds %s, saw loops %d, last %s" % [str(sound.workshop.played), sound.workshop.loops_playing, sound.workshop.last])
			sound.workshop.set_saws([])

		if before_ws < 9.0 and _test_workshop_t >= 9.0:
			print("Terrain client: workshop saw loops after stop %d" % sound.workshop.loops_playing)
			test_workshop = false

	# Headless check: the cooking and eating sounds play (sizzle and fuel at a spot beside the player, then each way of eating).
	if test_cooking and now - connected_msec > 18000:
		test_cooking = false
		var spot: Vector3 = body.global_position + Vector3(1.5, 0.0, 0.0)
		sound.fire.cook(spot)
		sound.fire.fuel(spot)

		for kind in ["crunch", "soft", "drink", "roast_forage", "raspberries", "poultice_plantain", "bandage_plantain"]:
			sound.itemfx.eat(kind)

		sound.itemfx.watch_vitals(10, 200.0)
		# A mouthful at the water's edge (Dave 2026-10-21): E sends the drink, the server raises thirst, the gulp plays; a rise without E is silent.
		items.thirst = 50
		var before_drink: int = sound.itemfx.eat_played
		items._on_vitals(items.hunger, items.health, int(items.weight_kg * 10.0), 60, items.luck, items.fitness)
		var silent_rise: int = sound.itemfx.eat_played - before_drink
		items._drink_msec = Time.get_ticks_msec()
		items._on_vitals(items.hunger, items.health, int(items.weight_kg * 10.0), 70, items.luck, items.fitness)
		print("Terrain client: drink check: %d gulps without E, %d gulp after E, last %s" % [silent_rise, sound.itemfx.eat_played - before_drink - silent_rise, sound.itemfx.last])

		print("Terrain client: cooking sounds: sizzle %d, fuel %d, eaten %d, growls %d, last fire %s, last item %s" % [sound.fire.cook_played, sound.fire.fuel_played, sound.itemfx.eat_played, sound.itemfx.growls_played, sound.fire.last, sound.itemfx.last])

	# Headless check: every placed-thing hook once, then a synthetic chest row appears and vanishes beside the player.
	if test_placed and now - connected_msec > 18000:
		test_placed = false
		var here: Vector3 = body.global_position + Vector3(2.0, 0.0, 0.0)
		sound.placed.place("leanto", here)
		sound.placed.place("chest", here)
		sound.placed.place("stone", here)
		sound.placed.pick_up(here)
		sound.placed.container(true, here)
		sound.placed.container(false, here)
		sound.placed.tool_break(here)
		sound.placed.tool_repair(here)
		sound.placed.watch_world({}, here)
		sound.placed.watch_world({7: {"state": 6, "pos": here}}, here)
		sound.placed.watch_world({}, here)
		print("Terrain client: placed sounds %s, last %s" % [str(sound.placed.played), sound.placed.last])
		test_structures = true

	# Headless check (a few seconds after the placed hooks have finished sounding): openable structures and their world-row watcher.
	if test_structures and now - connected_msec > 26000:
		test_structures = false
		var here: Vector3 = body.global_position + Vector3(2.0, 0.0, 0.0)
		var objects_before: int = sound.interior.objects_played
		var kinds_played: int = 0

		for kind in ["door", "gate", "hatch", "chest"]:
			kinds_played += int(sound.placed.use(kind, true, here)) + int(sound.placed.use(kind, false, here, 0.4))

		var unknown_kind: bool = sound.placed.use("trapdoor", true, here)
		var lock_knock: int = int(sound.placed.lock(true, here)) + int(sound.placed.lock(false, here)) + int(sound.placed.knock(here))
		var direct: int = sound.interior.objects_played - objects_before
		sound.placed.open_kinds = {90: "door"}
		objects_before = sound.interior.objects_played
		sound.placed.watch_open({5: {"state": 90, "pos": here, "open": 0}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here, "open": 0}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here, "open": 1}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here, "open": 1}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here, "open": 0}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here + Vector3(200.0, 0.0, 0.0), "open": 1}}, here)
		sound.placed.watch_open({5: {"state": 90, "pos": here + Vector3(200.0, 0.0, 0.0), "open": 0}}, here)
		print("Terrain client: structure check: %d uses, unknown %s, lock and knock %d, played %d, watched flips %d, last %s" % [kinds_played, str(unknown_kind), lock_knock, direct, sound.interior.objects_played - objects_before, sound.interior.last])
		sound.placed.open_kinds = {}

	# Headless check: the volume sliders change the buses and reset.
	if test_levels and now - connected_msec > 18000:
		test_levels = false
		var report: String = ""

		for setting in [["master", 0.5], ["effects", 0.0], ["ambient", 0.25], ["interface", 0.8]]:
			sound.set_level(setting[0], setting[1])

		for bus_name in ["Master", "Foley", "Wind", "Nature", "Weather", "Interface"]:
			var index: int = AudioServer.get_bus_index(bus_name)
			report += " %s %.1f dB%s;" % [bus_name, AudioServer.get_bus_volume_db(index), " muted" if AudioServer.is_bus_mute(index) else ""]

		print("Terrain client: levels set:%s" % report)

		for name in sound.levels:
			sound.set_level(name, 1.0)

		print("Terrain client: levels back to 100 %%: %s" % str(sound.levels))

	# Headless check: place, light, grow, rain on, put out, light, remove.
	if test_fire and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 1200
		print("Terrain client: fire step %d: %s" % [_test_fire_step, _fire_test_step(_test_fire_step, body.global_position + Vector3(3.0, 0.0, 0.0))])
		_test_fire_step += 1

		if _test_fire_step >= 7:
			test_fire = false

	# Hotbar ticks: slot 2, the same slot again (silent), slot 5, back to 0.
	if test_ui_sounds and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 700
		var picks: Array = [2, 2, 5, 0]

		if _ui_step < picks.size():
			held.select(picks[_ui_step])
			_ui_step += 1
		elif _ui_step == picks.size():
			print("Terrain client: ui sounds: %d hotbar ticks, last %s" % [sound.itemfx.hotbar_played, sound.itemfx.last])
			_ui_step += 1

	# Lake: still water is silent. Squares 8 to 14 m away: 10 s calm (no laps), then 10 s windy (rare laps, waits cut to a tenth);
	# the classification table and the near-lake quieting are asserted too.
	if test_lake and now - connected_msec > 18000:
		var water = sound.water

		if water.test_shore.is_empty():
			var at: Vector3 = body.global_position
			water.test_shore = [{"at": at + Vector3(8.0, -1.0, 0.0)}, {"at": at + Vector3(-10.0, -1.0, 6.0)}, {"at": at + Vector3(0.0, -1.0, -14.0)}]
			water.lap_scale = 0.1
			water.test_wind = 0.0
			_lake_start_msec = now
		elif now - _lake_start_msec > 10000 and water.test_wind == 0.0:
			_lake_calm_laps = water.laps_played
			water.test_wind = 1.0
			water._lap_left = 0.5
		elif now - _lake_start_msec > 25000 and test_lake:
			test_lake = false
			var table: String = "%s %s %s %s %s" % [water.kind_for(25, 0.8), water.kind_for(20, 0.1), water.kind_for(12, 0.9), water.kind_for(10, 0.1), water.kind_for(3, 0.4)]
			var at2: Vector3 = body.global_position
			var lakes: Array = [{"kind": "pond", "at": at2 + Vector3(10.0, 0.0, 0.0)}]
			var flowing: Array = [{"kind": "river", "at": at2 + Vector3(20.0, 0.0, 0.0)}, {"kind": "brook", "at": at2 + Vector3(-8.0, 0.0, 0.0)}, {"kind": "river", "at": at2 + Vector3(0.0, 0.0, 60.0)}]
			var kept: int = water.quiet_near_lakes(lakes, flowing, at2).size()
			print("Terrain client: lake laps: %d laps calm, %d laps windy, last %s; brook loop %s; kinds %s; flowing near lake kept %d of 3 (silenced %d)" % [_lake_calm_laps, water.laps_played - _lake_calm_laps, water.last_lap, water.brook_tag(), table, kept, water.lake_silenced])
			water.test_shore = []

	# Frozen pond (job 88): cold air, full ice cover and stand-in shore squares. Then groans come, no laps even in a gale,
	# steps may crack; after the thaw the pond is open water again (no groans, laps allowed, steps splash).
	if test_ice and now - connected_msec > 18000:
		var water2 = sound.water
		var weather2 = sound.weather
		var ice = sound.ice

		if water2.test_shore.is_empty():
			var at3: Vector3 = body.global_position
			water2.test_shore = [{"at": at3 + Vector3(8.0, -1.0, 0.0)}, {"at": at3 + Vector3(-10.0, -1.0, 6.0)}, {"at": at3 + Vector3(0.0, -1.0, -14.0)}]
			water2.lap_scale = 0.1
			water2.test_wind = 1.0
			water2._lap_left = 0.5
			weather2.temp_c = -8.0
			weather2.ice_cover = 1.0
			ice.groan_scale = 0.05
			ice._groan_left = 0.5
			_ice_start_msec = now
		elif now - _ice_start_msec > 12000 and _ice_report == "":
			var walk_frozen: bool = ice.walkable()
			var groans: int = ice.groans_played
			var laps: int = water2.laps_played

			for k in range(40):
				ice.step(body.global_position, 2, 1.0)
				ice.test_release()

			var cracks: int = ice.cracks_played
			ice.test_release()
			weather2.temp_c = 6.0
			weather2.ice_cover = 0.0
			water2._lap_left = 0.5
			_ice_report = "%s %d %d %d %s" % [str(walk_frozen), groans, laps, cracks, ice.last]
		elif now - _ice_start_msec > 20000 and test_ice:
			test_ice = false
			print("Terrain client: ice: frozen walkable %s, %d groans, %d laps, %d cracks in 40 hard steps, last %s; thaw walkable %s, %d new groans, %d new laps" % [
				_ice_report.get_slice(" ", 0), int(_ice_report.get_slice(" ", 1)), int(_ice_report.get_slice(" ", 2)), int(_ice_report.get_slice(" ", 3)),
				_ice_report.get_slice(" ", 4, ), str(ice.walkable()), ice.groans_played - int(_ice_report.get_slice(" ", 1)), water2.laps_played - int(_ice_report.get_slice(" ", 2))])
			water2.test_shore = []

	# Wind in structures (job 89): five set-ups three seconds each; the report holds whistle and moan levels in dB (-80 stopped).
	if test_windhole and now - connected_msec > 18000:
		var hole = sound.windhole
		var phases: Array = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.5), Vector3(1.0, 1.0, 1.0), Vector3(0.2, 1.0, 0.0)]
		var step: int = int((now - connected_msec - 18000) / 3000)

		if step < phases.size():
			hole.test_inputs = phases[step]

			if (now - connected_msec - 18000) % 3000 > 2500 and _windhole_report.size() == step:
				_windhole_report.append("%.0f %.0f" % [hole.player_db("wind_whistle"), hole.player_db("wind_hollow")])
		elif test_windhole:
			test_windhole = false
			hole.test_inputs = Vector3(-1.0, 0.0, 0.0)
			print("Terrain client: wind hole: open %s, lean-to %s, mouth %s, tunnel %s, calm %s (whistle and moan dB, -80 off)" % _windhole_report)

	if test_voice_priority and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		print("Terrain client: voice priority: " + sound.test_priority(body))

	# Season and clock sweep: each cell is two seconds at the fast nature clock (--nature-fast).
	if test_sweep and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 2000
		var seasons: Array = ["spring", "summer", "autumn", "winter"]
		var cells: int = seasons.size() * 8

		if _sweep_step >= 0 and _sweep_step <= cells:
			var done: int = _sweep_step - 1

			if done >= 0:
				var total: int = 0

				for kind in sound.ambient.calls_played:
					total += int(sound.ambient.calls_played[kind])

				_sweep_max = maxi(_sweep_max, _sweep_peak)
				print("Terrain client: sweep cell %s %02d:00 calls %d voices %d  %s" % [seasons[done / 8], (done % 8) * 3, total, _sweep_peak, str(sound.ambient.calls_played)])

		if _sweep_step < cells:
			_sweep_step += 1

			if _sweep_step < cells:
				sound.ambient.set_conditions(float((_sweep_step % 8) * 3), seasons[_sweep_step / 8], "clear")
				sound.ambient.calls_played = {}
				_sweep_peak = 0
		elif _sweep_step == cells:
			_sweep_step += 1
			print("Terrain client: sweep done: %d cells, peak %d of %d voices, shed %d" % [cells, _sweep_max, sound.voice_cap, sound.shed_count])

	if test_sweep:
		_sweep_peak = maxi(_sweep_peak, sound.voices_playing())

	if test_emitters and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var here: Vector3 = body.global_position
		var em = sound.emitters
		var wolf: bool = em.emit("wolf", "call_threat", here + Vector3(60.0, 0.0, 0.0), 1.0, 7)
		var deer: bool = em.emit("deer", "call_idle", here + Vector3(30.0, 0.0, 0.0), 1.0, 8)
		var burst: int = 0

		for k in range(6):
			if em.emit("hum", "tick", here + Vector3(8.0, 0.0, 0.0), 1.0, 9):
				burst += 1

		var nothing: bool = em.emit("ghost", "moan", here, 1.0, 10)
		var rows: Array = [{"id": 1, "kind": "hum", "loop": "hum", "at": here + Vector3(5.0, 0.0, 0.0)}, {"id": 2, "kind": "hum", "loop": "hum", "at": here + Vector3(0.0, 0.0, 6.0)}]

		for k in range(12):
			rows.append({"id": 100 + k, "kind": "hum", "loop": "hum", "at": here + Vector3(30.0 + float(k), 0.0, 0.0)})

		for k in range(3):
			rows.append({"id": 200 + k, "kind": "hum", "loop": "hum", "at": here + Vector3(0.0, 0.0, -35.0 - float(k))})

		em.sync(rows)
		print("Terrain client: emitter test: creature wolf %s deer %s, burst %d of 6 played, %d dropped, unknown %s, 17 rows -> %d loops, %d merged" % [str(wolf), str(deer), burst, em.dropped_rate, str(nothing), em.loops_playing(), em.merged_loops])

	if test_mix_levels:
		sound.track_peaks = now - connected_msec > 20000

		if now - connected_msec > 50000 and test_mix_levels:
			test_mix_levels = false
			sound.track_peaks = false
			print("Terrain client: mix levels: " + sound.mix_table())

	if test_landing and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		sound.landing.hurt.connect(func(drop, severity): _hurts.append([drop, severity]))

		sound.landing.landings = {}
		_hurts = []

		for drop in [1.0, 3.0, 7.0]:
			sound.landing.land(body, drop)

		var counts: Dictionary = sound.landing.landings
		print("Terrain client: landing check: step %d thud %d hard %d, %d hurt signals, severity %.2f, last %s" % [int(counts.get("step", 0)), int(counts.get("thud", 0)), int(counts.get("hard", 0)), _hurts.size(), float(_hurts[0][1]) if not _hurts.is_empty() else -1.0, sound.landing.last])

	if test_stepfx and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var fx = sound.stepfx
		fx.step(1, -35.0, "water", 0.4)
		var wet_start: float = fx.wetness
		var before: int = fx.squelches

		for k in range(10):
			fx.step(0, -35.0, "dirt", 0.0)

		var squelched: int = fx.squelches - before
		fx.update(10.0)
		var half: float = fx.wetness
		fx.update(15.0)
		var dry_before: int = fx.squelches

		for k in range(10):
			fx.step(0, -35.0, "dirt", 0.0)

		print("Terrain client: stepfx check: wet %.2f, %d squelches in 10 steps, wetness after 10 s %.2f, after 25 s %.2f, %d squelches when dry, %d cloth steps, last %s" % [wet_start, squelched, half, fx.wetness, fx.squelches - dry_before, fx.cloth_steps, fx.last])

	if test_swing and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var before: int = sound.hits.swings_played
		var heard: Array = []

		for tool in sound.hits.TOOLS:
			heard.append(sound.hits.swing(tool, body.global_position + Vector3(0.0, 1.0, -0.6)))

		print("Terrain client: swing check: %d swings, unknown tool %s, last %s" % [sound.hits.swings_played - before, str(sound.hits.swing("sword", body.global_position)), sound.hits.last_swing])

	if test_insects and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0}
		var levels: Array = []
		sound.weather.rain = 0.0
		sound.wind_strength = 0.3
		sound.cave.enclosure = 0.0

		for combo in [["summer", 13.0], ["summer", 2.0], ["winter", 13.0], ["spring", 13.0], ["summer", 5.7], ["summer", 20.8]]:
			amb.set_conditions(float(combo[1]), str(combo[0]), "clear")
			levels.append("%.2f" % sound.insects.target())

		amb.set_conditions(13.0, "summer", "clear")
		amb.weights = {"forest": 0.0, "meadow": 0.0, "water": 1.0, "highland": 0.0}
		var lake_noon: String = "%.2f" % sound.insects.target()
		var lake_cricket: bool = amb._water_day()
		amb.set_conditions(2.0, "summer", "clear")
		var lake_night: String = "%.2f" % sound.insects.target()
		amb.set_conditions(13.0, "summer", "clear")
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0}
		sound.weather.rain = 1.0
		levels.append("%.2f" % sound.insects.target())
		sound.weather.rain = 0.0
		sound.insects.level = 0.9
		sound.insects.update(0.1)
		print("Terrain client: insect check: summer noon %s, summer 2h %s, winter noon %s, spring noon %s, sunrise edge %s, sunset edge %s, rain %s, playing %d, lake noon %s, lake 2h %s, lake day %s" % (levels + [sound.insects.voices_playing(), lake_noon, lake_night, str(lake_cricket)]))

	if test_variety and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		var events: Dictionary = {}

		for event in amb.EVENTS:
			events[event["name"]] = event

		var ratios: Array = []

		for hour in [6.5, 9.0, 13.0, 18.0]:
			amb.set_conditions(hour, "spring", "clear")
			ratios.append("%.1f" % amb._tod_factor(events["bird_whistle"]))

		amb.set_conditions(13.0, "spring", "clear")
		var crow_noon: float = amb._tod_factor(events["crow_caw"])
		var seasons: Array = []

		for season_name in ["spring", "summer", "autumn", "winter"]:
			seasons.append("%.2f" % float(events["bird_trill"]["seasons"][season_name]))
			seasons.append("%.2f" % float(events["crow_caw"]["seasons"][season_name]))

		var repeats: int = 0
		var run_repeats: int = 0
		var last_pick: int = -1
		var window: Array = []
		amb._clock = 0.0

		for n in 60:
			amb._clock += 5.0
			var pick: int = amb._pick_variant("variety_test", 20)
			run_repeats += 1 if pick == last_pick else 0
			last_pick = pick
			window.append([amb._clock, pick])

			for other in window:
				if other != window[window.size() - 1] and int(other[1]) == pick and amb._clock - float(other[0]) < amb.REPEAT_SEC:
					repeats += 1

		var small_repeats: int = 0
		last_pick = -1

		for n in 40:
			amb._clock += 5.0
			var pick3: int = amb._pick_variant("variety_three", 3)
			small_repeats += 1 if pick3 == last_pick else 0
			last_pick = pick3

		print("Terrain client: variety check: whistle by hour %s, crow at noon %.1f, trill/crow by season %s, repeats in a minute %d, back-to-back %d, back-to-back of 3 %d" % [",".join(ratios), crow_noon, ",".join(seasons), repeats, run_repeats, small_repeats])

	if test_town and now - connected_msec > 18000 and now >= _test_town_bell:
		_test_town_bell = now + 12000
		var around: Vector3 = body.global_position
		var rows: Array = []

		for k in 10:
			var angle: float = TAU * float(k) / 10.0
			var kind: String = ["fire", "hammering", "crowd"][k % 3]
			rows.append({"id": 100 + k, "kind": kind, "at": around + Vector3(cos(angle), 0.0, sin(angle)) * (8.0 + 4.0 * float(k)), "strength": 1.0})

		sound.town.set_sources(rows)
		sound.town.ring_bell(around + Vector3(0.0, 20.0, -60.0), 3)

	if test_meters and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var before_calls: int = sound.meters_calls
		var meter_text: String = sound.meters_text()
		var meter_lines: int = meter_text.split("\n").size()
		var second: String = sound.meters_text()
		print("Terrain client: meters check: calls before %d, %d lines, Master line %s, World line %s, latency line %s, calls after %d, repeat same size %s" % [before_calls, meter_lines, str(meter_text.contains("Master")), str(meter_text.contains("World")), str(meter_text.contains("latency")), sound.meters_calls, str(second.split("\n").size() == meter_lines)])

	if test_splash and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var sp = sound.splashes
		sound.set_quality(2)
		var at_p: Vector3 = body.global_position + Vector3(3.0, 0.0, 0.0)
		var played: int = 0

		for g in ["stone", "gravel", "grass", "dirt", "sand", "mud", "litter", "water"]:
			played += 1 if sp.drop(g, at_p, 1.0) else 0
			sp.test_release()

		var unknown: bool = sp.drop("lava", at_p, 1.0)
		var burst: int = 0

		for n in 40:
			burst += 1 if sp.drop("stone", at_p, 1.0) else 0

		var live_now: int = sp.voices_playing()
		var cap_now: int = sp.cap()
		sp.test_release()
		var weather = sound.weather
		weather.rain = 1.0
		weather.covered = 0.0
		weather.roofed = 0.0
		weather.ground_snow = 0.0
		sp.ground = "stone"
		sp._scan_left = 100.0
		var before: int = sp.drops_played
		sound.cave.enclosure = 0.0

		for n in 50:
			sp.update(0.1, body, false)
			sp.test_release()

		var open_drops: int = sp.drops_played - before
		weather.covered = 1.0
		before = sp.drops_played

		for n in 50:
			sp.update(0.1, body, false)

		var covered_drops: int = sp.drops_played - before
		weather.covered = 0.0
		weather.roofed = 1.0
		before = sp.drops_played

		for n in 50:
			sp.update(0.1, body, false)

		var roofed_drops: int = sp.drops_played - before
		weather.roofed = 0.0
		weather.rain = 0.5
		before = sp.drops_played

		for n in 50:
			sp.update(0.1, body, false)
			sp.test_release()

		var half_drops: int = sp.drops_played - before
		weather.rain = 0.0
		weather.covered = 0.0
		print("Terrain client: splash check: %d grounds played, unknown %s, burst %d of 40 (cap %d, live %d), 5 s of heavy rain %d, covered %d, roofed %d, half rain %d, rate %.1f %.1f %.1f, last %s" % [
			played, str(unknown), burst, cap_now, live_now, open_drops, covered_drops, roofed_drops, half_drops, sp.rate(1.0, 0.0, 0.0, false), sp.rate(1.0, 0.0, 0.0, true), sp.rate(0.05, 0.0, 0.0, false), sp.last])
		sound.set_quality(1)

	if test_reverb and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var world: int = AudioServer.get_bus_index("World")
		var rows: Array = []

		for tier_n in [0, 1, 2]:
			sound.set_quality(tier_n)

			for level in [0.0, 0.3, 1.0]:
				sound.cave.enclosure = level
				sound.cave._apply()
				var verb: AudioEffectReverb = AudioServer.get_bus_effect(world, 0)
				rows.append("t%d e%.1f %s wet %.2f room %.2f" % [tier_n, level, "on" if AudioServer.is_bus_effect_enabled(world, 0) else "off", verb.wet, verb.room_size])

		var reverbs: int = 0

		for n in AudioServer.bus_count:
			for k in AudioServer.get_bus_effect_count(n):
				reverbs += 1 if AudioServer.get_bus_effect(n, k) is AudioEffectReverb else 0

		print("Terrain client: reverb check: %s; reverbs %d, World sends %s, Foley sends %s, Nature sends %s, World before Foley %s" % ["; ".join(rows), reverbs, AudioServer.get_bus_send(world), AudioServer.get_bus_send(AudioServer.get_bus_index("Foley")), AudioServer.get_bus_send(AudioServer.get_bus_index("Nature")), str(world < AudioServer.get_bus_index("Foley"))])
		sound.set_quality(1)
		sound.cave.enclosure = 0.0
		sound.cave._apply()

	if test_air and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var made: Array = []
		var aims: Array = [["fall", 40.0], ["fall", 200.0], ["fall", 400.0], ["fire", 20.0], ["fire", 60.0], ["fire", 140.0], ["fire", 5.0]]

		for aim in aims:
			var voice := AudioStreamPlayer3D.new()
			voice.stream = AudioStreamGenerator.new()
			voice.bus = "Nature" if aim[0] == "fall" else "Foley"
			voice.set_meta("air_kind", aim[0])
			add_child(voice)
			voice.add_to_group("world_sounds")
			voice.global_position = body.global_position + Vector3(float(aim[1]), 0.0, 0.0)
			voice.play()
			made.append(voice)

		sound.ambient.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0}
		sound.weather.roofed = 0.0
		sound.cave.enclosure = 0.0
		sound.occlusion._scan(body, false)
		var open_buses: Array = []

		for voice in made:
			open_buses.append(str(voice.bus))

		sound.ambient.weights = {"forest": 1.0, "meadow": 0.0, "water": 0.0, "highland": 0.0}
		sound.occlusion._scan(body, false)
		var forest_buses: Array = []

		for voice in made:
			forest_buses.append(str(voice.bus))

		sound.weather.roofed = 1.0
		sound.occlusion._scan(body, false)
		var roof_fire: String = str(made[3].bus)
		sound.weather.roofed = 0.0
		var thunder_open: String = sound.weather._thunder_bus(2500.0)
		var thunder_mid: String = sound.weather._thunder_bus(900.0)
		var thunder_near: String = sound.weather._thunder_bus(200.0)
		var hold: int = AirBandsCheck.band_for("fall", 120.0, 1)      # inside the edge's hysteresis it stays
		var hold_up: int = AirBandsCheck.band_for("fall", 120.0, 0)
		var filters: int = 0

		for bus_name in ["Air_fall_1", "Air_fall_2", "Air_fall_3", "Air_fire_1", "Air_fire_2", "Air_fire_3", "Air_thunder_1", "Air_thunder_2"]:
			var index: int = AudioServer.get_bus_index(bus_name)
			filters += AudioServer.get_bus_effect_count(index) if index >= 0 else 0

		print("Terrain client: air check: open falls %s, forest falls %s, open fires %s, forest fires %s, roofed fire %s, thunder %s %s %s, hold %d up %d, filters %d, shed parent %s" % [
			",".join(open_buses.slice(0, 3)), ",".join(forest_buses.slice(0, 3)), ",".join(open_buses.slice(3)), ",".join(forest_buses.slice(3)), roof_fire,
			thunder_open, thunder_mid, thunder_near, hold, hold_up, filters, AirBandsCheck.parent_of("Air_fire_2")])

		for voice in made:
			voice.queue_free()

	if test_flush and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		var files: Dictionary = {}
		var sizes: Dictionary = {"small": 0, "medium": 0, "large": 0}
		var repeats: int = 0
		var previous: String = ""

		for n in 300:
			amb.flush(body.global_position + Vector3(20.0, 2.0, 0.0), 0.0)
			var file: String = amb.last_file
			files[file] = int(files.get(file, 0)) + 1
			sizes[file.get_slice("_", 1)] = int(sizes.get(file.get_slice("_", 1), 0)) + 1
			repeats += 1 if file == previous else 0
			previous = file
			var flier = amb._fliers.pop_back()
			amb._voices.erase(flier["player"])
			flier["player"].queue_free()

		var crow: bool = amb.flush(body.global_position + Vector3(20.0, 2.0, 0.0), 0.0, "large")
		var crow_file: String = amb.last_file
		print("Terrain client: flush check: %d flushes, small %d, medium %d, large %d, files used %d, repeats %d, crow file %s, source %s" % [300, sizes["small"], sizes["medium"], sizes["large"], files.size(), repeats, crow_file, amb._source.get("wing_small", "?")])
		# Flying high above the forest (Dave 2026-10-21): no take-off, no alarm, no bird calls.
		var low_before: float = amb.low_factor()
		amb.forced_agl = 120.0
		amb.agl_m = 120.0
		print("Terrain client: high birds: low factor %.2f then %.2f, flush %s, alarm %s" % [low_before, amb.low_factor(), str(amb.flush(body.global_position + Vector3(20.0, 2.0, 0.0), 0.0)), str(amb.alarm(body.global_position + Vector3(20.0, 2.0, 0.0)))])
		amb.forced_agl = -1.0

	if test_reject and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var first: bool = sound.itemfx.reject("far")
		var again: bool = sound.itemfx.reject("far")
		print("Terrain client: reject check: first %s, held key %s, played %d, last %s" % [str(first), str(again), sound.itemfx.rejects_played, sound.itemfx.last])

	if test_step_levels and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var grass_walk: float = sound.step_level_db("grass", 0)
		var stone_run: float = sound.step_level_db("stone", 2)
		var plank_walk: float = sound.step_level_db("plank", 0)
		var source: String = sound.step_levels_source
		var custom := FileAccess.open("user://step_levels_test.json", FileAccess.WRITE)
		custom.store_string('{"surface_db": {"grass": -30.0}, "surface_gait_db": {"grass": [2.0, 0.0, 0.0]}}')
		custom.close()
		sound._load_step_levels("user://step_levels_test.json")
		var tweaked: float = sound.step_level_db("grass", 0)
		var broken := FileAccess.open("user://step_levels_test.json", FileAccess.WRITE)
		broken.store_string("not json at all")
		broken.close()
		sound._load_step_levels("user://step_levels_test.json")
		print("Terrain client: step levels: source %s, grass walk %.1f, stone run %.1f, plank walk %.1f, tweaked grass walk %.1f, after a broken file %.1f" % [source, grass_walk, stone_run, plank_walk, tweaked, sound.step_level_db("grass", 0)])

	if test_night and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0}
		sound.weather.rain = 0.0
		sound.wind_strength = 0.3
		sound.cave.enclosure = 0.0
		var night_levels: Array = []

		for combo in [["summer", 2.0], ["spring", 2.0], ["winter", 2.0], ["summer", 13.0]]:
			amb.set_conditions(float(combo[1]), str(combo[0]), "clear")
			night_levels.append("%.2f" % sound.insects.target())

		amb.set_conditions(2.0, "winter", "clear")
		var wolf_winter: float = sound.creatures.season_factor("wolf")
		amb.set_conditions(2.0, "summer", "clear")
		var wolf_summer: float = sound.creatures.season_factor("wolf")
		amb._answers.append({"left": 0.0, "name": "owl_hoot", "at": body.global_position + Vector3(40.0, 0.0, 0.0), "db": -17.0})
		amb._play_answers(1.0)
		print("Terrain client: night check: insects summer %s, spring %s, winter %s, day %s; wolf factor winter %.1f summer %.1f; owl answers %d; wild %s" % [night_levels[0], night_levels[1], night_levels[2], night_levels[3], wolf_winter, wolf_summer, amb.answers_played, str(sound.creatures.wild)])

	# Stance sounds: crouch, stand, sit, stand, lie (and sit for 20 s to hear settles), stand.
	if test_stance and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 1500
		var order: Array = ["crouch", "stand", "sit", "stand", "lie", "stand"]

		if _stance_step < order.size():
			sound.gear.set_worn(["cloth", "plate"])
			sound.stance.set_stance(order[_stance_step])
			_stance_step += 1
		elif _stance_step == order.size():
			print("Terrain client: stance check: %d changes, %d settles, crouch step %.0f dB, last %s" % [sound.stance.changes_played, sound.stance.settles_played, sound.stance.step_db(), sound.stance.last])
			_stance_step += 1

	# Distant fires and falls merge: one near fire and six far hearths, five far falls in a valley.
	if test_merge and now - connected_msec > 18000:
		sound.fire.hold_manual(60.0)
		var base: Vector3 = body.global_position

		if _merge_step == 0:
			var list: Array = [{"id": 1, "at": base + Vector3(5.0, 0.0, 0.0), "size": 0.5, "lit": true, "open": true}]

			for n in range(6):
				list.append({"id": 10 + n, "at": base + Vector3(27.0 + float(n % 3) * 3.0, 0.0, float(n / 3) * 3.0), "size": 0.5, "lit": true, "open": true})

			sound.fire.set_fires(list)
			var falls: Array = []

			for n in range(5):
				falls.append({"kind": "fall", "at": base + Vector3(150.0 + float(n) * 8.0, 0.0, 0.0), "distance": 150.0 + float(n) * 8.0, "drop": 6.0, "speed": -1.0, "width": 4.0, "score": 0.6})

			falls.append({"kind": "fall", "at": base + Vector3(60.0, 0.0, 0.0), "distance": 60.0, "drop": 6.0, "speed": -1.0, "width": 4.0, "score": 0.3})
			var out: Array = sound.water._merge_far_falls(falls, base)
			print("Terrain client: merge check: falls 6 -> %d voices, %d merged, widest %.0f" % [out.size(), sound.water.merged_falls, out.reduce(func(m, f): return maxf(m, float(f["width"])), 0.0)])

		if _merge_step == 0:
			sound.water._pick_base([{"kind": "fall", "at": base + Vector3(10.0, 0.0, 0.0), "distance": 10.0, "drop": 8.0, "width": 8.0}])

		if _merge_step == 120:
			print("Terrain client: fall base: playing %s at %.1f dB (target %.1f), drop %.0f m" % [str(sound.water._base.playing), sound.water._base.volume_db, sound.water._base_db, sound.water.base_fall_drop])
			print("Terrain client: merge check: fires 7 -> %d loops, %d merged" % [sound.fire._loops.size(), sound.fire.merged_fires])

		_merge_step += 1

	# Faint run: 27 s of over-exertion, faint and waking; the final report says how far the world fell silent.
	if test_faint and now - connected_msec > 18000 and not sound.breath.demo_done:
		if sound.breath.state == "normal" and sound.breath.exertion == 0.0 and not sound.breath._demo_t >= 0.0:
			sound.breath.demo()

	# Memory audit: every sound file loaded once, counted against the tier's cap (assets/audio/README.md "Sound memory").
	if test_load_all_sounds and now - connected_msec > 12000:
		test_load_all_sounds = false
		var before: int = OS.get_static_memory_usage()
		var count: int = 0
		var stack: Array = ["res://assets/audio/"]

		while not stack.is_empty():
			var dir: String = stack.pop_back()

			for sub in DirAccess.get_directories_at(dir):
				stack.append(dir + sub + "/")

			for file in DirAccess.get_files_at(dir):
				if file.ends_with(".ogg") or file.ends_with(".wav"):
					var stream: AudioStream = sound.load_for_audit(dir, file.get_basename())
					count += 1 if stream != null else 0

		print("Terrain client: sound memory audit: %d files loaded, %s, static memory +%.1f MB" % [count, sound.audit_text(), float(OS.get_static_memory_usage() - before) / 1048576.0])

	# Headless check: the lit and loaded cues from world-row state changes (Items fire states 8 empty, 9 loaded, 1 lit).
	if test_fire_world and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 1200
		var seq: Array = [8, 8, 9, 1, 9, 8]

		if _fire_world_step < seq.size():
			sound.fire.sync_world({77: {"state": seq[_fire_world_step], "pos": body.global_position + Vector3(3.0, 0.0, 0.0)}})
			_fire_world_step += 1

	# Headless check: a jab, then a throw into each material.
	if test_spear_sounds and now - connected_msec > 18000 and now >= _test_spear_at:
		_test_spear_at = now + 1500
		var spear_materials: Array = sound.spear.MATERIALS

		if _test_spear_step == 0:
			print("Terrain client: spear jab -> %s" % sound.spear.jab(body.global_position + Vector3(1.0, 0.0, 0.0)))
		elif _test_spear_step <= spear_materials.size():
			var material: String = spear_materials[_test_spear_step - 1]
			var flight_s: float = sound.spear.throw(body.global_position + Vector3(0.0, 1.5, 0.0), body.global_position + Vector3(25.0, 1.0, 5.0), 28.0, material)
			print("Terrain client: spear throw into %s -> flight %.2f s" % [material, flight_s])
		else:
			test_spear_sounds = false

		_test_spear_step += 1

	# Headless check: step inside, use each object, step back out.
	if test_interior and now - connected_msec > 18000 and now >= _test_interior_at:
		_test_interior_at = now + 600
		var names: Array = sound.interior.OBJECTS.keys()

		if _test_interior_step == 0:
			sound.interior.set_inside(1.0, "house")

		if _test_interior_step < names.size():
			sound.interior.object(names[_test_interior_step], body.global_position + Vector3(2.0, 0.0, 1.0), 1.0)

		_test_interior_step += 1

		if _test_interior_step > names.size() + 6:
			test_interior = false
			print("Terrain client: interior check: amount %.2f, enclosure %.2f, covered %.1f" % [sound.interior.amount, sound.cave.enclosure, sound.weather.covered])
			sound.interior.set_inside(0.0)

	# Headless check: more sounds than the tier's voice cap, then the shedding.
	if test_flood and now - connected_msec > 18000:
		test_flood = false

		for n in range(80):
			sound.hits.hit("axe", "wood", body.global_position + Vector3(float(n % 20) * 5.0 + 3.0, 0.0, float(n / 20) * 10.0), 1.0)

		var before: int = sound.voices_playing()
		sound._shed(body, maxi(before - sound.voice_cap, 0))
		print("Terrain client: flood: %d playing before (cap %d, tier %s), shed %d, %d playing right after" % [before, sound.voice_cap, sound.Presets.NAMES[sound.tier], sound.shed_count, sound.voices_playing()])

	# Headless check: the interface cues in turn.
	if test_ui and now - connected_msec > 18000 and now >= _test_ui_next:
		_test_ui_next = now + 500
		var cues: Array = ["ui_click", "ui_on", "ui_off", "ui_quality"]
		sound.ui.play(cues[_test_ui_step % cues.size()])
		_test_ui_step += 1

		if _test_ui_step >= 8:
			test_ui = false

	# Headless check: a scripted swim (jump in, strokes, dive, surface).
	if test_swim and now - connected_msec > 20000:
		test_swim = false
		sound.swim.demo()

	# Headless check: dig under the spawn once the ground around it is in.
	if test_dig and now - connected_msec > 20000:
		test_dig = false
		net.dig.rpc_id(1, Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0), 4.0)

	if test_dig_check and now - connected_msec > 24000:
		test_dig_check = false
		var probe_tool: VoxelTool = terrain.get_voxel_tool()
		var centre: Vector3 = Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0)
		print("Terrain client: dig check: ground value at the old hole %.2f (above 0 is open), 12 m away %.2f" % [probe_tool.get_voxel_f(Vector3i(centre.round())), probe_tool.get_voxel_f(Vector3i((centre + Vector3(12.0, 0.0, 0.0)).round()))])

	if frames_left > 0 and now >= _report_msec:
		_report_msec = now + 10000
		print("client: %d s, %d blocks loaded, %d from the server (%.1f MB), %d waiting, %d fps, at %s" % [
			(now - connected_msec) / 1000, stream.loads, stream.blocks_received,
			float(stream.bytes_received) / 1048576.0, stream.pending(), Engine.get_frames_per_second(), str(body.global_position.round())
		])

	var mode: String = ""

	if flying:
		mode = "flying"
	elif running:
		mode = "Running"
	elif jogging:
		mode = "Jogging"

	if inspecting:
		_update_inspect()

	if underwater:
		mode = (mode + " (underwater)").strip_edges()

	if waiting_for_ground and not flying:
		mode = (mode + " (building the ground around you, the first visit takes longer)").strip_edges()
	if Time.get_ticks_msec() < _bake_alert_until:
		# Sideways only: the player may drop a little while the ground reloads.
		if body != null and Vector2(body.global_position.x - _bake_alert_at.x, body.global_position.z - _bake_alert_at.z).length() > 1.0:
			_bake_alert_until = 0
			_bake_status = ""
		else:
			mode = _bake_status

	_mode_label.text = mode
	var worst_ms: float = 0.0
	var total_ms: float = 0.0

	for ms in _frame_ms:
		worst_ms = maxf(worst_ms, ms)
		total_ms += ms

	var avg_ms: float = total_ms / maxf(float(_frame_ms.size()), 1.0)
	status_icons.tick(delta)
	_note_last_sound()
	hud.text = "build %d (%s)  %d fps  %s (F2)\nx %.0f  y %.1f  z %.0f\nlast sound: %s" % [BUILD, _commit, Engine.get_frames_per_second(), QUALITY_NAMES[quality], body.global_position.x, body.global_position.y, body.global_position.z, _last_sound]
	hud.text += "\n" + _ground_health_line()

	if debug_hud.enabled:
		hud.text += "\n" + _debug_text(avg_ms, worst_ms)

	if _bake_status != "":
		hud.text += "\n" + _bake_status

	if frames_left > 0:
		frames_left -= 1

		if frames_left == 0:
			if test_fly and _fly_stop_msec > 0:
				print("Terrain client: ground collider under the player %s ms after stopping (altitude %.0f)" % [str(_fly_ground_msec - _fly_stop_msec) if _fly_ground_msec > 0 else "never", body.global_position.y])

				for lod in range(6):
					print("Terrain client: under the stop point, LOD %d first asked %s, loaded %s (ms after stopping)" % [
						lod,
						str(stream.watch_asked[lod] - _fly_stop_msec) if stream.watch_asked.has(lod) else "never",
						str(stream.watch_loaded[lod] - _fly_stop_msec) if stream.watch_loaded.has(lod) else "never",
					])

			print("Terrain client: last block asked for %d ms after the welcome; %d blocks loaded; %d from the server (%.2f MB, %.0f bytes each), %d from the cache, %d cache misses, %d timeouts, %d still waiting, %d prefetched blocks used" % [
				settled_msec, stream.loads, stream.blocks_received, float(stream.bytes_received) / 1048576.0,
				float(stream.bytes_received) / maxf(float(stream.blocks_received), 1.0), cache.hits, cache.misses, stream.timeouts, stream.pending(), stream.prefetch_used
			])
			print("Terrain client: cache folder %.1f MB" % (float(cache.size_bytes()) / 1048576.0))
			print("Terrain client: flora %d chunks (%.2f MB with water, last %d ms after the welcome), %d items held, %d drawn, %d colliders, %d cuts; water in %d chunks, %d cells" % [
				_flora_chunks, float(_flora_bytes) / 1048576.0, _flora_done_msec, flora.item_count(), flora.instances, flora.colliders, _flora_cuts,
				flora.water_chunks, flora.water_cells
			])
			var stats: Dictionary = flora.draw_stats()
			print("Terrain client: flora draws: %s nodes (tree, shrub, plant) for %s instances, %d nodes under 50 instances" % [str(stats["nodes"]), str(stats["instances"]), int(stats["small"])])
			print("Terrain client: fall columns: %d meshes drawn (cap %d per chunk)" % [flora.falls_drawn, flora.fall_cap])
			print("Terrain client: cover index %d tree crowns in %d chunks" % [flora.cover.trees, flora.cover.chunk_count()])
			print("Terrain client: grass %d tufts in %d cells (radius %.0f m), %d MultiMesh draws" % [grass.tufts, grass.cells_built, grass.radius_m, grass.draw_nodes])
			print("Terrain client: water sounds: %s (%d falls known)" % [sound.water.summary, flora.fall_list().size()])
			print("Terrain client: nature calls %s, zones %s" % [str(sound.ambient.calls_played), str(sound.ambient.weights)])
			print("Terrain client: tree sounds: %d falls, %d stump sprays, last %s" % [sound.trees.falls_played, sound.trees.chips_played, sound.trees.last])
			print("Terrain client: faint run: world muted to %.2f, heart gain down to %.2f, %d heaves, %d heartbeats, done %s, breaths while fainted %d, wake mute %.2f, bpm max %.0f, step %.2f" % [sound.breath.peak_mute, sound.breath.demo_min_gain, sound.breath.heaves_played, sound.breath.beats_played, str(sound.breath.demo_done), sound.breath.fainted_breaths, sound.breath.wake_mute_mid, sound.breath.bpm_max, sound.breath.bpm_step_max])
			print("Terrain client: fire world: %d fuel, %d lit, %d out" % [sound.fire.fuel_played, sound.fire.lit_played, sound.fire.out_played])
			print("Terrain client: fire sounds: %d lit, %d put out, %d loops, last %s" % [sound.fire.lit_played, sound.fire.out_played, sound.fire.loops_playing, sound.fire.last])
			print("Terrain client: item sounds %d, last %s" % [sound.itemfx.played, sound.itemfx.last])
			var kinds: Dictionary = {}

			for row_id in harvest._flora_by_id:
				var row: Dictionary = harvest._flora_by_id[row_id]

				if row.get("kind", "") != "tree":
					var k: String = sound.harvestfx.pick_kind(row)
					kinds[k] = int(kinds.get(k, 0)) + 1

			print("Terrain client: harvest sounds %s, last %s; plant kinds %s" % [str(sound.harvestfx.played), sound.harvestfx.last, str(kinds)])
			print("Terrain client: spear sounds %s, last %s" % [str(sound.spear.played), sound.spear.last])
			print("Terrain client: interior sounds: %d objects, %d creaks, last %s" % [sound.interior.objects_played, sound.interior.creaks_played, sound.interior.last])
			print("Terrain client: gear: worn %s, %d steps, last %s" % [str(sound.gear.worn), sound.gear.steps_played, sound.gear.last])
			print("Terrain client: creature calls %s, last %s" % [str(sound.creatures.calls_played), sound.creatures.last])
			print("Terrain client: sounds shed over the cap: %d" % sound.shed_count)
			print("Terrain client: interface sounds %d played, last %s" % [sound.ui.played, sound.ui.last])
			print("Terrain client: swim sounds %d splashes, %d strokes, %d dives, %d surfacings, last %s" % [sound.swim.splashes, sound.swim.strokes, sound.swim.dives, sound.swim.surfaces, sound.swim.last])
			print("Terrain client: town sounds %d loops, %d bells" % [sound.town.loops_playing, sound.town.bells_rung])
			print("Terrain client: tool hits %d, last %s" % [sound.hits.hits_played, sound.hits.last_hit])
			print("Terrain client: muffled sounds: %d filtered, %d behind hills" % [sound.occlusion.filtered, sound.occlusion.occluded])
			print("Terrain client: cave enclosure %.2f, drips %d" % [sound.cave.enclosure, sound.cave.drips_played])
			print("Terrain client: dig sounds %s, last %s" % [str(sound.dig.digs_played), sound.dig.last_dig])
			print("Terrain client: ", sound.wind_text())
			print("Terrain client: ", sound.heard_text(body).replace("\n", " | "))
			print("Terrain client: sound budget: %s, %d loads refused" % [sound.budget_text(), sound.refused_loads])
			print("Terrain client: snow hush %.2f (nature bus %.1f dB, wind bus %.1f dB)" % [sound.weather.snow_hush, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Nature")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Wind"))])
			print("Terrain client: rain ground %s (weights %s)" % [sound.weather.ground_class, str(sound.weather._ground_w)])
			print("Terrain client: weather %s rain %.2f wind %.2f calls %.2f thunders %d; ground wet %.2f snow %.2f, covered %.1f, puddle splashes %d, leaf drips %d, roofed %.1f, loops %s" % [sound.weather.kind, sound.weather.rain, sound.weather.wind, sound.weather.calls, sound.weather.thunders_played, sound.weather.ground_wet, sound.weather.ground_snow, sound.weather.covered, sound.puddles_played, sound.weather.drips_played, sound.weather.roofed, str(sound.weather.active_loops().map(func(entry): return entry[0]))])
			print("Terrain client: sound: footsteps %s, grass swishes %d, last ground %s, gust %.2f" % [str(sound.steps_played), sound.swishes_played, sound.surface, sound.gust])
			if _npc_view != null:
				var near_npc: Dictionary = _npc_view.nearest(body.global_position, 100000.0)
				print("Terrain client: npcs drawn %d (roster %d), nearest %s, player at %.0f %.0f" % [_npc_view.drawn_count(), _npc_view.roster.size(), str(near_npc.get("name", "none")) + (" %.1f m away" % Vector2(near_npc["pos"].x - body.global_position.x, near_npc["pos"].z - body.global_position.z).length() if not near_npc.is_empty() else ""), body.global_position.x, body.global_position.z])

			print("Terrain client: blocks waited for %d times, %.0f ms on average, worst %d ms; at most %d loader threads waiting at once; %d blocks came on the block line" % [stream.waits, float(stream.wait_msec_total) / maxf(float(stream.waits), 1.0), stream.wait_msec_worst, stream.most_waiting, link.blocks_in])
			print(Probe.report())
			var probe: Vector3i = Vector3i((Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0)).round())
			print("Terrain client: ground value 3 m under the spawn %.2f (above 0 is open)" % terrain.get_voxel_tool().get_voxel_f(probe))
			_finish(0)


# Headless walking check (--walk): lands on the ground, walks east without
# falling through, and is stopped by a tree trunk.

# Debug details (Dave 2026-10-20: the default HUD is only build, position and the last sound).
# Any thread that wants a diagnostic line on screen registers a Callable returning a String with
# debug_hud (debug_hud.add_line(name, callable), see src/client/debug_hud.gd); it is only called
# while Debug details is on (F3, or Esc > Settings).
func _debug_text(avg_ms: float, worst_ms: float) -> String:
	var text: String = "avg %.1f ms  worst %.1f ms  quality %s (F2)\nmem %.0f MB\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders, grass %d" % [
		avg_ms, worst_ms, QUALITY_NAMES[quality],
		float(OS.get_static_memory_usage()) / 1048576.0,
		stream.blocks_received, float(stream.bytes_received) / 1048576.0, cache.hits, flora.instances, flora.colliders, grass.tufts
	]

	var vp: RID = get_viewport().get_viewport_rid()
	text += "\ngame time: year %d, day %d (%s), %02d:%02d" % [game_clock.year() + 1, game_clock.day_of_year() + 1, game_clock.season(), int(game_clock.hour()), int(fposmod(game_clock.hour(), 1.0) * 60.0)]
	if not weather.is_empty():
		text += "\nweather: rain %.2f snow %.2f storm %.2f sun %.2f wind %.2f, %.0f C, %s" % [weather["rain"], weather["snow"], weather["storm"], weather["sun"], weather["wind"], weather["temp_c"], "under cover" if under_cover > 0.0 else "open"]

	var win: Vector2i = get_window().size
	text += "\n3D %dx%d 16:9 in window %dx%d (scale %.2f)%s, %s, %s" % [int(display.BASE.x * _render_scale), int(display.BASE.y * _render_scale), win.x, win.y, _render_scale, " (embedded: editor owns the window)" if display.embedded() else "", RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()]
	text += "\nGPU breakdown: Ctrl+Shift+G or Esc > Advanced; table shows top left, press again to close; also in the log and user://gpu_probe.txt"
	text += "\nlast step: " + sound.last_step
	text += "\nsound budget: " + sound.budget_text()
	text += "\n" + sound.heard_text(body)
	text += "\n" + sound.meters_text()
	text += "\n" + sound.wind_text()
	text += "\nexertion %.2f (%s): %d breaths, %d heartbeats, last %s" % [sound.breath.exertion, sound.breath.state, sound.breath.breaths_played, sound.breath.beats_played, sound.breath.last]
	text += "\ntree sounds: %d falls, %d sprays, last %s" % [sound.trees.falls_played, sound.trees.chips_played, sound.trees.last]
	text += "\nfire sounds: %d loops, %d lit, %d put out, last %s" % [sound.fire.loops_playing, sound.fire.lit_played, sound.fire.out_played, sound.fire.last]
	text += "\nitem sounds: %d, last %s" % [sound.itemfx.played, sound.itemfx.last]
	text += "\nspear sounds: %s, last %s" % [str(sound.spear.played), sound.spear.last]
	text += "\ninterior: %.2f inside (%s), %d objects, %d creaks, last %s" % [sound.interior.amount, sound.interior.kind, sound.interior.objects_played, sound.interior.creaks_played, sound.interior.last]
	text += "\ngear: worn %s, %d steps, last %s" % [str(sound.gear.worn), sound.gear.steps_played, sound.gear.last]
	text += "\ncreature calls: %s, last %s" % [str(sound.creatures.calls_played), sound.creatures.last]
	text += "\nswim sounds: %d splashes, %d strokes, %d dives, %d surfacings, last %s" % [sound.swim.splashes, sound.swim.strokes, sound.swim.dives, sound.swim.surfaces, sound.swim.last]
	text += "\ntown sounds: %d loops, %d bell strikes" % [sound.town.loops_playing, sound.town.bells_rung]
	text += "\nmuffled sounds: %d filtered, %d behind hills" % [sound.occlusion.filtered, sound.occlusion.occluded]
	text += "\ncave: enclosure %.2f, drips %d" % [sound.cave.enclosure, sound.cave.drips_played]
	text += "\nlast dig sound: %s" % sound.dig.last_dig
	text += "\nweather sounds follow: %s" % ("the TEST button (press it until it says follow the world)" if _sound_weather_at >= 0 else "the world weather above")
	text += "\nweather sounds: %s (rain %.1f, wind %.1f, thunder %d), ground wet %.2f snow %.2f, %s, drips %d" % [sound.weather.kind, sound.weather.rain, sound.weather.wind, sound.weather.thunders_played, sound.weather.ground_wet, sound.weather.ground_snow, "under canopy" if sound.weather.covered > 0.5 else "in the open", sound.weather.drips_played]
	text += "\nnature (%02d:%02d %s): forest %.1f meadow %.1f water %.1f high %.1f, last %s" % [int(sound.ambient.conditions["hour"]), int(fposmod(float(sound.ambient.conditions["hour"]), 1.0) * 60.0), sound.ambient.conditions["season"], sound.ambient.weights["forest"], sound.ambient.weights["meadow"], sound.ambient.weights["water"], sound.ambient.weights["highland"], sound.ambient.last_call]
	text += "\nwater sounds: " + sound.water.summary
	text += "\nframe work: cpu %.1f ms, gpu %.1f ms, vsync %s, draws %d" % [
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		["on", "adaptive", "off"][clampi([DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED].find(DisplayServer.window_get_vsync_mode()), 0, 2)],
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))]

	var extra: String = debug_hud.text()

	if extra != "":
		text += "\n" + extra

	return text


# The one-line "last sound": whichever sound source's last-played text changed most recently.
func _note_last_sound() -> void:
	var sources: Array = [
		["step", sound.last_step], ["breath", sound.breath.last], ["fire", sound.fire.last], ["tree", sound.trees.last], ["item", sound.itemfx.last], ["spear", sound.spear.last], ["placed", sound.placed.last],
		["interior", sound.interior.last], ["gear", sound.gear.last], ["creature", sound.creatures.last], ["swim", sound.swim.last],
		["dig", sound.dig.last_dig], ["nature", sound.ambient.last_call], ["npc voice", _npc_voice.last if _npc_voice != null else ""], ["inner voice", sound.inner.last],
	]

	for n in range(sources.size()):
		var now: String = str(sources[n][1])

		if now != "" and now != _last_sound_seen.get(sources[n][0], ""):
			_last_sound = "%s: %s" % [sources[n][0], now]

		_last_sound_seen[sources[n][0]] = now


func _walk_step() -> void:
	var now: int = Time.get_ticks_msec()

	match _walk_phase:
		0:
			# Wait for ground under the drop point (headless ground sometimes loads late: the walk then never landed
			# and the sound checks saw 0 footsteps), but not past 45 s.
			var drop_at: Vector3 = body.global_position + Vector3(0.0, 0.0, 40.0)

			if connected_msec > 0 and now - connected_msec > 15000 and (not is_nan(_ground_below(drop_at)) or now - connected_msec > 45000):
				flying = false
				# Away from the spawn, where earlier --dig checks leave a hole.
				body.global_position += Vector3(0.0, 0.0, 40.0)
				_walk_phase = 1
				_walk_msec = now
				print("Terrain client: walk: dropping from %s, ground below %.1f" % [str(body.global_position.round()), _ground_below(body.global_position)])
				_walk_stats = {"start_y": body.global_position.y, "fell_through": 0, "floor_frames": 0, "frames": 0, "lowest_gap": INF}
		1:
			if body.is_on_floor():
				_walk_stats["landed_s"] = float(now - _walk_msec) / 1000.0
				_walk_stats["drop_m"] = float(_walk_stats["start_y"]) - body.global_position.y
				_walk_stats["start_x"] = body.global_position.x
				_walk_phase = 2
				_walk_msec = now
				_walk_dir = Vector3(1.0, 0.0, 0.0)
			elif now - _walk_msec > 20000:
				_walk_stats["landed_s"] = -1.0
				_walk_phase = 4
				_walk_report()
		2:
			var ground: float = _ground_below(body.global_position)
			_walk_stats["frames"] += 1

			if body.is_on_floor():
				_walk_stats["floor_frames"] += 1

			if not is_nan(ground):
				var gap: float = body.global_position.y - ground
				_walk_stats["lowest_gap"] = minf(_walk_stats["lowest_gap"], gap)

				if gap < -0.5:
					_walk_stats["fell_through"] += 1

			if now - _walk_msec > 30000:
				_walk_stats["walked_m"] = body.global_position.x - float(_walk_stats["start_x"])
				_walk_dir = Vector3.ZERO
				_walk_phase = 3 if _place_by_tree() else 4
				_walk_msec = now

				if _walk_phase == 4:
					_walk_report()
		5:
			if now - _walk_msec > 3000:
				_walk_stats["rescued_gap"] = body.global_position.y - float(_walk_stats.get("rescue_ground", 0.0))
				_walk_phase = 4
				_walk_report()
		3:
			_walk_stats["tree_max_x"] = maxf(_walk_stats.get("tree_max_x", -INF), body.global_position.x)

			if now - _walk_msec > 4000:
				# Fell through the world? Drop the player 60 m below the ground
				# and see that they are lifted back.
				_walk_dir = Vector3.ZERO
				var p: Vector3 = body.global_position
				_walk_stats["rescue_ground"] = _ground_below(p)
				body.global_position = p + Vector3(0.0, -60.0, 0.0)
				body.velocity = Vector3.ZERO
				_walk_phase = 5
				_walk_msec = now
			elif now - _walk_msec > 1000:
				_walk_dir = Vector3(1.0, 0.0, 0.0)


# True when collision exists below the player. When there is none, finds
# the surface above (the player fell through, or the ground loaded
# underneath) and stands the player on it; false while nothing is loaded.
func _ground_ready() -> bool:
	var here: Vector3 = body.global_position
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 1.0, 0.0), here + Vector3(0.0, -300.0, 0.0))
	down.exclude = [body.get_rid()]

	if not space.intersect_ray(down).is_empty():
		return true

	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [body.get_rid()]
	var hit: Dictionary = space.intersect_ray(up)

	if not hit.is_empty():
		body.global_position = Vector3(here.x, float(hit["position"].y) + 1.2, here.z)
		rescued += 1

	return false


# Off the floor for a while and below the highest collider overhead: the
# player slipped through the ground (a gap, or collision that was not ready).
# Stands the player on top of the surface and returns true.
func _under_the_ground() -> bool:
	var here: Vector3 = body.global_position
	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(up)

	if hit.is_empty() or float(hit["position"].y) < here.y + 2.0:
		return false

	body.global_position = Vector3(here.x, float(hit["position"].y) + 1.2, here.z)
	body.velocity = Vector3.ZERO
	_floor_msec = Time.get_ticks_msec()
	return true


# Blue tint and thick blue fog while the camera is below the sea or a lake.
func _update_breath_label() -> void:
	var air: int = items.breath_ds
	_breath_label.visible = air >= 0

	if air >= 0:
		_breath_label.text = "%d" % int(ceil(float(air) / 10.0))
		_breath_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if air < 100 else Color.WHITE)


func _update_underwater() -> void:
	_update_breath_label()
	var eye: Vector3 = camera.global_position
	# Owner report (2026-10-20, build 145): beside a cliff gorge with a thin film of water the
	# view turned blue with nothing drawn. The highest wet corner of an 8 m square (water_level_at)
	# is the top of the film, tens of m above the eye. Now the blended surface at the eye's own
	# spot, and the water there must be deeper than a film.
	var surface: float = flora.water_surface_at(eye.x, eye.z) if eye.y >= 0.0 else NAN
	var under: bool = eye.y < 0.0

	if not under and not is_nan(surface) and eye.y < surface:
		under = WaterVolume.submerged(eye.y, surface, _ground_below(eye))

	if under == underwater:
		return

	underwater = under
	_tint.visible = under
	_environment.fog_density = 0.05 if under else LookSettings.FOG_DENSITY
	_environment.fog_light_color = Color(0.08, 0.28, 0.4) if under else SkyClouds.HORIZON
	_environment.fog_sky_affect = 1.0 if under else 0.0


# Ground height under a point, from the terrain colliders (NAN if none).
func _ground_below(p: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -200.0, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else NAN


# Puts the player 3 m west of the nearest tree with a trunk collider.
func _place_by_tree() -> bool:
	var here: Vector3 = body.global_position
	var best: Array = []

	for chunk in flora._chunks:
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			var info: Dictionary = flora._species.get(items["ids"][n] >> 16, {})

			if info.get("kind", 2) != 0 or float(info.get("trunk", 0.0)) < 0.1:
				continue

			var d: float = (items["positions"][n] - here).length()

			if d < 100.0 and (best.is_empty() or d < best[0]):
				best = [d, items["positions"][n]]

	if best.is_empty():
		return false

	var tree: Vector3 = best[1]
	_walk_stats["tree_x"] = tree.x
	body.global_position = Vector3(tree.x - 3.0, maxf(tree.y, _ground_below(Vector3(tree.x - 3.0, tree.y + 50.0, tree.z))) + 1.2, tree.z)
	body.velocity = Vector3.ZERO
	return true


func _walk_report() -> void:
	var s: Dictionary = _walk_stats
	print("Terrain client: walk: landed %.1f s after dropping %.0f m; walked %.0f m east in 30 s, on the ground %d%% of frames, %d frames below the ground (lowest gap %.2f m); tree trunk at x %.1f, furthest reached %.1f; put 60 m under the ground, then %.1f m above it (%d rescues); waited for ground %d of %d frames, slowest frame %.0f ms" % [
		float(s.get("landed_s", -1.0)), float(s.get("drop_m", 0.0)), float(s.get("walked_m", 0.0)),
		100 * int(s.get("floor_frames", 0)) / maxi(int(s.get("frames", 0)), 1), int(s.get("fell_through", 0)), float(s.get("lowest_gap", 0.0)),
		float(s.get("tree_x", NAN)), float(s.get("tree_max_x", NAN)), float(s.get("rescued_gap", NAN)), rescued,
		_wait_frames, int(s.get("frames", 0)), _slowest_frame * 1000.0
	])


func _finish(code: int) -> void:
	_drain_incoming()

	if link != null:
		link.close()

	if stream != null:
		stream.close()

	_finish_cache_task()

	if cache != null:
		cache.flush()

	get_tree().quit(code)


# Worker thread: writes pending blocks and keeps the cache folder inside its size limit.
func _cache_upkeep() -> void:
	cache.flush()
	_cache_removed = cache.enforce_budget(_cache_tile)


func _finish_cache_task() -> void:
	if _cache_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_cache_task)
		_cache_task = -1


func _exit_tree() -> void:
	_finish_cache_task()
	_drain_incoming()
	if stream != null:
		stream.close()
