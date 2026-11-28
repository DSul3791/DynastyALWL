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
#   --dig-ditch=X,Z,L 20 s in, ask the server to dig a ditch from (X, Z) L metres north (-Z), 1.5 m spheres every 1.5 m, two a second (water check, #506)
#   --water-step      with --frames: 12 s in, press + twice (the server re-settles the water)
#   --cut             with --frames: 25 s in, ask the server to cut the tree nearest the spawn
#   --walk            with --frames: 15 s in, drop to the ground, walk east for 30 s, then
#                     walk into the nearest tree, and print what happened
#   --no-block-line   blocks over the game connection only (no direct block line)
#   --wait=S          keep trying to connect for S seconds (the "play" launcher
#                     uses 120 while its own server starts)
#
# Controls (see CONTROLS.md): mouse look, W A S D, Space and Ctrl, walk WASD,
# run Shift+W, G or F fly or walk, Esc opens the options menu.

const KeyBindings := preload("res://src/client/key_bindings.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const NpcCampScript := preload("res://src/shared/npc_camp.gd")   # facing at the spawn (face_fire_yaw)
const SlotSoundsScript := preload("res://src/client/slot_sounds.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")   # the ears at the eye (Sound3D.ears)
const LogLookScript := preload("res://src/client/log_look.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const JoinAddress := preload("res://src/client/join_address.gd")
const ServerAuthScript := preload("res://src/shared/server_auth.gd")
const ServerListScript := preload("res://src/client/server_list.gd")
const PasswordBoxScript := preload("res://src/client/password_box.gd")
const OceanWaves := preload("res://src/sullivan_water/ocean/ocean_waves.gd")
const OceanMesh := preload("res://src/sullivan_water/ocean/ocean_mesh.gd")
const GroundWatchdogScript := preload("res://src/client/ground_watchdog.gd")
const Probe := preload("res://src/debug/frame_probe.gd")
const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")
const ProcessEndMarkScript := preload("res://src/debug/process_end_mark.gd")
const NetPollScript := preload("res://src/debug/net_poll.gd")
const DynastyArmsScript := preload("res://src/client/character/dynasty_arms.gd")
var _freeze_watch = FreezeWatchScript.new()   # its own thread: names a main-thread stall while it lasts, and tells a whole-game stop apart (Dave 2 Nov 2026)
const CompassScript := preload("res://src/client/admin_compass.gd")
const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const NpcViewScript := preload("res://src/client/npc_view.gd")
const PlayerViewScript := preload("res://src/client/player_view.gd")
const GroundDebugScript := preload("res://src/client/ground_debug.gd")
const ShowroomScript := preload("res://src/client/showroom.gd")
const CaveinDeathScript := preload("res://src/client/cavein_death.gd")
const DeathScreenScript := preload("res://src/client/death_screen.gd")
const CharacterStoreScript := preload("res://src/client/character/character_store.gd")
const WelcomeCardScript := preload("res://src/client/welcome_card.gd")
const HintCardScript := preload("res://src/client/hint_card.gd")
const DripViewScript := preload("res://src/client/drip_view.gd")
const ThunderScript := preload("res://src/shared/thunder.gd")
const GameMenuScript := preload("res://src/client/game_menu.gd")
const SoundTestMenuScript := preload("res://src/client/sound_test_menu.gd")
const QuakeViewScript := preload("res://src/client/quake_view.gd")
const CaveSoundsScript := preload("res://src/client/cave_sounds.gd")   # is_not_rock: cave roof rays skip plants and placed pieces
const SoundNow := preload("res://src/client/sound_now.gd")
const FeelKicksScript := preload("res://src/client/feel_kicks.gd")
const LadderClimbScript := preload("res://src/client/ladder_climb.gd")
const LADDER_RUNG_M := 0.35               # rungs are about a third of a metre apart
const NpcVoiceScript := preload("res://src/client/npc_voice.gd")
const TestSwitchesScript := preload("res://src/client/test_switches.gd")
const TrailCodec := preload("res://src/shared/trail_codec.gd")
const MapKnowledgeScript := preload("res://src/client/map_knowledge.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")
const BurrowViewScript := preload("res://src/client/burrow_view.gd")
const NestViewScript := preload("res://src/client/nest_view.gd")
const FarSmokeScript := preload("res://src/client/far_smoke.gd")
const DialogueViewScript := preload("res://src/client/dialogue_view.gd")
const HeldItemScript := preload("res://src/client/held_item.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")
const InstanceLockScript := preload("res://src/client/instance_lock.gd")
const WeatherScript := preload("res://src/shared/weather.gd")
const DrinkRules := preload("res://src/shared/drink_rules.gd")
const ClimateScript := preload("res://src/shared/climate.gd")
const DayCycleScript := preload("res://src/client/day_cycle.gd")
const IceScript := preload("res://src/shared/ice.gd")
const FrozenWater := preload("res://src/client/frozen_water.gd")   # the liquid sheets' ice look (docs/design/frozen_water_look.md)
const SpringSteam := preload("res://src/client/spring_steam.gd")   # steam over spring mouths on frosty mornings (Jamie #739)
const WetlandMist := preload("res://src/client/wetland_mist.gd")
const FishSignsView := preload("res://src/client/fish_signs_view.gd")   # fish jumps, ripples and shadows where the schools are (protocol 169, Dave 24 Nov 2026)   # low mist over fen, bog and swamp at dawn and dusk (Dave 21 Nov 2026)
const IceFeelScript := preload("res://src/client/ice_feel.gd")     # ice sounds, footing and cold shock by thickness (docs/design/ice_walk_feel.md)
const SnowWalkScript := preload("res://src/shared/snow_walk.gd")   # walking on snow and snowshoes (Part C plan 7)
const OceanIceScript := preload("res://src/client/ocean_ice.gd")
const ShoreProps := preload("res://src/client/shore_props.gd")
const SwimScript := preload("res://src/shared/swim.gd")
const FogGroundScript := preload("res://src/shared/fog_ground.gd")
const ICE_POND_DEPTH_M := 3.0           # a typical pond's depth for its freezing speed
const CoverScript := preload("res://src/shared/cover.gd")
const StanceScript := preload("res://src/client/stance.gd")
const StatusIconsScript := preload("res://src/client/status_icons.gd")
const CarryRulesScript := preload("res://src/shared/carry_rules.gd")   # the status strip's heavy-load symbol
const DebugHudScript := preload("res://src/client/debug_hud.gd")
const SoundPanelScript := preload("res://src/client/sound_panel.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const IdleTimeoutScript := preload("res://src/client/idle_timeout.gd")
const SelfTimeoutScript := preload("res://src/shared/self_timeout.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")
const JitterTestScript := preload("res://src/debug/jitter_test.gd")
const MachineProbeScript := preload("res://src/debug/machine_probe.gd")
const GpuProbeScript := preload("res://src/debug/gpu_probe.gd")
const WeatherLookScript := preload("res://src/client/weather_look.gd")
const FaintEffectScript := preload("res://src/client/faint_effect.gd")
const FallMistScript := preload("res://src/client/fall_mist.gd")
const LookWarm := preload("res://src/client/look_warm.gd")
const ShotRunnerScript := preload("res://src/debug/shot_runner.gd")
const FallGrowthScript := preload("res://src/client/fall_growth.gd")
# Shown on the HUD. Owner (2026-10-19): raise it by one with every push.
const RescueScript := preload("res://src/client/rescue.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
var BUILD: int = BuildStamp.number()   # the release stamp's build number, or build.gd NUMBER in an editor run (step A1)
var rig_flora_hold: Dictionary = {}   # look rig (--shot-flora): chunks whose plants the rig drew itself; incoming server flora for them is dropped
var _npc_view: Node3D = null            # NPC bodies, for the Ctrl+Shift+N shortcut
var _player_view: Node3D = null         # the other players (protocol 151, player_view.gd)
var _npc_voice: Node = null             # NPC speech (npc_voice.gd), switched in Settings
const AirBandsCheck := preload("res://src/client/air_bands.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const FlowTexture := preload("res://src/water2/water_flow_texture.gd")
const LiquidSurface := preload("res://src/water2/liquid_surface.gd")
const CaveStreams := preload("res://src/water2/cave_streams.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const WornSync := preload("res://src/client/worn_sync.gd")
const BasicLookScript := preload("res://src/client/basic_look.gd")
const SkyClouds := preload("res://src/client/sky_clouds.gd")
const LookSettings := preload("res://src/client/look_settings.gd")
const KnowledgeScript := preload("res://src/client/inspection_knowledge.gd")
const InspectReticleScript := preload("res://src/client/inspect_reticle.gd")
const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const BlockLinkScript := preload("res://src/stream/block_link.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")
const HorizonScript := preload("res://src/client/horizon_indicator.gd")
const CaveDressing := preload("res://src/client/cave_dressing.gd")
const SpringHeadsScript := preload("res://src/client/spring_heads.gd")
const UnderwaterLook := preload("res://src/client/underwater_look.gd")
const LinkBarsScript := preload("res://src/client/link_bars.gd")
const ConnectWindowScript := preload("res://src/client/connect_window.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const TreeTrunks := preload("res://src/flora/tree_trunks.gd")
const RECENT_CUT_MSEC := 60000   # how long a cut tree is kept out of flora chunks arriving late (BUG-024)
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const WaterVolume := preload("res://src/shared/water_volume.gd")
const ShoreRules := preload("res://src/shared/shore_rules.gd")
const HotbarStripScript := preload("res://src/client/hotbar_strip.gd")
const HeartPulseScript := preload("res://src/client/heart_pulse.gd")
const HudFadeScript := preload("res://src/client/hud_fade.gd")
const PickupFeedScript := preload("res://src/client/pickup_feed.gd")
const NetSettings := preload("res://src/shared/net_settings.gd")
const StepUpScript := preload("res://src/client/step_up.gd")
const EventLogScript := preload("res://src/shared/event_log.gd")
const CrashReportScript := preload("res://src/client/crash_report.gd")
const WaterFallsScript := preload("res://src/worldgen/runtime/water_falls.gd")
const FloraViewScript := preload("res://src/flora/flora_view.gd")
const PieceLook := preload("res://src/client/piece_look.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const AmbientCrittersScript := preload("res://src/client/ambient_critters.gd")
const GrassViewScript := preload("res://src/client/grass_view.gd")
const TrailSignsScript := preload("res://src/client/trail_signs.gd")
const FreshTracksScript := preload("res://src/client/fresh_tracks.gd")
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
const WATER_MIN_MSEC := 3000          # and never more often than this, ground loading or not
const WATER_MAX_MSEC := 12000         # a re-ask that brought no new water doubles the wait, up to this (settled water: the log spam in the lag logs)
const GroundColumn := preload("res://src/client/ground_column.gd")
const WaterReask := preload("res://src/client/water_reask.gd")
const WaterAreas := preload("res://src/shared/water_areas.gd")
# Spawn near the ground (Dave 25 Oct, Tyler): the server's spawn y is already the ground height at the spawn x,z plus 2 m (terrain_server._spawn_point), and a respawn point is
# a real standing place, so the player is put there with this small lift instead of 28 m up. The old +28 m was only waiting for ground to appear.
const SPAWN_LIFT_M := 0.5
const WATER_HOLD_MSEC := 2000        # water refreshes wait this long while ground loads
const SURFACE_WAIT_MSEC := 1500       # stopped in the air: wait this long for the server to say where the ground is
const LOAD_THREADS_MIN := 6                 # ground loading workers at least (see _ready)
const LOD_COUNT := 7
const STAGE_VIEW_M := 128            # the ground view distance in that time
const STAGE_VERTICAL := 0.25         # and this share of it up and down
const STAGE_LODS := 1                # after a stop high up only this many detail levels are built until the ground under the player has a collider
const STAGE_STEP_MIN_MSEC := 600
const STILL_MSEC := 3000              # flying: ground loads again after staying still this long
# Natural speeds in m/s (Dave 2026-10-21, Tyler Report 13; Dave 10 Nov 2026: no jog, "normal is walking at the original jogging speed and
# shift is still running"): two gaits, walk and run. The ONE place to tune them; the server reads effort from data/items/exertion.json
# effort_by_speed, so change those anchors to the same numbers.
const SPACE_WAKE_S := 1.0               # hold Space this long to wake from sleep early
const WALK_SPEED := 3.2               # the old jog speed (the old walk was 1.4)
const FAST := 3.0                     # flying: Shift multiplier
const RUN_SPEED := 9.0                # BUG-011 (Dave 2026-11-04): +50 percent over 6.0. The run clip plays faster to keep up (R-MOVE-RUN-FEET, avatar_driver RUN_CLIP_PACE) and the footsteps follow its feet: STEP_M[1]
# Walking camera (all tuning is here; each list is [walk, run], the walk taking the old jog's numbers). A footfall
# is the lowest point of the bob and the far end of the sway: left foot, camera
# down and leaning left; midway it rises back to the middle; right foot, down
# and leaning right. The bob therefore repeats every step and the sway every
# two steps.
const STEP_M := [1.2, 1.7]               # metres per step, the clips' own: the walk about 2.7 steps a second at 3.2 m/s; the run clip's step is 1.7 m, so at 9 m/s about 5.3 steps a second (R-MOVE-RUN-FEET)
const BOB_M := [0.052, 0.064]            # how far the camera dips at a footfall
const SWAY_M := [0.016, 0.020]           # sideways shift at a footfall
const SWAY_DEG := [0.13, 0.16]           # roll toward the stepping side at a footfall
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
var sound_panel = SoundPanelScript.new()   # Ctrl+Shift+F5: every playing sound with a switch to mute it (sound_panel.gd)
var debug_hud = DebugHudScript.new()   # F3 or Esc > Settings: the long list of diagnostic lines; threads add lines with debug_hud.add_line(name, callable)
var _last_sound: String = ""
var _quality_buttons: Array = []         # Esc > Settings, one per tier; the active one is marked
var _last_sound_seen: Dictionary = {}
var _sound_now: String = "none"          # the loudest sounds playing now, loops and beds included (sound_now.gd), for the HUD
var _sound_now_left: float = 0.0
var _sound_now_logged: String = ""
var _sound_now_log_msec: int = -100000
var compass                         # temporary admin compass (AdminCompass)
var sea: MeshInstance3D
var _work_serial: int = 0               # the held tool's swing count the avatar's chop clip was last started for
var is_admin_here: bool = false   # protocol 134: the server says after the hello whether this player is an admin there (in local play it says yes; false until it does)
var flying: bool = false
var grass_while_flying: bool = false   # the shot runner sets this: its camera flies, but a picture must show the grass a walking player sees (no grass in any rig shot until 9 Nov 2026)
var underwater: bool = false
var _flame_rain_s: float = 0.0          # seconds the held torch has been out in the open rain (flame_rules.gd)
var _torch_burn_msec: int = -100000
var _flame_asked_msec: int = -100000     # when the server was last asked to douse it (one ask a second at most)
var underwater_surface: float = 0.0      # the water surface over the eye while under (fog depth, caustics), 0 in the sea
var _ground_quality: int = -1       # quality the ground texture array was built for
var _z_down_msec: int = -1             # when Z went down while lying (hold to sleep), -1 when not held
var _z_slept: bool = false             # the hold already asked for sleep
const SLEEP_HOLD_S := 3.0              # data/items/sleep.json hold_s
var _was_lying: bool = false
var shot_lock: bool = false              # true while the shot runner takes pictures: mouse look is ignored so the pose it sets stays
var shot_sway: bool = false              # the shot runner's --shot-sway: the drawn bow's sway still turns the camera under shot_lock (the rig's pitch stays the base)
var stance = StanceScript.new()       # standing, crouching (C), sitting (X), lying (Z); client.stance.stance and its `changed` signal
var _shape: CollisionShape3D          # the player's collision capsule (resized by stance)
var running: bool = false             # Shift held with W
var _bob_phase: float = 0.0           # walking head bob
var _bob_amount: float = 0.0
var waiting_for_ground: bool = false
var _drop_ground_lods: int = 0                  # test only (--drop-ground-lods=N): the blocks of LOD 0 to N-1 in the spawn column fail for good; N=4 removes every collision LOD (collision_lod_count 4) and so forces the join hang
var _ground_watchdog = GroundWatchdogScript.new()  # restarts the stream when the ground does not come (see ground_watchdog.gd)
var _ground_giving_up: bool = false
var _ground_log_msec: int = 0
var _ground_logged: bool = false
var _was_waiting: bool = false
var arrival_protect_until_msec: int = 0   # no fall damage report until then (Dave 2026-10-21: arriving must not hurt)
const ARRIVAL_HEIGHT_M := 0.5             # the body is set this far above the ground when the ground first appears
const ARRIVAL_PROTECT_MS := 6000
const LOAD_QUIET_MS := 3000      # placed-thing sounds stay quiet this long after landing and after the join window closes (_world_loading)
var _load_quiet_until_msec: int = 0
const FLY_LAND_PROTECT_MS := 60000   # Dave 2026-10-21: pressing G to land from flying hurts nothing for a minute
var _tint: ColorRect
var _aim_msec: int = 0
var _aim_pos: Vector3 = Vector3.ZERO
var _mode_label: Label
var status_icons                      # StatusIcons: the status strip left of the hotbar (data/ui/status_strip.json); others add a symbol with status_icons.add(id, read)
var test_water_step: bool = false   # headless check: press + twice 12 s in
var _water_label: Label             # the water flow rate readout, shown for 3 seconds after + or -
var _water_label_until_msec: int = 0
var _inspect_label: Label            # what the player is looking at (inspection mode)
var inspecting: bool = false
var _inspect_plus: Control = null     # the red + at the middle while inspection is on (inspect_reticle.gd)
var test_clear: bool = false          # --test-clear: press Clear saved ground 12 s after the welcome
var _test_clear_done: bool = false
var test_start: Vector3 = Vector3.INF   # --start=x,y,z: put the player there (tests)
var _test_probe_msec: int = 0
var test_dump: bool = false           # --dump-test: 14 s after the welcome dump the ground under the feet (prints the dump)
var _test_dump_done: bool = false
var tunnel_on: bool = false               # the server's tunnel collapse switch (admins change it in Esc > Settings)
var tunnel_cave_in_s: int = 1200
var _health_seen: float = -1.0           # last frame's health, to jolt the view when it drops
var _swim_t: float = 0.0                 # swimming bob clock
var feel = FeelKicksScript.new()                 # landing dip and tool-blow jolt on the eye (feel_kicks.gd)
var quake_view = QuakeViewScript.new()        # shake, dust and notices while a tunnel is failing (quake_view.gd)
var _ladder_climbed_m: float = 0.0           # metres climbed since the last rung sound
var ladder = LadderClimbScript.new()          # holding on to a placed ladder (ladder_climb.gd)
var ground_debug = GroundDebugScript.new()    # ground dump, ground self-check, hole probe (ground_debug.gd)
var drip_view = DripViewScript.new()          # dripping ceilings under water (drip_view.gd)
var game_menu = GameMenuScript.new()          # the Esc menu (game_menu.gd)
var sound_tests = SoundTestMenuScript.new()   # Esc > Settings sound test buttons and their state (sound_test_menu.gd)
var menu_open: bool = false          # the Esc options menu
var _menu: Control
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
var test_menu: bool = false                    # --menu-test: open every Esc menu page and flip every switch
var _test_menu_done: bool = false
var test_fly: bool = false
var test_route: Vector2 = Vector2(1.0, 0.0)   # --route=east|south|diag: heading of the --fly test
var test_fly_msec: int = 30000                # --flytime=seconds: how long the --fly test moves
var hole_probe: bool = false                  # --hole-probe: count missing ground colliders around the player every second (stress test)
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
var _tunnel_test: int = 0
var _spawn_test: String = ""            # --test-respawn=S / --test-go-to-spawn=S: S s after the welcome (and ground) do a respawn or go-to-spawn and log how it lands
var _spawn_test_after_s: float = 0.0
var _spawn_test_msec: int = 0           # when it was done (0 = not yet), then the log waits for the player to stand
var _spawn_y_offset: float = 0.0        # --spawn-y-offset=M: M added to every spawn point's height (negative puts the spawn inside the ground)
var _tunnel_msec: int = 0
var _tunnel_at: Vector3 = Vector3.ZERO
var rescue = RescueScript.new()        # every way the player is stood back on the surface (src/client/rescue.gd)
var test_walk: bool = false
var test_crouch_walk: bool = false      # --walk --crouchwalk: crouched walks past the trees near the drop point (Dave 23 Nov 2026, the crouch block)
var shot_run: bool = false             # the shot runner's --shot-run: on foot along _walk_dir at run_speed while it measures frame times (running lag)
var _walk_phase: int = 0               # 0 wait, 1 falling, 2 walking, 3 into a tree, 4 done
var _walk_msec: int = 0
var _walk_dir: Vector3 = Vector3.ZERO
var _walk_stats: Dictionary = {}
var test_dig: bool = false
var _ditch: Array = []                  # --dig-ditch: dig centres still to request (x, z), oldest first
var _ditch_next_msec: int = 0
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
var _test_fire_at: int = 0
var _test_fire_step: int = 0
var _test_spear_step: int = 0
var _test_spear_at: int = 0
var test_interior: bool = false
var _test_interior_step: int = 0
var _test_interior_at: int = 0
var test_items: bool = false
var test_gather: bool = false
var test_strain_run: bool = false       # --strainrun: with --walk --runspeed=11, the server strain must climb while running
var test_arrival: bool = false         # --arrival: after the ground appears, health must still be 100 (arriving is not a fall)
var test_leanto: bool = false
var test_chest: bool = false
var test_eat: bool = false
var test_quickkeys: bool = false
var test_texttest: bool = false
var test_screen_audit: bool = false    # --screenaudit: every screen at every text size, laid out headless and checked (screen_audit.gd)
var test_screen_shots: String = ""     # --screenshots=DIR with --screenaudit in a real window: a picture of each audited screen (tools/screen_shots.sh)
var test_plantpick: bool = false
var test_embed: bool = false
var test_resume: String = ""          # --resume-test=logout|drop (leave 60 m from the spawn), =stay (then 90 m, and stay in) or =check (say where the game starts)
var test_dig_next: bool = false
var test_spear: bool = false
var test_chop: bool = false
var lag_run: Node = null               # --lag-run: the scripted early-game lag run (src/client/lag_run.gd, tools/lag_run.sh)
var motion_audit = null                 # --motion-audit or a robot: the walk measured against the keys (src/client/motion_audit.gd)
var welcome_card = null                # the welcome card, once per character on this computer (welcome_card.gd)
var hint_card = null                   # the guide hints' OK box (hint_card.gd, R-HUD-HINT-BOX)
var _hurt_msec: int = -100000          # the last blow that landed on this player (the hint card waits a while after it)
var robot: Node = null                 # --robot=NAME: a robot play-tester drives this client by key presses (src/client/robot_play.gd, tools/robots.sh)
var _block_port_override: int = 0      # --block-port=N: the block line connects here instead of the port the server named (a test relay, tools/lossy_link.py)
var test_shoot: bool = false            # --shoot: draw and loose one arrow with no key presses (SHOOT TEST lines)
var test_cook: bool = false              # --cook: lay and light a campfire, roast raw meat, eat it (COOK TEST lines)
var test_sleep: bool = false             # --sleep: set down a rough bed, lie on it, sleep a few seconds, wake (SLEEP TEST lines)
var test_net: bool = false               # --net: hold the fishing net and click with it, pack before and after (NET TEST lines, BUG-022)
var test_snare: bool = false             # --snare: set a snare and wait for a carcass (SNARE TEST lines; server knob traps.json test_chance)
var test_place_foundation: bool = false   # --place-foundation: give a thatch floor kit and place it ahead (FOUNDATION TEST lines)
var test_creatures: bool = false
var _test_creature_at: int = 0
var _test_creature_step: int = 0
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
var shore_props                       # ShoreProps (the tide-line gather spots drawn on the beach)
var nest_view                         # NestView (inland grouse and songbird nests, src/client/nest_view.gd)
var swimming: bool = false            # in deep water, feet under the surface (src/shared/swim.gd)
var _climb_until_msec: int = 0        # pulling out of the water onto a bank or floe until then
var _under_ice_next_msec: int = 0
var _ice_gap: Vector3 = Vector3.ZERO  # the way out from under a floe or ice sheet (zero when not under one)
var fall_mist                         # FallMist: spray at the foot of the nearest waterfalls
var fall_growth                       # FallGrowth: ferns around the foot of the nearest waterfall
var items                             # InventoryView: inventory panel (I), pick-up (E)
var harvest                           # Harvest: E prompt, tap to pick, hold to sweep
var pickup_feed                       # PickupFeed: "+3 Firewood" notices on the left of the screen
var hotbar_strip                      # HotbarStrip: keys 1 to 0 on screen, drag items onto a key (the keys are pack slots 0 to 9)
var heart_pulse                       # HeartPulse: the line of light over the hotbar that pulses with the heartbeat (heartbeat_design.md)
var hud_fade                          # HudFade: passing out fades the whole HUD but the heartbeat line (heartbeat_design.md "Passing out")
var held                              # HeldItem: hotbar keys 1 to 8, spear jab and throw
var grass                             # GrassView
var trail_signs                       # TrailSigns: signs along the animals' trails (stage 2d)
var fresh_tracks                      # FreshTracks: prints left by live animals near the player, fading (hunting thread)
var map_knowledge = MapKnowledgeScript.new()   # this character's surveyed map cells (protocol 120); the Journal's Map page draws them (map_page.gd)
var critters                          # AmbientCritters: butterflies, bees, dragonflies, birds and fireflies (client only)
var faint                             # FaintEffect: tunnel vision, blur and black-out (set_state)
var sound                             # SoundStage: wind, footsteps, grass swish
var _commit: String = GitStamp.short_commit()   # which checkout is running
var _render_scale: float = 1.0            # 3D resolution scale now (render_scale.gd)
var _jitter_test                      # float-precision test, J or Esc > Advanced
var _machine_probe                    # "Measure this machine" run for the minimum-spec test (Esc > Advanced)
var _gpu_probe                        # GPU cost per piece of the scene, Ctrl+Shift+P
var weather_look                      # WeatherLook: clouds, rain, snow, fog, lightning from `weather`
var _bake = null                      # admin: background tile bake (src/admin/tile_bake_launcher.gd), made when started; editor runs only (game_menu.gd)
var _bake_check_msec: int = 0
var _bake_status: String = ""
var _bake_alert_until: int = 0
var _bake_alert_at: Vector3 = Vector3.ZERO   # where the player stood when the finished notice came up
var _bake_done_note: String = ""          # the bake's own finished message, shown once the ground reloads
var idle_timeout = IdleTimeoutScript.new()   # the game closes after the idle minutes of Esc > Settings > Gameplay without input (idle_timeout.gd)
const HitNumbersScript := preload("res://src/client/hit_numbers.gd")
var display = DisplaySettingsScript.new()   # saved window, VSync and quality choices
var quality: int = 2                  # index into QUALITY_NAMES; High is the default
var _flora_view_full: PackedFloat32Array = PackedFloat32Array()
var _flora_near_full: PackedFloat32Array = PackedFloat32Array()
var _viewer: VoxelViewer
var _sun: DirectionalLight3D
var _frame_ms: Array = []             # recent frame times for the HUD readout
var test_cut: bool = false
var _recent_cuts: Dictionary = {}     # held chunk -> {item id: msec the cut came in} (BUG-024; see _apply_incoming)
var _flora_asked: Dictionary = {}     # chunk -> true asked or held in full, false trees only
var _flora_check_msec: int = 0
var link = null                       # direct block line (block_link.gd)
var quitting: bool = false            # the game is closing, not changing scene (death screen, Retry): _ends_at_exit_tree
var _in_queue: Array = []             # chunks from the server being unpacked, in arrival order
var _flow_jobs: Array = []            # [task id, job] of the live water windows being unpacked on a worker, in arrival order (_on_water_flow)
var _in_mutex: Mutex = Mutex.new()
var _in_generation: int = 0           # raised when the plants are dropped (a bake): older chunks are ignored
var under_cover: float = 0.0          # 1 under a tree's canopy, else 0 (Cover.at at the player, once a second)
var weather: Dictionary = {}          # the weather here and now (WeatherScript.state): the same on every client, no network traffic; rendering and sounds read it
var _weather_next_msec: int = 0
var world_wind_dir: float = 0.0       # the world's wind heading before the ground here bends it (Weather.state)
var wind_here: Dictionary = {}        # what the ground round the viewer does to the wind (Weather.local_wind's `here`), every 2 s
var _wind_here_next_msec: int = 0
var game_clock = GameClockScript.new()   # copy of the server's game clock, set at the welcome
var _water_dirty: bool = false        # the server said the water moved; not asked for yet
var _water_asked_msec: int = 0
var _water_wait_msec: int = WATER_MIN_MSEC   # the wait between re-asks now (WATER_MIN_MSEC to WATER_MAX_MSEC)
var _water_new_since_ask: int = 0           # chunks with changed water since the last re-ask
var _water_quiet_asks: int = 0              # re-asks in a row that brought nothing new (the log line is printed for the first only)
var _water_dirty_areas: Array = []   # protocol 88, a list since 130: the Rect2s where the water moved since the last ask
var _water_dirty_all: bool = false
var _flora_chunks: int = 0
var _flora_bytes: int = 0
var _flora_cuts: int = 0
var _flora_done_msec: int = 0
var _host: String = "127.0.0.1"
var _port: int = 24600
var _wait_until_msec: int = 0
var _auth = null                          # the join handshake (server_auth.gd): an open server passes at once, one with a password asks
var _password_arg: String = ""            # --password= (tests, bots): typed for the player once
var _password_box = null                  # the password popup (password_box.gd), made when a server first asks
var _remember_password: bool = false      # the player ticked "Remember on this computer" for the password now being tried
var _avatar_glb: String = ""              # the player's own body model file (my_character.gd body_model), warmed in _ready
var _remote: bool = false                 # a client-only build joining someone's server: no local Play server to restart (join_address.gd)


func _ready() -> void:
	load("res://src/client/title_music.gd").stop(get_tree())   # the menu music fades out: it never plays over the world
	var my_model: String = MyCharacter.body_model()
	_avatar_glb = DynastyBodyScript.BodyModels.glb(my_model)
	DynastyBodyScript.warm([my_model], [MyCharacter.genome().get("hair_model", "")])   # the body and arm files (and the player's own body model and hair style) load on loader threads now, not on the main thread at the welcome (a 3 s freeze)
	DynastyBodyScript.clips_on_worker = not DynastyBodyScript.headless()   # in a window the first body's 143 clips are made on a worker thread, not in the join's first-body frame (276 ms, Lane A Low route 26 Nov 2026)
	OceanMesh.start()   # the sea's 148 thousand vertex grid, on a worker while the client connects (about 400 ms of the welcome's frame on Lane A Low)
	LookWarm.start(get_tree())   # the mist, rain and snow looks, one a frame while the client waits for the welcome, when the menus did not make them
	InventoryViewScript.warm_pickups()   # the stone, stick and driftwood models, on loader threads while the client connects (406 ms of the welcome's frame on Lane A Low)

	# Ground loading threads (Dave 2026-10-21, settling after a fast fly-over took 61 s): each ground block a worker asks for
	# waits for the server's answer, so with the engine's default pool (half the cores: 2 on a 4 core machine) only two
	# blocks were in flight. 6 or more workers settle the same stop in about 15 s (hole_stress east, 4 cores, 4 to 8 threads);
	# a machine whose default is already higher keeps it. VOXEL_THREADS=n overrides (tests).
	if OS.has_environment("VOXEL_THREADS"):
		VoxelEngine.set_thread_count(int(OS.get_environment("VOXEL_THREADS")))
	else:
		VoxelEngine.set_thread_count(maxi(VoxelEngine.get_thread_count(), LOAD_THREADS_MIN))

	# Crash reporting (crash_report.gd): breadcrumbs, a flag, and a report file in crash_reports/ after an unclean end.
	if DisplayServer.get_name() != "headless" or OS.has_environment("CRASH_CHECK"):
		crash_report = CrashReportScript.new()
		crash_report.start(BUILD, _commit)
		SoundStageScript.slow_load = crash_report.event      # a slow first load of a sound file is named in the crash report

		if crash_report.last_report != "":
			_previous_run_note_until_msec = Time.get_ticks_msec() + 90000

	net = $TerrainNet
	process_physics_priority = 1000   # _physics_process notes the start of the physics engine's step
	add_child(ProcessEndMarkScript.new())   # stamps the end of every frame's scripts (diagnostics: HITCH lines' "scripts" and "deferred and engine")
	add_child(NetPollScript.new(net))   # polls the network itself from process_frame, timed as "net poll" (diagnostics: what a slow poll held)
	display.load_saved()
	SelfTimeoutScript.install(self, OS.get_cmdline_user_args(), func(why: String):   # testing only: --timeout=S / --watch-parent=PID
		_telemetry.event("EXIT: %s" % why)
		_finish(0))
	idle_timeout.name = "IdleTimeout"
	add_child(idle_timeout)
	idle_timeout.setup(OS.get_cmdline_user_args(), display.idle_minutes, DisplayServer.get_name() == "headless")
	idle_timeout.timed_out.connect(func():
		_telemetry.event("EXIT: idle timeout after %d minutes without input" % idle_timeout.minutes)
		_finish(0))

	if display.quality >= 0:
		quality = clampi(display.quality, 0, QUALITY_NAMES.size() - 1)

	display.apply(get_window(), true)   # joining keeps a window the player made fullscreen or maximised on the title or server page

	for shot_argument in OS.get_cmdline_user_args():
		if shot_argument.begins_with("--shots="):
			var shot_runner = ShotRunnerScript.new()
			shot_runner.name = "ShotRunner"
			add_child(shot_runner)
			shot_runner.setup(self, OS.get_cmdline_user_args())
			shot_lock = true   # a picture run: the mouse must not turn the player between the pose and the shot (tech/CAMERA_TURN_RECIPE.md)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			break
	var host: String = "127.0.0.1"
	var port: int = 24600
	_remote = JoinAddress.client_only()

	if _remote and AppConfig.get_command_line_value("server", "") == "":   # --server= (tests, rigs) names its own host and port
		var joined: Dictionary = JoinAddress.parse(JoinAddress.current())
		host = str(joined.get("host", ""))
		port = int(joined.get("port", JoinAddress.DEFAULT_PORT))

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
		elif argument.begins_with("--water-spam="):
			_water_spam_per_s = float(argument.trim_prefix("--water-spam="))   # test: ask for the water of every held chunk this many times a second
		elif argument == "--tunnel-test":
			_tunnel_test = 1                      # test: dig a shaft and a side tunnel, stand in it, report whether the player was moved
		elif argument == "--no-dig-guard":
			rescue.dig_guard = false                    # test: switch the dig guard of the surface rescue off (shows the old behaviour)
		elif argument.begins_with("--lose-after="):
			_lose_after_s = float(argument.trim_prefix("--lose-after="))   # test: act as if the server dropped us this many seconds after the welcome
		elif argument == "--act-test":
			_act_test = true   # test: ask for stones, drop one, dig, 2 s apart, 10 s after the welcome (the server logs each action)
		elif argument.begins_with("--tunnel-spam="):
			_tunnel_per_s = float(argument.trim_prefix("--tunnel-spam="))   # test: dig a shaft down then a tunnel along, a new 0.9 m spot this many times a second
		elif argument.begins_with("--dig-spam="):
			_dig_spam_per_s = float(argument.trim_prefix("--dig-spam="))   # test: dig the same 0.9 m spot this many times a second (a held click)
		elif argument == "--fly":
			test_fly = true
		elif argument.begins_with("--flyalt="):
			test_fly_alt = float(argument.trim_prefix("--flyalt="))
		elif argument.begins_with("--wait="):
			_wait_until_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--wait=")) * 1000.0)
		elif argument.begins_with("--drop-ground-lods="):
			_drop_ground_lods = int(argument.trim_prefix("--drop-ground-lods="))
		elif argument.begins_with("--test-respawn="):
			_spawn_test = "respawn"
			_spawn_test_after_s = float(argument.trim_prefix("--test-respawn="))
		elif argument.begins_with("--test-go-to-spawn="):
			_spawn_test = "go_to_spawn"
			_spawn_test_after_s = float(argument.trim_prefix("--test-go-to-spawn="))
		elif argument.begins_with("--spawn-y-offset="):
			_spawn_y_offset = float(argument.trim_prefix("--spawn-y-offset="))
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
			ground_debug.check_enabled = false
		elif argument == "--menu-test":
			test_menu = true
		elif argument == "--dump-test":
			test_dump = true
		elif argument == "--inspect":
			inspecting = true
			test_inspect = true
		elif argument == "--walk":
			test_walk = true
		elif argument == "--crouchwalk":
			test_crouch_walk = true
		elif argument.begins_with("--runspeed="):
			run_speed = float(argument.trim_prefix("--runspeed="))
		elif argument == "--water-step":
			test_water_step = true
		elif argument == "--dig-check":
			test_dig_check = true
		elif argument == "--dig":
			test_dig = true
		elif argument.begins_with("--dig-ditch="):
			var d: PackedStringArray = argument.trim_prefix("--dig-ditch=").split(",")

			if d.size() == 3:
				for n in range(int(float(d[2]) / 1.5) + 1):
					_ditch.append(Vector2(float(d[0]), float(d[1]) - 1.5 * float(n)))
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
		elif argument == "--embed-test":
			test_embed = true
		elif argument.begins_with("--resume-test="):
			test_resume = argument.trim_prefix("--resume-test=")
		elif argument == "--dig-next-test":
			test_dig_next = true
		elif argument == "--texttest":
			test_texttest = true
		elif argument == "--screenaudit":
			test_screen_audit = true
		elif argument.begins_with("--screenshots="):
			test_screen_shots = argument.trim_prefix("--screenshots=")
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
		elif argument == "--lag-run":
			lag_run = preload("res://src/client/lag_run.gd").new()
		elif argument == "--motion-audit":
			motion_audit = preload("res://src/client/motion_audit.gd").new()
		elif argument.begins_with("--robot="):
			if motion_audit == null:
				motion_audit = preload("res://src/client/motion_audit.gd").new()   # every robot measures its own walk
			robot = preload("res://src/client/robot_play.gd").new()
			robot.prepare(argument.trim_prefix("--robot="), OS.get_cmdline_user_args())   # makes and picks its own character before hello
		elif argument.begins_with("--block-port="):
			_block_port_override = int(argument.trim_prefix("--block-port="))
		elif argument == "--shoot":
			test_shoot = true
		elif argument == "--place-foundation":
			test_place_foundation = true
		elif argument == "--cook":
			test_cook = true
		elif argument == "--sleep":
			test_sleep = true
		elif argument == "--snare":
			test_snare = true
		elif argument == "--net":
			test_net = true
		elif argument == "--creatures":
			test_creatures = true

	net.welcome_received.connect(_on_welcome)
	net.game_time_received.connect(func(game_seconds: float) -> void: game_clock.sync(game_seconds))   # a night skip moved the server's clock to dawn (protocol 170)
	net.join_refused_received.connect(func(text: String) -> void:
		_on_join_refused(text, join_refused_title(text)))
	net.notice_received.connect(func(text: String) -> void:
		if text == NetScript.SERVER_CLOSING:
			_server_closing = text)   # the server is stopping (a restart or an update): its "connection lost" window says so
	net.blocks_received.connect(_on_blocks)
	net.tile_changed_received.connect(_on_tile_changed)
	net.edits_since_received.connect(_on_edits_since)
	net.dug_received.connect(_on_dug)
	net.filled_received.connect(_on_filled)
	net.flora_received.connect(_on_flora)
	net.flora_cut_received.connect(_on_flora_cut)
	net.flora_stripped_received.connect(_on_flora_stripped)
	net.drink_points_received.connect(_on_drink_points)
	net.nests_received.connect(_on_nests_sound)   # songbird nests are heard (ambient_life.set_nests); MikeW draws them from the same signal
	net.flora_fruit_received.connect(_on_flora_fruit)
	net.zone_received.connect(func(biome_id: int) -> void: sound.ambience.set_zone(biome_id))
	net.vent_received.connect(func(at: Vector3) -> void: sound.ambience.set_vent(at))
	net.water_rate_received.connect(_on_water_rate)
	net.water_changed_received.connect(_on_water_changed)
	net.water_changed_in_received.connect(_on_water_changed_in)
	net.water_flow_received.connect(_on_water_flow)
	net.fine_water_received.connect(_on_fine_water)
	net.tunnel_settings_received.connect(func(on: bool, cave_in_s: int) -> void:
		tunnel_on = on
		tunnel_cave_in_s = cave_in_s
		_show_tunnel_buttons())
	net.leak_received.connect(func(points: PackedVector3Array, closeness: PackedByteArray) -> void:
		drip_view.on_leak(points, closeness, body.global_position))
	net.quake_received.connect(func(stage: int, strength: float, point: Vector3) -> void:
		quake_view.on_quake(stage, strength)

		if sound != null and sound.placed != null:
			sound.placed.quake(stage, strength, point))
	net.pulse_received.connect(func() -> void:
		if link_bars != null:
			link_bars.pulse())
	net.ground_reset_received.connect(_on_ground_reset)
	net.died_received.connect(_on_died)
	net.final_death_received.connect(_on_final_death)
	net.hit_number_received.connect(func(at: Vector3, amount: int) -> void:
		if display.damage_numbers:
			HitNumbersScript.spawn(self, at, amount))   # the flesh thud comes with animal_hit below: a tree or boulder blow sends a number too and is not flesh
	net.start_at_received.connect(_on_start_at)
	net.admin_status_received.connect(_on_admin_status)
	net.step_to_received.connect(_on_step_to)
	net.water_received.connect(_on_water_received)
	net.cave_streams_received.connect(_on_cave_streams)
	net.cave_dressing_received.connect(_on_cave_dressing)
	net.cave_dens_received.connect(_on_cave_dens)
	net.surface_received.connect(_on_surface_received)
	net.dump_received.connect(ground_debug.on_dump_received)
	_host = host
	_port = port

	if crash_report != null:
		crash_report.server_port = port
		_telemetry.start("telemetry_client.log")
		_telemetry.event("client start build %d, port %d" % [BUILD, port])

	# Started by the "play" launcher, whose server may still be loading.
	if waits_for_server(AppConfig.get_command_line_value("role", "")) and _wait_until_msec == 0:
		_wait_until_msec = Time.get_ticks_msec() + (30000 if _remote else 120000)   # a remote server is already up; 30 s rides out a brief drop
	multiplayer.server_disconnected.connect(_on_server_lost)
	multiplayer.connected_to_server.connect(func():
		_link_up_msec = Time.get_ticks_msec()
		NetSettings.apply((multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)))
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_authentication_failed.connect(_on_auth_failed)
	started_msec = Time.get_ticks_msec()

	if DisplayServer.get_name() != "headless":
		_connect_window = ConnectWindowScript.new()

		if _remote:
			_connect_window.on_back = _back_to_servers   # server pick page: Cancel while joining, Back to servers on a failure

		_connect_window.setup(self)
		_connect_window.show_first_load_note(BUILD)

		if _remote and Engine.has_meta("continue_join"):
			_connect_window.set_heading("Joining %s as %s" % [_server_label(), str(CharacterStoreScript.active().get("name", "your character"))])

	_connect()


var _refused_read_msec: int = -100000   # _play_server_refused: when the run note was last read


# Play's own server refused to start (its save files could not be read: terrain_server.gd): its reason, from the note it left
# (user://server_run.json, state "refused") since this game began waiting; "" otherwise.
func _play_server_refused(waited: int) -> String:
	var path: String = "user://server_run.json"
	var now: int = Time.get_ticks_msec()

	if now - _refused_read_msec < 1000:
		return ""   # read once a second, not every frame of the start-up

	_refused_read_msec = now
	var note: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

	if not (note is Dictionary) or str(note.get("state", "")) != "refused" or float(note.get("t", 0.0)) < Time.get_unix_time_from_system() - float(waited) - 30.0:
		return ""

	return str(note.get("why", "The server did not start."))


# What the connection window says: the step the game is on, how long it has been there, and (when it is stuck) the likely reason.
func _update_connect_window() -> void:
	if _join_refused != "":
		return   # the refusal stays on the window until the player quits

	var now: int = Time.get_ticks_msec()
	var waited: int = int(float(now - started_msec) * 0.001)
	var where: String = "%s:%d" % [_host, _port]

	if connected_msec > 0:
		var since: int = int(float(now - connected_msec) * 0.001)

		# On a first start the window (and its note) stays until the player has landed ("JOIN: ground ready"): the long pause comes a frame
		# after the welcome, when waiting_for_ground is still false (Lane A, 21 Nov 2026: the window closed at +5 s, then froze 24 s).
		# Ground on the very first walk step (a warm ground cache after an update) never logs "ground ready": then 10 s, past the pause's start.
		var landed: bool = (_ground_logged or (not waiting_for_ground and since >= 10)) if _connect_window.first_load_note_shown() else not waiting_for_ground

		if since > JOIN_GIVE_UP_S and not landed:
			_connect_window.fail("The ground did not arrive", "The server welcomed this game, but after %d minutes the ground under you has still not loaded.\n\nGo back and join again, or quit and send these files from the game's user folder: telemetry_client.log and ground_mismatch.log." % floori(since / 60.0), func(): _finish(1))
			return

		if landed and since >= 3:   # never before the ground is there: a window closed at 120 s left a player looking at an empty world, and the ground watchdog's give-up (up to 180 s and more) then had no window to say it on
			_telemetry.event("connect window closed after %d s in the world" % since)

			if landed:
				ConnectWindowScript.mark_first_load_done(BUILD)
			_connect_window.close()
			_connect_window = null
			_load_quiet_until_msec = maxi(_load_quiet_until_msec, now + LOAD_QUIET_MS)
			_offer_welcome()   # landed, also on the warm-cache first step that never logs "ground ready"
			return

		var silent_server: bool = waiting_for_ground and stream != null and _ground_received() == 0 and stream.pending() == 0 and _ground_watchdog.tries == 0

		if silent_server and since >= 20:
			_telemetry.event("JOIN: %d s in the world with no ground, 0 blocks received, 0 asked for; link: %s" % [since, link_bars.text() if link_bars != null else "?"])
			var advice: String = "The server welcomed this game but no ground has arrived for %d s and none is being asked for. Most likely the server is an old one from an earlier run that is closing or out of date. Quit, wait a few seconds, and press Play again (a new game replaces an out-of-date server)." % since

			if _remote:
				advice = "The server welcomed this game but no ground has arrived for %d s and none is being asked for. The server may be restarting. Quit, wait a minute and join again; if it keeps happening, tell whoever runs the server." % since

			_connect_window.fail("The server is not sending ground", "1. Server found at %s: done\n2. Welcome received\n3. Loading the ground under you: nothing arriving\n\n%s" % [where, advice], func(): _finish(1))

		_connect_window.update("1. Server found at %s: done\n2. Welcome received, server protocol %s, this game %d: matches\n3. Loading the ground under you: %d blocks still arriving, %d received, %d s so far\n\nThe game opens as soon as there is ground to stand on.%s%s" % [where, str(world.get("protocol", "?")), NetScript.PROTOCOL_VERSION, stream.pending() if stream != null else 0, _ground_received(), since, ("\n\n" + _ground_watchdog.note()) if _ground_watchdog.tries > 0 else "", ("\n\nThe ground is taking long: %d blocks received, %d failed, %d still arriving, player height %.0f m." % [_ground_received(), _ground_failed(), stream.pending() if stream != null else 0, body.global_position.y]) if since > 60 and body != null else ""])
		return

	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	var status: int = peer.get_connection_status() if peer != null else MultiplayerPeer.CONNECTION_DISCONNECTED

	if _link_up_msec > 0:
		var quiet: int = int(float(now - _link_up_msec) * 0.001)
		var text: String = "1. Opening the connection to %s: done\n2. Waiting for the server's welcome: %d s" % [where, quiet]

		if quiet >= 8:
			if _remote:
				text += "\n\nThe server at %s accepted the connection but has not welcomed this game. It may be busy or restarting. Quit, wait a minute and try again; if it keeps happening, tell whoever runs the server." % where
			else:
				text += "\n\nThe server accepted the connection but has not welcomed this game. Most likely an OLD server from an earlier run is still running on port %d. Close the game, end every \"Godot\" process except the editor in Task Manager, then press Play again." % _port

			_connect_window.fail("The server is not answering this game", text, func(): _finish(1))

		_connect_window.update(text)
		return

	var refused: String = "" if _remote else _play_server_refused(waited)

	if refused != "":
		_join_refused = refused   # stays on the window; no retry
		_telemetry.event("JOIN: Play's server refused to start: %s" % refused)
		_connect_window.fail("The server did not start", refused, func(): _finish(1))
		return

	var trying: String = "1. Opening the connection to %s: %s, %d s\n2. Waiting for the server's welcome\n3. Loading the ground under you" % [where, "trying" if status == MultiplayerPeer.CONNECTION_CONNECTING else "not connected", waited]

	if waited >= 20 and _remote:
		trying += "\n\nNo server has answered yet at %s. The game keeps trying for about half a minute." % where
	elif waited >= 20:
		trying += "\n\nNo server has answered yet. The server may still be starting (the game keeps trying for up to 2 minutes), or it did not start: if port %d is held by another program the new server cannot use it." % _port

	_connect_window.update(trying)


func _connect() -> void:
	if _remote and _host == "":
		_cannot_reach("This game has no server address yet. Start it again and choose a server on the server pick page.")
		return

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(_host, _port)

	if error != OK:
		push_error("Terrain client: cannot connect to %s:%d (%s)" % [_host, _port, error_string(error)])

		if not _remote:
			quitting = true
			get_tree().quit(1)
			return

		_cannot_reach("The game cannot open a connection to %s:%d (%s). If that is a name, check its spelling and this computer's internet connection." % [_host, _port, error_string(error)])
		return

	_attach_auth()
	multiplayer.multiplayer_peer = peer
	FreezeWatchScript.printer.line("Terrain client: connecting to %s:%d" % [_host, _port])
	GroundMaterialScript.start_early(quality)   # the ground photos are sized on a worker while the welcome is on its way
	SoundStageScript.prewarm()   # every sound file starts loading now, not in the welcome frame (181 ms there in the 5 Nov lag run)


# The server dropped this client or ended. A player sees a plain message with Retry and Quit and the world stays
# visible (the game is paused); a headless test run quits as before. The crash report is written first.
func _on_server_lost() -> void:
	if quitting:
		return   # this game closed its own line as it quits (_close_line)

	FreezeWatchScript.printer.line("Terrain client: server left")
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	_telemetry.event("EXIT: server_disconnected (the server dropped this client or ended); last link: %s" % (EventLogScript.peer_stats(enet.get_peer(1)) if enet != null and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED else "gone"))

	if _join_refused != "":
		return   # dropped after a refusal: the window already says why (_on_join_refused)

	if crash_report != null:
		crash_report.report_now("server left: the connection to the server was lost")

	if _lost_layer != null:
		return

	if DisplayServer.get_name() == "headless" and not OS.get_cmdline_user_args().has("--lost-notice"):
		_finish(1)
		return

	_show_lost_notice(lost_reason(_server_closing))


# Why the connection went, for the "connection lost" window: the server's own word when it said it was stopping (a restart).
static func lost_reason(closing: String) -> String:
	return closing.trim_suffix(".") if closing != "" else "the server stopped answering or closed the connection"


# The notice stays up until the player picks Retry or Quit: no timer, no automatic quit. The world is frozen (tree paused,
# so input and movement stop), sound is muted, and the window stays open even if the server process is gone.
func _show_lost_notice(reason: String) -> void:
	if _lost_layer != null:
		return

	if link_bars != null:
		link_bars.set_lost()
		reason += " (" + link_bars.text() + ")"

	_telemetry.event("NOTICE: connection lost, window stays open: " + reason)
	FreezeWatchScript.printer.line("Terrain client: connection lost notice shown: " + str(reason))
	AudioServer.set_bus_mute(0, true)
	_lost_layer = CanvasLayer.new()
	_lost_layer.layer = 100
	_lost_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label: Label = Label.new()
	label.text = "Connection to the server was lost"
	label.add_theme_font_size_override("font_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var note: Label = Label.new()
	@warning_ignore("integer_division")
	note.text = "At %s, after %d min in this session.\nReason: %s.\n%s" % [Time.get_time_string_from_system(), (Time.get_ticks_msec() - connected_msec) / 60000, reason, "Retry joins again. If the server has stopped, Back to servers opens the server list, which shows when it answers again." if _remote else "Retry joins again. If the server has stopped, Quit and press Play."]
	note.add_theme_font_size_override("font_size", 20)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(640.0, 0.0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	var choices: Array = [["Retry", func(): AudioServer.set_bus_mute(0, false); get_tree().paused = false; get_tree().reload_current_scene()]]

	if _remote:
		choices.append(["Back to servers", _back_to_servers])   # a joined player is never left with only Retry or Quit

	choices.append(["Quit", func(): _finish(1)])

	for entry in choices:
		var button: Button = Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(280.0, 48.0)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(entry[1])
		box.add_child(button)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	_lost_layer.add_child(backdrop)
	_lost_layer.add_child(panel)
	add_child(_lost_layer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


# Whether the client keeps trying for 120 s while its server comes up. The "play" launcher starts the server beside it, and so does a plain
# editor run (F5 / F6), which has no role at all: launcher.gd defaults it to play. Dave's F6 test play on 9 Nov 2026 failed with
# "connection failed" because the server took 21.7 s to listen on its first start after a pull (the ground and the flora layout rebuilt)
# and the client, with no role, gave up on its first try. "terrain_client" (joining a server by address) still fails at once.
static func waits_for_server(role: String) -> bool:
	return role == "play" or role == ""


# While a --wait is running, a server not up yet is tried again.
func _on_connection_failed() -> void:
	if _join_refused != "":
		return   # refused at the password or the build: the window already says why, and a retry would only ask again

	if Time.get_ticks_msec() < _wait_until_msec:
		multiplayer.multiplayer_peer = null
		get_tree().create_timer(1.0).timeout.connect(_connect)
		return

	FreezeWatchScript.printer.line("Terrain client: connection failed")

	if DisplayServer.get_name() != "headless" and connected_msec > 0:
		_show_lost_notice("the connection failed after joining")
		return

	if _remote:
		_cannot_reach("No server answered at %s:%d. Check the address on the server pick page, that the server is running, and this computer's internet connection." % [_host, _port])   # a full server says so (terrain_server.gd SERVER_FULL), so this is a server that is down or unreachable
		return

	_finish(1)


# The window's title for a refusal the server explains (terrain_server.gd: _drop_replaced, SERVER_FULL, BuildStamp.refusal).
static func join_refused_title(text: String) -> String:
	if text.contains("joined the server again"):
		return "Joined from elsewhere"

	if text.contains("server is full"):
		return "Server full"

	return "Update required"


# The server cannot be reached before joining: a window says why, with Back to servers and Quit;
# a headless run quits with code 1 as before.
func _cannot_reach(text: String) -> void:
	_telemetry.event("JOIN: cannot reach the server: %s" % text)
	FreezeWatchScript.printer.line("Terrain client: cannot reach the server: " + text)   # the console too: headless checks (tools/way_in_check.sh) read it

	if _connect_window == null:
		_finish(1)
		return

	_connect_window.fail("Cannot reach the server", text, func(): _finish(1))


# Every server runs the join handshake (server_auth.gd); it must be attached before the connection opens. A server with a password asks for it:
# --password= answers once (tests); a player gets the password popup (password_box.gd): 3 tries (Dave 19 Nov 2026), then "You got it wrong
# 3 times..." and back to the server pick page. A password the player chose to remember is tried first (only its salted hash is kept).
# A password typed this run is reused on every new connection to that server, so the box asks once (R-JOIN-PASSWORD-ONCE, server_auth.gd).
func _attach_auth() -> void:
	if _auth != null:
		_auth.new_connection()
		return

	_password_arg = AppConfig.get_command_line_value("password", "")
	_auth = ServerAuthScript.new()
	_auth.protocol = NetScript.PROTOCOL_VERSION   # said first in the handshake (161): a server of another protocol answers with why
	_auth.session_address = "%s:%d" % [_host, _port]
	_auth.outdated.connect(func(text: String) -> void:
		_on_join_refused(text, "Update required")

		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close())   # nothing further: the two do not speak the same calls
	_auth.remembered = func(salt_hex: String) -> String:
		var rows: Array = ServerListScript.load_rows()
		var index: int = ServerListScript.find(rows, "%s:%d" % [_host, _port])
		var saved: Dictionary = rows[index].get("password", {}) if index >= 0 and rows[index].get("password") is Dictionary else {}
		return str(saved.get("hash", "")) if str(saved.get("salt", "")) == salt_hex else ""
	_auth.password_needed.connect(_on_password_needed)
	_auth.accepted.connect(func(salt_hex: String, hash_hex: String) -> void:
		var rows: Array = ServerListScript.load_rows()
		var index: int = ServerListScript.find(rows, "%s:%d" % [_host, _port])

		if index >= 0 and (_remember_password or ServerAuthScript.session_keeps("%s:%d" % [_host, _port])):   # Remember ticked before a Retry
			rows[index]["password"] = {"salt": salt_hex, "hash": hash_hex}
			ServerListScript.save_rows(rows))
	_auth.refused.connect(func(reason: String) -> void:
		if _auth.remembered_was_wrong:
			_forget_password()   # a remembered password the guard refused (busy) would be tried, and refused, again

		var words: String = "You got it wrong 3 times. Check your Caps Lock, and take a minute to recompose."

		if reason == "busy":
			words = "Too many wrong passwords from this computer. Wait a minute and try again."

		if _password_box != null:
			_join_refused = words
			_password_box.fail("Wrong password" if reason != "busy" else "Wait a minute", words)
		else:
			_on_join_refused(words, "Wrong password" if reason != "busy" else "Wait a minute"))
	_auth.attach_client(multiplayer as SceneMultiplayer)


func _on_password_needed(tries_left: int, wrong: bool) -> void:
	_telemetry.event("JOIN: the server asks for a password (%d tries left%s)" % [tries_left, ", the last one was wrong" if wrong else ""])

	if _auth.remembered_was_wrong:
		_forget_password()

	if _password_arg != "" and not wrong:
		_auth.submit(_password_arg)
		return

	if _connect_window == null or not _remote:
		_on_join_refused("The password was wrong." if wrong else "The server at %s:%d has a password: start the game with --password=." % [_host, _port], "Wrong password" if wrong else "Password needed")
		return

	if _password_box == null:
		_password_box = PasswordBoxScript.new()
		_password_box.on_ok = func(typed: String, keep: bool) -> void:
			_remember_password = keep
			_auth.submit(typed, keep)
		_password_box.on_cancel = _back_to_servers
		_password_box.setup(self)

	var saved_failed: bool = _auth.remembered_was_wrong or _auth.kept_was_wrong   # sent by itself, not typed now: "the saved password no longer works"
	_password_box.ask(_server_label(), tries_left, wrong and not saved_failed, saved_failed)


func _forget_password() -> void:
	var rows: Array = ServerListScript.load_rows()
	var index: int = ServerListScript.find(rows, "%s:%d" % [_host, _port])

	if index >= 0 and rows[index].has("password"):
		rows[index].erase("password")
		ServerListScript.save_rows(rows)


# The server's name as the player knows it on the server pick page, else its address.
func _server_label() -> String:
	var rows: Array = ServerListScript.load_rows()
	var index: int = ServerListScript.find(rows, "%s:%d" % [_host, _port])
	return ServerListScript.shown_name(rows[index]) if index >= 0 else "%s:%d" % [_host, _port]


# Back to the server pick page: the game starts again on that page (the cleanest way out of a half-made join; nothing is saved here).
func _back_to_servers() -> void:
	_telemetry.event("JOIN: back to the server pick page")
	var user_args: Array = []

	for argument in OS.get_cmdline_user_args():
		if argument not in ["--to-servers", "--test"] and not argument.begins_with("--password=") and not argument.begins_with("--server="):   # else the launcher rejoins
			user_args.append(argument)

	OS.set_restart_on_exit(true, OS.get_cmdline_args() + PackedStringArray(["--"]) + PackedStringArray(user_args + ["--to-servers"]))
	_finish(0)


# A remote server welcomed this game: remember when, and as which character, for Continue and the server pick page's Last played.
func _note_played() -> void:
	var rows: Array = ServerListScript.load_rows()
	var index: int = ServerListScript.find(rows, "%s:%d" % [_host, _port])

	if index < 0:
		var added: Dictionary = ServerListScript.add(rows, "%s:%d" % [_host, _port])

		if added.has("error"):
			return

		index = int(added["index"])

	ServerListScript.mark_played(rows, str(rows[index]["address"]), CharacterStoreScript.active_id())
	ServerListScript.save_rows(rows)


# The join handshake ended without getting in (server_auth.gd). A server that never said a word there does not speak this game's join: it is
# an older or newer build. Otherwise the server dropped the join (a refusal already says why), or it went away: as a failed connection.
func _on_auth_failed(_peer: int) -> void:
	if _join_refused != "":
		return

	if _auth != null and not _auth.heard:
		_on_join_refused("The server at %s:%d answered but does not speak this game's way of joining: it runs an older or newer build of the game. Update the game, or ask whoever runs the server to update it." % [_host, _port], "Different version")
		return

	if _remote and _connect_window != null and connected_msec <= 0 and Time.get_ticks_msec() >= _wait_until_msec:   # within a --wait it is tried again (_on_connection_failed)
		_cannot_reach("The server at %s:%d answered, then dropped this join without saying why. It may be restarting. Wait a minute and try again." % [_host, _port])
		return

	_on_connection_failed()


# The server runs another build (step A1): its reason stays on the join window until the player quits. The server drops this client next.
# Also a password the server would not take (title says which).
func _on_join_refused(text: String, title: String = "Update required") -> void:
	if _join_refused != "":
		return   # already showing (the welcome's check came first)

	_join_refused = text if text != "" else "The server refused this game."
	FreezeWatchScript.printer.line("Terrain client: join refused: " + str(_join_refused.replace("\n", " ")))
	_telemetry.event("JOIN: refused by the server: " + _join_refused.replace("\n", " "))

	if _connect_window != null:
		_connect_window.fail(title, _join_refused, func(): _finish(1))
	elif DisplayServer.get_name() != "headless":
		_show_lost_notice(_join_refused.replace("\n", " "))
	else:
		_finish(1)


func _on_welcome(info: Dictionary) -> void:
	Probe.joined()   # the JOIN slow frame lines follow the 30 frames from here
	var tw: int = Probe.start()
	_welcome_body(info)
	Probe.stop("welcome", tw)
	var welcome_ms: float = float(Time.get_ticks_usec() - tw) / 1000.0

	# Lane A r4 Low at 35dcde90: a 3.5 s welcome with its steps never printed (the freeze watch starts part way through it, so the frame's
	# own lines miss the start). Its named steps, once, at the join.
	if welcome_ms > Probe.JOIN_SLOW_MS:
		FreezeWatchScript.printer.line("JOIN welcome %.0f ms: %s" % [welcome_ms, Probe._top_text(32)])


func _welcome_body(info: Dictionary) -> void:
	if _remote:
		_note_played()

	if int(info.get("protocol", 0)) != NetScript.PROTOCOL_VERSION:
		push_error("Terrain client: server speaks protocol %s, this client %d" % [str(info.get("protocol")), NetScript.PROTOCOL_VERSION])

		if _remote:   # a tester's game: no local server to restart, only an update helps
			_on_join_refused("This game and the server are different versions (protocol %d; the server %s).\nUpdate the game and try again." % [NetScript.PROTOCOL_VERSION, str(info.get("protocol"))])
			return

		if _connect_window != null:
			_connect_window.fail("The server is out of date", "The server on port %d speaks protocol %s, this game speaks %d.\nAn old server from an earlier run is still running. Close the game, end every \"Godot\" process except the editor in Task Manager, then press Play again." % [_port, str(info.get("protocol")), NetScript.PROTOCOL_VERSION], func(): _finish(1))
			return

		_finish(1)
		return

	# A release server names its build in the welcome (protocol 133): another build stops here, before anything is loaded or the hello is
	# sent, with the server's own wording. The server refuses it at hello too (BuildStamp.refusal), so a client that skips this is still kept out.
	if bool(info.get("server_stamped", false)):
		var refused: String = BuildStamp.refusal(int(info.get("server_build", 0)), BuildStamp.stamped_build())

		if refused != "":
			_on_join_refused(refused)
			return

	var server_commit: String = str(info.get("server_commit", ""))

	# A stamped server checks the build itself (above and at hello); this commit check is for editor Play.
	if not bool(info.get("server_stamped", false)) and server_commit != "" and _commit != "" and server_commit != _commit and _connect_window != null:
		# Dave (build 621): an old server answered and sent no ground. A different checkout is named at once. A joined server
		# cannot be restarted from here, so the player closes the game and presses Play again.
		_telemetry.event("JOIN: server is build %s commit %s, this game is build %d commit %s" % [str(info.get("server_build", "?")), server_commit, BUILD, _commit])
		_connect_window.fail("The server is out of date", "The server on port %d runs build %s (commit %s); this game is build %d (commit %s).\nClose the game and press Play again so a new server starts. If you joined a friend's server, ask them to restart it." % [_port, str(info.get("server_build", "?")), server_commit, BUILD, _commit], func(): _finish(1))
		return

	world = info
	tunnel_on = bool(info.get("tunnels", {}).get("on", false))
	tunnel_cave_in_s = int(info.get("tunnels", {}).get("cave_in_s", 1200))
	game_clock.sync(float(info.get("game_seconds", game_clock.seconds)))
	connected_msec = Time.get_ticks_msec()

	if cache_dir == "":
		# One folder per terrain version and set of tile files, so older blocks are never mixed in.
		cache_dir = "user://terrain_cache/%s/v%d_%s" % [str(info["world_name"]).validate_filename(), int(info.get("terrain_version", 1)), str(info.get("tiles_stamp", ""))]

	var tw_cache: int = Probe.start()
	cache = CacheScript.new()
	if cache_mb <= 0:
		cache_mb = QUALITY_CACHE_MB[quality]
		cache_mb_from_quality = true

	if clear_cache:
		var folder: String = CacheScript.base_path(cache_dir)

		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + "/" + file)

		FreezeWatchScript.printer.line("Terrain client: cleared the saved ground cache")

	cache.setup(cache_dir, info, info["revisions"], cache_mb)

	if cache.fell_back != "":
		FreezeWatchScript.printer.line("Terrain client: the ground cache folder %s could not be made; using %s" % [cache.fell_back, CacheScript.FALLBACK_DIR])

	var seeded: int = cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))
	_starter_seeded = seeded

	if seeded > 0:
		cache.set_revisions(info["revisions"])
		FreezeWatchScript.printer.line("Terrain client: first run, copied the starter ground for the spawn (%d tile)" % seeded)

	Probe.stop("welcome: ground cache and starter ground", tw_cache)
	var tw_line: int = Probe.start()
	_ask_catch_up()
	stream = StreamScript.new()
	stream.cache = cache
	stream.drop_lods = _drop_ground_lods
	stream.drop_xz = Vector2(float(info["spawn"].x), float(info["spawn"].z)) if test_start.is_finite() == false else Vector2(test_start.x, test_start.z)
	link = BlockLinkScript.new()
	link.stream = stream
	var block_port: int = _block_port_override if _block_port_override > 0 else int(info.get("block_port", 0))   # --block-port: a test relay's port (tools/lossy_link.py)
	link.open(_host, 0 if OS.get_cmdline_user_args().has("--no-block-line") else block_port, multiplayer.get_unique_id())
	stream.link = link
	Probe.stop("welcome: catch-up ask and block line", tw_line)
	var root: Node3D = Node3D.new()
	root.name = "World"
	add_child(root)
	var t1: int = Probe.start()
	_tables = TableSetScript.new()
	_tables.load_directory()
	Probe.stop("welcome: tables", t1)
	var tw_ground: int = Probe.start()
	terrain = VoxelLodTerrain.new()
	terrain.format = Layout.make_format()
	terrain.stream = stream
	var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_SINGLE_S4
	terrain.mesher = mesher
	terrain.lod_count = LOD_COUNT
	terrain.view_distance = VIEW_DISTANCE
	terrain.mesh_block_size = 32
	# Path decals paint only the ground: the terrain goes on its own render layer as well as the default one, when this voxel build can (piece_look.gd).
	if "render_layers_mask" in terrain:
		terrain.set("render_layers_mask", 1 | PieceLook.TERRAIN_DECAL_LAYER)
		PieceLook.use_terrain_only_decals()

	terrain.generate_collisions = true
	terrain.collision_lod_count = Layout.COLLISION_LODS   # caves are carved at every one of these levels (terrain_generator.gd cave_carve_lods)
	# Not the clipbox streaming system (tried in build 61): it loads the fine ground under the
	# player first, but makes no collision until every coarser level is loaded too, so the
	# player had no ground to stand on for most of a minute (owner, 2026-10-20).
	Probe.stop("welcome: ground node", tw_ground)
	var t2: int = Probe.start()
	terrain.material = GroundMaterialScript.make(_tables, quality)
	Probe.stop("welcome: ground material", t2)
	_ground_quality = quality
	var tw_ground_add: int = Probe.start()
	root.add_child(terrain)
	Probe.stop("welcome: ground added", tw_ground_add)
	var tp0: int = Probe.start()
	_make_player(root, test_start if test_start.is_finite() else info["spawn"] + Vector3(0.0, SPAWN_LIFT_M + _spawn_y_offset, 0.0))

	if not test_start.is_finite():
		_face_from_spawn(Vector3(info["spawn"]))
	Probe.stop("welcome: player", tp0)
	flora = FloraViewScript.new()
	flora.name = "Flora"
	var t3: int = Probe.start()
	flora.setup(_tables, TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", []))
	Probe.stop("welcome: flora setup", t3)
	var tw_flora_add: int = Probe.start()
	root.add_child(flora)
	flora.ground_ready = func(x: float, z: float) -> bool: return stream != null and stream.column_loaded(x, z)
	_freeze_watch.start()
	Probe.context = func() -> String: return "%s; ground blocks waiting %d; at %s" % [flora.load_state() if flora != null else "no flora", stream.pending() if stream != null else -1, str(body.global_position) if body != null else "?"]
	Probe.stop("welcome: flora added", tw_flora_add)
	var tw_ice: int = Probe.start()
	var tq_sub0_oceanice: int = Probe.start()
	ocean_ice = OceanIceScript.new()
	ocean_ice.name = "OceanIce"
	ocean_ice.seed_value = int(info.get("master_seed", 0))
	ocean_ice.ground_below = _ground_below
	root.add_child(ocean_ice)
	Probe.stop("welcome: ocean ice", tq_sub0_oceanice)
	var tq_sub1_shoreprops: int = Probe.start()
	shore_props = ShoreProps.new()
	shore_props.name = "ShoreProps"
	root.add_child(shore_props)
	Probe.stop("welcome: shore props", tq_sub1_shoreprops)
	var tq_sub2_fallmist: int = Probe.start()
	fall_mist = LookWarm.take("fall_mist") as Node3D   # made in the menus or while waiting for the welcome (look_warm.gd)

	if fall_mist != null:
		fall_mist.set_quality(quality)
	else:
		fall_mist = FallMistScript.new()
		fall_mist.name = "FallMist"
		fall_mist.setup(quality)
	root.add_child(fall_mist)
	Probe.stop("welcome: fall mist", tq_sub2_fallmist)
	var tq_sub3_fallgrowth: int = Probe.start()
	fall_growth = FallGrowthScript.new()
	fall_growth.name = "FallGrowth"
	fall_growth.setup(terrain, flora, quality)
	root.add_child(fall_growth)
	Probe.stop("welcome: fall growth", tq_sub3_fallgrowth)
	_flora_view_full = flora.view_m.duplicate()
	_flora_near_full = flora.near_m.duplicate()
	Probe.stop("welcome: ice, shore, mist and fall growth", tw_ice)
	var tw_grass: int = Probe.start()
	grass = GrassViewScript.new()
	grass.third_person = third_person
	grass.name = "Grass"
	root.add_child(grass)
	critters = AmbientCrittersScript.new()
	critters.name = "Critters"
	root.add_child(critters)
	grass.setup(terrain, flora, _tables)
	grass.brook_spots = _brook_spots
	Probe.stop("welcome: grass and critters", tw_grass)
	var tw_signs: int = Probe.start()
	trail_signs = TrailSignsScript.new()   # signs along the trails (stage 2d): latrines, scrapes, deer prints, droppings, beds and rubbed trees, for everyone
	trail_signs.name = "TrailSigns"
	trail_signs.ground_height = func(x, z): return _ground_below(Vector3(x, body.global_position.y + 40.0, z)) if body != null else NAN
	trail_signs.wet = func(x, z): return _wet_near(x, z, float(trail_signs.cfg.get("wet_m", 3.0)))
	trail_signs.trunks_near = func(point: Vector3, radius: float) -> Array: return _trunks_round(point, radius) if flora != null else []   # rubbed trees by deer trails
	trail_signs.patches_changed.connect(grass.set_sign_patches)   # the grass short round latrines, droppings and warrens (Lane A 23 Nov: unseen in tall grass)
	trail_signs.on_spot = func(_kind: String, at: Vector3) -> void:   # a sign spotted (153): the server trains Tracking; the sound only with hunting gear in hand (QA #20)
		if sound != null and held != null and TrailSignsScript.sounds_with(trail_signs.cfg, [held.held_id(), held.off_id()]):
			sound.slots.play("sign_spot", at)

		if net != null and multiplayer.has_multiplayer_peer():
			net.sign_spotted.rpc_id(1, at.x, at.z)
	root.add_child(trail_signs)
	fresh_tracks = FreshTracksScript.new()
	fresh_tracks.name = "FreshTracks"
	fresh_tracks.player_at = func() -> Vector3: return body.global_position if body != null else Vector3.INF
	root.add_child(fresh_tracks)
	Probe.stop("welcome: trail signs and fresh tracks", tw_signs)
	var tw_probes: int = Probe.start()
	_jitter_test = JitterTestScript.new()
	add_child(_jitter_test)
	_jitter_test.setup(self)
	_machine_probe = MachineProbeScript.new()
	add_child(_machine_probe)
	_machine_probe.setup(self)
	_gpu_probe = GpuProbeScript.new()
	add_child(_gpu_probe)
	_gpu_probe.setup(self)
	Probe.stop("welcome: jitter, machine and gpu probes", tw_probes)
	var tw_weather: int = Probe.start()
	weather_look = WeatherLookScript.new()
	add_child(weather_look)
	weather_look.setup(self)
	weather_look.set_quality(quality)
	Probe.stop("welcome: weather look", tw_weather)
	var tw_sound_add: int = Probe.start()
	sound = SoundStageScript.new()
	sound.name = "Sound"
	root.add_child(sound)
	sound.ground_below = _ground_below
	sound.under_land = _under_land   # no sea under the island: a deep tunnel has dry steps (Dave 20 Nov 2026)
	sound.floor_under = _floor_under
	sound.loading = true   # the world's sounds stay silent until it is ready, then fade in (Dave 24 Nov 2026, the static at load)
	Probe.stop("welcome: sound added", tw_sound_add)
	var t4: int = Probe.start()
	sound.setup(terrain, flora, grass)
	sound.puddles = weather_look.puddles          # steps splash where a puddle is drawn (puddles.gd)
	# Thunder plays the shared strikes, the ones the server's birds flush at (src/shared/thunder.gd, the same seed and clock).
	sound.weather.thunder_between = func(from_s: float, to_s: float, centre: Vector3, reach_m: float) -> Array:
		return ThunderScript.strikes(int(world.get("master_seed", 0)), from_s, to_s, sound.weather.thunder_state(weather, sound_tests.weather_at >= 0), centre, reach_m)
	sound.weather.game_seconds = func() -> float: return game_clock.seconds
	sound_panel.setup(self, sound, func() -> Vector3: return camera.global_position if camera != null else (body.global_position if body != null else Vector3.ZERO))
	for sound_log_arg in OS.get_cmdline_user_args():   # --sound-log=SECONDS: print what plays, its distance and dB each second (sound_stage.gd)
		if sound_log_arg.begins_with("--sound-log="):
			sound.enable_sound_log(float(sound_log_arg.trim_prefix("--sound-log=")))
	stance.changed.connect(func(new_stance: int):
		sound.stance.set_stance(["stand", "crouch", "sit", "lie"][clampi(new_stance, 0, 3)])
		sound.slots.play("bed_lie" if new_stance == 3 else ("bed_rise" if _was_lying else ""), body.global_position)
		_was_lying = new_stance == 3)
	Probe.stop("welcome: sound setup", t4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--floor="):
			sound.set_floor(argument.get_slice("=", 1))

	if test_gear:
		sound.gear.set_worn(["plate", "cloth", "iron"])
	var t5: int = Probe.start()
	debug_hud.add_line("server build", func() -> String: return "build %s, commit %s (this game: build %d, commit %s)" % [str(world.get("server_build", "?")), str(world.get("server_commit", "?")), BUILD, _commit])
	debug_hud.add_line("ground check", func() -> String: return "%d samples, %d mismatches, %d zeroed blocks refused, last %s" % [ground_debug.check_samples, ground_debug.check_mismatches, stream.zeroed_blocks, ground_debug.check_last])
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
	var tw_env: int = Probe.start()
	_make_environment(root)
	Probe.stop("welcome: environment made", tw_env)
	var tw_quality: int = Probe.start()
	_apply_quality()
	Probe.stop("welcome: quality applied", tw_quality)

	if OS.get_cmdline_user_args().has("--print-tier"):
		FreezeWatchScript.printer.line("Terrain client: " + str(debug_hud.text()))
	Probe.stop("welcome: environment", t5)
	var tw_layers: int = Probe.start()
	get_window().size_changed.connect(_apply_render_scale)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	link_bars = LinkBarsScript.new()
	# a closed line (after quitting, _close_line) has no peers to ask for: get_peer would print an engine error each check
	link_bars.setup(func() -> ENetPacketPeer: return (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1) if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED else null)
	link_bars.on_drop = func(text: String) -> void: _telemetry.event(text)
	link_bars.position = Vector2(12.0, 8.0)
	link_bars.size = Vector2(80.0, 36.0)
	layer.add_child(link_bars)
	_horizon = HorizonScript.new()
	_horizon.setup(camera, func() -> bool: return swimming or (items != null and items.breath_ds >= 0))
	layer.add_child(_horizon)
	debug_hud.add_line("server link", func() -> String: return link_bars.text())
	# Under water: a gentle wobble and a darker rim over the 3D picture (no flat blue sheet; the water's colour is the fog,
	# weather_look.gd _underwater_fog). Its own layer under the HUD, so the HUD is not read back into it.
	var under_layer: CanvasLayer = CanvasLayer.new()
	under_layer.layer = -1
	add_child(under_layer)
	_tint = UnderwaterLook.make()
	under_layer.add_child(_tint)
	faint = FaintEffectScript.new()
	add_child(faint)
	faint.setup(layer)      # over-exertion and fainting picture (faint.set_state), hidden while normal
	_mode_label = Label.new()
	_mode_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 32)
	_mode_label.add_theme_constant_override("outline_size", 5)
	_mode_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_mode_label)
	_inspect_label = Label.new()
	# The name sits just ABOVE the crosshair, bottom-aligned, so it grows upward and never meets the "Press E" prompt, which sits below it
	# (inventory_view.gd _prompt). Anchored to the screen's middle line, so the gap holds at every UI scale and for names of several lines.
	_inspect_label.anchor_left = 0.0
	_inspect_label.anchor_right = 1.0
	_inspect_label.anchor_top = 0.5
	_inspect_label.anchor_bottom = 0.5
	_inspect_label.offset_left = 0.0
	_inspect_label.offset_right = 0.0
	_inspect_label.offset_top = -280.0
	_inspect_label.offset_bottom = -16.0
	_inspect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspect_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.add_theme_font_size_override("font_size", 28)
	_inspect_label.add_theme_constant_override("outline_size", 5)
	_inspect_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_inspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_inspect_label)
	_inspect_plus = InspectReticleScript.new()
	layer.add_child(_inspect_plus)
	_water_label = Label.new()
	_water_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_water_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_water_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_water_label.offset_top = 100.0
	_water_label.add_theme_font_size_override("font_size", 24)
	_water_label.add_theme_constant_override("outline_size", 5)
	_water_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_water_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_water_label)
	sound_tests.setup(self)
	ground_debug.setup(self)
	Probe.stop("welcome: hud layers, labels and tests", tw_layers)
	var tq_menu: int = Probe.start()
	_build_menu()
	Probe.stop("welcome: menu", tq_menu)
	var tq_views: int = Probe.start()   # the windowed lag run (5 Nov) froze 0.8 to 1.3 s "after welcome: menu", before "welcome: items view": these pieces were not timed
	hud = Label.new()
	hud.position = Vector2(8.0, 48.0)   # below the link bars (top left)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # a long "playing:" line wraps instead of running off the right edge (screen audit, 23 Nov 2026)
	hud.size = Vector2(1900.0, 0.0)
	hud.visible = display.hud_text
	hud.add_theme_font_size_override("font_size", 34)
	hud.add_theme_constant_override("outline_size", 5)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
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
	_animal_view_node = animal_view
	npc_view.goblin_called.connect(func(at: Vector3, mood: String, who: Node3D) -> void: sound.creatures.call_at("goblin", at, mood, who))   # a camp goblin squaring up to a weapon (Dave 20 Nov 2026: "make angry sounds")
	npc_view.goblin_maker = animal_view.make_goblin   # goblin tribe members wear the wild goblin's model (data/creatures/goblin_tribes.json)
	animal_view.water_level = func(x: float, z: float) -> float: return flora.water_level_at(x, z) if flora != null else NAN      # swimmers play their swim clip in water
	animal_view.player_at = func() -> Vector3: return body.global_position if body != null and body.is_inside_tree() else Vector3.INF   # the capsule's middle, about 1 m above the feet the server uses: only its xz matters (stop_toward's 2 m height gate is that much looser): a charge is never drawn inside the player
	animal_view.look_points = func() -> Array: return _look_points()      # head tracking: an animal watches the nearest player (head_look.gd)
	net.animals_received.connect(animal_view.on_rows)
	animal_view.state_changed.connect(func(kind: String, state: int, at: Vector3, who: Node3D) -> void:
		var mood: String = sound.creatures.mood_for(kind, state)   # an animal noticing, bolting, warning or charging calls (rate limited by the voice budget); a bear stays quiet till it warns

		if mood != "":
			sound.creatures.call_at(kind, at, mood, who))   # the call moves with the animal (Dave 25 Nov 2026: a running bear's growl stayed behind)
	animal_view.took_off.connect(func(kind: String, at: Vector3) -> void:
		if sound != null and sound.creatures != null:
			sound.creatures.took_off(kind, at))      # a grouse, pheasant or guineafowl bursts up with a whirr of wings, a crow caws and flaps off
	animal_view.stepped.connect(func(kind: String, at: Vector3) -> void:
		if fresh_tracks != null:
			fresh_tracks.on_step(kind, at)      # a print where the foot landed, fading over minutes (fresh_tracks.gd)
		sound.slots.play("rabbit_hop" if kind == "rabbit" else kind + "_step", at, body.global_position)      # hoof and paw sounds by species (slots without a clip, like a wolf pack far away, are skipped)
		if weather_look != null and weather_look.puddles != null and weather_look.puddles.shown > 0.001:
			weather_look.puddles.animal_step(kind, at, sound._ground_under(at))      # a foot in a puddle splashes (puddles.gd)
	)
	net.hit_number_received.connect(func(at: Vector3, _amount: int) -> void: animal_view.note_hit(at))
	# A blow that lands on an animal (any player's, within 60 m; Dave 19 Nov 2026: "there need to be damage numbers or better hit sounds. or both"):
	# the flesh thud where it struck, and the body flinches. A miss is only the swing or the jab, so a hit is heard and seen.
	# The player's own blow shows as it lands, the server's hit for it then plays nothing twice (docs/design/ANIMAL_NETCODE.md "Plans" step 3).
	net.animal_hit_point_received.connect(func(id: int, _zone: int, at: Vector3) -> void:
		if animal_view.confirm_hit(id):
			return

		if sound != null:
			sound.spear.hit("flesh", at, 1.0)

		animal_view.flinch(id))
	# Fish schools seen (protocol 169; server_fish_signs.gd sends them only within 100 m): a jump with its splash, rings and sound, and the dark
	# shapes of the schools within 40 m in shallow water.
	net.fish_jump_received.connect(func(at: Vector3, kind: int, seed_value: int) -> void: _fish_signs_view().jump(at, kind, seed_value))
	net.fish_shadows_received.connect(func(rows: PackedFloat32Array) -> void: _fish_signs_view().set_shadows(rows))
	# Another player's blow, pick or craft (protocol 156; server_action_cues.gd sends it only within earshot): heard where it happened.
	net.action_cue_received.connect(func(_peer: int, cue: int, detail: int, at: Vector3) -> void:
		if sound != null:
			sound.other_action(cue, detail, at, harvest._flora_by_id.get(detail, {}) if cue == sound.CUE_PICK and harvest != null else {},
					items.recipes.recipe(detail) if cue == sound.CUE_CRAFT and items != null and items.recipes != null else {},
					items.table.id_of(detail) if cue == sound.CUE_PICKUP and items != null and items.table != null else ""))
	animal_view.fell.connect(func(_kind: String, at: Vector3, small: bool) -> void:
		sound.slots.play("animal_fall", at, body.global_position, 0.4 if small else 1.0))      # the body drops where it was killed (a small one softly)

	# MikeW's footfall hook (docs/design/FOOTFALL.md), once the animal view has it: a landing in mud, snow, water or a puddle adds that ground's
	# hoof or paw layer on top of the species step (slot_sounds.gd footfall). Connected by name, so a build without the signal is unchanged.
	if animal_view.has_signal("footfall"):
		animal_view.connect("footfall", func(kind: String, at: Vector3, ground: String, speed: float) -> void:
			sound.slots.footfall(kind, at, ground, speed, body.global_position)
		)

	net.trails_received.connect(func(bx: int, bz: int, bytes: PackedByteArray, routes: PackedByteArray) -> void:
		grass.set_trail_block(bx, bz, TrailCodec.decode(bytes))

		if routes == TrailCodec.ROUTES_SAME:
			return   # only the worn cells changed (protocol 158): the routes kept are right, nothing to decode, rebuild or log
		var decoded: Array = TrailCodec.decode_routes(routes, Vector2i(bx, bz), TrailCodec.ROUTE_BLOCK_M)
		grass.set_trail_routes(bx, bz, decoded)   # the trails between animal places (protocol 149)
		trail_signs.set_routes(bx, bz, decoded)
	)
	net.map_block_received.connect(map_knowledge.receive)
	net.map_trails_received.connect(map_knowledge.set_trails)   # the game trails this character was near, drawn on the Map from a Tracking level (protocol 152)
	net.trap_marks_received.connect(map_knowledge.set_traps)   # the snares this character has set, marked on the Map (protocol 150)
	net.blood_received.connect(animal_view.on_blood)
	var burrow_view: Node3D = BurrowViewScript.new()      # rabbit burrow mounds (MikeW #236 sends the spots, Kathleen draws them)
	burrow_view.name = "Burrows"
	burrow_view.ground_at = _ground_below
	add_child(burrow_view)
	net.burrows_received.connect(burrow_view.on_burrows)
	nest_view = NestViewScript.new()                      # grouse and songbird nests (MikeW: protocol 91 spots, the basic_look ground nest)
	nest_view.name = "Nests"
	add_child(nest_view)
	net.nests_received.connect(nest_view.on_nests)
	var far_smoke: Node3D = FarSmokeScript.new()           # smoke of campfires 100 m to 2 km off (TEST-011, protocol 114 far_fires)
	far_smoke.name = "FarSmoke"
	far_smoke.view_m = func() -> float: return float(terrain.view_distance)
	add_child(far_smoke)
	net.far_fires_received.connect(far_smoke.on_far_fires)
	net.burrows_received.connect(_on_burrows_for_grass)
	Probe.stop("welcome: hud, npc, animal, burrow and nest views", tq_views)
	var tq_items_ready: int = Probe.start()
	items = InventoryViewScript.new()
	items.name = "Items"
	add_child(items)   # its _ready prewarms the loose item meshes
	items.set_rock_quality(quality)   # _apply_quality ran before the view existed
	items.dead_body = func(kind: String, look: int, num: int, at: Vector3) -> Node3D: return _animal_view_node.dead_body(kind, look, num, at) if _animal_view_node != null else null   # a dead animal is its own model (animal_view dead_body)
	Probe.stop("welcome: items view ready", tq_items_ready)
	var tq_items_view: int = Probe.start()
	var tw_items_setup: int = Probe.start()
	items.setup(net, layer, root, func(): return body.global_position, _ground_below)
	Probe.stop("welcome: items setup", tw_items_setup)
	_setup_hint_card()
	var tw_strip: int = Probe.start()
	_setup_status_strip(layer)   # after items.setup: its reads use the vitals data the view loads there
	Probe.stop("welcome: status strip", tw_strip)
	var tw_players: int = Probe.start()
	_player_view = PlayerViewScript.new()   # the other players (protocol 151)
	_player_view.name = "Players"
	_player_view.table = items.table
	_player_view.bed_near = items.bed_near   # another player lying on a bed is drawn asleep, not crawling
	add_child(_player_view)
	net.player_look_received.connect(_player_view.on_look)
	net.players_received.connect(_player_view.on_rows)
	net.flight_seen_received.connect(func(number: int, from: Vector3, velocity: Vector3, fire: bool) -> void:
		if held != null:
			held.add_seen_flight(number, from, velocity, fire))   # another player's arrow or thrown spear in the air (protocol 159)
	net.ground_taken_received.connect(_on_ground_taken)   # branches, tide-line nodes and nests others took (protocol 160)
	_player_view.stepped.connect(func(at: Vector3, gait: int, crouched: bool) -> void:
		if sound != null:
			sound.step_at(at, gait, crouched))   # other players' footsteps, where they walk
	_player_view.drew.connect(func(at: Vector3) -> void:
		if sound != null and sound.slots != null:
			sound.slots.play("bow_draw", at))   # another player draws their bow: the limbs and string creak at their shoulder
	if sound != null and sound.flame != null:
		sound.flame.others = Callable(_player_view, "flames_near")   # and their burning torch or lantern flutters at their hand
	_player_view.stroked.connect(func(at: Vector3) -> void:
		if sound != null and sound.swim != null:
			sound.swim.stroke_at(at))   # and their strokes where they swim
	_player_view.landed.connect(func(at: Vector3, drop_m: float) -> void:
		if sound != null and sound.landing != null:
			sound.landing.land_at(at, drop_m))   # and their landing from a fall, where their feet came down
	Probe.stop("welcome: player view", tw_players)
	items.journal.map_knowledge = map_knowledge   # the Journal's Map page draws what this character surveyed (protocol 120)
	Probe.stop("welcome: items view", tq_items_view)
	# The 4 Nov freeze watch said the welcome was stuck 1.5 s "after welcome: items view" and before "welcome: held item": these three pieces were not timed.
	var tq_dialogue: int = Probe.start()
	var dialogue_view: Node = DialogueViewScript.new()
	dialogue_view.name = "Dialogue"
	add_child(dialogue_view)
	dialogue_view.setup(net, items, npc_view, layer, func(): return body.global_position)
	Probe.stop("welcome: dialogue view", tq_dialogue)
	var tq_voice: int = Probe.start()
	var npc_voice: Node = NpcVoiceScript.new()
	npc_voice.name = "NpcVoice"
	add_child(npc_voice)
	_npc_voice = npc_voice
	Probe.stop("welcome: npc voice", tq_voice)

	var tq_gmenu: int = Probe.start()
	game_menu.refresh()
	Probe.stop("welcome: game menu", tq_gmenu)

	var tw_hooks: int = Probe.start()
	dialogue_view.voice_line = func(voice_id: String, text: String):
		var talker: Dictionary = npc_view.nearest(body.global_position, npc_voice.hear_m)

		if not talker.is_empty():       # nobody in earshot is talking: no voice (the text still shows)
			npc_voice.speak(voice_id, text, talker["pos"])
	items.knowledge = knowledge
	items.is_inspecting = func(): return inspecting
	items.auto_pickup_blocked = func(): return swimming or (held != null and (held.placing() or held.tool_busy()))
	items.stance_event = _on_stance_from_server
	items.lie_on_bed = _lie_on_bed
	items.on_bed = func(): return not _bed_hold.is_empty()
	items.sit_on_seat = _sit_on_seat
	items.notice_event = func(text: String):
		var cue: String = SlotSoundsScript.net_cue(text)

		if cue != "" and sound != null and body != null:
			var float_at: Vector3 = held.float_point(body.global_position) if cue == "fish_bite" and held != null else Vector3.INF
			sound.slots.play(cue, float_at if float_at.is_finite() else body.global_position - body.global_transform.basis.z * 1.5)   # a bite at the float, where the line went in
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
	items.gather_event = func():
		feel.strike(0.0, 0.3)
	items.eat_event = func(item_id): sound.itemfx.eat(item_id)
	items.bellows_event = func(at: Vector3): sound.workshop.bellows(at)
	items.worn_event = func(changed: Array, ids: Array) -> void:
		if not test_gear:
			sound.gear.set_worn(SoundStageScript.GearScript.layers_for(ids))   # what is worn rustles, creaks or clinks on every step (--test-gear keeps its own set)

		if not changed.is_empty():
			sound.gear.dress(str(changed[0]))   # one sound for a change (a swap sends both pieces in one list)
	items.skill_up_event = func() -> void: sound.slots.play("skill_tock", body.global_position + Vector3(0.0, 1.5, 0.0))   # a skill rises: a soft wooden tock (the skill group cools down 20 s)
	items.hurt_event = func(lost: int) -> void:
		_hurt_msec = Time.get_ticks_msec()
		sound.slots.play("player_hurt", body.global_position + Vector3(0.0, 1.5, 0.0), Vector3.INF, clampf(float(lost) / 25.0, 0.4, 1.0))   # a blow lands on you: a sharp breath, louder for a bigger hit
		_attacker_snarl()
	items.fuel_event = func(): sound.itemfx.fuel_pressed()
	items.reject_event = func(reason): sound.itemfx.reject(reason)
	items.thought_event = func(line_id, kind): sound.inner.speak(line_id, kind)
	items.heart_bpm = func(): return sound.breath.bpm_now
	items.view_direction = func(): return -camera.global_transform.basis.z
	items.crown_landed = func(centre: Vector3, radius: float):
		if grass != null:
			grass.flatten(centre, radius)
	sound.trees.landed.connect(func(at: Vector3, size: float): feel.thud(at.distance_to(body.global_position), size))
	sound.landing.hurt.connect(func(drop_m, severity):
		if Time.get_ticks_msec() >= arrival_protect_until_msec:
			items.report_fall(drop_m, severity))
	items.strain_event = func(strain, _state, _fade):
		var shown: Array = items.faint_state()
		faint.set_state(shown[0], strain, shown[1])
	@warning_ignore("standalone_ternary")
	items.chest_event = func(what, at): sound.placed.chest(what == "open", at) if what in ["open", "close"] else sound.placed.container(what == "put", at)
	@warning_ignore("standalone_ternary")
	items.tool_event = func(what): sound.placed.tool_break(body.global_position) if what == "broke" else sound.placed.tool_repair(body.global_position)
	harvest = HarvestScript.new()
	harvest.setup(self, items, net)
	items.register_interactable("drink", 35, func():
		var water: Vector3 = _water_ahead_point()   # its point lets it compete for the reticle with a reed or plant beside it (current_interaction)

		if not is_nan(water.x) and items.held_container_has_room():
			return {"kind": "water", "point": water, "prompt": "Press E to fill", "tap": items.drink}

		if items.thirst >= 100:
			return {}

		if not is_nan(water.x):
			return {"kind": "water", "point": water, "prompt": "Press E to drink", "tap": items.drink}

		# The record's water where the settled water shows none (docs/design/drink_prompt_design.md (a); Kathleen: name what is there).
		var source: String = _record_drink_here()

		if source != "":
			return {"prompt": "%s — Press E to drink" % source, "tap": items.drink}

		# The sea (Dave 24 Nov 2026: "when you try to drink water from the ocean it should tell you that is too salty"): E asks, and the server
		# answers that it is too salty (server_items _drink_water); there was no prompt and E did nothing.
		return {"prompt": "Sea water — Press E to drink", "tap": items.drink} if not items.held_container_has_water() and _sea_in_reach() else {})
	# The sea's edge (Sonny, 31 Oct 2026; the server half is ACT_GATHER_EDGE): with a container shore_nodes.json lists (bucket, clay jug, clay pot, waterskin) in the pack E fills it with sea water; otherwise on a tide-line node
	# (data/items/shore_nodes.json) E gathers it. Shown only where the server would not refuse (ShoreRules.prompt), so before the plain drink prompt.
	items.register_interactable("gather_edge", 34, func():
		var text: String = _shore_prompt()
		return {"prompt": text, "tap": _shore_tap} if text != "" else {})
	items.register_interactable("drink_held", 36, func():
		return {"prompt": "Press E to drink", "tap": func(): items.eat_slot(items.held_container_slot())} if items.thirst < 100 and items.held_container_has_water() else {})
	# Reading a trail sign (hunting thread, 23 Nov 2026): the sign the reticle is on within read_m; E tells what it is, and with more Tracking
	# which way its trail runs and when its animal uses it (trail_signs.gd read_text). Client only.
	items.register_interactable("trail_sign", 46, func():
		if trail_signs == null or body == null:
			return {}

		var level: int = int(items.skill_level_of("tracking"))
		var near: Array = trail_signs.readable(body.global_position, level)
		var pick: int = items.reticle_index(near.map(func(r): return r[1]))

		if pick < 0 or items.aim_cos_of(near[pick][1]) < float(trail_signs.cfg.get("read_aim_cos", 0.985)):
			return {}   # only a sign looked right at: a looser look leaves E (and held E, auto pick-up) to the item, snare or plant beside it

		var seen: Array = trail_signs.sign_at(int(near[pick][0]))
		var text: String = TrailSignsScript.read_text(seen, level, trail_signs.cfg) if not seen.is_empty() else ""
		return {} if text == "" else {"kind": "sign", "point": near[pick][1], "prompt": "Press E to read the sign", "tap": func(): items.show_notice(text)})
	# Reading a fresh print (hunting thread): whose, how old, a warning for a predator's, and with Tracking which way it went. Client only.
	items.register_interactable("fresh_print", 47, func():
		if fresh_tracks == null or body == null:
			return {}

		var near: Array = fresh_tracks.readable(body.global_position)
		var pick: int = items.reticle_index(near.map(func(r): return r[1]))

		if pick < 0 or items.aim_cos_of(near[pick][1]) < float(fresh_tracks.cfg.get("read_aim_cos", 0.985)):
			return {}

		var mark: Array = fresh_tracks.mark_at(int(near[pick][0]))
		var text: String = FreshTracksScript.read_text(mark, int(items.skill_level_of("tracking")), Time.get_ticks_msec(), fresh_tracks.cfg) if not mark.is_empty() else ""
		return {} if text == "" else {"kind": "sign", "point": near[pick][1], "prompt": "Press E to read the prints", "tap": func(): items.show_notice(text)})
	items.register_interactable("plant", 40, func():
		return {} if items.plant_hint == "" else {"kind": "plant", "point": items.plant_point, "prompt": items.plant_hint, "quiet": not items.plant_aimed, "tap": harvest.tap})
	held = HeldItemScript.new()
	held.name = "Held"
	add_child(held)
	Probe.stop("welcome: item hooks, harvest and interactables", tw_hooks)
	var tq_held_item: int = Probe.start()
	held.setup(items, net, camera, root, layer, _ground_below, sound, _tree_trunk_near, _cover_here)
	held.trunks_round = _trunks_round
	held.trunks_version = func() -> int: return flora.canopy_version
	held.report_now = send_position_now   # a fresh position report just before each blow (server_items strike_origin)
	held.seen_ms = animal_view.seen_server_ms if animal_view != null else Callable()   # a blow is judged where the animals were drawn (protocol 155)
	held.season_now = func(): return season_here()   # the hoe's plant list greys out what is out of season: the season where the player stands, as the server sows by the bed's (season_at; the server's own clock, synced at the welcome)
	held.animal_aim_rows = func() -> Array: return _animal_view_node.aim_rows(camera.global_position, 80.0) if _animal_view_node != null else []   # the bow's aim assist
	held.blow_landing.connect(func(id: int, at: Vector3) -> void:   # the player's own blow shows as it lands (animal_view.predict_hit)
		if _animal_view_node != null and _animal_view_node.predict_hit(id) and sound != null:
			sound.spear.hit("flesh", at, 1.0))
	held.spyglass_look = _spyglass_item
	held.light_block_fn = _light_block
	Probe.stop("welcome: held item", tq_held_item)
	var tq_tail: int = Probe.start()   # Low-quality lag runs (5 Nov) stuck up to 2.2 s "after held item": the rest of the welcome was not timed
	held.struck.connect(func(side: float, weight: float): feel.strike(side, weight))
	held.shrub_near = _shrub_near
	held.swath_cut = func(slot: int, tool_class: String) -> float: return harvest.swath(slot, tool_class) if harvest != null else 0.0
	held.water_depth_at = func(x: float, z: float) -> float:
		var surface: float = flora.water_surface_at(x, z)
		return 0.0 if is_nan(surface) else WaterVolume.depth(surface, _ground_below(Vector3(x, body.global_position.y, z)))
	held.held_light_budget = func(): return quality >= 1
	if _player_view != null:
		_player_view.lit_most = func() -> int: return PlayerViewScript.LIT_MOST if quality >= 1 else PlayerViewScript.LIT_MOST_LOW   # Low: one other player's torch lights
	items.equip_requested = func(slot): held.equip_toggle(slot)
	items.held_slot_now = func(): return held.held_slot if held.holding else -1
	items.pick_hand = func(key: int): held.press_slot(key)
	items.held_key_now = func(): return held.held_key if held.holding else -1
	items.crop_model = func(crop: String, share: float, spots: Array): return flora.crop_model(crop, share, spots) if flora != null else null   # a garden crop wears its wild plant's model (Dave play test 19 Nov 2026)
	items.crop_models_ready = func(): return flora == null or flora.models_ready()
	hotbar_strip = HotbarStripScript.new()
	hotbar_strip.setup(items, layer, held)
	items.hotbar_strip = hotbar_strip
	heart_pulse = HeartPulseScript.new()
	heart_pulse.setup(sound.breath, layer)
	items.heart_pulse = heart_pulse
	hud_fade = HudFadeScript.new()
	add_child(hud_fade)
	hud_fade.setup(layer, [heart_pulse, faint._rect], sound.breath.heart.get("faint_hud", {}))
	pickup_feed = PickupFeedScript.new()
	pickup_feed.setup(items, layer)

	# The server's one "received" event for every gain (pickup, quest reward, craft, harvest); Items adds the RPC.
	if net.has_signal("item_received"):
		net.connect("item_received", func(item_id: String, count: int, source: String): pickup_feed.push_id(item_id, count, source))

	# Two actions on one key (an older key file meeting a newer default) both fire: say so once, after the world has had time to show.
	if KeyBindings.shared_note() != "":
		get_tree().create_timer(12.0).timeout.connect(func() -> void:
			var shared_keys: String = KeyBindings.shared_note()   # again: a key changed in the first seconds needs no warning
			if shared_keys != "" and is_instance_valid(items):
				items.show_notice(shared_keys))

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

	if test_embed:
		_run_embed_test()

	if test_resume != "":
		_run_resume_test()

	if test_dig_next:
		_run_dig_next_test()

	if test_texttest:
		items.run_text_test(self)

	if test_screen_audit:
		_run_screen_audit()

	if test_plantpick:
		items.run_plant_test(self)

	if test_spear:
		held.run_test()

	if test_chop:
		items.run_chop_test(self)

	if lag_run != null and lag_run.get_parent() == null:
		lag_run.client = self
		add_child(lag_run)
		lag_run.run()

	if robot != null and robot.get_parent() == null:
		robot.client = self
		add_child(robot)
		robot.run()

	if test_shoot:
		items.run_shoot_test(self)

	if test_place_foundation:
		items.run_foundation_test(self)

	if test_cook:
		items.run_cook_test(self)

	if test_sleep:
		items.run_sleep_test(self)

	if test_snare:
		items.run_snare_test(self)

	if test_net:
		held.run_net_test()
	Probe.stop("welcome: hotbar, pickup feed and tests", tq_tail)
	var tq_print: int = Probe.start()
	FreezeWatchScript.printer.line("Terrain client: welcome after %d ms; world %s; spawn %s; cache %s (%d MB)" % [
		connected_msec - started_msec, str(info["world_name"]), str(info["spawn"]), cache_dir, cache_mb
	])
	Probe.stop("welcome: welcome line printed", tq_print)
	var tq_join: int = Probe.start()
	_join_log("JOIN: at the welcome: player y %s, viewer y %s" % ["?" if body == null else "%.1f" % body.global_position.y, _viewer_y_text()])
	Probe.stop("welcome: join line logged", tq_join)
	_after_welcome = []   # the next frames are timed too (_note_after_welcome)



func _on_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	if stream != null:
		var t: int = Probe.start()
		stream.deliver(keys, payloads)
		Probe.stop("blocks in", t)


# The server's note that a tile's ground was edited (sent at most every half second, after the edits' own dug / filled messages).
# Dave 18 Nov 2026 (ground "unloaded" for many minutes while a road was built): this used to throw the whole 15 km tile out of the
# saved ground and every prefetched block with it, at every edit. Only the blocks round this session's edits are outdated
# (_forget_edit); they are marked again here, so a block the server answered just before the edit and that landed after it is
# asked for again too. Edits made while this client was away still empty the tile at the next join (the welcome's revisions).
func _on_tile_changed(tile: Vector2i, revision: int) -> void:
	for edit in _edits_untold:
		_forget_edit(edit[0], edit[1], false)

	_edits_untold.clear()

	FreezeWatchScript.printer.line("Terrain client: tile %s is now revision %d" % [str(tile), revision])


# Protocol 128 (Dave 18 Nov 2026): saved tiles older than the server's are held while the server is asked for the edits since, so only
# the blocks round those edits are fetched again at a join (it used to fetch the whole 15 km tile after any edit by anyone).
func _ask_catch_up() -> void:
	for ask in cache.take_catch_up():
		net.ask_edits_since.rpc_id(1, ask[0], int(ask[1]))
		FreezeWatchScript.printer.line("Terrain client: saved ground of tile %s is at revision %d; asking for the edits since" % [str(ask[0]), int(ask[1])])


func _on_edits_since(tile: Vector2i, since: int, revision: int, spheres: PackedFloat32Array, whole: bool) -> void:
	if cache == null:
		return

	var keys: Array = cache.apply_catch_up(tile, since, revision, spheres, whole)

	if stream != null:
		stream.forget_blocks(keys)

	@warning_ignore("integer_division")
	FreezeWatchScript.printer.line("Terrain client: tile %s caught up from revision %d to %d: %s" % [str(tile), since, revision, "saved ground dropped (the server could not list the edits)" if whole else "%d edits, %d blocks to fetch again" % [spheres.size() / 4, keys.size()]])


var _edits_untold: Array = []   # [center, radius] of the dug / filled edits since the last tile_changed


# A ground edit: the saved and prefetched copies of the blocks it touches are outdated and come from the server again.
func _forget_edit(center: Vector3, radius: float, remember: bool = true) -> void:
	if cache == null:
		return

	var keys: Array = cache.forget_area(center, radius)

	if stream != null:
		stream.forget_blocks(keys)

	if remember:
		_edits_untold.append([center, radius])


# Applies an edit to the terrain already loaded; blocks loaded later come
# from the server with the edit in them.
# Digs made or seen this session (spot, time). A player inside a dug tunnel or pit is not "under the ground": the rescue that
# stands a player on the surface must not fire there (Dave 2026-10-22: tunnelled underground and popped back up to the top).
func _note_dig(center: Vector3) -> void:
	rescue.note_dig(center)


# --test-respawn / --test-go-to-spawn: once the first ground is ready and S seconds have passed, do it and print "SPAWNTEST" lines: height above the ground on the first frame and the seconds until the player stands.
func _spawn_test_step(now: int) -> void:
	if _spawn_test == "" or connected_msec <= 0 or body == null or not world.has("spawn"):
		return

	if _spawn_test_msec == 0:
		if now - connected_msec > int((_spawn_test_after_s + 150.0) * 1000.0):
			FreezeWatchScript.printer.line("SPAWNTEST %s: FAILED never started, still waiting for ground 150 s after the start time (player %s)" % [_spawn_test, str(body.global_position.round())])
			_spawn_test = ""
			return

		if waiting_for_ground or now - connected_msec < int(_spawn_test_after_s * 1000.0):
			return

		_spawn_test_msec = now
		var from: Vector3 = body.global_position
		body.global_position += Vector3(0.0, 0.0, 300.0)   # somewhere else first, so the move is a real one

		if _spawn_test == "respawn":
			_on_died("spawn test", Vector3(world["spawn"]))
		else:
			go_to_spawn()

		var ground: float = _ground_below(body.global_position)
		FreezeWatchScript.printer.line("SPAWNTEST %s: from %s, first frame at %s, %s m above the ground" % [_spawn_test, str(from.round()), str(body.global_position.round()), "?" if is_nan(ground) else "%.1f" % (body.global_position.y - ground)])
		return

	if _spawn_test_msec > 0 and now - _spawn_test_msec > 60000:
		FreezeWatchScript.printer.line("SPAWNTEST %s: FAILED not standing 60 s later, player %s" % [_spawn_test, str(body.global_position.round())])
		_spawn_test = ""
		return

	if _spawn_test_msec > 0 and not waiting_for_ground and body.is_on_floor():
		FreezeWatchScript.printer.line("SPAWNTEST %s: standing on the ground %.1f s later, player %s" % [_spawn_test, float(now - _spawn_test_msec) * 0.001, str(body.global_position.round())])
		_spawn_test = ""


# --tunnel-test: stand on the ground at the spawn, dig a 6 m shaft and a 6 m side tunnel, stand in the tunnel for 10 s, say where the player is.
func _tunnel_step() -> void:
	var now: int = Time.get_ticks_msec()

	if _tunnel_test == 1 and connected_msec > 0 and now - connected_msec > 20000 and not waiting_for_ground:
		var top: Vector3 = body.global_position
		_tunnel_at = top
		for n in range(7):
			net.dig.rpc_id(1, top + Vector3(0.0, -1.0 - float(n), 0.0), 1.6)

		for n in range(1, 7):
			net.dig.rpc_id(1, top + Vector3(float(n), -6.5, 0.0), 1.6)

		_tunnel_test = 2
		_tunnel_msec = now
	elif _tunnel_test == 2 and now - _tunnel_msec > 4000:
		body.global_position = _tunnel_at + Vector3(0.0, -6.0, 0.0)
		body.velocity = Vector3.ZERO
		_tunnel_test = 3
		_tunnel_msec = now
	elif _tunnel_test == 3 and now - _tunnel_msec > 12000:
		var moved: float = body.global_position.distance_to(_tunnel_at + Vector3(0.0, -6.0, 0.0))
		FreezeWatchScript.printer.line("Terrain client: tunnel test: player ended %.1f m from where it was put in the tunnel (y %.1f, surface y %.1f), rescues %d, %s" % [moved, body.global_position.y, _tunnel_at.y, rescue.rescued, "STAYED" if body.global_position.y < _tunnel_at.y - 3.0 else "POPPED UP"])
		_tunnel_test = 4
		_tunnel_msec = now
		body.global_position = _tunnel_at + Vector3(7.0, -12.0, 0.0)      # inside solid rock beside the dug tunnel: the rescue must lift the player
		body.velocity = Vector3.ZERO
	elif _tunnel_test == 4 and now - _tunnel_msec > 8000:
		FreezeWatchScript.printer.line("Terrain client: tunnel test: put inside rock beside the tunnel, ended at y %.1f (rock was y %.1f, surface y %.1f): %s" % [body.global_position.y, _tunnel_at.y - 12.0, _tunnel_at.y, "LIFTED" if body.global_position.y > _tunnel_at.y - 6.0 else "STUCK"])
		_tunnel_test = 0


func _on_dug(center: Vector3, radius: float) -> void:
	_forget_edit(center, radius)

	if terrain == null:
		return

	if sound != null and sound.dig != null and body != null:
		sound.dig.dug(center, radius, body.global_position)        # before the ground changes: it hears what was there

	var t_edit: int = Probe.start()   # Dave 3 Nov 2026: every hoe click pauses the game; these name the part (HITCH line, frame_probe.gd)
	var tool: VoxelTool = terrain.get_voxel_tool()
	var t_note: int = Probe.start()
	_note_dig(center)   # even on ground not loaded yet: a player rejoining in their own tunnel must not be lifted to the surface
	Probe.stop("dig: note", t_note)

	if not _edit_area_loaded(tool, center, radius):
		Probe.stop("dig: ground edit", t_edit)
		return

	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.do_sphere(center, radius)
	Probe.stop("dig: ground edit", t_edit)
	dig_applied += 1

	if grass != null:
		var t_grass: int = Probe.start()
		grass.ground_changed(center, radius)
		Probe.stop("dig: grass", t_grass)

	FreezeWatchScript.printer.line("Terrain client: applied a %.1f m dig at %s; ground value there now %.2f (above 0 is open)" % [
		radius, str(center), tool.get_voxel_f(Vector3i(center.round()))
	])


# A fill (a dam, a filled hole): the same sphere put back as ground, the grass under it buried.
func _on_filled(center: Vector3, radius: float, _material: int) -> void:
	_forget_edit(center, radius)

	if terrain == null:
		return

	var t_edit: int = Probe.start()
	var tool: VoxelTool = terrain.get_voxel_tool()

	if not _edit_area_loaded(tool, center, radius):
		Probe.stop("fill: ground edit", t_edit)
		return

	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_ADD
	tool.do_sphere(center, radius)
	Probe.stop("fill: ground edit", t_edit)

	if grass != null:
		var t_grass: int = Probe.start()
		grass.ground_changed(center, radius, true)
		Probe.stop("fill: grass", t_grass)


# A dig or fill the server sends for ground this game has not loaded (often far away: the replay of other players' edits) cannot be applied:
# do_sphere then only prints "Area not editable" with a backtrace, 5,560 of them in Dave's 21 Nov play, each a main-thread print. Such an
# edit is skipped quietly: _forget_edit already dropped its cached blocks, so they come from the server with the edit in them. Counted, and
# said on one line every 30 s at most.
var edits_skipped: int = 0
var _edits_skipped_said_msec: int = -100000


func _edit_area_loaded(tool: VoxelTool, center: Vector3, radius: float) -> bool:
	if tool.is_area_editable(AABB(center - Vector3.ONE * radius, Vector3.ONE * (2.0 * radius))):
		return true

	edits_skipped += 1

	if Time.get_ticks_msec() - _edits_skipped_said_msec >= 30000:
		_edits_skipped_said_msec = Time.get_ticks_msec()
		FreezeWatchScript.printer.line("Terrain client: %d dig or fill edit(s) so far on ground not loaded here, skipped (its blocks come with the edit)" % edits_skipped)

	return false


# Applies the experiment switches (Esc > Advanced); also at start.
func _apply_switches() -> void:
	_cleared_key = -1      # the clearing and the log strip are worked out again
	grass.set_trails_on(_switches.on("trails"))
	var talking: bool = _switches.on("speech")

	if _npc_voice != null:
		_npc_voice.set_enabled(talking)

	if sound != null:
		sound.inner.enabled = talking
		sound.ambient.enabled = _switches.on("ambient")


# Animals and NPCs leave the same trail in the grass as the player (data/look/grass_trample.json): the nearest few walkers each pass.
var _trail_msec: int = 0
var _animal_view_node: Node3D = null


func _stamp_walkers(now: int) -> void:
	if now < _trail_msec:
		return

	_trail_msec = now + 300
	grass.set_trail_multiplier(float(items.get("trail_mult")) if items != null and items.get("trail_mult") != null else 1.0)   # Tracking skill (Radar's value, 1 until it exists)
	var here: Vector3 = body.global_position
	var spots: Array = []

	for view in [_animal_view_node, _npc_view]:
		if view != null:
			spots.append_array(view.trail_points(here, grass.trail_reach_m()))

	spots.sort_custom(func(a, b): return a.distance_squared_to(here) < b.distance_squared_to(here))

	for n in range(mini(spots.size(), grass.trail_budget())):
		grass.stamp(spots[n])

	# The other players mat the grass as the player does (tester report #7, 23 Nov 2026), outside the walkers' budget so a herd nearby
	# never leaves a friend without a trail. flatten, not stamp: stamp also moves the trample map's window, which follows this player only.
	if _player_view != null:
		for spot in _player_view.trail_points(here, grass.trail_reach_m()):
			grass.flatten(spot, PlayerViewScript.TRAIL_RADIUS_M)


# Placed things clear the ground around them (data/look/placed_clearing.json): grass and litter in grass_view, shrubs and small plants in
# flora_view. The spots are read from the world items the inventory view already holds (a fire, shelter, chest, bench, forge...; loose
# sticks, stumps, boulders, remains and carcasses do not count). Updated when the set changes.
const PLACED_CLEARING := "res://data/look/placed_clearing.json"
const CLEARING_NOT := [0, 2, 4, 10]   # loose items and stumps; every other state asks structures.json "clears_grass" (StructureLook)
const StructureLook := preload("res://src/shared/structure_look.gd")
const LyingLogs := preload("res://src/shared/lying_logs.gd")
var wet_gap_override: float = -1.0     # look rig (--shot-wet=GAP): pretend this many metres of rock lie between the tunnel ceiling and the water; -1 = the real drip view
var cavein_death                      # the cave-in death sequence (src/client/cavein_death.gd), made at the first one
var showroom                          # the admin showroom at spawn (src/client/showroom.gd), shown while Admin mode is on
var _cleared_key: int = 0
var _burrow_spots: Array = []      # burrow mound spots from the server (burrow_view draws them), kept bare of grass


func _on_burrows_for_grass(points: PackedVector3Array) -> void:
	_burrow_spots = []

	for point in points:
		_burrow_spots.append(Vector3(snappedf(point.x, 0.01), point.y, snappedf(point.z, 0.01)))

	if grass != null and items != null:
		_sync_cleared()
var _switches_applied: bool = false
var _switches = TestSwitchesScript.new()      # Esc > Advanced experiment switches (default on)
var _cleared_cfg: Dictionary = {}
var _loose_segs: Dictionary = {}        # loose log id -> the segment it presses, kept while it rolls (_sync_cleared)


func _sync_cleared() -> void:
	if items == null or grass == null or flora == null:
		return

	if not _switches_applied and sound != null:
		_switches_applied = true
		_apply_switches()

	if _cleared_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACED_CLEARING))
		_cleared_cfg = parsed if parsed is Dictionary else {"radius_m": 3.0, "edge_m": 1.0}

	var spots: Array = []
	var lying: Array = []
	var paths: Array = []      # trodden path patches: left out of the grass cells (set_bare), pressed out of the plants like a log
	var roads: Array = []      # a surveyed road's patches: the same, 2 m out past the road's edges (Dave 17 Nov 2026)
	var key: int = 0

	if showroom == null and world.has("spawn"):
		showroom = ShowroomScript.new()
		showroom.setup(items, Vector3(world["spawn"]))

	if showroom != null and body != null:
		showroom.update(items.admin_craft, body.global_position)   # Admin mode on: the test rows at spawn, with the grass cleared under them

		for spot in showroom.clear_spots():
			spots.append(spot)
			key = key ^ hash(Vector2(spot.x, spot.z))

	var segs_now: Dictionary = {}

	for id in items._world:
		var row: Dictionary = items._world[id]

		if int(row.get("state", 0)) == 4 and _switches.on("log_grass"):
			# A standing stump: no blade grows out of it (inventory_view._make_felled draws it as a short cylinder).
			var stump_at: Vector3 = row["pos"]
			var stump_r: float = float(row.get("extra", {}).get("radius", 0.3))
			lying.append(LyingLogs.round_segment(stump_at, stump_r * 0.95))
			key = key ^ hash(Vector2(stump_at.x, stump_at.z)) ^ int(id)
			continue

		if int(row.get("state", 0)) == 0 and _switches.on("log_grass") and row.get("node") is Node3D:
			var loose_id: String = items.table.id_of(int(row.get("number", 0)))

			if loose_id == "log" or loose_id.begins_with("log_"):
				# A loose log lies along its node's x axis, centred on it (inventory_view._log_mesh): the grass under it is pressed flat.
				var node: Node3D = row["node"]
				var seg: Array

				if items._falling.has(id):
					continue   # a felled tree's log still coming down: pressed once it lies (a segment every frame of the fall would filter the grass again each time)

				# A log on the move (gliding where the server's physics rolls it, inventory_view._glide_tick): its node moves and turns every frame, and each new segment made the grass and the
				# plants of its chunks filter again, ten times a second for the whole roll (Dave 3 Nov 2026: "every time I drop a log off my shoulder
				# or I kick one everything lags each time it moves"). While it rolls it keeps the segment it had; the new one is taken once it rests.
				if items._gliding.has(id) and _loose_segs.has(id):
					seg = _loose_segs[id]
				else:
					seg = LyingLogs.loose_segment(node.global_position, node.global_transform.basis.x, 3.0, 0.22, 0.28)

				segs_now[id] = seg
				lying.append(seg)
				key = key ^ hash(Vector2(seg[0], seg[1])) ^ int(id)
				continue

		if int(row.get("state", 0)) == 32:
			# A trodden hoe path (Dave 2 Nov 2026): a round patch, so the grass is pressed out of its brown middle only, not cleared 5 m round like a bench.
			var path_at: Vector3 = row["pos"]
			(roads if bool(row.get("road", false)) else paths).append(Vector3(snappedf(path_at.x, 0.01), path_at.y, snappedf(path_at.z, 0.01)))
			key = key ^ hash(Vector2(path_at.x, path_at.z)) ^ int(id)
			continue

		if int(row.get("state", 0)) in CLEARING_NOT or not StructureLook.clears_grass(int(row.get("state", 0))) or not _switches.on("clearing"):
			continue

		var pos: Vector3 = row["pos"]
		var tile: Vector2 = StructureLook.tile_of(int(row.get("state", 0)))

		if tile != Vector2.ZERO:
			# A floor tile clears only its own footprint: bare patches 0.8 m apart across it, turned with the piece (paths use the same bare list).
			var turn: Basis = Basis(Vector3.UP, deg_to_rad(float(row.get("yaw", 0.0))))
			var nx: int = maxi(int(ceil(tile.x / 0.8)) - 1, 0)
			var nz: int = maxi(int(ceil(tile.y / 0.8)) - 1, 0)

			for iz in range(nz + 1):
				for ix in range(nx + 1):
					var local: Vector3 = Vector3((float(ix) / maxf(float(nx), 1.0) - 0.5) * (tile.x - 0.4) if nx > 0 else 0.0, 0.0, (float(iz) / maxf(float(nz), 1.0) - 0.5) * (tile.y - 0.4) if nz > 0 else 0.0)
					var at_tile: Vector3 = pos + turn * local
					paths.append(Vector3(snappedf(at_tile.x, 0.01), pos.y, snappedf(at_tile.z, 0.01)))

			key = key ^ hash(Vector2(pos.x, pos.z)) ^ int(id) ^ int(float(row.get("yaw", 0.0)))
			continue

		spots.append(Vector3(snappedf(pos.x, 0.01), pos.y, snappedf(pos.z, 0.01)))
		key = key ^ hash(Vector2(pos.x, pos.z)) ^ int(id)

	_loose_segs = segs_now

	for mound in _burrow_spots:      # rabbit burrow mounds are 0.13 m high: no grass stands through them (same bare patch as a path)
		paths.append(mound)
		key = key ^ hash(Vector2(mound.x, mound.z))

	for bog_id in items.bogs:      # a bog iron stain (Dave 19 Nov 2026: obvious to find): no grass or small plant stands on it
		var bog_at: Vector3 = items.bogs[bog_id]["pos"]
		spots.append(Vector3(snappedf(bog_at.x, 0.01), bog_at.y, snappedf(bog_at.z, 0.01)))
		key = key ^ hash(Vector2(bog_at.x, bog_at.z)) ^ int(bog_id)

	for boulder_id in items._boulders:
		var boulder: Dictionary = items._boulders[boulder_id]
		var rock_r: float = float(boulder.get("now", boulder.get("radius", 0.5)))
		lying.append(LyingLogs.round_segment(boulder["pos"], rock_r))
		key = key ^ hash(Vector2(boulder["pos"].x, boulder["pos"].z)) ^ int(boulder_id) ^ int(rock_r * 100.0)

	if key == _cleared_key:
		return

	_cleared_key = key
	var radius: float = float(_cleared_cfg.get("radius_m", 3.0))
	grass.set_cleared(spots, radius, float(_cleared_cfg.get("edge_m", 1.0)))
	grass.set_trunks(lying, float(_cleared_cfg.get("trunk_margin_m", 0.3)), float(_cleared_cfg.get("trunk_squash", 0.15)))
	grass.set_bare(paths, roads)
	var plant_lying: Array = lying.duplicate()

	for patch in paths:
		plant_lying.append(LyingLogs.round_segment(patch, 0.6))

	for patch in roads:
		plant_lying.append(LyingLogs.round_segment(patch, grass.ROAD_BARE_M))

	flora.set_cleared(spots, radius)
	flora.set_trunks(plant_lying, float(_cleared_cfg.get("trunk_margin_m", 0.3)))


# Water within a stride of the feet or a step or two ahead (where you look, flat): what the E-to-drink prompt needs.
var _shore_cfg: Dictionary = {}
var _shore_used: Dictionary = {}          # "cx,cz" -> game day this client gathered that tide-line node
var _shore_text: String = ""
var _shore_msec: int = -1000


# What E does at the sea's edge now, "" when nothing: the sea within 4 m (the ground under it below sea level at the player or 4 m around), a container in the pack, or a node in this cell.
# Worked out at most four times a second (five ground rays).
func _shore_prompt() -> String:
	var now: int = Time.get_ticks_msec()

	if now - _shore_msec < 250:
		return _shore_text

	_shore_msec = now
	_shore_text = ""

	if _shore_cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/shore_nodes.json"))
		_shore_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}

	if body == null or items == null or items.inventory == null or _shore_cfg.has("none"):
		return ""

	var here: Vector3 = body.global_position
	var reach: float = float(_shore_cfg.get("reach_m", 4.0))
	var container: String = ""

	for id in _shore_cfg.get("containers", []):
		var number: int = items.table.number_of(str(id))

		if number > 0 and items.inventory.numbers.has(number):
			container = str(id)
			break

	if nest_view != null:
		nest_view.set_season(season_here(), int(floor(game_clock.seconds / 86400.0)))   # eggs show in the laying season only, and not in a nest robbed lately

	if shore_props != null:
		shore_props.update(here, _shore_cfg, int(floor(game_clock.seconds / 86400.0)), game_clock.hour(), season_here(), _shore_used, _ground_below)

	var ground: float = _ground_below(here)

	if is_nan(ground) or ground > float(_shore_cfg.get("beach_max_height_m", 4.0)) + 1.0:
		return ""

	var sea: bool = false

	for offset in ([] if _under_land(here) else [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]):   # a tunnel under the island is no shore
		var g: float = _ground_below(here + Vector3(offset.x, 0.0, offset.y))

		if not is_nan(g) and g < 0.0:
			sea = true
			break

	var day: int = int(floor(game_clock.seconds / 86400.0))
	_shore_text = ShoreRules.prompt(_shore_cfg, here, sea, container, ground, day, game_clock.hour(), season_here(), _shore_used)
	return _shore_text


# The sea within drinking reach: the ground below sea level at the player or DRINK_REACH_M around (as _shore_prompt), never in a tunnel under the island.
# Asked each frame the prompts are read, so the answer is kept for 250 ms (as _shore_prompt).
var _sea_reach_msec: int = -1000
var _sea_reach: bool = false


func _sea_in_reach() -> bool:
	var now: int = Time.get_ticks_msec()

	if now - _sea_reach_msec < 250:
		return _sea_reach

	_sea_reach_msec = now
	_sea_reach = false

	if body == null or _under_land(body.global_position):
		return false

	for offset in [Vector2.ZERO, Vector2(DRINK_REACH_M, 0.0), Vector2(-DRINK_REACH_M, 0.0), Vector2(0.0, DRINK_REACH_M), Vector2(0.0, -DRINK_REACH_M)]:
		var g: float = _ground_below(body.global_position + Vector3(offset.x, 0.0, offset.y))

		if not is_nan(g) and g < 0.0:
			_sea_reach = true
			break

	return _sea_reach


func _shore_tap() -> void:
	var here: Vector3 = body.global_position
	net.inventory_action.rpc_id(1, NetScript.ACT_GATHER_EDGE, 0, 0, 0, here)

	# A tide-line gather uses the cell up for today (a container fill does not).
	if not _shore_text.begins_with("Press E to fill"):
		_shore_used[ShoreRules.cell_key(_shore_cfg, here)] = int(floor(game_clock.seconds / 86400.0))

	_shore_msec = -1000



# The record's drink points (net drink_points, DrinkRules.chunk_points): per flora chunk its brook cells and spring heads, kept for the last
# DRINK_KEEP_CHUNKS chunks that sent any. Where the settled water shows nothing, they give the E-to-drink prompt; the server's rule then says
# whether the water runs (docs/design/drink_prompt_design.md (a)).
const DRINK_KEEP_CHUNKS := 600
const DRINK_REACH_M := 3.0   # vitals.json thirst.reach_m, the server's reach for the same rows
var _drink_chunks: Dictionary = {}   # chunk -> [cell keys (Array of Vector2i), springs PackedFloat32Array x, z], oldest first
var _drink_cells: Dictionary = {}    # Vector2i world sample (cell_m grid) -> 1 + the brook's regime
var _drink_cell_m: float = 8.0
var _row_here: int = WeatherScript.STARTER_ROW   # starter-calendar: until the first weather step; the tile row the player stands in (set each second in _update_weather): its own seasons, sun and ice
var _eq_row: int = 0                 # the world's equator tile row
var _ice_across: bool = false        # the row is across the equator from the starter island (its year half a year on): ice answers kept for the other side are dropped
var _view_season: String = ""       # the season the flora view draws: the player's, held near the equator's row edge (_update_weather)
const VIEW_SEASON_EDGE_M := 64.0     # how far past that edge the player walks before the view takes the new side's season
var _drink_season: String = ""      # the season and rain the server's drink rule reads (DrinkRules.brook_shows), set each second in _update_weather
var _drink_raining: bool = false
var _drink_heads: Dictionary = {}    # Vector2i cell (cell_m grid) -> PackedFloat32Array x, z of the spring heads in it, for the lush grass (_brook_spots)
var _spring_heads = null   # SpringHeads: the damp patch, runnel and pebbles at each spring head of the drink points, made on the first that has any


func _on_drink_points(chunk: Vector2i, cell_m: float, cells: PackedInt32Array, springs: PackedFloat32Array) -> void:
	_forget_drink(chunk)
	_drink_cell_m = maxf(cell_m, 1.0)
	var keys: Array = []

	for n in range(0, cells.size() - 2, 3):
		var key: Vector2i = Vector2i(cells[n], cells[n + 1])
		_drink_cells[key] = cells[n + 2]
		keys.append(key)

	_drink_chunks[chunk] = [keys, springs]

	for n in range(0, springs.size() - 1, 2):
		var at: Vector2i = Vector2i(floori(springs[n] / _drink_cell_m), floori(springs[n + 1] / _drink_cell_m))
		var heads_here: PackedFloat32Array = _drink_heads.get(at, PackedFloat32Array())
		heads_here.append_array([springs[n], springs[n + 1]])
		_drink_heads[at] = heads_here

	if _spring_heads == null and not springs.is_empty():
		_spring_heads = SpringHeadsScript.new()
		_spring_heads.name = "SpringHeads"
		add_child(_spring_heads)

	if _spring_heads != null:
		_spring_heads.set_chunk(chunk, _drink_cell_m, cells, springs)

	while _drink_chunks.size() > DRINK_KEEP_CHUNKS:
		_forget_drink(_drink_chunks.keys()[0])


# The record brooks and spring heads in a box, as (x, z, NAN) triples: grass_view grows lush grass by them (Dave 10 Nov 2026: "all brooks and
# water ways"), where the settled water may draw nothing.
func _brook_spots(x0: float, z0: float, x1: float, z1: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()

	if _drink_cells.is_empty() and _drink_heads.is_empty():
		return out

	for j in range(floori(z0 / _drink_cell_m), floori(z1 / _drink_cell_m) + 2):
		for i in range(floori(x0 / _drink_cell_m), floori(x1 / _drink_cell_m) + 2):
			var at: Vector2i = Vector2i(i, j)

			if _drink_cells.has(at):
				out.append_array([float(i) * _drink_cell_m, float(j) * _drink_cell_m, NAN])

			for n in range(0, (_drink_heads.get(at, PackedFloat32Array()) as PackedFloat32Array).size() - 1, 2):
				out.append_array([_drink_heads[at][n], _drink_heads[at][n + 1], NAN])

	return out


func _forget_drink(chunk: Vector2i) -> void:
	if not _drink_chunks.has(chunk):
		return

	for key in _drink_chunks[chunk][0]:
		_drink_cells.erase(key)

	var springs: PackedFloat32Array = _drink_chunks[chunk][1]

	for n in range(0, springs.size() - 1, 2):
		_drink_heads.erase(Vector2i(floori(springs[n] / _drink_cell_m), floori(springs[n + 1] / _drink_cell_m)))

	_drink_chunks.erase(chunk)

	if _spring_heads != null:
		_spring_heads.drop_chunk(chunk)


# The spring heads' damp patches (spring_heads.gd): built as the player comes near, the runnel's far end iced when the puddles are, and the drawn
# heads handed to the trickle sound (cave_water_sounds.gd).
func _update_spring_heads(delta: float) -> void:
	if _spring_heads == null or body == null:
		return

	if weather_look != null and weather_look.puddles != null:
		_spring_heads.frost = float(weather_look.puddles.ice)

	if weather_look != null and weather_look.day != null:
		_spring_heads.daylight = clampf(float(weather_look.day.elevation) * 4.0, 0.0, 1.0)

	_spring_heads.update(delta, body.global_position)

	if sound != null and sound.cavewater != null:
		sound.cavewater.spring_heads = _spring_heads.heads_built()


# "Spring" within DRINK_REACH_M of a ground spring head, "Brook" when one of the five points the server reads (the feet and DRINK_REACH_M each
# way, nearest sample: DrinkRules.tile_rows) is a record brook cell that runs now (DrinkRules.brook_shows), else "".
func _record_drink_here() -> String:
	if body == null or _drink_chunks.is_empty():
		return ""

	var here: Vector3 = body.global_position
	var chunk_m: float = 256.0 if flora == null else float(flora.chunk_m)
	var home: Vector2i = Vector2i(int(floor(here.x / chunk_m)), int(floor(here.z / chunk_m)))

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var springs: PackedFloat32Array = _drink_chunks.get(home + Vector2i(dx, dz), [[], PackedFloat32Array()])[1]

			for n in range(0, springs.size() - 1, 2):
				if Vector2(springs[n] - here.x, springs[n + 1] - here.z).length() <= DRINK_REACH_M and _bed_in_reach(springs[n], springs[n + 1]):
					return "Spring"

	for offset in [Vector2.ZERO, Vector2(DRINK_REACH_M, 0.0), Vector2(-DRINK_REACH_M, 0.0), Vector2(0.0, DRINK_REACH_M), Vector2(0.0, -DRINK_REACH_M)]:
		var key: Vector2i = Vector2i(roundi((here.x + offset.x) / _drink_cell_m), roundi((here.z + offset.y) / _drink_cell_m))

		# Only a bed the rule says runs now: a dry gully offered a drink the server always refused (Dave 19 Nov 2026: "press e to drink" on a dry hillside).
		if _drink_cells.has(key) and DrinkRules.brook_shows(int(_drink_cells[key]) - 1, _drink_season, _drink_raining) and _bed_in_reach(float(key.x) * _drink_cell_m, float(key.y) * _drink_cell_m):
			return "Brook"

	return ""


# The ground at a record drink point (a brook cell's sample point, a spring head) is not down a bank out of reach, as the server measures it
# (DrinkRules.too_far_below on the sample's height or the head's). The ray starts well above the player, so water uphill is found too; no ground
# read yet is no.
func _bed_in_reach(x: float, z: float) -> bool:
	var bed: float = _ground_below(Vector3(x, body.global_position.y + 40.0, z))
	return not is_nan(bed) and not DrinkRules.too_far_below(bed, body.global_position.y)


# The drinkable spot ahead (at the feet, 1 m and 2 m forward) best centred on the reticle, on the water's surface; NAN when none. The drink probe gives
# it as its point, so E at the water's edge drinks when the reticle is on the water and gathers a reed only when the reticle is on the reed (robot
# goals run 25 Nov 2026: looking down at the water among reeds, E offered "gather"; Dave 21 Nov 2026: E acts on what is closest to the reticle).
func _water_ahead_point() -> Vector3:
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.ZERO
	var best: Vector3 = Vector3(NAN, NAN, NAN)
	var best_cos: float = -2.0

	for step in [0.0, 1.0, 2.0]:
		var spot: Vector3 = body.global_position + forward * step
		var surface: float = flora.water_surface_at(spot.x, spot.z)

		# Water down a bank out of reach is none, as the server's test (DrinkRules.too_far_below).
		if is_nan(surface) or DrinkRules.too_far_below(surface, body.global_position.y):
			continue

		var ground: float = _ground_below(spot)

		if is_nan(ground):
			continue   # no ground read yet (its collision not built) is no answer: depth() would take the whole surface height for the depth

		if WaterVolume.depth(surface, ground) >= WaterVolume.DRINK_DEPTH_M:   # shallow reed water too (BUG-015)
			var at: Vector3 = Vector3(spot.x, surface, spot.z)
			var aim: float = items.aim_cos_of(at) if items != null else 0.0

			if aim > best_cos:
				best_cos = aim
				best = at

	return best


# The world is still loading round the player (Dave 21 Nov 2026: at login "it makes the sounds of building everything really fast ... it can mute
# sounds until they land on the ground and everything is loaded"): not yet joined, gliding for ground, the join window still up, or less than
# LOAD_QUIET_MS since landing or since that window closed. Placed-thing sounds only note the rows meanwhile (PlacedSounds.quiet).
func _world_loading() -> bool:
	return connected_msec == 0 or waiting_for_ground or _connect_window != null or Time.get_ticks_msec() < _load_quiet_until_msec


var _welcome_offered: bool = false


# The welcome card once this join, when the player is in the world: a robot or the screen audit never stops for it (the audit shows it as one of
# its screens).
func _offer_welcome() -> void:
	if _welcome_offered or robot != null or test_screen_audit:
		return

	_welcome_offered = true
	var build: int = int(world.get("server_build", 0)) if bool(world.get("server_stamped", false)) else 0   # a release server: a new build is a new world (QA #13)
	_welcome().offer(CharacterStoreScript.active_id(), str(world.get("world_name", "")), build)


# The hint card (R-HUD-HINT-BOX) for a real player: robots and the test runs keep the passing line they read.
func _setup_hint_card() -> void:
	if robot != null or test_screen_audit or DisplayServer.get_name() == "headless" or items == null:
		return

	hint_card = HintCardScript.new()
	add_child(hint_card)
	items.hint_card = hint_card


func _tick_hint_card() -> void:
	if hint_card != null:
		hint_card.tick(_hint_safe(), Time.get_ticks_msec(), menu_open or items.screen_open() or (held != null and held.blueprints.is_open))


const HINT_CALM_MS := 10000     # no blow landed on the player this long
const HINT_THREAT_M := 30.0     # and no animal attacking or charging within this


# Safe for a card that takes the mouse: nothing else on screen, the mouse on the camera, no fight or danger, and no mouse button held (a held
# swing would lose its release). The game does not pause, so a card waits for this and steps aside the moment it is false.
func _hint_safe() -> bool:
	if body == null or menu_open or shot_lock or swimming or (welcome_card != null and welcome_card.showing):
		return false

	if items.screen_open() or items.body_out() or (held != null and (held.blueprints.is_open or held.tool_busy())):
		return false

	if hint_card.showing == "" and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		return false

	if Time.get_ticks_msec() - _hurt_msec < HINT_CALM_MS:
		return false

	return _animal_view_node == null or (_animal_view_node.attacker_near(body.global_position, HINT_THREAT_M) as Dictionary).is_empty()


var _audit_card = null


# The screen audit's own hint card (the audit run has none of its own): it never touches the mouse.
func _audit_hint_card():
	if _audit_card == null:
		_audit_card = HintCardScript.new()
		_audit_card.mouse_free = false
		add_child(_audit_card)

	return _audit_card


# The longest card the guide gives: a goal done with the copper journey next.
func _audit_hint_line() -> String:
	var copper: Dictionary = items.goal_book.row("copper_ore") if items.goal_book != null else {}
	return "Goal done: Make every stone tool. You earn 10 copper. Next: %s. %s" % [str(copper.get("title", "Find copper ore")), str(copper.get("howto", ""))]


func _welcome():
	if welcome_card == null:
		welcome_card = WelcomeCardScript.new()
		add_child(welcome_card)

	return welcome_card


# The body glides high above the spawn until the ground under it has collision. When it does, set it down just above the
# surface and protect it for a few seconds, so arriving is not a fall (Dave 2026-10-21: damage and a faint every landing).
func _arrive_on_ground() -> void:
	if connected_msec > 0 and not _ground_logged:
		_ground_logged = true
		_join_log("JOIN: ground ready after %d retries, test drops %d, player %s, viewer y %s" % [_ground_watchdog.tries, stream.drops_made if stream != null else 0, str(body.global_position), _viewer_y_text()])

		if _connect_window == null:
			_offer_welcome()   # no join window up (it offers the card when it closes, so the card is never under it)

	var ground: float = _ground_below(body.global_position)
	var water: Dictionary = _water_here()

	if not is_nan(ground) and not water.is_empty():
		ground = maxf(ground, float(water["surface"]) - ARRIVAL_HEIGHT_M)   # water has no collider: arriving over it is at its surface, swimming, never on the bed

	if not is_nan(ground) and body.global_position.y - ground > ARRIVAL_HEIGHT_M + 0.2:
		body.global_position.y = ground + ARRIVAL_HEIGHT_M
		body.velocity = Vector3.ZERO

	arrival_protect_until_msec = Time.get_ticks_msec() + ARRIVAL_PROTECT_MS
	_load_quiet_until_msec = Time.get_ticks_msec() + LOAD_QUIET_MS
	sound.forget_fall(body)


# The character died (protocol 34): the server already holds the remains and the reset vitals; put the body back at the spawn
# high up and let it settle on the ground the way a first arrival does (no fall, a few seconds of protection).
# Ctrl+Shift+N (admin): stand next to the nearest NPC that is drawn (they are sent within 120 m); press E there to talk.
func _go_to_npc() -> void:
	var near: Dictionary = _npc_view.nearest(body.global_position, 100000.0) if _npc_view != null else {}

	if near.is_empty():
		if items != null:
			items.show_notice("No NPC drawn (roster %d, drawn %d). You are at x %.0f z %.0f." % [_npc_view.roster.size(), _npc_view.drawn_count(), body.global_position.x, body.global_position.z])

		return

	if items != null:
		items.show_notice("Next to %s (roster %d, drawn %d)" % [str(near["name"]), _npc_view.roster.size(), _npc_view.drawn_count()])

	body.global_position = near["pos"] + Vector3(2.0, 1.5, 0.0)


# Not an admin on this server (server/client split A5): no Esc > Admin, no flying, no admin free crafting. The server refuses the
# admin requests anyway; this keeps the client's own admin keys (fly, go to the nearest NPC) from working.
func _on_admin_status(on: bool) -> void:
	is_admin_here = on

	if not on:
		flying = false

		if items != null:
			items.admin_craft = false

	game_menu.refresh()


# The server's answer to hello with where this character resumes (protocol 69): the spot they left, made safe by the server.
func _on_start_at(spot: Vector3) -> void:
	if body == null or body.global_position.distance_to(spot) < 8.0:
		return

	_telemetry.event("JOIN: resuming at %s (from %s)" % [str(spot.round()), str(body.global_position.round())])
	body.global_position = spot + Vector3(0.0, 1.0, 0.0)
	body.velocity = Vector3.ZERO
	_was_waiting = true   # set down like a first arrival once there is ground (_arrive_on_ground): a spot left in mid-air is not a fall


# The server moved this player to a station to craft there (protocol 103, server_items._step_to_station): stand there facing it.
func _on_step_to(spot: Vector3, yaw: float) -> void:
	if body == null:
		return

	_telemetry.event("CRAFT: stepped to the station at %s (from %s)" % [str(spot.round()), str(body.global_position.round())])
	body.global_position = spot + Vector3(0.0, 1.0, 0.0)
	body.velocity = Vector3.ZERO
	body.rotation.y = yaw


# Tells the server this quit is on purpose, then lets the packet go out before the game closes.
func _say_logout() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and net != null:
		net.logout.rpc_id(1)
		multiplayer.poll()


# Esc > Admin > Go to spawn: set the body down above the spawn point the way a respawn does (it waits for the ground there).
func go_to_spawn() -> void:
	if body == null or not world.has("spawn"):
		return

	body.global_position = Vector3(world["spawn"]) + Vector3(0.0, SPAWN_LIFT_M + _spawn_y_offset, 0.0)
	body.velocity = Vector3.ZERO
	_face_from_spawn(Vector3(world["spawn"]))
	_was_waiting = true
	arrival_protect_until_msec = Time.get_ticks_msec() + 10000


# Back from a death: at the starter spawn (not a shelter or bed the server chose) face the camp fire again; elsewhere keep the facing.
func _face_if_starter_spawn(spawn_point: Vector3) -> void:
	if world.has("spawn") and Vector2(spawn_point.x, spawn_point.z).distance_to(Vector2(Vector3(world["spawn"]).x, Vector3(world["spawn"]).z)) < 1.0:
		_face_from_spawn(spawn_point)


# Set down at the starter spawn (first arrival, a death that sends the character back there, Go to spawn): face Edda and Hob's camp fire
# (npc_camp.gd face_fire_yaw; Dave 20 Nov 2026). A returning character is then moved to where they left (_on_start_at) and keeps this facing.
func _face_from_spawn(spawn_at: Vector3) -> void:
	if body != null:
		body.rotation.y = NpcCampScript.face_fire_yaw(Vector2(spawn_at.x, spawn_at.z))


var death_screen                      # the real-death screen (src/client/death_screen.gd), made when the server sends final_death


func _on_final_death(cause: String) -> void:
	if death_screen == null:
		death_screen = DeathScreenScript.new()
		add_child(death_screen)

	if body != null:
		body.velocity = Vector3.ZERO

	death_screen.show_for(cause, str(CharacterStoreScript.active().get("name", "")))


func _on_died(cause: String, spawn_point: Vector3) -> void:
	if body == null:
		return

	# A cave-in death plays its long sequence first; the body is moved when it ends (finish_cavein_death).
	if cause == "cave-in" or cause == "cave-in survived":
		if cavein_death == null:
			cavein_death = CaveinDeathScript.new()
			add_child(cavein_death)

		body.velocity = Vector3.ZERO
		cavein_death.start(self, spawn_point, cause == "cave-in survived")
		return

	body.global_position = spawn_point + Vector3(0.0, SPAWN_LIFT_M + _spawn_y_offset, 0.0)
	body.velocity = Vector3.ZERO
	_face_if_starter_spawn(spawn_point)
	_was_waiting = true
	arrival_protect_until_msec = Time.get_ticks_msec() + 10000
	_respawn_gasp()


# Back at the respawn point after a death: the player comes to with a sharp breath (batch3 slot respawn_gasp), so a death is not a
# silent jump. Played at the new spot, after the body moved.
func _respawn_gasp() -> void:
	if sound != null:
		sound.slots.play("respawn_gasp", body.global_position + Vector3(0.0, 1.5, 0.0))


func _on_nests_sound(points: PackedVector3Array, kinds: PackedByteArray) -> void:
	if sound != null and sound.ambient != null:
		sound.ambient.set_nests(points, kinds)


# The built floor under the feet for the footsteps (sound_stage.floor_under): a short ray down hits a placed piece whose model carries
# "floor_sound" (inventory_view._model_for_state, structure_look.step_surface), or "" on natural ground.
func _floor_under(feet: Vector3) -> String:
	if body == null:
		return ""

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(feet + Vector3(0.0, 0.3, 0.0), feet - Vector3(0.0, 0.3, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider") if not hit.is_empty() else null

	for _i in 3:
		if node == null:
			break

		if node.has_meta("floor_sound"):
			return str(node.get_meta("floor_sound"))

		node = node.get_parent()

	return ""


# The end of the cave-in death sequence: back at the respawn point, as any other death does at once.
func finish_cavein_death(spawn_point: Vector3) -> void:
	if body == null:
		return

	body.global_position = spawn_point + Vector3(0.0, SPAWN_LIFT_M + _spawn_y_offset, 0.0)
	body.velocity = Vector3.ZERO
	_face_if_starter_spawn(spawn_point)
	_was_waiting = true
	arrival_protect_until_msec = Time.get_ticks_msec() + 10000
	_respawn_gasp()


var _water_key: Dictionary = {}   # chunk -> hash of the water bytes last received for it (unchanged water is not redrawn)


func _on_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool) -> void:
	if flora == null:
		return

	# A late trees-only answer for a chunk already held in full.
	if not full and flora.holds_full(chunk):
		return

	_flora_chunks += 1
	_flora_bytes += bytes.size() + water.size()
	_flora_done_msec = Time.get_ticks_msec() - connected_msec
	_water_key[chunk] = hash(water) ^ water.size() if not water.is_empty() else 0
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

	if int(grid.get("wet", 0)) > 0 and flora.LIQUID_CHUNKS:
		grid["liquid_image"] = LiquidSurface.image_from_grid(grid)
	elif int(grid.get("wet", 0)) > 0:
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

	for entry in _flow_jobs:
		WorkerThreadPool.wait_for_task_completion(int(entry[0]))

	_flow_jobs.clear()


func _apply_incoming() -> void:
	var started: int = Time.get_ticks_usec()
	var applied: int = 0
	var water_applied: int = 0

	while not _in_queue.is_empty():
		_in_mutex.lock()
		var job: Dictionary = _in_queue[0]
		var done: bool = job["done"]
		_in_mutex.unlock()

		if not done or (applied > 0 and Time.get_ticks_usec() - started > INCOMING_USEC):
			break

		# One chunk's water redraw a frame at most (Steve's lag report, 2 Nov 2026): a burst of changed chunks is spread over frames.
		if job["kind"] == "water" and water_applied > 0:
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

			if rig_flora_hold.has(chunk):   # look rig: its own plants stay, the server's chunk is ignored
				Probe.stop("flora chunk in", t)
				continue

			if not full and flora.holds_full(chunk):
				Probe.stop("flora chunk in", t)
				continue

			# BUG-024: the server makes chunks on worker threads, so one made just before a cut can arrive after the cut message
			# and would put the felled tree back, near or far. Trees cut in the last minute are left out of what arrives.
			if _recent_cuts.has(chunk):
				var cuts: Dictionary = _recent_cuts[chunk]
				var now_msec: int = Time.get_ticks_msec()

				for cut_id in cuts.keys():
					if now_msec - int(cuts[cut_id]) > RECENT_CUT_MSEC:
						cuts.erase(cut_id)

				if cuts.is_empty():
					_recent_cuts.erase(chunk)
				else:
					result["items"] = PlacerScript.without(result["items"], cuts)

			if flora.has_chunk(chunk):
				flora.replace_items(chunk, result["items"], _anchor, full)
			else:
				flora.set_chunk(chunk, result["items"], _anchor, result["grid"], full)

			Probe.stop("flora chunk in", t)
		else:
			water_applied += 1
			var tw: int = Probe.start()
			flora.set_water(chunk, result["grid"])
			Probe.stop("water in", tw)


# Weather from the game clock, the world seed, the zone of the tile the player is in and their
# altitude (town spirit is a neutral placeholder until it exists). Once a second; it is only a
# few noise lookups.
# The season where the player stands (Weather.season_at at their row, set each second in _update_weather: half a year on across the
# equator), as the server reads it there; the calendar's until the first weather step.
func season_here() -> String:
	return _drink_season if _drink_season != "" else game_clock.season()   # starter-calendar: only before the first weather step


func _update_weather() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _weather_next_msec or world.is_empty():
		return

	_weather_next_msec = now + 1000
	# BugsList 108: "clock, weather" reached 30-59 ms in some lane frames; each part is timed on its own so a HITCH line names which.
	var tw: int = Probe.start()
	var tile_m: float = float(world.get("tile_size_m", 15360))
	var row: int = ClimateScript.row_of_z(_anchor.z, tile_m)
	var group: String = WeatherScript.zone_group(world.get("zones", []), int(world.get("equator_row", 0)), row)
	_row_here = row
	_eq_row = int(world.get("equator_row", 0))
	var across: bool = ClimateScript.local_year_phase(0.0, row, _eq_row) > 0.25

	if across != _ice_across:   # over the equator the ice is the other half of the year's: no answer kept for the old side is used
		_ice_across = across
		_finish_ice_task()
		_ice_last = {}
		_ice_memo.clear()

	DayCycleScript.sky_row_latitude = ClimateScript.latitude_of_row(row, int(world.get("equator_row", 0)))   # this row's sky
	under_cover = CoverScript.at(_anchor, flora.cover) if flora != null else 0.0
	weather = WeatherScript.state(int(world.get("master_seed", 0)), game_clock.seconds, group, _anchor.y, 0.0, row, int(world.get("equator_row", 0)))
	# The drink rule's season and rain as the server reads them (_drink_source_ok): the season at the player's row (season_at), and the rain
	# over this spot (the server's weather_at, terrain_server._weather_here: this row and height, the same state as this sky).
	_drink_season = WeatherScript.season_at(game_clock.seconds, _anchor.z, tile_m, int(world.get("equator_row", 0)))
	# The view's season (flora_view.set_season redraws every chunk on a change): it follows the player's, but over the equator's row edge
	# only once they are VIEW_SEASON_EDGE_M past it, so a walk along the edge does not redraw the view every second.
	if _view_season == "" or _drink_season == _view_season or (WeatherScript.season_at(game_clock.seconds, _anchor.z - VIEW_SEASON_EDGE_M, tile_m, _eq_row) == _drink_season
			and WeatherScript.season_at(game_clock.seconds, _anchor.z + VIEW_SEASON_EDGE_M, tile_m, _eq_row) == _drink_season):
		_view_season = _drink_season
	_drink_raining = float(weather["rain"]) > 0.05
	world_wind_dir = float(weather["wind_dir"])
	weather = wind_onto(weather)

	if items != null:
		items.air_c = float(weather["temp_c"])

	Probe.stop("weather: state", tw)
	tw = Probe.start()
	# Ice on ponds and lakes: a pure function of the clock, zone and altitude (src/shared/ice.gd), so
	# every client and the server agree with no traffic.
	# The walkable ice (collider, ice feel bands, sounds) takes a fresh answer each second from a worker (_ice_season_now): only the look
	# below uses kept answers. The one season run gives the cover and the thaw (the same loop and numbers as IceScript.cover).
	var seed_value: int = int(world.get("master_seed", 0))
	var season_now: Dictionary = _ice_season_now(group, seed_value)
	var thaw_season: Dictionary = season_now if now >= _ice_thaw_next_msec else {}
	var ice_now: float = float(season_now["cover"])

	if not thaw_season.is_empty():
		_ice_memo_put(group, ICE_POND_DEPTH_M, thaw_season)   # the look's 3 m answer for this slot: the same depth, height and game time (FrozenWater.OPEN_DEPTH_M)

	ice_now = _update_ice_feel_weather(ice_now, group, now, thaw_season)

	if flora != null:
		flora.set_ice_cover(ice_now)

	if ocean_ice != null:
		# The sea never freezes outside the arctic zone (Ice.sea_cover); there, salt water freezes at -1.8 C.
		ocean_ice.update(_anchor, IceScript.sea_cover(game_clock.seconds, group, int(world.get("master_seed", 0)), _row_here, _eq_row))

	if sound != null and sound.weather != null:
		sound.weather.ice_cover = ice_now

	Probe.stop("weather: ice", tw)
	tw = Probe.start()
	_update_frozen_water(group, now)
	Probe.stop("weather: frozen water", tw)
	tw = Probe.start()

	if weather_look != null and weather_look.puddles != null:
		weather_look.puddles.set_ice_from(game_clock.seconds, group, _anchor.y, _row_here, _eq_row)      # puddles freeze by the same rule, shallow (every 10 s)

	if sound_tests.weather_at < 0 and sound != null and sound.weather != null:
		sound.weather.apply_state(weather)

	if sound != null and sound.occlusion != null and sound.occlusion.outdoors:     # --sound-outdoors (sound_outdoors_design.md)
		sound.occlusion.set_air(weather, weather_look.day.elevation if weather_look != null else 0.5, game_clock.hour(), weather_look.fog_now() if weather_look != null else 0.0)

	Probe.stop("weather: puddles+sound", tw)


# Frozen water look (docs/design/frozen_water_look.md): every 5 s the covers at 3 m and 1 m, the thaw, the lying snow, the springs
# near the player (their brooks stay open) and the ice holes go to every liquid sheet. --frozen-force=open[,thaw[,snow]] and --frozen-hole=x,z are
# picture switches (a solid sheet the starter island never grows; a hole before the server sends them).
var ice_holes: Array = []   # {"pos": Vector3, "until": game seconds}: the server's fishing holes, once it sends them (section 5; Steve)
var _frozen_next_msec: int = 0
var _frozen_force: Vector4 = Vector4(-2.0, 0.0, 0.0, 0.0)   # -2: not read yet
var _frozen_hole: Array = []


func _read_frozen_switches() -> void:
	if _frozen_force.x < -1.5:
		_frozen_force = FrozenWater.force_of(AppConfig.get_command_line_value("frozen-force", ""))
		_frozen_hole = FrozenWater.hole_of(AppConfig.get_command_line_value("frozen-hole", ""))


# Ice walk feel (docs/design/ice_walk_feel.md): the band of the ice under the player from the collider's own cover, the footing on a
# sheet, wading through skim and film, the cold shock and the thaw moat in the walkable collider.
var _ice_feel_cover: float = 0.0
var _ice_feel_band: int = 0
var _ice_thaw: float = 0.0
var _ice_thaw_next_msec: int = 0
var _ice_underfoot: bool = false          # this physics frame the body stands on the ice collider (layer 2)
var _ice_patches: Array = []              # skim and film broken by the player's wading (FrozenWater hole form; client only)
var _ice_shock: Dictionary = {}           # IceFeel.shock_step state
var _warmth_cfg_cache: Dictionary = {}
var _ice_moat_logged: int = -1
var _spring_mouths: Dictionary = {}       # tile -> PackedVector3Array, where spring cave brooks leave their caves
var _spring_steam = null                  # SpringSteam, made on the first frosty update with a mouth known
var _wetland_mist = null                  # WetlandMist, made at the first dawn or dusk it could show
var fish_signs = null                     # FishSignsView, made at the first fish sign the server sends (protocol 169)
var _steam_logged: bool = false


# BugsList 108 (lane frame-time runs, 22 Nov 2026: "weather: ice" 8-24 ms and "weather: frozen water" 16-22 ms in HITCH frames): Ice.season
# walks 30 game days hour by hour (721 weather samples) and was asked up to five times every 5 s. For the frozen water LOOK only (never what
# bears a step: that stays the exact Ice.cover each second), each depth's answer is kept for ICE_MEMO_GAME_S of game time and per ICE_MEMO_BAND_M
# of height (climbing a slope no longer misses every tick; 10 m of height is under 0.1 C of air): ice grows and melts over game hours, so a
# ten-minute-old answer looks the same (coordinator ruling, 22 Nov 2026).
const ICE_MEMO_GAME_S := 600.0
const ICE_MEMO_BAND_M := 10.0
var _ice_memo: Dictionary = {}   # [depth, zone group, seed, height band, game time slot] -> Ice.season


# The pond ice for the feel and the look, once a second (BugsList 108: "weather: ice" 8-24 ms in HITCH frames, a hitch every second). Ice.season
# walks 30 game days hour by hour, so it runs on a worker: each second takes the answer the worker finished (asked about a second earlier;
# ice grows and melts over game hours, so a second-old cover is the same cover to the step) and asks the next one. The first second, and any
# second whose worker has not finished, uses the last answer; the very first answer is worked out here, so the walkable ice is never unknown.
var _ice_task: int = -1
var _ice_task_out: Dictionary = {}   # written by the worker, read only after it finished
var _ice_last: Dictionary = {}       # {"cover", "peak"} at the anchor
var _ice_last_key: Array = []        # [zone group, height band] that answer was asked for
var _ice_task_key: Array = []        # the same for the task still running


func _ice_season_now(group: String, seed_value: int) -> Dictionary:
	var height: float = maxf(_anchor.y, 0.0)
	var game_s: float = game_clock.seconds
	var band: int = int(floorf(height / ICE_MEMO_BAND_M))

	if _ice_task >= 0 and WorkerThreadPool.is_task_completed(_ice_task):
		WorkerThreadPool.wait_for_task_completion(_ice_task)
		_ice_task = -1

		if str(_ice_task_key[0]) == group and absi(int(_ice_task_key[1]) - band) <= 1:   # asked for another zone or height: dropped
			_ice_last = _ice_task_out
			_ice_last_key = _ice_task_key

	# The first answer, and the first after a new zone or a move of two height bands or more (a teleport, a respawn): worked out here once,
	# so the step and the look never use another place's ice. A climb into the next band (under 0.1 C of air) waits for the worker.
	if _ice_last.is_empty() or str(_ice_last_key[0]) != group or absi(int(_ice_last_key[1]) - band) >= 2:
		_ice_last = IceScript.season(game_s, group, height, ICE_POND_DEPTH_M, seed_value, _row_here, _eq_row)
		_ice_last_key = [group, band]
	elif _ice_task < 0:
		_ice_task_key = [group, band]
		var row: int = _row_here
		var eq: int = _eq_row
		_ice_task = WorkerThreadPool.add_task(func() -> void: _ice_task_out = IceScript.season(game_s, group, height, ICE_POND_DEPTH_M, seed_value, row, eq), true, "pond ice")

	return _ice_last


func _finish_ice_task() -> void:
	if _ice_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ice_task)
		_ice_task = -1


func _ice_memo_key(group: String, depth_m: float) -> Array:
	return [depth_m, group, int(world.get("master_seed", 0)), int(floorf(maxf(_anchor.y, 0.0) / ICE_MEMO_BAND_M)), int(floorf(game_clock.seconds / ICE_MEMO_GAME_S))]


func _ice_memo_put(group: String, depth_m: float, season: Dictionary) -> void:
	if _ice_memo.size() >= 8:
		_ice_memo.clear()   # old slots and heights: a handful of entries at most, never a growing table

	_ice_memo[_ice_memo_key(group, depth_m)] = season


func _ice_season(group: String, depth_m: float) -> Dictionary:
	var key: Array = _ice_memo_key(group, depth_m)

	if not _ice_memo.has(key):
		_ice_memo_put(group, depth_m, IceScript.season(game_clock.seconds, group, maxf(_anchor.y, 0.0), depth_m, int(world.get("master_seed", 0)), _row_here, _eq_row))

	return _ice_memo[key]


# Once a second with the weather: the forced cover (--frozen-force) also drives the collider and the sounds; every 5 s the thaw for the moat.
func _update_ice_feel_weather(ice_now: float, group: String, now: int, thaw_season: Dictionary = {}) -> float:
	_read_frozen_switches()

	if _frozen_force.x >= 0.0:
		ice_now = _frozen_force.x

	if now >= _ice_thaw_next_msec:
		_ice_thaw_next_msec = now + 5000

		if _frozen_force.x >= 0.0:
			_ice_thaw = _frozen_force.z
		else:
			var season: Dictionary = thaw_season if not thaw_season.is_empty() else IceScript.season(game_clock.seconds, group, maxf(_anchor.y, 0.0), ICE_POND_DEPTH_M,
				int(world.get("master_seed", 0)), _row_here, _eq_row)
			_ice_thaw = FrozenWater.thaw_of(float(season["cover"]), float(season["peak"]))

		var moat: int = IceFeelScript.moat_cells(_ice_thaw)

		if flora != null:
			flora.set_ice_moat(moat)

		if moat != _ice_moat_logged:
			_ice_moat_logged = moat
			FreezeWatchScript.printer.line("ice feel: moat %d cell%s (thaw %.2f)" % [moat, "" if moat == 1 else "s", _ice_thaw])

	var band: int = IceFeelScript.band_of(ice_now)

	if band != _ice_feel_band:
		FreezeWatchScript.printer.line(IceFeelScript.log_line(band, "band now", "", 1.0, INF))

	_ice_feel_cover = ice_now
	_ice_feel_band = band

	if sound != null and sound.ice != null:
		sound.ice.hour = WeatherScript.hour_of(game_clock.seconds)

	_update_spring_steam()
	_update_wetland_mist()
	return ice_now


func _update_wetland_mist() -> void:
	if sound == null or sound.ambient == null:
		return

	var hour: float = WeatherScript.hour_of(game_clock.seconds)
	var sun: Array = sound.ambient._sun()
	var wind: float = float(weather.get("wind", 0.0))
	var rain: float = float(weather.get("rain", 0.0))

	if _wetland_mist == null:
		if WetlandMist.strength_of(hour, float(sun[0]), float(sun[1]), wind, rain) <= 0.02:
			return

		_wetland_mist = WetlandMist.new()
		_wetland_mist.name = "WetlandMist"
		_wetland_mist.setup(quality)
		add_child(_wetland_mist)

	_wetland_mist.update(body.global_position, hour, float(sun[0]), float(sun[1]), wind, rain, float(weather.get("wind_dir", 0.0)), sound.ground_at)


func _fish_signs_view():
	if fish_signs == null:
		fish_signs = FishSignsView.new()
		fish_signs.name = "FishSigns"
		fish_signs.conditions = func() -> Array: return [WeatherScript.hour_of(game_clock.seconds), float(weather.get("rain", 0.0))]
		fish_signs.sound_room = func() -> bool: return sound == null or sound.has_room()
		add_child(fish_signs)
		fish_signs.setup(quality)

	return fish_signs


func _update_spring_steam() -> void:
	if _spring_mouths.is_empty():
		return

	var mouths: PackedVector3Array = PackedVector3Array()

	for tile in _spring_mouths:
		mouths.append_array(_spring_mouths[tile])

	var air: float = float(weather.get("temp_c", 10.0))
	var hour: float = WeatherScript.hour_of(game_clock.seconds)
	var wind: float = float(weather.get("wind", 0.0))

	if _spring_steam == null:
		if SpringSteam.strength_of(air, hour, wind) <= 0.02:
			return

		_spring_steam = SpringSteam.new()
		_spring_steam.name = "SpringSteam"
		_spring_steam.setup(quality)
		add_child(_spring_steam)

	_spring_steam.update(mouths, body.global_position, air, hour, wind, float(weather.get("wind_dir", 0.0)))
	var steaming: bool = _spring_steam.strength > 0.02

	if steaming != _steam_logged:
		_steam_logged = steaming
		FreezeWatchScript.printer.line("ice feel: spring steam %s (strength %.2f, air %.1f C, %d mouths known)" % ["on" if steaming else "off", _spring_steam.strength, air, mouths.size()])


func _warmth_cfg() -> Dictionary:
	if _warmth_cfg_cache.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))
		_warmth_cfg_cache = parsed if parsed is Dictionary else {"water_base_c": 12.0}

	return _warmth_cfg_cache


# A bite or a charge lands: the animal doing it snarls where it is (a wolf's growl, a brown bear's roar, a black bear's growl: creature_sounds.mood_for), so a fight is heard from the attacker,
# at most once every SNARL_EVERY_MS. Nothing when the blow came from no attacking animal (a fall, a bandit).
const SNARL_M := 5.0
const SNARL_EVERY_MS := 1500
var _snarl_ms: int = 0


# The players' heads for head tracking (animal_view.look_points): this player's (the capsule's middle is about 1 m up, the head 0.6 m
# above it) and each other player drawn (player_view.drawn: the feet).
func _look_points() -> Array:
	var out: Array = []

	if body != null and body.is_inside_tree():
		out.append(body.global_position + Vector3(0.0, 0.6, 0.0))

	if _player_view != null:
		for who in _player_view.drawn():
			out.append((who["pos"] as Vector3) + Vector3(0.0, 1.6, 0.0))

	return out


func _attacker_snarl() -> void:
	if _animal_view_node == null or sound == null or Time.get_ticks_msec() < _snarl_ms:
		return

	var who: Dictionary = _animal_view_node.attacker_near(body.global_position, SNARL_M)

	if who.is_empty():
		return

	_snarl_ms = Time.get_ticks_msec() + SNARL_EVERY_MS
	sound.creatures.call_at(str(who["kind"]), who["at"], sound.creatures.mood_for(str(who["kind"]), 11), who.get("node", null))   # the attack's own call: a black bear, lynx or puma growls, never roars


# The footstep and ice tier (sound_stage, gear_sounds, ice_feel: 0 walk, 1 the middle step a jump push-off uses, 2 run).
func _gait() -> int:
	return 2 if running else 0


# The walking velocity on ice: wading through skim or film is slower; on a sheet the top speed drops and the velocity eases toward the input
# (a slide), snow gives most of the grip back.
func _ice_feel_velocity(velocity: Vector3, water: Dictionary, delta: float) -> Vector3:
	_ice_underfoot = false

	if body.is_on_floor():
		for i in range(body.get_slide_collision_count()):
			var hit = body.get_slide_collision(i).get_collider()

			if hit is StaticBody3D and (hit.collision_layer & 2) != 0:
				_ice_underfoot = true
				break

	var snow: float = sound.weather.ground_snow if sound != null and sound.weather != null else 0.0

	if _ice_underfoot and IceFeelScript.bears(_ice_feel_band):
		var want: Vector2 = Vector2(velocity.x, velocity.z) * IceFeelScript.pace_mult(_ice_feel_band, _gait(), snow)
		var now_v: Vector2 = IceFeelScript.grip_step(Vector2(body.velocity.x, body.velocity.z), want, IceFeelScript.grip_rate(_ice_feel_band, snow), delta)
		velocity.x = now_v.x
		velocity.z = now_v.y
	elif not water.is_empty() and not float(water["surface"]) <= float(water.get("ground", NAN)) and body.is_on_floor() and sound != null and sound.water.still_near():   # in the water, not on the bank its sheet runs under
		var slow: float = IceFeelScript.wade_mult(_ice_feel_band)
		velocity.x *= slow
		velocity.z *= slow

	return velocity


# The cold shock on going into icy water (swimming, or the soles 0.8 m under): one gasp, one jolt, a minute of slower swimming.
func _ice_feel_shock(water: Dictionary, delta: float) -> void:
	var immersion: float = float(water["surface"]) - (body.global_position.y - SoundStageScript.FEET_M) if not water.is_empty() else -1.0
	var air: float = float(weather.get("temp_c", 10.0))
	var icy: bool = IceFeelScript.icy(IceFeelScript.water_c(air, _warmth_cfg()), _ice_feel_cover)

	if IceFeelScript.shock_step(_ice_shock, delta, icy and (swimming or immersion > 0.8), immersion > 0.45):
		feel.strike(1.0 if randf() < 0.5 else -1.0, IceFeelScript.SHOCK_DIP_M / 0.08)

		if sound != null and sound.slots != null:
			sound.slots.play("respawn_gasp", body.global_position + Vector3(0.0, 1.5, 0.0))

		FreezeWatchScript.printer.line(IceFeelScript.log_line(_ice_feel_band, "cold shock, water %.1f C" % IceFeelScript.water_c(air, _warmth_cfg()), "respawn_gasp", IceFeelScript.SHOCK_SWIM, INF))


# After a footstep: skim or film broken under the wader leaves a patch in the look; the plunge jolts the eye.
func _ice_feel_after_step() -> void:
	if sound == null or sound.ice_break_event == "":
		return

	var event: String = sound.ice_break_event
	var feet: Vector3 = body.global_position - Vector3(0.0, SoundStageScript.FEET_M, 0.0)
	var patch: Dictionary = IceFeelScript.patch_at(_ice_feel_band, feet, game_clock.seconds)

	if not patch.is_empty():
		_ice_patches = IceFeelScript.add_patch(_ice_patches, patch, game_clock.seconds)

	if event == "plunge":
		feel.strike(1.0 if randf() < 0.5 else -1.0, IceFeelScript.PLUNGE_DIP_M / 0.08)
		FreezeWatchScript.printer.line(IceFeelScript.log_line(_ice_feel_band, "plunge", sound.ice.last, IceFeelScript.wade_mult(_ice_feel_band), INF))


func _update_frozen_water(group: String, now: int) -> void:
	if now < _frozen_next_msec:
		return

	_frozen_next_msec = now + 5000
	var seed_value: int = int(world.get("master_seed", 0))

	_read_frozen_switches()

	var snow: float = sound.weather.ground_snow if sound != null and sound.weather != null else 0.0
	var look: Vector4 = _frozen_force if _frozen_force.x >= 0.0 else FrozenWater.look_from(_ice_season(group, FrozenWater.OPEN_DEPTH_M),
		float(_ice_season(group, FrozenWater.SHORE_DEPTH_M)["cover"]), snow)
	var pools: Array = []

	if _cave_streams != null:
		for tile in _cave_streams._pools:
			pools.append_array(_cave_streams._pools[tile])

	var air: float = WeatherScript.air_c(game_clock.seconds, group, maxf(_anchor.y, 0.0), seed_value, _row_here, _eq_row)
	var springs: PackedVector4Array = FrozenWater.springs_near(pools, _anchor, air, group, float(weather.get("wind", 0.0)))
	var holes: PackedVector4Array = FrozenWater.holes_near(ice_holes + _frozen_hole + _ice_patches, _anchor, game_clock.seconds)
	LiquidSurface.set_ice_all(get_tree(), true, look, springs, holes)


# Protocol 85: the simulated water window as a texture: the liquid sheet draws it, and the grid look steps aside inside it (src/water2/water_flow_texture.gd).
signal cave_dens_changed(tile: Vector2i, dens: PackedVector3Array)   # den sounds (Sound thread #211) listen here
var cave_dens: Dictionary = {}   # tile -> PackedVector3Array of den floor points (protocol 87)
var _cave_streams = null   # spring cave streams and pools (protocol 87), made on the first list
var _liquid = null   # the liquid water sheet over the live window (created on the first flow packet)
var _flow_tex: ImageTexture = null      # the live water window's texture, updated in place each publish
var _liquid_hole_told: Rect2 = Rect2()
var _fine_holes: PackedVector4Array = PackedVector4Array()   # their rectangles, given to every 8 m sheet
var _fine_received: int = 0   # 2 m water messages received (the log line for the PC check)
var _fine_sheets: Dictionary = {}   # Sullivan water: region key -> {"sheet": LiquidSurface in fine mode, "rect": Vector4 world x, z, size x, size z}


var _cave_dressing = null   # bone piles and stalagmites/stalactites in caves (protocol 92), made on the first list


func _on_cave_dressing(tile: Vector2i, bones: PackedFloat32Array, formations: PackedFloat32Array) -> void:
	if _cave_dressing == null:
		_cave_dressing = CaveDressing.new()
		_cave_dressing.name = "CaveDressing"
		add_child(_cave_dressing)

	_cave_dressing.set_tile(tile, bones, formations)


func _on_cave_dens(tile: Vector2i, dens: PackedVector3Array) -> void:
	cave_dens[tile] = dens
	cave_dens_changed.emit(tile, dens)


func _on_cave_streams(tile: Vector2i, streams: PackedFloat32Array) -> void:
	if _cave_streams == null:
		_cave_streams = CaveStreams.new()
		_cave_streams.name = "CaveStreams"
		_cave_streams.add_to_group("water_draw")
		add_child(_cave_streams)

	_cave_streams.show_tile(tile, streams)

	_spring_mouths[tile] = SpringSteam.mouths_of(streams)
	@warning_ignore("integer_division")
	FreezeWatchScript.printer.line("Terrain client: cave streams for tile %s (%d pieces, %d pools)" % [str(tile), streams.size() / 7, CaveStreams.pools_of(streams).size()])

	if sound != null:
		sound.cavewater.set_tile(tile, streams)       # the water inside the cave makes its sound (cave_water_sounds.gd)


# Lane A 26 Nov 2026 (r4 route at Low on 4 cores, PR #1953's NET slow lines): this message took 41-47 ms of the main thread 25 times in a
# 10-minute run, almost all of it tuck_dry_edges, a GDScript pass over the window's 128 x 128 texels. The unpacking and the tuck now run on
# a worker; _apply_flow shows the newest finished window the next frame (twice a second, a newer window replaces any older one waiting).
func _on_water_flow(origin: Vector2, w: int, h: int, cell_m: float, raw_size: int, bytes: PackedByteArray) -> void:
	if flora == null or flora.water_material() == null:
		return

	# Every key is set before the task starts, the worker writes only "image", and the main thread reads the job only once the task is done.
	var job: Dictionary = {"origin": origin, "w": w, "h": h, "cell_m": cell_m, "raw_size": raw_size, "bytes": bytes, "image": null}
	_flow_jobs.append([WorkerThreadPool.add_task(_unpack_flow.bind(job)), job])


func _unpack_flow(job: Dictionary) -> void:
	var im: Image = FlowTexture.unpack(int(job["w"]), int(job["h"]), int(job["raw_size"]), job["bytes"])

	if im != null:
		FlowTexture.tuck_dry_edges(im)   # the sheet runs flat into the bank instead of up it (water_flow_texture.gd)

	job["image"] = im


# Each frame: the finished windows in arrival order are taken off (their tasks waited on, which returns at once), the newest one is shown.
func _apply_flow() -> void:
	var newest: Dictionary = {}

	while not _flow_jobs.is_empty() and WorkerThreadPool.is_task_completed(int(_flow_jobs[0][0])):
		var entry: Array = _flow_jobs.pop_front()
		WorkerThreadPool.wait_for_task_completion(int(entry[0]))
		newest = entry[1]

	if newest.is_empty() or newest["image"] == null:
		return

	var t: int = Probe.start()
	_show_flow(newest["image"], newest["origin"], float(newest["cell_m"]))
	Probe.stop("water flow in", t)


func _show_flow(im: Image, origin: Vector2, cell_m: float) -> void:
	var material: Material = flora.water_material() if flora != null else null

	if material == null:
		return

	var w: int = im.get_width()
	var h: int = im.get_height()

	# Protocol 85: the liquid sheet draws the live window (src/water2/liquid_surface.gd), the grid look steps aside there.
	if _liquid == null:
		_liquid = LiquidSurface.new()
		_liquid.name = "LiquidSurface"
		_liquid.add_to_group("liquid_sheet")
		_liquid.add_to_group("water_draw")
		flora.add_child(_liquid)
		_liquid.set_fine_holes(_fine_holes)

	# One texture for every publish (twice a second, 256 KB): updated in place, not a new GPU texture each time (lag review, Dave 2 Nov 2026).
	if _flow_tex == null or _flow_tex.get_size() != Vector2(im.get_size()):
		_flow_tex = ImageTexture.create_from_image(im)
		flora.set_liquid_live(_flow_tex)   # chunk sheets give way only where the live sheet draws water (Dave 4 Nov 2026: a dry sim hid a baked river)
	else:
		_flow_tex.update(im)

	_liquid.show_window(im, origin, cell_m, _flow_tex)
	flora.set_liquid_live_image(im, origin, cell_m)   # wading and swimming read the water this window draws (flora_view water_surface_at)
	# The chunk sheets step aside inside the window from one cell in, where this sheet has faded in (told only when the window moves).
	var hole: Rect2 = Rect2(origin - Vector2(0.5, 0.5) * cell_m, Vector2(w, h) * cell_m)

	if hole != _liquid_hole_told:
		_liquid_hole_told = hole
		flora.set_liquid_hole(hole.position, hole.size, cell_m)

	FlowTexture.apply_image(material as ShaderMaterial, im, origin, cell_m, _flow_tex)


# Sullivan water (protocol 94, docs/water/fine_drawing_2m.md): each dig region's 2 m water on its own fine sheet; the 8 m sheets step aside there.
func _on_fine_water(keys: PackedStringArray, packets: Array) -> void:
	_fine_received += 1

	if _fine_received == 1 or _fine_received % 20 == 0:
		FreezeWatchScript.printer.line("Terrain client: 2 m water message %d: %d regions, %d textures%s" % [_fine_received, keys.size(), packets.size(), "" if flora != null else " (no flora yet, not drawn)"])

	if flora == null:
		return

	for key in _fine_sheets.keys():
		if not keys.has(key):
			_fine_sheets[key]["sheet"].queue_free()
			_fine_sheets.erase(key)

	for p in packets:
		if typeof(p) != TYPE_ARRAY or p.size() != 7 or not keys.has(String(p[0])):
			continue

		var w: int = int(p[2])
		var h: int = int(p[3])
		var cell_m: float = float(p[4])
		var im: Image = FlowTexture.unpack(w, h, int(p[5]), p[6])

		if im == null:
			continue

		FlowTexture.tuck_dry_edges(im)

		var key: String = String(p[0])
		var origin: Vector2 = p[1]

		if not _fine_sheets.has(key):
			var sheet = LiquidSurface.new()
			sheet.name = "FineWater_" + key
			sheet.add_to_group("liquid_sheet")
			sheet.add_to_group("water_draw")
			flora.add_child(sheet)
			_fine_sheets[key] = {"sheet": sheet, "shown": 0}

		# The log line for the PC check: on the first picture of a sheet and every 20th after (about every 5 minutes).
		if int(_fine_sheets[key]["shown"]) % 20 == 0:
			var wet: int = 0

			for j in range(h):
				for i in range(w):
					wet += 1 if im.get_pixel(i, j).a >= 0.05 else 0

			FreezeWatchScript.printer.line("Terrain client: 2 m water sheet %s, %d x %d cells at %s, %d wet cells, %d fine sheets" % [key, w, h, str(origin.round()), wet, _fine_sheets.size()])

		_fine_sheets[key]["shown"] = int(_fine_sheets[key]["shown"]) + 1

		var corner: Vector2 = origin - Vector2(0.5, 0.5) * cell_m
		_fine_sheets[key]["rect"] = Vector4(corner.x, corner.y, float(w) * cell_m, float(h) * cell_m)
		_fine_sheets[key]["sheet"].show_fine(im, origin, cell_m)

	var holes: PackedVector4Array = PackedVector4Array()

	for key in _fine_sheets:
		if _fine_sheets[key].has("rect"):
			holes.append(_fine_sheets[key]["rect"])

	_fine_holes = holes
	flora.set_liquid_fine_holes(holes)

	if _liquid != null:
		_liquid.set_fine_holes(holes)


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


# Ctrl+Shift+R (admin): a rabbit on the ground where the crosshair points, up to 40 m away (testing animals).
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
	_water_dirty_all = true


func _on_water_changed_in(areas: Array) -> void:
	_water_dirty = true

	for area in areas:
		if typeof(area) == TYPE_RECT2 and (area as Rect2).has_area() and not _water_dirty_areas.has(area):
			_water_dirty_areas.append(area)   # each kept apart: two digs far apart do not make a box over the ground between (audit finding 7)


# Asks again for the water of the chunks held. While ground is still loading this waits up
# to WATER_HOLD_MSEC: each answer costs the server main-thread time and shares the line with
# the ground blocks, and the server says the water moved about twice a second.
func _send_water_request(now: int) -> void:
	if not _water_dirty or flora == null:
		return

	if stream.pending() > 0 and now - _water_asked_msec < WATER_HOLD_MSEC:
		return

	# At most one re-ask every WATER_MIN_MSEC: the server says the water moved about twice a second and answers every flora chunk
	# held each time, which in Dave's crash logs kept its main thread about 65 percent busy.
	if now - _water_asked_msec < _water_wait_msec:
		return

	_water_wait_msec = WaterReask.wait_after(_water_wait_msec, _water_new_since_ask, WATER_MIN_MSEC, WATER_MAX_MSEC)
	_water_quiet_asks = 0 if _water_new_since_ask > 0 else _water_quiet_asks + 1
	_water_new_since_ask = 0
	_water_dirty = false
	_water_asked_msec = now
	var chunks: PackedInt32Array = PackedInt32Array()
	var areas: Array = [] if _water_dirty_all else _water_dirty_areas
	_water_dirty_all = false
	_water_dirty_areas = []

	# Only the chunks the moving water touches (protocol 88, a list since 130); the rest still hold the right water.
	for chunk in WaterAreas.chunks_to_ask(flora.held_chunks(), areas, flora.chunk_m):
		chunks.append_array(PackedInt32Array([chunk.x, chunk.y]))

	if _water_quiet_asks <= 1 and not chunks.is_empty():   # "asking again for 0 chunks" (the moved water is outside every chunk held) says nothing
		@warning_ignore("integer_division")
		FreezeWatchScript.printer.line("Terrain client: the water moved, asking again for %d chunks (next in %.0f s or more)" % [chunks.size() / 2, _water_wait_msec / 1000.0])

	if not chunks.is_empty():
		net.request_water.rpc_id(1, chunks)


func _on_water_received(chunk: Vector2i, water: PackedByteArray) -> void:
	if flora == null:
		return

	# Steve's lag report (2 Nov 2026, 120-147 ms spikes): every "water moved" re-ask brought back ~9 chunks and each was unpacked and redrawn
	# though most had not changed. The same bytes as the chunk's last water are dropped here (the server skips them too since #128).
	var key: int = hash(water) ^ water.size()

	if int(_water_key.get(chunk, 0)) == key:
		return

	_water_key[chunk] = key
	_water_new_since_ask += 1
	_queue_in({"kind": "water", "chunk": chunk, "water": water})


func _on_flora_fruit(chunk: Vector2i, ids: PackedInt32Array, taken: PackedInt32Array) -> void:
	flora.set_fruit_taken(chunk, ids, taken)


# Protocol 160: forest-floor pickups taken by anyone (this player too), as the server keeps them: a dead branch is hidden, a tide-line
# node is used for that day, a nest shows empty until it refills (server_items.gd _tell_taken_near).
func _on_ground_taken(kind: int, points: PackedVector3Array, days: PackedInt32Array) -> void:
	if kind == 3 and points.is_empty():
		points = PackedVector3Array([Vector3.ZERO])   # the clear carries no points

	for i in points.size():
		var day: int = days[i] if i < days.size() else int(floor(game_clock.seconds / 86400.0))

		if kind == 3:
			if grass != null:
				grass.clear_taken()
			_shore_used.clear()
			if nest_view != null:
				nest_view.clear_robbed()
			return
		elif kind == 0 and grass != null:
			grass.take_branch(points[i], day)
		elif kind == 1:
			_shore_used[ShoreRules.cell_key(_shore_cfg, points[i])] = day
		elif kind == 2 and nest_view != null:
			nest_view.robbed(points[i], day)


func _on_flora_stripped(chunk: Vector2i, ids: PackedInt32Array) -> void:
	if flora == null:
		return

	var period: int = int(round(float(world["tiles_per_side"]) * float(world["tile_size_m"]) / flora.chunk_m))

	@warning_ignore("shadowed_variable")
	for held in _flora_asked:
		if posmod(held.x - chunk.x, period) == 0 and posmod(held.y - chunk.y, period) == 0:
			flora.set_stripped(held, ids)


func _on_flora_cut(chunk: Vector2i, id: int) -> void:
	if flora == null:
		return

	# The server names the chunk in its own (wrapped) coordinates; any copy
	# of it this client holds is the same chunk.
	var period: int = int(round(float(world["tiles_per_side"]) * float(world["tile_size_m"]) / flora.chunk_m))

	@warning_ignore("shadowed_variable")
	for held in _flora_asked:
		if posmod(held.x - chunk.x, period) == 0 and posmod(held.y - chunk.y, period) == 0:
			flora.remove_item(held, id, _anchor)

			if not _recent_cuts.has(held):
				_recent_cuts[held] = {}

			_recent_cuts[held][id] = Time.get_ticks_msec()

	_flora_cuts += 1
	FreezeWatchScript.printer.line("Terrain client: flora item %d in chunk %s was cut" % [id, str(chunk)])


var _bogs_rev: int = -1      # the inventory_view.bogs_rev last handed to the ground shader (set_bogs)


# Asks for flora chunks coming into view and forgets ones far behind. Far chunks
# are asked for with their trees only, near ones in full (owner, 2026-10-19).
func _update_flora() -> void:
	var p: Vector3 = _anchor
	var falls: Array = flora.fall_list()
	GroundMaterialScript.set_falls(terrain.material as ShaderMaterial, falls, p)

	if items != null and items.bogs_rev != _bogs_rev:   # the bog iron rust (only when a patch came, went or changed)
		_bogs_rev = items.bogs_rev
		GroundMaterialScript.set_bogs(terrain.material as ShaderMaterial, items.bogs, p)

	if fall_mist != null:
		fall_mist.update(falls, p)

	if fall_growth != null:
		fall_growth.update(falls, p)

	flora.set_season(_view_season if _view_season != "" else season_here())   # the season where the player stands (shortcut: the whole view, a few km, draws that one season; it differs only over the equator's row edge)
	grass.set_season(flora.season)   # the season the flora view shows (the game season, or the --flora-season preview)

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
	# 25 Oct (Dave: a start in the air never built the ground under it): the same dive runs for a player who is not flying but waiting for ground.
	var column: bool = flying or waiting_for_ground

	if follow and column and _anchor_set and not is_nan(_ground_below_y) and absf(_ground_below_xz.x - here.x) < 2.0 and absf(_ground_below_xz.y - here.z) < 2.0:
		pass
	elif follow and column and _anchor_set:
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
			FreezeWatchScript.printer.line("Terrain client: stopped flying at %s, loading the ground here" % str(here.round()))

		_anchor = here
		_anchor_set = true

		_viewer_ground_y = NAN

		if GroundColumn.dive(column, _ground_below_y, here.y):
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


func _viewer_y_text() -> String:
	return "?" if _viewer == null else "%.1f" % _viewer.global_position.y


# A collider under the player within 3000 m (the ground there has loaded).
func _collider_below(p: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + Vector3(0.0, -3000.0, 0.0))
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_surface_received(x: float, z: float, y: float) -> void:
	if ground_debug.surface_received(x, z, y):
		return

	_ground_below_xz = Vector2(x, z)
	_ground_below_y = y
	_surface_answered_msec = Time.get_ticks_msec()
	FreezeWatchScript.printer.line("Terrain client: ground under (%.0f, %.0f) is at %.1f m" % [x, z, y])

	if waiting_for_ground and connected_msec > 0:
		_join_log("JOIN: column answer %.1f s after the welcome: ground %.1f m, player %.1f m, viewer y %s" % [float(_surface_answered_msec - connected_msec) * 0.001, y, body.global_position.y, _viewer_y_text()])


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
	FreezeWatchScript.printer.line("Terrain client: ground detail levels %d" % terrain.lod_count)


# Cover.at at a point, for the campfire blueprint colour.
func _cover_here(point: Vector3) -> bool:
	return CoverScript.at(point, flora.cover) > 0.0


# [chunk, id] of the standing tree whose trunk is within 1.3 m (flat distance) of the point, else [].
func _tree_trunk_near(point: Vector3) -> Array:
	for chunk in flora._chunks:
		var held_items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(held_items["ids"].size()):
			var at: Vector3 = held_items["positions"][n]
			var dx: float = at.x - point.x
			var dz: float = at.z - point.z

			# The cheap flat-distance test first: only the few trees within 1.3 m pay for the species lookup (this runs over every loaded plant on each swing that lands).
			if dx * dx + dz * dz < 1.69 and flora._species.get(held_items["ids"][n] >> 16, {}).get("kind", 2) == 0:
				return [chunk, held_items["ids"][n]]

	return []



# The standing tree trunks within `radius` of `point` (flat), as the server's trunks_near lists them: [root, trunk radius m, height m], saplings left
# out (no collider). The placement ghost turns red over one (PlacementRules.over_trunk, round 4 of the physical world audit, 23 Nov 2026). Each
# chunk's trees are listed once (_trunk_index) and listed again when flora's trees change (canopy_version: a chunk in or out, a tree felled), so a
# look reads the trees only, not every plant of a 256 m chunk.
var _trunk_index: Dictionary = {}     # chunk -> [[root, trunk radius, height]]
var _trunk_index_version: int = -1


func _trunks_round(point: Vector3, radius: float) -> Array:
	if flora.canopy_version != _trunk_index_version:
		_trunk_index.clear()
		_trunk_index_version = flora.canopy_version

	var found: Array = []
	var chunk_m: float = float(flora.chunk_m)
	var reach: float = radius + TreeTrunks.widest_m()
	var lo: Vector2i = Vector2i(int(floor((point.x - reach) / chunk_m)), int(floor((point.z - reach) / chunk_m)))
	var hi: Vector2i = Vector2i(int(floor((point.x + reach) / chunk_m)), int(floor((point.z + reach) / chunk_m)))

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var chunk: Vector2i = Vector2i(cx, cz)

			if not flora._chunks.has(chunk):
				continue

			if not _trunk_index.has(chunk):
				_trunk_index[chunk] = _chunk_trunks(flora._chunks[chunk]["items"])

			for trunk in _trunk_index[chunk]:
				var at: Vector3 = trunk[0]

				if Vector2(at.x - point.x, at.z - point.z).length() <= radius + float(trunk[1]):
					found.append(trunk)

	return found


# A held flora chunk's standing trees with a trunk collider (flora_view's own radius: the species trunk by height, the drawn model's where listed).
func _chunk_trunks(held_items: Dictionary) -> Array:
	var list: Array = []

	for n in range(held_items["ids"].size()):
		var info: Dictionary = flora._species.get(held_items["ids"][n] >> 16, {})

		if int(info.get("kind", 2)) != 0:
			continue

		var height: float = float(held_items["heights"][n])
		var r: float = PlacerScript.collider_radius(0, float(info["trunk"]), height / float(info["height"]), height)

		if r > 0.0:
			list.append([held_items["positions"][n], TreeTrunks.standing_collider(str(info["name"]), held_items["ids"][n], height, r), height])

	return list


# The bush or shrub an axe or pickaxe swing reaches (Dave 2 Nov 2026): the one whose middle lies closest to the swing line from the eye to where
# it hit, within SHRUB_HIT_M; [chunk, id] or [].
const SHRUB_HIT_M := 0.9


func _shrub_near(from: Vector3, to: Vector3) -> Array:
	var best: Array = []
	var best_d: float = SHRUB_HIT_M

	for chunk in flora._chunks:
		var held_items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(held_items["ids"].size()):
			var root_at: Vector3 = held_items["positions"][n]
			var dx: float = root_at.x - to.x
			var dz: float = root_at.z - to.z

			if dx * dx + dz * dz > 16.0 or int(flora._species.get(held_items["ids"][n] >> 16, {}).get("kind", 2)) != 1:
				continue

			var height: float = float(held_items["heights"][n]) if held_items.has("heights") and n < held_items["heights"].size() else 1.0
			var middle: Vector3 = root_at + Vector3(0.0, clampf(height * 0.5, 0.2, 1.2), 0.0)
			var d: float = middle.distance_to(Geometry3D.get_closest_point_to_segment(middle, from, to))

			if d < best_d:
				best_d = d
				best = [chunk, held_items["ids"][n]]

	return best


# Headless check: cut the tree nearest the spawn.
func _cut_nearest_tree() -> void:
	var spawn: Vector3 = world["spawn"]
	var best: Array = []

	for chunk in flora._chunks:
		@warning_ignore("shadowed_variable")
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			if flora._species.get(items["ids"][n] >> 16, {}).get("kind", 2) != 0:
				continue

			var d: float = (items["positions"][n] - spawn).length()

			if best.is_empty() or d < best[0]:
				best = [d, chunk, items["ids"][n]]

	if best.is_empty():
		FreezeWatchScript.printer.line("Terrain client: no tree to cut")
		return

	FreezeWatchScript.printer.line("Terrain client: asking to cut tree %d in chunk %s, %.0f m from the spawn" % [best[2], str(best[1]), best[0]])
	net.cut_flora.rpc_id(1, best[1], best[2])


# The player body's collision margin. Godot's 1 mm default stopped a crouched player dead on flat forest ground (Dave 23 Nov 2026: "like I was
# against an invisible wall but if I stood up I could walk"): at the crouch pace (0.64 m/s, about 1 cm a physics step) move_and_slide on the
# terrain made no headway at about one walk in seven past trees near the town, touching only the floor; standing at that pace stuck as often,
# so it is the pace, not the crouched shape. The 1 cm margin cleared the crouch pace but not slower ones; _carry_slide covers those
# (the crouchwalk and crouchslow checks, tools/items_check.py).
const PLAYER_SAFE_MARGIN_M := 0.01
var _slide_carry: Vector3 = Vector3.ZERO   # see _carry_slide


func _make_player(root: Node3D, start: Vector3) -> void:
	body = CharacterBody3D.new()
	body.collision_mask = 3                # the ground (1) and ice sheets and floes (2)
	body.wall_min_slide_angle = 0.0        # always slide along a wall, never stop dead against it
	body.safe_margin = PLAYER_SAFE_MARGIN_M
	_movement = JSON.parse_string(FileAccess.get_file_as_string("res://data/movement.json")) if FileAccess.file_exists("res://data/movement.json") else {}
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	_shape = shape
	body.add_child(shape)
	root.add_child(body)
	rescue.setup(self)
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
	quake_view.setup(self, camera)
	drip_view.setup(self, self)
	view_cam.current = true
	Sound3D.ears(camera)   # heard from the eye, not from the drawn camera behind it in third person
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
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if shot_lock else Input.MOUSE_MODE_CAPTURED


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

	if fish_signs != null:
		fish_signs.set_quality(quality)

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

	if _wetland_mist != null:
		_wetland_mist.set_quality(quality)
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

	if items != null:
		items.set_rock_quality(quality)   # Low draws the rocky ground lighter (PR #1988)

	if terrain != null and quality != _ground_quality:
		_ground_quality = quality
		GroundMaterialScript.apply_quality(terrain.material as ShaderMaterial, quality)

	if _environment != null:
		LookSettings.apply(_environment, _sun, get_viewport(), quality)
		_apply_render_scale()
		_environment.fog_density = WeatherLookScript.UNDER_FOG_DENSITY if underwater else LookSettings.FOG_DENSITY


# Tells what the display setting really did, a moment later when the window had time to change:
# the window size the system gave us and the 3D size drawn. Inside the editor's Game tab the
# editor owns the window, so only the 3D size changes.
func _report_display(prefix: String = "") -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var win: Vector2i = get_window().size
	var render: Vector2i = Vector2i(Vector2(display.BASE) * _render_scale)
	var text: String = "%s3D picture %dx%d" % [prefix, render.x, render.y]

	@warning_ignore("static_called_on_instance")
	if display.embedded():
		text += " (window %dx%d). The game runs inside the editor, which owns the window: it cannot be resized or made fullscreen from here, only the 3D size changes. To change the real window size, resize the Game tab or turn embedding off (Project > Run without embedding)." % [win.x, win.y]
	elif display.fullscreen:
		text += " in a fullscreen windowed screen of %dx%d." % [win.x, win.y]
	elif display.fitted != Vector2i.ZERO and display.fitted != display.size() and win == display.fitted:
		text += ", window %dx%d: the chosen %s is larger than this screen, so the window was fitted to it." % [win.x, win.y, display.size_text()]
	elif win != (display.fitted if display.fitted != Vector2i.ZERO else display.size()):
		var asked: Vector2i = display.fitted if display.fitted != Vector2i.ZERO else display.size()
		text += ". The system kept the window at %dx%d (asked for %dx%d)." % [win.x, win.y, asked.x, asked.y]
	else:
		text += ", window %dx%d." % [win.x, win.y]

	_menu_note.text = text


# The idle timeout minutes were changed in the menu (idle_timeout.gd): 5 to 120, never below.
func set_idle_minutes(value: int) -> void:
	display.idle_minutes = IdleTimeoutScript.clamp_minutes(value)
	idle_timeout.set_minutes(display.idle_minutes)


# Saves the window, VSync and quality choices (display_settings.gd).
func _save_display() -> void:
	display.quality = quality
	display.save()


# The 3D picture is the chosen size (Low at most 720p, Ultra a third larger), always 16:9.
func _apply_render_scale() -> void:
	if DisplayServer.get_name() == "headless":
		return

	# Owner (2026-10-20): the 3D picture is always the chosen size, 16:9, whatever shape the
	# window or the editor's Game tab has (display_settings.gd): a share of the fixed 1920x1080
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


# The status strip left of the hotbar (Dave 23 Nov 2026, src/client/status_icons.gd): hunger and thirst always, and a symbol for every state
# that changes the player while it lasts. The words and the order are data/ui/status_strip.json; each read here only reports the state, from
# what the client already holds (no new server work). Every number in the words comes from the game's own data files.
func _setup_status_strip(layer: CanvasLayer) -> void:
	status_icons = StatusIconsScript.new()
	layer.add_child(status_icons)
	items.status_strip = status_icons
	status_icons.theme = items._tooltip_theme()   # the hover lines on the art kit's card, as the inventory's tooltips
	var spec: Dictionary = status_icons.spec
	var vitals: Dictionary = items._vitals_cfg
	var warmth_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))
	var warmth_cfg: Dictionary = warmth_parsed if typeof(warmth_parsed) == TYPE_DICTIONARY else {}
	var body_703: Dictionary = warmth_cfg.get("body_703", {}) if bool(warmth_cfg.get("body_703", {}).get("enabled", false)) else {}
	var limp_cfg: Dictionary = vitals.get("limp", {})
	var health_max: float = float(vitals.get("health_max", 100))
	var level_tone: Callable = func(id: String, value: float) -> int:   # the strip's own warn_at / danger_at for a number
		var row: Dictionary = spec.get(id, {})
		return 2 if value <= float(row.get("danger_at", -INF)) else (1 if value <= float(row.get("warn_at", -INF)) else 0)

	status_icons.add_icon("inspection", _load_brain_icon(), func() -> bool: return inspecting)

	for slot in range(int(items._food_ui.cfg.get("slots", 3))):
		status_icons.add("food_effect:%d" % slot, func() -> Dictionary:
			var rows: Array = items._food_ui.rows

			if slot >= rows.size():
				return {}

			return {"value": "%dm" % int(rows[slot][3]), "vars": {"text": items._food_ui.lines()[slot]}})

	status_icons.add("cart", func() -> Dictionary: return {} if items.pulling_id == 0 else {"vars": {"n": snappedf(items.pull_pace_mps, 0.1)}})
	status_icons.add("snow", func() -> Dictionary: return {} if _snow_pace_now >= 0.999 or flying else {"vars": {"n": int(round(_snow_pace_now * 100.0))}})
	status_icons.add("cover", func() -> Dictionary: return {"tone": 0} if under_cover > 0.0 else {})
	status_icons.add("soaked", func() -> Dictionary: return {} if items.soak_percent < 30 else {"value": "%d%%" % items.soak_percent, "tone": 1 if items.soak_wind else 0})
	status_icons.add("cold", func() -> Dictionary:
		var w: float = float(items.warmth)

		if warmth_cfg.is_empty() or w >= float(warmth_cfg.get("cold_at", 40.0)):
			return {}

		var stage: int = 2 if not body_703.is_empty() and w < float(body_703.get("severe_at", 8.0)) else (1 if w < float(warmth_cfg.get("hurt_at", 20.0)) else 0)
		return {"value": "%d%%" % items.warmth, "tone": stage})
	status_icons.add("sick", func() -> Dictionary: return {} if items.sick_hours <= 0 else {"value": "%dh" % items.sick_hours, "tone": 1, "vars": {"h": items.sick_hours}})
	status_icons.add("tired", func() -> Dictionary:
		var tone: int = level_tone.call("tired", float(items.energy))
		return {} if tone == 0 else {"value": "%d%%" % items.energy, "tone": tone, "vars": {"n": items.energy}})
	status_icons.add("strain", func() -> Dictionary:
		return {} if items.strain_state != 1 else {"tone": 1, "vars": {"n": int(round((1.0 - items.over_pace_factor()) * 100.0))}})
	status_icons.add("load", func() -> Dictionary:
		if items._carry_cfg.is_empty():
			return {}

		var kg: float = items.carried_kg()
		var body_kg: float = items.carry_body_kg()
		var free: float = CarryRulesScript.comfort_kg(body_kg, items._carry_cfg)

		if kg <= free:
			return {}

		var cap: float = CarryRulesScript.cap_kg(body_kg, items._carry_cfg)
		var pace: int = int(round(CarryRulesScript.speed_factor(kg, body_kg, items._carry_cfg) * 100.0))
		var share: int = int(round(kg / maxf(cap, 0.001) * 100.0))   # the load as a share of what you can carry, as the pack's bar shows it (Dave 24 Nov 2026: the speed read as the load)
		return {"value": "%d%%" % share, "tone": 2 if kg >= cap else 1, "vars": {"kg": snappedf(kg, 0.1), "free": int(round(free)), "cap": int(round(cap)), "n": pace, "p": share}})
	status_icons.add("limp", func() -> Dictionary:
		return {} if items.limp_share >= 1.0 else {"tone": 1, "vars": {"n": int(round(items.limp_share * 100.0)), "min": int(ceil(float(limp_cfg.get("seconds", 600.0)) / 60.0)),
			"heal": int(round(health_max * float(limp_cfg.get("heal_at", 0.6))))}})
	status_icons.add("oxygen", func() -> Dictionary:
		if items.breath_ds < 0:
			return {}

		var seconds: int = int(ceil(float(items.breath_ds) / 10.0))
		return {"value": str(seconds), "tone": level_tone.call("oxygen", float(seconds)), "vars": {"n": seconds}})
	status_icons.add("health", func() -> Dictionary:
		return {} if float(items.health) >= health_max else {"value": str(items.health), "tone": level_tone.call("health", float(items.health)), "vars": {"n": items.health, "max": int(health_max)}})
	# Food and water show only once they run low (Dave 24 Nov 2026: "food and water shouldn't show up until they are below 10%"): the row's show_below.
	var below: Callable = func(id: String) -> int: return int(spec.get(id, {}).get("show_below", 10))
	status_icons.add("hunger", func() -> Dictionary:
		return {} if items.hunger >= below.call("hunger") else {"value": "%d%%" % items.hunger, "tone": 2 if items.hunger <= 0 else 1, "vars": {"n": items.hunger}})
	status_icons.add("thirst", func() -> Dictionary:
		return {} if items.thirst >= below.call("thirst") else {"value": "%d%%" % items.thirst, "tone": 2 if items.thirst <= 0 else 1, "vars": {"n": items.thirst}})
	status_icons.tick(0.0, true)


# ------------------------------------------------------------------ options menu

# The Esc menu: the painted front (Continue, Settings, Exit), then the settings pages (game_menu.gd).
func _build_menu() -> void:
	game_menu.build(self)
	_menu = game_menu.root
	_menu_note = game_menu.note
	_quality_buttons = game_menu.quality_buttons


# --screenaudit: the HUD, the inventory, the character screen, every Journal page and every Esc menu page, at each text size, checked by
# screen_audit.gd. Prints "Screen audit: <screen> at <size>: N problems" with a line per problem, then "Screen audit: N problems on M screens".
const ScreenAudit := preload("res://src/client/screen_audit.gd")


func _run_screen_audit() -> void:
	await get_tree().create_timer(4.0).timeout
	var view: Rect2 = get_viewport().get_visible_rect()
	var total: int = 0
	var screens: int = 0
	var saved_text: int = display.text_index
	var test_layer: CanvasLayer = CanvasLayer.new()
	var test_holder: Control = Control.new()
	test_layer.add_child(test_holder)
	add_child(test_layer)
	ScreenAudit.self_test(test_holder)

	for n in range(3):
		await get_tree().process_frame

	var test_lines: PackedStringArray = ScreenAudit.audit(test_holder, view)
	var caught: int = ScreenAudit.self_test_count(test_lines)

	for line in test_lines:
		FreezeWatchScript.printer.line("Screen audit self test:   " + line)

	FreezeWatchScript.printer.line("Screen audit self test: %d of 5 kinds caught" % caught)
	test_layer.queue_free()
	await get_tree().process_frame

	for text_index in range(display.TEXT_SCALES.size()):
		items.set_text_scale(display.TEXT_SCALES[text_index])
		var scale_name: String = display.TEXT_NAMES[text_index]
		var shows: Array = [["HUD", func() -> void: pass, func() -> void: pass],
			["welcome card", func() -> void: _welcome().show_card(), func() -> void: _welcome().close()],
			["hint card, copper goal", func() -> void: _audit_hint_card().show_text(_audit_hint_line()), func() -> void: _audit_hint_card().ok()],
			["inventory", func() -> void: items.toggle(), func() -> void: items.toggle()],
			["character", func() -> void: items.toggle_character(), func() -> void: items.toggle_character()],
			["character, everything shown", func() -> void:
				_fill_character_worst()
				items.toggle_character(), func() -> void:
				items.toggle_character()
				_unfill_character_worst()]]

		for journal_page in [items.journal.INDEX, items.journal.GOALS, items.journal.SKILLS, items.journal.MAP]:
			shows.append(["journal " + journal_page, func() -> void: items.journal.show_page(journal_page), func() -> void: items.journal.close()])

		shows.append(["journal goals, longest how-to", func() -> void:   # the goal with the most words, so its wrapping is seen
			var longest: String = ""

			for row in items.goal_book.rows:
				if longest == "" or str(row["howto"]).length() > str(items.goal_book.row(longest)["howto"]).length():
					longest = str(row["id"])

			items.journal.selected = longest
			items.journal.show_page(items.journal.GOALS), func() -> void: items.journal.close()])

		shows.append(["journal skills, everything shown", func() -> void:   # every skill listed, each at a class top with every note
			_fill_character_worst()
			items.journal.skill_selected = "broadswords"
			items.journal.show_page(items.journal.SKILLS), func() -> void:
			items.journal.close()
			_unfill_character_worst()])

		for menu_page in game_menu._pages.keys():
			shows.append(["menu " + str(menu_page), func() -> void:
				_set_menu(true)
				_show_menu_page(str(menu_page)), func() -> void: _set_menu(false)])

		for show in shows:
			(show[1] as Callable).call()

			for n in range(4):
				await get_tree().process_frame

			var problems: PackedStringArray = ScreenAudit.audit(get_tree().root, view)
			FreezeWatchScript.printer.line("Screen audit: %s at %s: %d problems" % [show[0], scale_name, problems.size()])

			if test_screen_shots != "" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var picture: Image = get_viewport().get_texture().get_image()
				var file_name: String = ("%s_%s.png" % [show[0], scale_name]).replace(" ", "_").replace(",", "")
				DirAccess.make_dir_recursive_absolute(test_screen_shots)
				var saved: int = picture.save_png(test_screen_shots.path_join(file_name)) if picture != null else ERR_CANT_CREATE
				FreezeWatchScript.printer.line("Screen audit: picture %s %s (picture %s, window %s)" % [file_name, "saved" if saved == OK else "FAILED", str(picture.get_size()) if picture != null else "none", str(get_window().size)])

			for line in problems:
				FreezeWatchScript.printer.line("Screen audit:   " + line)

			total += problems.size()
			screens += 1
			(show[2] as Callable).call()

			for n in range(2):
				await get_tree().process_frame

	items.set_text_scale(display.TEXT_SCALES[saved_text])
	FreezeWatchScript.printer.line("Screen audit: %d problems on %d screens (canvas %dx%d)" % [total, screens, int(view.size.x), int(view.size.y)])
	frames_left = 1


# The character screen's widest rows (screen audit): every skill at a cap wall with its trainers, trained, rusty and practised today; three
# reputations; every worn place holding the longest-named bag (Take off and Open); two remains. Put back by _unfill_character_worst().
var _audit_saved: Array = []


func _fill_character_worst() -> void:
	_audit_saved = [items.skill_rows, items.rep_names, items.rep_points, items.worn, items.remains_marks]
	var skills: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
	var count: int = (skills.get("skills", {}) as Dictionary).size() if typeof(skills) == TYPE_DICTIONARY else 0
	var rows: Array = []

	for i in range(count):
		rows.append([i, 24, 1, 25, 7, 1, 24, 99, 100])   # index, level, rusty, cap, trained, practised today, working level, % to next, % of the day left

	items.skill_rows = rows
	items.rep_names = PackedStringArray(["Aldric the Miller", "Brother Osric of the Hill", "Gwendolyn Fairweather"])
	items.rep_points = PackedInt32Array([500, -500, 0])
	var bag: int = 0
	var longest: int = 0

	for id in items.table._by_id:
		var entry: Dictionary = items.table._by_id[id]

		if int(entry.get("bag_slots", 0)) > 0 and str(entry.get("name", "")).length() > longest:
			longest = str(entry.get("name", "")).length()
			bag = items.table.number_of(str(id))

	var worn: PackedInt32Array = PackedInt32Array()
	worn.resize(items.worn_places().size())
	worn.fill(bag)
	items.worn = worn
	items.remains_marks = [[Vector3(5000.0, 0.0, 5000.0), 600000, Time.get_ticks_msec()], [Vector3(-80.0, 0.0, 12.0), 3600, Time.get_ticks_msec()]]


func _unfill_character_worst() -> void:
	items.skill_rows = _audit_saved[0]
	items.rep_names = _audit_saved[1]
	items.rep_points = _audit_saved[2]
	items.worn = _audit_saved[3]
	items.remains_marks = _audit_saved[4]


func _show_menu_page(page_name: String) -> void:
	game_menu.show_page(page_name)


func _set_menu(open: bool) -> void:
	menu_open = open
	_menu.visible = open

	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game_menu.next_painting()         # the painted front shows the next page of the story each time (Dave 6 Nov 2026)
		_show_menu_page("main")
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if shot_lock else Input.MOUSE_MODE_CAPTURED


# "Clear saved ground": this client drops its own saved copy and reloads the
# terrain. The server's own saved ground is the server's business (its
# --clear-generated option); a client never clears it.
var _starter_seeded: int = 0
var _water_spam_per_s: float = 0.0
var _dig_spam_per_s: float = 0.0
var _tunnel_per_s: float = 0.0
var _act_test: bool = false
var _act_test_step: int = 0
var _act_test_next: int = 0
var _tunnel_spam_count: int = 0
var _dig_spam_next_msec: int = 0
var _step_lift: float = 0.0               # metres the eye still has to rise after a step-up (eased out)
var _step_hover_m: float = 0.0            # after a step-up: metres the body still moves held level onto the step (see _step_up)
var _movement: Dictionary = {}        # data/movement.json
var _telemetry = EventLogScript.new()       # crash_reports/telemetry_client.log: traffic, backlog and frame gaps once a second
var _join_refused: String = ""            # the server's reason when it refused this build (join_refused, protocol 133)
var _connect_window = null                # shown until the ground under the player is ready (connect_window.gd)
const JOIN_GIVE_UP_S := 600               # the join window turns into a failure (Back to servers, Quit) if the ground is still missing this long after the welcome
var _link_up_msec: int = 0                # when ENet reported the connection up (welcome still to come)
var _pit_shadow_msec: int = 0
var _in_pit: bool = false
var _lose_after_s: float = 0.0
var _link_print_msec: int = 0
var _horizon = null                   # artificial horizon (horizon_indicator.gd), shown underground or in water
var link_bars = null                      # server connection indicator (link_bars.gd)
var _server_closing: String = ""          # NetScript.SERVER_CLOSING once the server said it is stopping
var _lost_layer: CanvasLayer             # "Connection to the server was lost" window
var crash_report                      # CrashReport: breadcrumbs and the report of an unclean last run
var _previous_run_note_until_msec: int = 0
var _ground_line: String = ""
var _ground_line_msec: int = 0
# Esc > Controls: every hotkey on one screen (CONTROLS.md has the full rules; keep this in step with it).
const HELP_TEXT := """Move: W A S D   Run: Shift+W   Jump / fly up: Space   Fly down: Ctrl   Walk or fly (admin): Ctrl+Shift+G
Crouch C   Sit X   Lie down Z (hold Z 3 s to sleep)   Mouse wheel: third-person camera
K: photo camera (mouse swings round you, wheel zooms, PageUp / PageDown raise and lower it, W A S D walk relative to it, K again to leave)
Ctrl+Shift+L: admin spyglass (wheel zooms 2x to 40x; the animal at the centre dot shows its name, level and health; Ctrl+Shift+L or Esc to lower it)
Spyglass in hand: hold the right mouse button to look through it (3x), let go to lower it
E: gather, drink, fill, talk, open (hold E for the long action)   Left click: use held item   Right click: aim or eat
J: Journal   G: goals   O: skills   M: map   I: crafting and inventory   Hammer in hand: right click for blueprints (R too)   Tab: character screen   1 to 9, 0: hotbar   Split S, Drop D, Use E, Repair R, Transfer T (inventory)
/: inspection mode
Admin and debug shortcuts always need Ctrl+Shift together with the key (Esc > Settings > Controls changes the key, never the Ctrl+Shift):
Ctrl+Shift+F2: quality   F3: debug details   F4: all screen text on or off   F5: sound panel   F7 / F8: water debug   P: GPU probe table (press again to close)   J: jitter test
Ctrl+Shift+N: nearest NPC   R: rabbit   X: dig hole   ]: starter items   = and -: spring flow (tuning)   Esc > Advanced > Dump ground: crosshair ground report
Esc: this menu"""


# One line for screenshots: terrain version, tile stamp, starter ground, saved ground (size, hits, misses) and the guards' counts.
# One telemetry line (once a second): what is moving over the link and what is waiting, so a backlog or an overload shows before a drop.
func _telemetry_state() -> String:
	var voxel: Dictionary = VoxelEngine.get_stats()
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	@warning_ignore("integer_division")
	return "fps %d ram %d MB video %d MB, block requests waiting %d, chunks unpacking %d, voxel %s | %s | link %s" % [
		Engine.get_frames_per_second(), int(OS.get_static_memory_usage() / 1048576), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576),
		stream.pending() if stream != null else -1, _in_queue.size(), str(voxel.get("tasks", voxel)),
		EventLogScript.host_stats(multiplayer.multiplayer_peer), EventLogScript.peer_stats(enet.get_peer(1)) if enet != null else "no link"
	]


func _crash_state() -> String:
	var at: Vector3 = body.global_position if body != null else Vector3.ZERO
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var link_stats: String = EventLogScript.peer_stats(enet.get_peer(1)) if enet != null else "no link"
	@warning_ignore("integer_division")
	return "link " + link_stats + " pos %d,%d,%d quality %d fps %d ram %d MB video %d MB menu %s screen %s" % [at.x, at.y, at.z, quality, Engine.get_frames_per_second(), int(OS.get_static_memory_usage() / 1048576), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576), menu_open, items != null and items.screen_open()]


func _ground_health_line() -> String:
	var now: int = Time.get_ticks_msec()

	if now - _ground_line_msec > 5000 and cache != null and stream != null:
		_ground_line_msec = now
		_ground_line = "ground v%s  tiles %s  starter %s\nsaved %.0f MB  %d hit  %d miss  refused %d" % [str(world.get("terrain_version", "?")), str(world.get("tiles_stamp", "?")), ("seeded" if _starter_seeded > 0 else "none"), float(cache.size_bytes()) / 1048576.0, cache.hits, cache.misses, stream.zeroed_blocks + stream.bad_blocks + stream.timeouts]

	return _ground_line


func _ask_clear_cache() -> void:
	_reload_ground()
	_menu_note.text = "Done. The ground is reloading."
	FreezeWatchScript.printer.line("Terrain client: cleared the saved ground and reloaded the terrain")


# The server made its ground again from new tile files (a bake finished): drop the
# saved ground and the plants and load them again, and close the menu.
func _on_ground_reset(tiles_stamp: String, starter_stamp: String) -> void:
	world["tiles_stamp"] = tiles_stamp
	world["starter_stamp"] = starter_stamp
	_reload_ground()

	if sound != null:
		sound.trees.forget()

	if _cave_streams != null:
		_cave_streams.clear()   # the server sends each tile's list again with the first water asked there

	if _cave_dressing != null:
		_cave_dressing.clear()   # and its cave dressing with it

	if sound != null:
		sound.cavewater.clear()

	for tile in cave_dens.keys():
		cave_dens_changed.emit(tile, PackedVector3Array())

	cave_dens.clear()

	_in_generation += 1

	_drink_chunks.clear()
	_drink_cells.clear()

	if _spring_heads != null:
		_spring_heads.clear()

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
	FreezeWatchScript.printer.line("Terrain client: the tile files changed on the server; reloaded the ground and plants")


# The join hang (Dave, build 787): the ground never came and nothing was left to ask for. Start a new stream so everything is asked for again; the cache and
# the starter ground stay as they are. Six tries, then the window says so and names the logs.
func _run_ground_watchdog() -> void:
	if connected_msec <= 0 or stream == null or _ground_giving_up:
		return

	var now: int = Time.get_ticks_msec()
	var action: String = _ground_watchdog.step(now, waiting_for_ground, stream.pending(), _ground_received(), _ground_failed())

	# While the ground is missing, one line every 5 s (with the wall-clock time), so a hang is visible in the log before any retry.
	if waiting_for_ground and now - _ground_log_msec >= 5000:
		_ground_log_msec = now
		_join_log("JOIN: waiting for ground %d s after the welcome: loads %d, received %d (total %d), failed total %d, pending %d, test drops %d, retries %d (stall %d), ray down hits: %s, player y %.1f, viewer y %s" % [int(float(now - connected_msec) * 0.001), stream.loads, stream.blocks_received, _ground_received(), _ground_failed(), stream.pending(), stream.drops_made, _ground_watchdog.tries, _ground_watchdog.stall_tries, str(_ground_ray_hits()), body.global_position.y, _viewer_y_text()])

	if action == "":
		return

	var line: String = "JOIN: ground %s, try %d of %d: loads %d, received %d, timeouts %d, bad %d, zeroed %d, pending %d, player %s" % [action, _ground_watchdog.tries, _ground_watchdog.MAX_TRIES, stream.loads, _ground_received(), stream.timeouts, stream.bad_blocks, stream.zeroed_blocks, stream.pending(), str(body.global_position) if body != null else "?"]
	_join_log(line)

	if action == "retry":
		_restream_ground()
		return

	_ground_giving_up = true

	if _connect_window != null:
		_connect_window.fail("The ground did not arrive", "The server welcomed this game, but the ground under you did not load after %d tries.\n\nPlease quit, press Play again, and send these files from the game's user folder: telemetry_client.log and ground_mismatch.log." % _ground_watchdog.tries, func(): _finish(1))


# One join line to the telemetry log and to the console, with the wall-clock time and the seconds since the welcome (the logs had neither).
func _join_log(text: String) -> void:
	var line: String = "%s [+%.1f s] %s" % [Time.get_datetime_string_from_system(), float(Time.get_ticks_msec() - connected_msec) * 0.001, text]
	_telemetry.event(line)
	FreezeWatchScript.printer.line("Terrain client: " + line)   # off the main thread (D-LAG-1); the lanes read these lines from the log afterwards


# Diagnostics for the join line: does a ray straight down from the player find any collision (the thing "waiting for ground" waits for)?
func _ground_ray_hits() -> bool:
	if body == null:
		return false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(body.global_position + Vector3(0.0, 1.0, 0.0), body.global_position + Vector3(0.0, -300.0, 0.0))
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# Blocks received and failed since the welcome, over every stream the watchdog has started (a restart resets the new stream's own counters).
var _ground_received_prior: int = 0
var _ground_failed_prior: int = 0


func _ground_received() -> int:
	return _ground_received_prior + (stream.blocks_received if stream != null else 0)


func _ground_failed() -> int:
	return _ground_failed_prior + (stream.failed_total() if stream != null else 0)


func _restream_ground() -> void:
	_ground_received_prior = _ground_received()
	_ground_failed_prior = _ground_failed()
	stream.close()
	stream = StreamScript.new()
	stream.cache = cache
	stream.link = link
	link.stream = stream
	terrain.stream = stream


func _reload_ground() -> void:
	_ground_received_prior = 0
	_ground_failed_prior = 0
	cache.clear_all()
	stream.close()
	stream = StreamScript.new()
	stream.cache = cache
	stream.link = link
	link.stream = stream
	terrain.stream = stream
	cache.seed_starter("res://worlds/base_world/starter_cache", str(world.get("starter_stamp", "")))
	cache.set_revisions({})   # the starter ground just copied in is caught up like any older saved tile
	_ask_catch_up()


# Inspection mode (the / key): names whatever the crosshair points at. Checked
# ten times a second with one physics ray, so it costs next to nothing.
func _update_inspect() -> void:
	_set_inspect_text_from(_inspect_target())

	if test_inspect and _inspect_label.text != _last_inspected:
		_last_inspected = _inspect_label.text
		FreezeWatchScript.printer.line("Terrain client: inspect -> '%s'" % _last_inspected)


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
	# Water has no collision: name it when the look crosses its surface before anything solid (Dave's QA list BUG-015, 3 Nov 2026: shallow
	# water among reeds named nothing). A reed standing above the water is hit first and keeps its own name.
	var water_m: float = _water_on_look(origin, direction, 30.0 if hit.is_empty() else origin.distance_to(hit["position"]))

	if water_m >= 0.0:
		return "Water"   # the drink prompt says what E does (the look label said it too, so two drink lines showed at once: Dave 24 Nov 2026)

	if hit.is_empty():
		return ""

	var collider: Object = hit["collider"]
	var species: int = -1

	# A boulder (TEST-013, Dave 12 Nov 2026): it is drawn apart from the world items, so the look fell through to the ground under it and read
	# "Forest humus". It is rock to break with a pick.
	if collider != null and collider.has_meta("boulder"):
		return "Rock"

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
		var product: String = harvest.product_name_at(point) if harvest != null else ""

		if product != "":
			return product

		return knowledge.reveal("f%d" % species, flora.label_of(species), flora.familiarity_of(species), "horticulture", flora.lookalikes(species))

	var lying: String = items.world_item_name_near(point, 1.2)

	if lying != "":
		return lying

	return _ground_name(point - hit["normal"] * 0.4)


# How far along a look the water surface is first crossed going down into it, -1 when it is not (steps of half a metre).
func _water_on_look(origin: Vector3, direction: Vector3, length: float) -> float:
	if flora == null:
		return -1.0

	var step: float = 0.5
	var d: float = step

	while d <= length + 0.001:
		var p: Vector3 = origin + direction * minf(d, length)
		var surface: float = flora.water_surface_at(p.x, p.z)

		if not is_nan(surface) and p.y <= surface and origin.y > surface and WaterVolume.depth(surface, _ground_below(p)) >= WaterVolume.DRINK_DEPTH_M:
			return d

		d += step

	return -1.0


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
		return _known_from_table("soils", "s", Layout.soil_of(material))

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
		@warning_ignore("shadowed_variable_base_class")
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
	var te_sky: int = Probe.start()
	environment.sky = SkyClouds.make_sky(quality)
	Probe.stop("environment: sky", te_sky)
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
	var te_sea: int = Probe.start()
	sea = MeshInstance3D.new()
	sea.mesh = OceanMesh.take()   # its arrays were made on a worker since _ready (OceanMesh.start); 12 km, 1 m vertices at the centre: the swell lifts it near the camera (M5)
	Probe.stop("environment: sea mesh", te_sea)
	var te_water: int = Probe.start()
	sea.material_override = WaterMaterial.make_sea()   # the rivers' shader with the sea look on (swell, depth colours, surf)
	root.add_child(sea)
	Probe.stop("environment: sea material", te_water)



# The sea plane follows the body; its swell is drawn relative to a phase origin near the body, so the waves stay exact 54 km from the
# world's corner (M5, docs/water/ocean_m5.md). The origin moves in 1024 m steps. Every frame the sea clock is folded into the phases in
# 64-bit floats (ocean_waves.gd), so the shader's swell and _sea_height_at() are the same water at the same moment.
func _follow_sea() -> void:
	sea.global_position = Vector3(body.global_position.x, 0.0, body.global_position.z)
	_mask_sea_under_land()
	var origin: Vector2 = OceanWaves.origin_for(Vector2(body.global_position.x, body.global_position.z))
	OceanWaves.apply(sea.material_override as ShaderMaterial, origin, _sea_clock())


# Under the island, not the sea (Dave 20 Nov 2026: a tunnel dug below sea level hit water): the baked ground round p is above sea level
# (fog_ground.gd under_land, a lookup in the window the server already sends). False until that window has come: the old rule.
func _under_land(p: Vector3) -> bool:
	return weather_look != null and weather_look.fog_ground.under_land(p.x, p.z)


# The sea plane is not drawn under the island, so a tunnel below 0 m (or a fen flat below 0 m cut off from the sea) shows no sheet of sea across it: the window's ground ("sea_low", the
# lowest within 64 m) goes to the sea shader as a small texture (water_material.gd land_low), made again only when a new window comes.
var _sea_land_grid: Dictionary = {}


func _mask_sea_under_land() -> void:
	if weather_look == null or is_same(weather_look.fog_ground.grid, _sea_land_grid):
		return

	_sea_land_grid = weather_look.fog_ground.grid
	var material: ShaderMaterial = sea.material_override as ShaderMaterial

	if _sea_land_grid.is_empty():
		material.set_shader_parameter("land_on", 0.0)
		return

	var n: int = int(_sea_land_grid["n"])
	var low: PackedFloat32Array = _sea_land_grid["sea_low"]
	material.set_shader_parameter("land_low", ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, low.to_byte_array())))
	material.set_shader_parameter("land_origin", _sea_land_grid["origin"])
	material.set_shader_parameter("land_size_m", float(n) * FogGroundScript.CELL_M)
	material.set_shader_parameter("land_above_m", FogGroundScript.LAND_ABOVE_M)
	material.set_shader_parameter("land_on", 1.0)


# The sea clock (s): this client's own (M5 second step; a shared server clock comes with the boats, M7).
func _sea_clock() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


# The sea surface at p: the swell's height, the same the shader lifts the plane by near the camera.
func _sea_height_at(p: Vector3) -> float:
	return OceanWaves.height(Vector2(p.x, p.z), _sea_clock())


# Third-person view (Dave, 2026-10-21): scroll out from first person to look at yourself from up and back
# of the shoulders; scrolling out more pulls the camera further away, scrolling in comes back and, past
# the nearest distance, returns to first person. The distance is remembered between sessions.
const VIEW_FILE := "user://view.txt"
const VIEW_MIN_M := 1.6
const VIEW_MAX_M := 7.0
const VIEW_STEP_M := 0.4
const VIEW_HEIGHT := 0.12              # camera rise per metre of distance
const VIEW_CLEAR_M := 0.25             # how far short of a wall or trunk the camera stops
const VIEW_BALL_M := 0.3               # the camera is a ball this wide, not a point: a thin ray slips through the rock at a shallow angle or a ragged cave wall and the camera ends up inside the hill (Dave 7 Nov 2026: spring cave drawn from inside the rock, no ground)

var view_cam: Camera3D
var _view_ball: SphereShape3D          # the camera's ball for the wall sweep (VIEW_BALL_M)
const PhotoCameraScript := preload("res://src/client/photo_camera.gd")
var photo = PhotoCameraScript.new()                      # K: the photo camera (src/client/photo_camera.gd), a free orbiting view of the character
const SpyglassScript := preload("res://src/client/spyglass.gd")
var spyglass = SpyglassScript.new()                      # Ctrl+Shift+L: the admin spyglass (src/client/spyglass.gd), zoom and the watched animal's readout
var _spyglass_overlay = null
var _spyglass_sent_ms: int = 0
var third_person: bool = false:
	set(value):
		third_person = value

		if grass != null:
			grass.third_person = value
var debug_clip: String = ""                              # shot runner only (--shot-clip=NAME): play this clip whatever the body does
var debug_pace: float = -1.0                              # shot runner only: pretend to move at this speed (m/s) so the walk animation plays
var shot_stance: int = -1                                # shot runner only (--shot-stance): draw the third-person body in this stance (0 stand, 1 crouch, 2 sit, 3 lie) even while the runner flies
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


# How far along from -> to the drawn camera may go: stops short of the first rock, trunk or wall by VIEW_CLEAR_M. A ray alone misses walls it meets at a shallow
# angle, so a ball of VIEW_BALL_M is swept along the same line too, and the nearer of the two wins (7 Nov 2026: the camera slipped through a cave wall).
func _clear_view_m(from: Vector3, to: Vector3) -> float:
	var full: float = from.distance_to(to)

	if full < 0.001:
		return 0.0

	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var reach: float = full
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)

	if not hit.is_empty():
		reach = from.distance_to(hit["position"])

	if _view_ball == null:
		_view_ball = SphereShape3D.new()
		_view_ball.radius = VIEW_BALL_M

	var sweep: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sweep.shape = _view_ball
	sweep.transform = Transform3D(Basis.IDENTITY, from)
	sweep.motion = to - from
	sweep.exclude = [body.get_rid()]
	var span: PackedFloat32Array = space.cast_motion(sweep)

	# A ball that already touches rock at the start (standing against a wall) says 0: the ray alone decides then, or the view would flip to first person.
	if span.size() >= 2 and span[0] > 0.0 and span[0] < 1.0:
		reach = minf(reach, full * span[0])

	return maxf(reach - VIEW_CLEAR_M, 0.0)


# The colour of the second log on the shoulders (the pack's second large log), null when only one or none is carried.
func _second_log_color() -> Variant:
	if items == null or items.shoulder_id == "":
		return null   # nothing on the shoulders: no pack scan

	var logs: Array = items.shoulder_logs()

	if logs.size() < 2:
		return null

	return LogLookScript.color_of(str(logs[1]))


# Each drawn frame: place the drawn camera, keep it out of walls and trunks, and show the ragdoll body.
# The log on the shoulder: a full 3 m log (drops.json log_length_m; the species' real length is not sent; Radar's item data has the weight).
const CARRY_LOG_LENGTH_M := 3.0
const CARRY_LOG_RADIUS_M := 0.14
const FOV_BASE := 75.0                 # Godot's default, which the game has always used
const FOV_RUN_EXTRA := 5.0             # degrees wider at a full run
var _fov_extra: float = 0.0


func _update_view(delta: float) -> void:
	if view_cam == null or body == null:
		return

	# The drawn bow's sway turns the whole view, the aim with it (Dave 10 Nov 2026: "the whole screen should move like that but much less"):
	# the eye camera goes back to the mouse's look each frame, then held_item turns it; the bow's cross stays in the middle.
	if not photo.active and (not shot_lock or shot_sway):
		camera.rotation.x = pitch
		camera.rotation.y = 0.0
		var turn: Vector2 = held.bow_view_turn() if held != null else Vector2.ZERO
		camera.rotation.y = -deg_to_rad(turn.x)
		camera.rotation.x = pitch + deg_to_rad(turn.y)

	if _avatar == null:
		# Dave's PC log 4 Nov 2026: the first call waited for the body file still loading on a loader thread ("update view" 404 ms at the join).
		# The body is made once the file is in; until then (a second or two, while the ground loads) there is no third-person body to draw.
		if ResourceLoader.load_threaded_get_status(DynastyBodyScript.GLB) == ResourceLoader.THREAD_LOAD_IN_PROGRESS or ResourceLoader.load_threaded_get_status(_avatar_glb) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return

		_avatar = _make_avatar()
		body.add_child(_avatar)
		net.worn_received.connect(func(_numbers: PackedInt32Array, _insts: PackedByteArray) -> void: _dress_avatar())
		_dress_avatar()

	var want: float = _view_m if third_person and not spyglass.active else 0.0
	var eye: Vector3 = camera.global_position
	var aim: Vector3 = camera.global_transform.basis * Vector3(0.0, VIEW_HEIGHT, 1.0)

	if third_person and want > 0.0:
		want = _clear_view_m(eye, eye + aim * want)

	# Pull in at once when blocked, ease out otherwise.
	_view_now = want if want < _view_now else lerpf(_view_now, want, clampf(delta * 10.0, 0.0, 1.0))

	if absf(_view_now - want) < 0.01:
		_view_now = want

	if photo.active:
		_place_photo_camera(delta)
		_view_now = 3.0   # the whole body is drawn, the first-person arms are hidden
	else:
		view_cam.top_level = false
		view_cam.rotation = Vector3.ZERO   # the drawn camera only ever sits on the eye, looking the way the eye looks
		view_cam.position = Vector3(0.0, VIEW_HEIGHT, 1.0) * _view_now

		# Speed feel: the view widens a little toward a run, and eases back when you stop (the usual first-person trick; the field of view was never touched before).
		var pace: float = Vector2(body.velocity.x, body.velocity.z).length()
		var want_extra: float = clampf((pace - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0) * FOV_RUN_EXTRA if body.is_on_floor() and not swimming else 0.0
		_fov_extra = lerpf(_fov_extra, want_extra, clampf(delta * 4.0, 0.0, 1.0))
		view_cam.fov = spyglass.fov(FOV_BASE) if spyglass.active else (FOV_BASE + _fov_extra * feel.intensity) * (held.aim_fov_share() if held != null else 1.0)   # the drawn bow narrows the view a little

	_avatar.visible = _view_now > 0.5

	if held != null:
		held.set_avatar(_avatar)
		held.set_first_person(_view_now <= 0.5)
		held.carrying_log = items != null and items.shoulder_id != ""
		held.set_shoulder(items != null and items.shoulder_id != "" and _view_now <= 0.5, CARRY_LOG_LENGTH_M, CARRY_LOG_RADIUS_M, LogLookScript.color_of(items.shoulder_id if items != null else ""), _second_log_color())
	if _avatar.animation_player != null:
		_avatar.animation_player.active = _avatar.visible      # no animation cost in first person
	# Feet on the ground whatever the stance (the capsule's bottom stays put; the body origin is its standing middle).
	_avatar.position.y = -float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5

	if not _seat.is_empty() and stance.stance == StanceScript.SIT:
		_avatar.position.y += _seat_lift()   # hips on the seat whatever the clip's own hips height (Dave 7 Nov 2026: the body sank through the chair)

	if _avatar.visible:
		var pace: float = Vector2(body.velocity.x, body.velocity.z).length() if debug_pace < 0.0 else debug_pace
		# Clip, playback speed and slope tilt come from src/client/character/avatar_driver.gd (moved there unchanged).
		var carrying: bool = items != null and items.shoulder_id != "" and stance.stance == StanceScript.STAND
		_avatar.set_meta("lie_rest", lying_at_rest())   # lying: the sleep pose at rest, the crawl otherwise (avatar_driver.gd crawl_clip; a --shot-stance=lie picture shows the crawl's still pose)
		var clip: String = AvatarDriver.clip_for(_avatar, stance.stance if shot_stance < 0 else shot_stance, body.velocity, body.global_transform.basis, body.is_on_floor(), pace, _avatar.current(), carrying, delta)

		if not _seat.is_empty() and stance.stance == StanceScript.SIT and _avatar.animation_player != null and _avatar.animation_player.has_animation("sit_chair"):
			clip = "sit_chair"   # on a seat, not the ground

		if debug_clip != "":
			clip = debug_clip

		# Tool work (31 Oct 2026): swinging an axe plays the wide chop, a pick axe the overhead arc (the generated body only: the old body has no such clip). The clip restarts at every
		# swing and its impact frame is the moment held_item.gd sends the blow.
		var hook: String = AvatarDriver.hook_clip(_avatar, {"swimming": swimming, "asleep": items != null and items.asleep, "stance": stance.stance if shot_stance < 0 else shot_stance, "drink_stamp": items._drink_msec if items != null else 0}, pace, delta)

		if hook != "" and debug_clip == "":
			clip = hook

		var work: String = held.work_clip() if held != null else ""

		if work != "" and _avatar.animation_player != null and _avatar.animation_player.has_animation(work):
			clip = work

			if held.swing_serial != _work_serial:
				_work_serial = held.swing_serial
				_avatar.animation_player.play(work, 0.05)
				_avatar.animation_player.seek(0.0, true)

		_avatar.set_meta("torch_in_hand", held != null and held.holding_torch())
		_avatar.set_meta("torch_left", held != null and held.torch_in_left())
		_avatar.set_shoulder_log(CARRY_LOG_LENGTH_M if carrying else 0.0, CARRY_LOG_RADIUS_M, LogLookScript.color_of(items.shoulder_id if items != null else ""), _second_log_color())

		if _avatar.current() != clip and not _avatar.is_one_shot_playing():
			_avatar.play(clip, 1.0, 0.25)

		if _avatar.animation_player != null:
			_avatar.animation_player.speed_scale = AvatarDriver.speed_scale(clip, pace) * AvatarDriver.backward_sign(_avatar, clip)   # walking backwards plays the gait in reverse

			if work != "" and clip == work and _avatar.animation_player.has_animation(work):
				# The blow's impact frame is the sound and the hit (held_item.gd _strike): the clip runs the swing's length, whatever the tool or its speed.
				_avatar.animation_player.speed_scale = _avatar.animation_player.get_animation(work).length / maxf(held.work_seconds(), 0.05)

		var tilt: float = AvatarDriver.slope_tilt(body.is_on_floor(), body.global_transform.basis.inverse() * body.get_floor_normal(), pace, clip)

		_avatar.rotation.x = lerpf(_avatar.rotation.x, -tilt, minf(1.0, 6.0 * get_process_delta_time()))


var _photo_saved: Dictionary = {}


# Ctrl+Shift+L: the admin spyglass up or down (docs/design/spyglass_design.md). Not from the photo camera. The server is told (ACT_SPYGLASS) so it
# sends animals out to 300 m and the watched one's readout; a player who is not an admin is refused and the glass comes down.
# Ctrl+Shift+L or Esc while looking through a held spyglass item lowers that instead.
func _toggle_spyglass() -> void:
	if spyglass.active and spyglass.tier > 0:
		_spyglass_item(false, -1, spyglass.tier)
		return

	if (photo.active or _animal_view_node == null) and not spyglass.active:
		return

	_spyglass_ready()
	var on: bool = spyglass.toggle()
	_spyglass_shown(on)
	net.inventory_action.rpc_id(1, NetScript.ACT_SPYGLASS, 1 if on else 0, 0, 0, Vector3.ZERO)


# The held spyglass item (held_item.spyglass_look, data/items/spyglass.json): right mouse down looks through it, up lowers it. `slot` is its
# pack slot, `item_tier` its tier. The server checks the item, takes one use and sends animals out to the tier's radius (ACT_SPYGLASS a = 2).
func _spyglass_item(on: bool, slot: int, item_tier: int) -> void:
	if on == spyglass.active or (not on and spyglass.tier == 0):
		return   # already so, or the admin glass is up: Ctrl+Shift+L owns that one

	var cfg: Dictionary = SpyglassScript.tier_config(item_tier)

	if on and (photo.active or _animal_view_node == null or cfg.is_empty()):
		return

	_spyglass_ready()
	spyglass.look_item(on, item_tier, cfg)
	_spyglass_shown(on)
	net.inventory_action.rpc_id(1, NetScript.ACT_SPYGLASS, 2 if on else 0, 0, slot, Vector3.ZERO)


func _spyglass_ready() -> void:
	if _spyglass_overlay == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_spyglass_overlay = SpyglassScript.Overlay.new()
		layer.add_child(_spyglass_overlay)
		net.animal_info_received.connect(_on_animal_info)


# The glass up or down: the vignette, more animals drawn, and a tier's fixed focus (closer than blur_near_m is soft).
func _spyglass_shown(on: bool) -> void:
	_spyglass_overlay.visible = on
	_spyglass_overlay.text = ""
	_animal_view_node.set("max_drawn", AnimalViewScript.SPYGLASS_DRAWN if on else AnimalViewScript.MAX_DRAWN)
	_spyglass_sent_ms = Time.get_ticks_msec()
	var near_m: float = float(spyglass.tier_cfg.get("blur_near_m", 0.0))

	if on and near_m > 0.0:
		var focus: CameraAttributesPractical = CameraAttributesPractical.new()
		focus.dof_blur_near_enabled = true
		focus.dof_blur_near_distance = near_m
		focus.dof_blur_near_transition = float(spyglass.tier_cfg.get("blur_near_transition_m", 8.0))
		focus.dof_blur_amount = float(spyglass.tier_cfg.get("blur_amount", 0.08))
		view_cam.attributes = focus
	else:
		view_cam.attributes = null


# The server's readout for the watched animal; id -1: refused (not an admin, or no spyglass in hand), the glass comes down.
func _on_animal_info(id: int, info: Dictionary) -> void:
	if id == -1 and spyglass.active:
		_toggle_spyglass()
	elif spyglass.active and id == spyglass.watched:
		spyglass.info = info


# Each frame while the spyglass is up: watch the animal nearest the centre (the server is told when it changes) and draw its readout.
func _update_spyglass() -> void:
	if not spyglass.active or _spyglass_overlay == null:
		return

	if not spyglass.has_readout():
		if _spyglass_overlay.text != "%.0fx" % spyglass.zoom:
			_spyglass_overlay.text = "%.0fx" % spyglass.zoom
			_spyglass_overlay.queue_redraw()

		return   # a tier without a readout watches nothing: the server needs no word while it is up

	var eye: Vector3 = view_cam.global_position
	var forward: Vector3 = -view_cam.global_transform.basis.z
	var drawn: Array = _animal_view_node.call("drawn_positions")
	var id: int = spyglass.pick(eye, forward, drawn)
	var now: int = Time.get_ticks_msec()

	if id != spyglass.watched or now - _spyglass_sent_ms > 3000:   # on a change, and every 3 s in case one was lost
		if id != spyglass.watched:
			spyglass.info = {}

		spyglass.watched = id
		_spyglass_sent_ms = now
		net.inventory_action.rpc_id(1, NetScript.ACT_SPYGLASS, 1, id, 0, Vector3.ZERO)

	var distance_m: float = 0.0

	for row in drawn:
		if int(row[0]) == id:
			distance_m = eye.distance_to(row[1])

	var text: String = "%.0fx" % spyglass.zoom
	var lines: String = SpyglassScript.readout(spyglass.info, distance_m) if id != 0 else ""

	if lines != "":
		text = lines + "\n" + text

	if text != _spyglass_overlay.text:
		_spyglass_overlay.text = text
		_spyglass_overlay.queue_redraw()


# K: into the photo view (the normal view is remembered) or back out (all of it restored: heading, pitch, roll, drawn camera and field of view).
func _toggle_photo() -> void:
	if spyglass.active:
		return   # lower the spyglass first (Ctrl+Shift+L or Esc)

	if not photo.active:
		_photo_saved = PhotoCameraScript.snapshot(body, camera, view_cam, pitch)
		photo.toggle(body.rotation.y)
		return

	photo.toggle(body.rotation.y)

	if not _photo_saved.is_empty():
		PhotoCameraScript.restore(_photo_saved, body, camera, view_cam)
		pitch = float(_photo_saved["pitch"])

		if _horizon != null:
			_horizon.pitch_rad = pitch


# The photo camera (K): drawn from where photo_camera.gd puts it, kept out of the ground and walls. Only the drawn camera moves.
func _place_photo_camera(delta: float) -> void:
	photo.raise(float(KeyBindings.held("photo_up")) - float(KeyBindings.held("photo_down")), delta)
	photo.step(delta)
	var focus: Vector3 = photo.focus_point(body.global_position)
	var want: Vector3 = photo.camera_position(focus)
	var reach: float = _clear_view_m(focus, want)
	want = focus.move_toward(want, reach)
	want = photo.clamp_to_ground(want, _ground_below(want))
	view_cam.top_level = true
	view_cam.global_transform = Transform3D(photo.camera_basis(want, focus), want)


# The plain ragdoll character (owner, 2026-10-21): body, head, arms, legs and hands, no features.
# Stage-one clothing on the body (art/MODEL_PLAN.md): the worn body, legs and feet items colour the coat, trousers and shoes of the ragdoll
# with their basic-look colour (data/items/looks.json); head, hands and back items have no look on the body yet.
func _dress_avatar() -> void:
	AvatarDriver.dress(_avatar, items)


func _make_avatar() -> Node3D:
	# Dave's own body (1 Nov 2026) is the only player body; the generated body of src/client/character/ stands in when his glb is not imported.
	var avatar: Node3D = MyCharacter.make_avatar()     # Dave's body, or the previous one when his glb is not imported (my_character.gd)
	avatar.visible = false
	return avatar


# Crash report breadcrumbs: the window losing or getting back focus, and the game being hidden (a throttled window can stop answering the server).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_telemetry.event("EXIT: the window was asked to close (X button, Alt+F4 or the editor's Stop)")
		quitting = true
		_say_logout()

	if crash_report == null:
		return

	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			crash_report.event("window focus lost")
		NOTIFICATION_APPLICATION_FOCUS_IN:
			crash_report.event("window focus back")
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			crash_report.event("game window focus lost")
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			crash_report.event("game window focus back")


# Breadcrumbs for crash reports: every key and mouse button press, before any menu or window can swallow it.
func _input(event: InputEvent) -> void:
	if crash_report == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Keys typed into a text box (a server or chest password, a chat line) are never written down: crash reports are shared.
		var focus: Control = get_viewport().gui_get_focus_owner()
		crash_report.event("key (typing in a text box)" if focus is LineEdit or focus is TextEdit else "key %s" % OS.get_keycode_string(event.keycode))
	elif event is InputEventMouseButton and event.pressed:
		crash_report.event("mouse button %d at %d,%d" % [event.button_index, int(event.position.x), int(event.position.y)])


func _unhandled_input(event: InputEvent) -> void:
	if body == null:
		return

	if welcome_card != null and event is InputEventKey and welcome_card.take_key(event):
		return   # Enter or Esc closes the welcome card first (Esc does not open the menu under it)

	if hint_card != null and event is InputEventKey and hint_card.take_key(event):
		return   # Enter is the hint card's OK

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if spyglass.active:
			_toggle_spyglass()   # Esc lowers the spyglass first
			return

		if items != null and items.search_escape():
			return

		if items != null and items.screen_open():
			items.close()
			return

		_set_menu(not menu_open)
		return

	if menu_open:
		return

	# The hammer or knife build screen takes the keys and clicks while it is open (its search box, rows and tabs; right click and Esc shut it).
	if held != null and held.blueprints.is_open:
		if event is InputEventKey and event.pressed and not event.echo and KeyBindings.matches(event, "blueprints"):
			held.toggle_blueprints()   # R shuts it too while the search box does not have the key

		return

	if event is InputEventKey and event.pressed and not event.echo and KeyBindings.matches(event, "inventory") and items != null:
		items.toggle()
		return

	if event is InputEventKey and event.pressed and not event.echo and KeyBindings.matches(event, "character") and items != null:
		items.toggle_character()
		return

	# The Journal (docs/design/PLAYER_JOURNAL_GOALS_UI.md): J the index, G goals, O skills, M map, from the world or inside the Journal. With the inventory up
	# these keys stay the inventory's (plain G is Store all there); I and Tab above swap the Journal for their own screen.
	if event is InputEventKey and event.pressed and not event.echo and items != null and items.journal != null and (items.journal.open or not items.screen_open()):
		if KeyBindings.matches(event, "journal"):
			items.journal.press_journal()
			return

		if KeyBindings.matches(event, "goals"):
			items.journal.show_page("goals")
			return

		if KeyBindings.matches(event, "skills"):
			items.journal.show_page("skills")
			return

		if KeyBindings.matches(event, "map"):
			items.journal.show_page("map")
			return

	if items != null and items.journal != null and items.journal.open:
		return   # the Journal takes no other key (Esc is handled above)

	if items != null and items.screen_open():
		if event is InputEventKey and event.pressed and not event.echo:
			items.quick_key(event)

		return

	# Passing out, fainted or waking: the body is not the player's (Dave 25 Nov 2026, QA #19: "they must stop the second the game determines
	# its time to pass out"). No tool, E, stance or other key press reaches the world; looking round, the menu and screens above, and key
	# and button releases (so nothing stays held) still do.
	if items != null and items.body_out() and not (event is InputEventMouseMotion) and event.is_pressed():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not shot_lock and photo.active:
		photo.orbit(event.relative.x * display.mouse_look, event.relative.y * display.mouse_look)   # the camera swings round the character; the character does not turn
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and photo.active and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		photo.zoom(event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and spyglass.active and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		spyglass.wheel(event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not shot_lock:
		var look: float = MOUSE_SENSITIVITY * display.mouse_look * (spyglass.mouse_scale() if spyglass.active else 1.0)   # through the spyglass the mouse slows by the zoom
		body.rotate_y(-event.relative.x * look)
		pitch = clampf(pitch - event.relative.y * look, -1.5, 1.5)
		camera.rotation.x = pitch

		if _horizon != null:
			_horizon.pitch_rad = pitch
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held != null and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and held.wheel(event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		pass
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_scroll_view(event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	elif event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and held != null and held.mouse_button(event.button_index, event.pressed):
		pass
	elif event is InputEventMouseButton and event.pressed and not (hint_card != null and hint_card.showing != ""):   # a click beside the hint card's OK keeps the mouse free for it
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if shot_lock else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and KeyBindings.released(event, "interact") and items != null:
		items.release_e()
	elif event is InputEventKey and event.pressed and not event.echo:
		if KeyBindings.matches(event, "gpu_probe"):
			_gpu_probe.toggle()
		elif KeyBindings.matches(event, "water_hide"):
			flora.toggle_water_visible()
		elif KeyBindings.matches(event, "water_debug"):
			flora.toggle_water_debug()
		elif KeyBindings.matches(event, "sound_panel"):
			sound_panel.toggle()
		elif KeyBindings.matches(event, "admin_dig"):
			_admin_dig()
		elif KeyBindings.matches(event, "admin_npc") and is_admin_here:
			_go_to_npc()
		elif KeyBindings.matches(event, "admin_rabbit"):
			_admin_rabbit()
		elif KeyBindings.matches(event, "admin_spyglass"):
			_toggle_spyglass()
		elif KeyBindings.matches(event, "photo"):
			_toggle_photo()
		elif KeyBindings.matches(event, "auto_pickup") and items != null:
			items.toggle_auto_pickup()
		elif KeyBindings.matches(event, "inspect"):
			inspecting = not inspecting
			status_icons.tick(0.0, true)
			sound.ui.play("ui_on" if inspecting else "ui_off")

			if not inspecting:
				_inspect_label.text = ""
		elif KeyBindings.matches(event, "spring_up"):
			net.step_water_rate.rpc_id(1, 1)
		elif KeyBindings.matches(event, "spring_down"):
			net.step_water_rate.rpc_id(1, -1)
		elif KeyBindings.matches(event, "put_down_log") and not flying and items != null and not items.open:
			items.lay_down_shoulder()
		elif KeyBindings.matches(event, "crouch") and not flying:
			_set_stance(StanceScript.CROUCH, true)
		elif KeyBindings.matches(event, "sit") and not flying:
			var near_seat: Dictionary = items.seat_near(body.global_position, SEAT_SIT_KEY_REACH_M) if items != null and stance.stance != StanceScript.SIT else {}

			if not near_seat.is_empty():
				_sit_on_seat(near_seat["pos"], float(near_seat["yaw"]), near_seat["def"])   # beside or inside a seat, X sits ON it, not on the ground through it
			else:
				_set_stance(StanceScript.SIT, true)
		elif KeyBindings.matches(event, "lie") and not flying:
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
		elif KeyBindings.matches(event, "interact") and items != null:
			items.press_e()
		elif KeyBindings.matches(event, "starter_items") and items != null:
			if items.admin_craft:   # free items only while Admin mode is on (Dave 11 Nov 2026)
				items.admin_give_test_set()
		elif KeyBindings.matches(event, "jitter_test") and _jitter_test != null:
			_jitter_test.next_spot()
		elif KeyBindings.matches(event, "debug_details"):
			debug_hud.enabled = not debug_hud.enabled
		elif KeyBindings.matches(event, "hud_text"):
			hud.visible = not hud.visible
			display.hud_text = hud.visible
			display.hud_text_chosen = true   # a choice made with the key is kept, in the installed game too
			display.save()
		elif KeyBindings.matches(event, "quality"):
			quality = (quality + 1) % QUALITY_NAMES.size()
			_apply_quality()
			_save_display()
		elif KeyBindings.matches(event, "garden_wider") and held != null and held.garden_resize(1, 0):
			pass
		elif KeyBindings.matches(event, "garden_narrower") and held != null and held.garden_resize(-1, 0):
			pass
		elif KeyBindings.matches(event, "garden_longer") and held != null and held.garden_resize(0, 1):
			pass
		elif KeyBindings.matches(event, "garden_shorter") and held != null and held.garden_resize(0, -1):
			pass
		elif KeyBindings.matches(event, "blueprints") and items != null and not items.open:
			if held != null:
				held.toggle_blueprints()   # a hammer in hand: its blueprint list
		elif KeyBindings.matches(event, "ruler") and _horizon != null:
			_horizon.toggle()   # the inclination ruler underground (Dave 4 Nov 2026); off until asked for
		elif KeyBindings.matches(event, "open"):
			if items != null and not flying:
				items.press_f(Time.get_ticks_msec())   # F opens the chest beside you (Dave 2026-10-22; fly is Ctrl+Shift+G); with a log on the shoulder and nothing to open, F twice puts the log down
		elif KeyBindings.matches(event, "fly") and is_admin_here:
			flying = not flying
			body.velocity = Vector3.ZERO

			if not flying:
				arrival_protect_until_msec = Time.get_ticks_msec() + FLY_LAND_PROTECT_MS


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

		# Dave 2026-10-21: going to sleep looks and sounds exactly like passing out. The server sends the same fine 0..1 blackout
		# for both (strain_fade: fade_in_s / fade_out_s for sleep), so sleep goes through the faint states and the one picture path.
		if shown[0] == "sleeping":
			shown = ["fainting", items.strain_fade] if items.strain_fade < 0.999 else ["fainted", 1.0]
		elif shown[0] == "normal" and items.strain_fade > 0.002:
			shown = ["waking", items.strain_fade]

		faint.set_state(shown[0], items.strain, shown[1])      # every frame: the picture eases toward it, so it is smooth (Dave 2026-10-21)
		var heard: String = shown[0]
		var heard_progress: float = shown[1]

		sound.breath.set_server_heart(float(items.body_bpm), items.body_phase)
		sound.breath.set_body(items.strain, heard, heard_progress)

	# Passing out (Dave 10 Nov 2026): the whole HUD goes with the vision, only the heartbeat line stays. The scripted --faint run has no server.
	if hud_fade != null:
		var black: float = 0.0

		if items != null and not test_exertion and not test_faint and sound.breath._demo_t < 0.0:
			black = HudFadeScript.black_of(items.strain_state, items.strain_fade, items.asleep)
		elif sound.breath.state in ["fainting", "fainted", "waking"]:
			black = sound.breath._faint

		hud_fade.step(delta, black)

	var tsd: int = Probe.start()
	if swimming:
		sound.forget_fall(body)   # landing in deep water breaks the fall: no height is carried on to the shore

	sound.loading = connected_msec == 0 or waiting_for_ground or _connect_window != null   # _world_loading without its 3 s tail: the world's sounds fade in from landing
	sound.update(delta, body, flying, underwater)
	Probe.stop("sound", tsd)

	if items != null:
		items.character_update(delta)

	_item_sync_left -= delta

	if _item_sync_left <= 0.0:
		_item_sync_left = 0.1
		sound.itemfx.watch(items)
		sound.breath.set_exertion(items.strain)   # the server's real strain replaces the stand-in
		var cleared_t0: int = Time.get_ticks_usec()
		_sync_cleared()
		var cleared_ms: float = float(Time.get_ticks_usec() - cleared_t0) / 1000.0

		if cleared_ms > 10.0:
			FreezeWatchScript.printer.line("client slow: grass and plant clearing %.0f ms (%d boulders, %d world items)" % [cleared_ms, items._boulders.size(), items._world.size()])

	_fire_sync_left -= delta

	if _fire_sync_left <= 0.0 and items != null:
		_fire_sync_left = 0.25

		if not test_fire and not test_fire_world and not sound.fire.manual_active():
			sound.fire.sync_world(items._world, _cover_here)

		sound.placed.quiet = _world_loading()
		sound.workshop.quiet = sound.placed.quiet
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

	if target != StanceScript.SIT and not _seat.is_empty():
		_leave_seat()   # off the seat first: the room check would find the seat itself

	if target != StanceScript.LIE and not _bed_hold.is_empty():
		_leave_bed()   # off the bed first, to its side

	if target < stance.stance and not _room_to_rise(target):
		_menu_note.text = "Not enough room to stand up here"
		return

	if stance.set_stance(target):
		stance.apply_shape(_shape)
		status_icons.tick(0.0, true)

		if items != null:
			items.request_stance(stance.stance)   # the server: sitting and lying bring exertion down


# E on a seat (docs/COMFORT_DESIGN.md 10.3; Dave 5 Nov 2026 "we need a sitting on a chair action", his picture: the body stood inside the chair). The player sits ON it in
# the chair pose (dynasty_body.gd "sit_chair"), hips over the seat, feet on the ground in front, and is held there until a movement key stands them up in front of it.
# structures.json says how: sit_face "front" (a chair: facing its -Z, the back at +Z), "sides" (a bench: facing the side the player came from, at the nearest of
# sit_spots_x) or "free" (a log seat or stool: facing the way the player already faces).
const SEAT_HIPS_BACK_M := 0.05      # a chair's hips this far behind the middle of the seat, toward its back
const SEAT_SIT_KEY_REACH_M := 0.9  # the sit key (X) within this of a seat's middle sits on the seat (Dave 7 Nov 2026: X in a chair sat through it on the ground)
const SEAT_TOP_M := 0.45            # every seat's top above its foot (piece_look.gd: chair, stool, bench, log seat); a row can say "seat_m"
const SEAT_HIPS_ABOVE_M := 0.07     # the hips joint above the seat top when sitting on it (the chair clip: hips 0.51 m, seat 0.45 m)
const SEAT_LIFT_MAX_M := 0.6        # never move the body more than this to meet the seat
const SEAT_STEP_OFF_M := 0.7        # standing up puts the player this far in front of the seat, clear of its solid (a chair is 0.5 m deep, the capsule 0.33 m wide)

var _seat: Dictionary = {}          # while on a seat: {"at": the body position held, "front": the way the sitter faces}


func _sit_on_seat(seat_pos: Vector3, yaw_deg: float, def: Dictionary) -> void:
	if swimming or flying:
		return

	var turn: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var local: Vector3 = turn.inverse() * (body.global_position - seat_pos)
	var face: String = str(def.get("sit_face", "front"))
	var spot: Vector3 = Vector3.ZERO
	var best: float = INF

	for x in def.get("sit_spots_x", [0.0]):   # the spot along the seat nearest the player (a bench has three)
		if absf(float(x) - local.x) < best:
			best = absf(float(x) - local.x)
			spot.x = float(x)

	var front: Vector3

	if face == "free":
		front = -body.global_transform.basis.z
		front.y = 0.0
		front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	else:
		var front_local: Vector3 = Vector3(0.0, 0.0, 1.0 if face == "sides" and local.z > 0.0 else -1.0)

		if face == "front":
			spot.z = -front_local.z * SEAT_HIPS_BACK_M

		front = turn * front_local

	var at: Vector3 = seat_pos + turn * spot
	at.y = seat_pos.y + float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5
	body.velocity = Vector3.ZERO
	body.global_position = at
	body.rotation.y = atan2(-front.x, -front.z)
	_set_stance(StanceScript.SIT)

	if stance.stance == StanceScript.SIT:
		_seat = {"at": at, "front": front, "top": seat_pos.y + float(def.get("seat_m", SEAT_TOP_M))}
		stance.seated = true


# How far to raise the body so its hips joint rests on the seat top: measured from the posed skeleton each frame, so it holds for any clip, body or seat.
func _seat_lift() -> float:
	var skel: Skeleton3D = _avatar.get("skeleton") as Skeleton3D if _avatar != null else null

	if skel == null:
		return 0.0

	var hips: int = skel.find_bone("mixamorig_Hips")

	if hips < 0:
		return 0.0

	var hips_y: float = (skel.global_transform * skel.get_bone_global_pose(hips).origin).y
	var want: float = float(_seat["top"]) + SEAT_HIPS_ABOVE_M
	return clampf(want - hips_y, -SEAT_LIFT_MAX_M, SEAT_LIFT_MAX_M)


# Holds a seated player on the seat (true while seated: no walking, no gravity, no sliding out of the seat's solid). A stance the server changed ends it.
func _hold_seat() -> bool:
	if _seat.is_empty():
		return false

	if stance.stance != StanceScript.SIT:
		_leave_seat()
		return false

	body.velocity = Vector3.ZERO
	body.global_position = _seat["at"]
	return true


# Off the seat: stepped forward in front of it, clear of its solid.
func _leave_seat() -> void:
	body.global_position = _seat["at"] + (_seat["front"] as Vector3) * SEAT_STEP_OFF_M
	body.velocity = Vector3.ZERO
	_seat = {}
	stance.seated = false


# E on a bed (Dave 4 Nov 2026): the player is laid on top of it along its length, head at the pillow end, and lies down. Held there while lying (Dave 18 Nov 2026,
# "should allow me to lay on it": before, nothing held the body on the bed, and the straw and feather beds laid it across the bed, not along it). E again, Z,
# a movement key or the server standing the player up gets them up beside the bed. structures.json: lie_turn_deg turns the lie pose (head along its +Z) to the
# bed's head end (the comfort beds have the head at -X: -90), lie_top_m is the top of its solid (default 0.5). E with no bed (an empty row) gets up.
const BED_STEP_OFF_M := 0.95       # getting up puts the player this far to the side of the bed's middle (a bed is 1.0 m wide, the capsule 0.33 m)
const BED_TOP_M := 0.5

var _bed_hold: Dictionary = {}     # while lying on a bed: {"at": the body position held, "off": where getting up puts the body, "yaw": the body's turn held}


func _lie_on_bed(bed_pos: Vector3, yaw_deg: float, def: Dictionary) -> void:
	if def.is_empty():
		_set_stance(StanceScript.STAND)
		return

	if swimming or flying:
		return

	var half: float = float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5
	body.velocity = Vector3.ZERO
	body.rotation.y = deg_to_rad(yaw_deg + float(def.get("lie_turn_deg", 0.0)))
	var at: Vector3 = Vector3(bed_pos.x, bed_pos.y + float(def.get("lie_top_m", BED_TOP_M)) + half, bed_pos.z)
	var off: Vector3 = bed_pos + body.global_transform.basis.x * BED_STEP_OFF_M + Vector3(0.0, half + 0.05, 0.0)
	body.global_position = at
	_set_stance(StanceScript.LIE)

	if stance.stance == StanceScript.LIE:
		_bed_hold = {"at": at, "off": off, "yaw": body.rotation.y}


# Lying at rest, drawn in the sleep pose (dynasty_body.gd "lie"): on a bed, asleep (held Z, or collapsed) or fainted. Lying any other way is the stealthy
# crawl (Dave, QA #10, 25 Nov 2026: "right now when you lay down its always like you are sleeping. that should only be when you are lying on a bed or when
# you hold Z to go to sleep. otherwise you should first drop like you are being stealthy and crawling").
func lying_at_rest() -> bool:
	return stance.stance == StanceScript.LIE and (not _bed_hold.is_empty() or (items != null and (items.asleep or items.strain_state >= 2)))


# Lying off a bed and awake: the movement keys crawl (StanceScript.CRAWL_MPS) instead of standing the player up.
func crawling() -> bool:
	return stance.stance == StanceScript.LIE and not lying_at_rest()


# Holds a player lying on a bed there (true while held: no gravity, no sliding off). A stance the server changed ends it.
func _hold_bed() -> bool:
	if _bed_hold.is_empty():
		return false

	if body.global_position.distance_to(_bed_hold["at"]) > 2.0:   # moved away by something else (a respawn, a teleport): no longer on the bed
		_bed_hold = {}
		return false

	if stance.stance != StanceScript.LIE:
		_leave_bed()
		return false

	body.velocity = Vector3.ZERO
	body.global_position = _bed_hold["at"]
	body.rotation.y = float(_bed_hold["yaw"])   # mouse look turns the head, not the body across the bed
	return true


func _leave_bed() -> void:
	body.global_position = _bed_hold["off"]
	body.velocity = Vector3.ZERO
	_bed_hold = {}


# The server's answer (or its own change: fainting forces lying, walking off stands you up).
# Lying and holding Z for sleep.json hold_s asks to sleep; letting go sooner gets you up like before.
func _check_sleep_hold() -> void:
	if _z_down_msec < 0:
		return

	if not KeyBindings.held("lie"):
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


var _snow_pace_at_msec: int = -100000
var _snow_pace_now: float = 1.0


# The snow pace under the feet (SnowWalk): the voxel material the footsteps read, looked at four times a second.
func _snow_pace() -> float:
	var now: int = Time.get_ticks_msec()

	if now - _snow_pace_at_msec < 250 or sound == null or items == null:
		return _snow_pace_now

	_snow_pace_at_msec = now
	var soil: int = sound._ground_under(body.global_position - Vector3(0.0, sound.FEET_M, 0.0))
	_snow_pace_now = SnowWalkScript.pace_mult(SnowWalkScript.soil_is_snow(soil), SnowWalkScript.shod(items.worn, items.table))
	return _snow_pace_now


# Movement keys held for the body (jump, swim up, fly, Ctrl down or dive, ladder climb): never while a screen (inventory, character, Journal, a talk) is open, as walking
# is not (the screen's keys and clicks are not the world's).
func _move_held(id: String) -> bool:
	return KeyBindings.held(id) and not _screen_up()


# A screen that takes the keys is up: the inventory, character, Journal, a talk, or the hammer or knife build screen (letters typed in its search
# box are not walking).
func _screen_up() -> bool:
	return (items != null and items.screen_open()) or (held != null and held.blueprints.is_open)


func _move_player(delta: float) -> void:
	if menu_open or (cavein_death != null and cavein_death.active) or (death_screen != null and death_screen.active):
		body.velocity = Vector3.ZERO
		return

	var input: Vector3 = Vector3(
		float(KeyBindings.held("move_right")) - float(KeyBindings.held("move_left")),
		0.0,
		float(KeyBindings.held("move_back")) - float(KeyBindings.held("move_forward"))
	)
	if _screen_up():
		input = Vector3.ZERO   # the inventory's quick keys (S split) and the build screen's search are not walking

	var direction: Vector3 = photo.move_direction(input) if photo.active else body.global_transform.basis * input

	if photo.active and input != Vector3.ZERO:   # in the photo view the character walks facing where it goes (the mouse never turns it)
		body.rotation.y = lerp_angle(body.rotation.y, photo.facing_for(direction, body.rotation.y), clampf(delta * 10.0, 0.0, 1.0))

	# Any movement key stands the player up from sitting, and from lying at rest (on a bed, asleep or fainted); lying off a bed the keys crawl
	# (Dave, QA #10, 25 Nov 2026). Space stands up from a crawl too.
	var sleeping_now: bool = items != null and items.asleep

	if sleeping_now and KeyBindings.held("jump") and input == Vector3.ZERO:   # waking works with a screen open too (Dave 2026-10-21: hold Space to wake)
		# Dave 2026-10-21: holding Space wakes a sleeper early (not fully rested: the energy stays where it was).
		_space_wake_s += delta

		if _space_wake_s >= SPACE_WAKE_S:
			_space_wake_s = 0.0
			items.request_sleep(0)
	else:
		_space_wake_s = 0.0

	# A crawler who reaches deep water stands up to swim (review of PR #1939: a lying swimmer crept along at the crawl's pace).
	if ((input != Vector3.ZERO and (not crawling() or swimming)) or (_move_held("jump") and not sleeping_now)) and not (items != null and items.body_out()):   # no stand-up asks while passing out (QA #19)
		if stance.stance >= StanceScript.SIT:
			_set_stance(StanceScript.STAND)

	stance.step(delta)

	if test_walk:
		_walk_step()
		direction = _walk_dir
	elif (lag_run != null or shot_run) and _walk_dir != Vector3.ZERO:
		direction = _walk_dir
	var fast: float = FAST if KeyBindings.held("run") else 1.0
	var forward: bool = KeyBindings.held("move_forward")
	var strain_cap: float = items.move_cap() if items != null and not flying else 0.0

	# Gaits (CONTROLS.md): walk is plain WASD, run is Shift with W.
	running = forward and KeyBindings.held("run") and strain_cap == 0.0 and not (held != null and held.blocking)   # a raised shield walks (protection.json note_shield)
	var pace: float = RUN_SPEED if running else WALK_SPEED

	if not flying and stance.stance != StanceScript.STAND:
		running = false
		pace = WALK_SPEED * float(StanceScript.SPEED[stance.stance])

	if items != null and not flying:
		pace *= items.speed_factor() * items.over_pace_factor()

		if stance.stance == StanceScript.STAND:
			pace *= items.path_pace_factor(body.global_position, "run" if running else "walk")

		pace *= _snow_pace()   # snow and glacial ice are slow going, snowshoes ease it (snow_walk.json, Part C plan 7)

		if items.pulling_id != 0:
			pace = minf(pace, items.pull_pace_mps)   # a handcart in hand: no faster than the cart can go (server cart_pull, catalog Phase 10)

		if strain_cap > 0.0:
			pace = minf(pace, strain_cap)
		elif strain_cap < 0.0:
			pace = 0.0   # fainted or waking: no control

	var walked: bool = false   # this frame took the walk (or swim) branch: the motion audit judges only those

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
		direction.y += float(_move_held("jump")) - float(_move_held("down"))
		body.global_position += direction * FLY_SPEED * fast * delta
	elif _hold_seat():
		pass
	elif _hold_bed():
		pass
	elif _climb_ladder(delta, strain_cap):
		pass
	else:
		var velocity: Vector3 = direction.normalized() * (run_speed if run_speed > 0.0 and (test_walk or lag_run != null or shot_run) else pace)

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

			velocity.x *= IceFeelScript.swim_mult(_ice_shock)
			velocity.z *= IceFeelScript.swim_mult(_ice_shock)
		else:
			velocity.y = body.velocity.y - GRAVITY * delta

			# Wading: water over the knees slows a walker.
			if not water.is_empty() and body.is_on_floor():
				var slow: float = SwimScript.wade_factor(WaterVolume.depth(float(water["surface"]), float(water["ground"])))
				velocity.x *= slow
				velocity.z *= slow

			# An ankle-deep wetland pool (the last step splashed in one, sound_stage.gd pool_pace) slows a walker a little.
			if body.is_on_floor() and sound != null:
				velocity.x *= sound.pool_pace
				velocity.z *= sound.pool_pace

			velocity = _ice_feel_velocity(velocity, water, delta)

		if not waiting_for_ground:
			_ice_feel_shock(water, delta)

		if not swimming and body.is_on_floor() and _move_held("jump") and strain_cap >= 0.0:
			velocity.y = 7.0
			feel.jump()
			sound.footstep(body, 1, -3.0, "right")        # the push off the ground (job 61: a jump had no sound, only the landing)

		if _step_hover_m > 0.0:
			if swimming or waiting_for_ground or velocity.y > 0.0 or Vector2(velocity.x, velocity.z).length_squared() < 0.0001:
				_step_hover_m = 0.0   # swimming, a jump, or no longer walking: gravity as ever
			else:
				velocity.y = 0.0

		body.velocity = velocity

		if not swimming and not waiting_for_ground and body.is_on_floor() and _step_hover_m <= 0.0:
			_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)

		var fall_speed: float = -body.velocity.y
		var was_on_floor: bool = body.is_on_floor()
		var tm: int = Probe.start()
		var wanted_move: Vector3 = body.velocity
		var slide_from: Vector3 = body.global_position
		var carrying: bool = was_on_floor and not swimming and not waiting_for_ground and delta > 0.0

		var carried: Vector3 = _slide_carry / delta if carrying else Vector3.ZERO
		body.velocity += carried
		body.move_and_slide()
		var slid_at: Vector3 = body.global_position
		var touched: Array = []

		if motion_audit != null:
			for i in range(body.get_slide_collision_count()):
				var hit: KinematicCollision3D = body.get_slide_collision(i)
				var what: Object = hit.get_collider()
				touched.append([(str(what.get_parent().name) + "/" + str(what.name)) if what is Node and what.get_parent() != null else str(what), hit.get_normal()])

		if _step_hover_m > 0.0:
			_step_hover_m = StepUpScript.hover_left(body, slide_from, _step_hover_m)

		var wall_n: Vector3 = body.get_wall_normal() if body.is_on_wall() else Vector3.ZERO
		body.velocity -= carried.slide(Vector3(wall_n.x, 0.0, wall_n.z).normalized()) if body.is_on_wall() else carried   # the pace the animation, sounds and ice grip read stays the walker's own
		Probe.stop("p slide", tm)

		if carrying:
			_carry_slide(slide_from, Vector3(wanted_move.x, 0.0, wanted_move.z) * delta)
		else:
			_slide_carry = Vector3.ZERO

		if items != null and not swimming and not waiting_for_ground:
			# Loose logs are bodies in the server's physics, not in this world: the walker stops at one they walk into and pushes it (inventory_view.walker_logs).
			var capsule: CapsuleShape3D = _shape.shape as CapsuleShape3D
			body.global_position += items.walker_logs(body.global_position - Vector3(0.0, 0.9, 0.0), capsule.radius if capsule != null else 0.35, capsule.height if capsule != null else 1.8, wanted_move, running)

		if _animal_view_node != null and not swimming and not waiting_for_ground:
			# An animal's body stops the walker as a log does (they stand against it or slide round it): walked into, its drawn body was
			# shoved along ahead of them, metres from where the server had it (AnimalContact.walker_stop).
			var stopped: Vector3 = _animal_view_node.call("walker_stop", slide_from - Vector3(0.0, 0.9, 0.0), body.global_position - Vector3(0.0, 0.9, 0.0))
			body.global_position += stopped

		if not was_on_floor and body.is_on_floor() and not swimming and not waiting_for_ground:
			var landed: float = feel.land(fall_speed)

			if landed > 0.0 and IceFeelScript.bears(_ice_feel_band) and _ice_underfoot:
				feel.strike(0.0, 0.25)   # ice_walk_feel.md section 4: a hard landing on a sheet dips a little more (0.02 m)

		var before_rescue: Vector3 = body.global_position
		rescue.step()

		if motion_audit != null:
			var gait: String = "swim" if swimming else ("crouch" if stance.stance == StanceScript.CROUCH else ("prone" if stance.stance != StanceScript.STAND else ("run" if running else "walk")))
			motion_audit.frame(delta, gait, wanted_move, slide_from, slid_at, before_rescue, body.global_position, touched, body.get_floor_normal().y if body.is_on_floor() else 0.0)

		walked = true
		var tb: int = Probe.start()
		_update_bob(delta)
		_ease_step_lift(delta)
		Probe.stop("p bob", tb)

	if not walked:
		_step_hover_m = 0.0   # a seat, a bed, a ladder or flying: no hop's level hold carries over

		if motion_audit != null:
			motion_audit.reset()   # the next walk frame starts fresh

	if flying:
		_bob_amount = 0.0
		camera.position = Vector3(0.0, 0.7, 0.0)
		camera.rotation.z = 0.0

		if stance.stance != StanceScript.STAND:
			_set_stance(StanceScript.STAND)

	_follow_sea()
	_update_underwater()


# The two tunnel collapse buttons in Esc > Settings show the server's settings: On in green or Off in red, and the cave-in time.
func _show_tunnel_buttons() -> void:
	game_menu.refresh()


# On a placed ladder (ladder_climb.gd): W climbs, S descends, Space lets go. True while holding on (that frame does no walking).
func _climb_ladder(delta: float, strain_cap: float) -> bool:
	if items == null or strain_cap < 0.0 or (items.ladders.is_empty() and not ladder.climbing()) or (stance.stance == StanceScript.LIE and not ladder.climbing()):   # a crawler does not start up a ladder
		ladder.let_go()
		return false

	var look: Vector3 = -body.global_transform.basis.z
	var result: Dictionary = ladder.step(items.ladders.values(), body.global_position - Vector3(0.0, 0.9, 0.0), look, _move_held("move_forward"), _move_held("move_back"), _move_held("jump"), delta * items.worn_speed())   # a pack frame climbs slower
	var at: Vector3 = result["position"]

	if at != Vector3.INF:
		body.global_position = at + Vector3(0.0, 0.9, 0.0)

	body.velocity = result["velocity"]

	if not bool(result["active"]):
		_ladder_climbed_m = 0.0
		return false

	_ladder_climbed_m += absf(body.velocity.y) * delta

	if _ladder_climbed_m >= LADDER_RUNG_M:
		_ladder_climbed_m = fmod(_ladder_climbed_m, LADDER_RUNG_M)
		sound.slots.play("ladder_rung", body.global_position - Vector3(0.0, 0.9, 0.0))      # one per rung climbed, by distance, not by a timer

	_follow_sea()
	_update_underwater()
	return true


# Dave 23 Nov 2026, crouched "like I was against an invisible wall but if I stood up I could walk": on the voxel terrain under Jolt a
# move_and_slide of only a few millimetres on the floor (a slow crouch, a loaded or tired walker) often goes nowhere at all, though nothing
# but the floor is touched, and the same at a wall or trunk it is sliding along. The part of the asked move (against a wall only the part along
# it) that a frame did not make, measured against what the floor's slope lets it make, is carried into the next frame's when it is over 30%
# of the move, so the body moves in steps of a centimetre or two instead of standing still, and a slope stays as slow as it was. Walking
# straight into a wall carries nothing (it stops you as before); SLIDE_CARRY_MAX_M caps it.
const SLIDE_CARRY_MAX_M := 0.05


func _carry_slide(from: Vector3, asked: Vector3) -> void:
	var carry: Vector3 = _slide_carry

	if body.is_on_wall() and asked.length_squared() >= 0.00000001:
		# Against a wall or a trunk only the move along it counts (robots 23 Nov 2026: crouched, sliding along a tree trunk went nowhere while standing
		# slid past), however small (from 0.1 mm a frame): walking nearly head on into a round trunk slides round it as the standing walk does (robots, later the same
		# day: crouched it stopped dead there). Straight into a wall nothing is along it, nothing is carried and the wall stops you.
		var wall: Vector3 = Vector3(body.get_wall_normal().x, 0.0, body.get_wall_normal().z).normalized()
		asked = asked.slide(wall)
		carry = carry.slide(wall)

	var want: Vector3 = asked + carry
	var got: float = Vector2(body.global_position.x - from.x, body.global_position.z - from.z).length()

	if asked.length_squared() < 0.00000001:
		_slide_carry = Vector3.ZERO
		return

	# What the floor lets the move make across the ground: on a slope move_and_slide goes along it, so less (cos squared of the slope) than asked.
	# Measured against that, a slope is never sped up to the flat pace.
	var floor_move: Vector3 = want.slide(body.get_floor_normal()) if body.is_on_floor() else want
	var can: Vector3 = Vector3(floor_move.x, 0.0, floor_move.z)

	if got >= can.length() * 0.3:
		# It moved: what of the headway it could make and did not is kept, not dropped (round a trunk nearly head on the moves along it are under
		# a millimetre, Jolt makes one in a few, and dropping the rest crept round at a fraction of the standing pace). A move pushed backwards
		# (the body set out of the trunk) leaves more than the move to make up, still within SLIDE_CARRY_MAX_M.
		var moved: Vector3 = Vector3(body.global_position.x - from.x, 0.0, body.global_position.z - from.z)
		var short: float = can.length() - moved.dot(can.normalized())
		_slide_carry = want.normalized() * minf(short, SLIDE_CARRY_MAX_M) if short > can.length() * 0.3 else Vector3.ZERO
		return

	_slide_carry = want.limit_length(SLIDE_CARRY_MAX_M)


# Walking or running into something you can step over (a log, a stone, a low stump): you hop onto it and keep going.
# The step height is data/movement.json step_up_m. Anything higher is a wall and move_and_slide slides along it.
# The hop lifts the body just clear of the step's top, but its round foot is still over the edge: at a walk or a crouch it fell back before it
# got over and stood at the step (robots 23 Nov 2026: crouched it could not get onto a foundation, 0.3 m, nor walking onto a 0.45 m one; only a
# run went up). After a hop the body is held level while it moves StepUpScript.HOVER_M on, so it walks onto the top at its own pace.
func _step_up(motion: Vector3) -> void:
	var lift: float = StepUpScript.try(body, motion, float(_movement.get("step_up_m", 0.5)))
	_step_lift += lift

	if lift > StepUpScript.HOVER_MIN_LIFT_M:
		_step_hover_m = StepUpScript.HOVER_M
		body.velocity.y = 0.0


# The window stays put while the body hops: the eye eases up the step (the lift fades) instead of jumping.
func _ease_step_lift(delta: float) -> void:
	_step_lift = move_toward(_step_lift, 0.0, maxf(delta * 3.0, _step_lift * (1.0 - exp(-14.0 * delta))))
	camera.position.y -= _step_lift


# The water at the player: {"surface", "ground"} when they are in or over water deeper than a film
# (a lake or river level from the water grid, or the sea at 0 m), else {}. One ray down, only when
# water is near the player.
var _water_ground: float = NAN           # _water_here's cached bed height, where and when it was read
var _water_ground_at: Vector2 = Vector2(INF, INF)
var _water_ground_msec: int = -1000


func _water_here() -> Dictionary:
	var here: Vector3 = body.global_position
	var surface: float = flora.water_surface_at(here.x, here.z) if flora != null else NAN

	if not is_nan(surface) and here.y < surface and _rock_over(here, surface):
		surface = NAN   # in a cave under the outside water (a hillside's film, a river): that water is on the ground above, not here

	# A spring cave's pool (BUG-008: 20 m deep) lies under the ground the water grid knows: swim in it there.
	if (is_nan(surface) or surface < here.y - 3.0) and _cave_streams != null:
		var pool: float = _cave_streams.pool_surface_at(here)

		if not is_nan(pool):
			surface = pool

	# Under the island the sea is not there (_under_land): only a lake, river or cave pool counts.
	var land: bool = _under_land(here)

	if is_nan(surface) and (here.y > 2.0 or land):
		return {}

	# The bed under a swimmer or wader hardly changes from frame to frame: one ray down per 0.25 m moved or 150 ms, not one per frame.
	var now: int = Time.get_ticks_msec()
	var ground: float = _water_ground

	if now - _water_ground_msec > 150 or Vector2(here.x - _water_ground_at.x, here.z - _water_ground_at.y).length() > 0.25:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 0.5, 0.0), here + Vector3(0.0, -250.0, 0.0), 1)
		query.exclude = [body.get_rid()]
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
		ground = float(hit["position"].y) if not hit.is_empty() else NAN
		_water_ground = ground
		_water_ground_msec = now
		_water_ground_at = Vector2(here.x, here.z)

	if land:
		return {"surface": surface, "ground": ground}

	return SwimScript.water_at(here.y, surface, ground, _sea_height_at(here))   # a swimmer in the sea rides the swell (M5)


# The swimmer's velocity: strokes at the swim pace (never more than the walking pace the player's
# load and strain allow), buoyancy and Space/Ctrl up and down, and the pull-out onto a bank or floe
# edge (walking into a ledge up to CLIMB_MAX_M above the water climbs it).
func _swim_velocity(wanted: Vector3, direction: Vector3, pace: float, hard: bool, strain_cap: float, surface: float, delta: float) -> Vector3:
	var now: int = Time.get_ticks_msec()
	var velocity: Vector3 = wanted
	var horizontal: Vector3 = direction.normalized() * minf(pace, SwimScript.pace(hard)) if direction != Vector3.ZERO else Vector3.ZERO

	if strain_cap < 0.0:
		horizontal = Vector3.ZERO

	var up: bool = _move_held("jump") and strain_cap >= 0.0
	var down: bool = _move_held("down") and strain_cap >= 0.0
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	# BUG-028: forward / back (W / S, or the keys bound to them) swim along the view, so looking up rises and looking down dives; Space and Ctrl still do.
	var stroke_vy: float = 0.0 if strain_cap < 0.0 else SwimScript.pitch_wish(camera.rotation.x, float(_move_held("move_forward")) - float(_move_held("move_back")), horizontal.length())
	velocity.y = SwimScript.vertical_speed(body.global_position.y, surface, body.velocity.y, up, down, delta, stroke_vy)

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


func _ice_step_scale() -> float:
	if not _ice_underfoot:
		return 1.0

	return IceFeelScript.step_scale(_ice_feel_band, sound.weather.ground_snow if sound != null and sound.weather != null else 0.0)


func _ice_bob_scale() -> float:
	if not _ice_underfoot:
		return 1.0

	return IceFeelScript.bob_scale(_ice_feel_band, sound.weather.ground_snow if sound != null and sound.weather != null else 0.0)


# A very small up-and-down camera bob while walking on the ground. Its speed
# follows the pace and its height grows only a little, to avoid motion sickness.
func _update_bob(delta: float) -> void:
	var pace: float = Vector2(body.velocity.x, body.velocity.z).length()
	var moving: bool = body.is_on_floor() and pace > 1.0
	_bob_amount = move_toward(_bob_amount, 1.0 if moving else 0.0, delta * 6.0)
	var stride: int = 1 if pace > AvatarDriver.RUN_FROM else 0   # STEP_M, BOB_M, SWAY_M, SWAY_DEG: by the clip the pace plays (run above 5 m/s), so the steps follow the feet even when a runner is slowed
	var gait: int = _gait()                  # the footstep tier

	if moving and items != null and items.body_out():
		moving = false   # passing out, fainted or waking: no footsteps, whatever the body is doing (Dave 25 Nov 2026, QA #19)

	if moving:
		# One full turn of the phase is one step (a footfall at 0, then at TAU).
		var before: float = _bob_phase
		_bob_phase = fposmod(_bob_phase + delta * pace / (float(STEP_M[stride]) * _ice_step_scale()) * TAU, 2.0 * TAU)

		if floor(before / TAU) != floor(_bob_phase / TAU):
			sound.footstep(body, gait, 0.0, "left" if _bob_phase < TAU else "right")

			_ice_feel_after_step()

	var dip: float = 0.5 * (1.0 + cos(_bob_phase))            # 1 at a footfall, 0 mid-stride
	var side: float = cos(_bob_phase * 0.5)                   # +1 left foot, -1 right foot
	var careful: float = _ice_bob_scale()   # a flatter, careful walk on bare ice
	camera.position.y = stance.eye_y - float(BOB_M[stride]) * dip * _bob_amount * feel.intensity * careful
	camera.position.x = -float(SWAY_M[stride]) * side * _bob_amount * feel.intensity * careful
	camera.rotation.z = deg_to_rad(float(SWAY_DEG[stride])) * side * _bob_amount * feel.intensity * careful
	drip_view.step(delta)
	sound.wet.update(delta, body.global_position, wet_gap_override if wet_gap_override >= 0.0 else drip_view.gap_m)
	sound.cave.note_gap(wet_gap_override if wet_gap_override >= 0.0 else drip_view.gap_m)
	if items != null:
		var health_now: float = float(items.health)

		if _health_seen >= 0.0 and health_now <= _health_seen - 2.0:   # a bite or a fall; slow starvation drain of 1 a tick stays unjolted
			feel.hurt(_health_seen - health_now, 1.0 if int(Time.get_ticks_msec() / 1000) % 2 == 0 else -1.0)

		_health_seen = health_now

	# Swimming: the head rides the water, a slow rise and fall with a little sideways roll (stronger when stroking), so the water feels like it is carrying you.
	if swimming:
		_swim_t += delta
		var stroke: float = clampf(pace / 2.0, 0.0, 1.0)
		camera.position.y += (0.018 + 0.012 * stroke) * sin(_swim_t * 1.9) * feel.intensity
		camera.rotation.z += deg_to_rad((0.5 + 0.5 * stroke) * sin(_swim_t * 1.3)) * feel.intensity

	var kick: Dictionary = feel.step(delta)
	camera.position.y += float(kick["y"])
	camera.rotation.z += deg_to_rad(float(kick["roll"]))
	var shake: Dictionary = quake_view.step(delta)
	camera.position += shake["offset"]
	camera.rotation.z += deg_to_rad(float(shake["roll"]))


# A light frame-time log (Dave 2 Nov 2026: "there is constant lag"): every 10 s one line with the average and worst frame and how many frames went
# over 50 ms, only when something was slow, so the client log shows when and how bad.
var _frame_log: Dictionary = {"t": 0.0, "n": 0, "sum": 0.0, "worst": 0.0, "slow": 0}


func _log_frame(delta: float) -> void:
	var ms: float = delta * 1000.0
	_frame_log["t"] = float(_frame_log["t"]) + delta
	_frame_log["n"] = int(_frame_log["n"]) + 1
	_frame_log["sum"] = float(_frame_log["sum"]) + ms
	_frame_log["worst"] = maxf(float(_frame_log["worst"]), ms)
	_frame_log["slow"] = int(_frame_log["slow"]) + (1 if ms > 50.0 else 0)

	if float(_frame_log["t"]) < 10.0:
		return

	if int(_frame_log["slow"]) > 0 or float(_frame_log["sum"]) / float(_frame_log["n"]) > 25.0:
		FreezeWatchScript.printer.line("client frames: avg %.1f ms, worst %.0f ms, %d over 50 ms in %.0f s at %s" % [float(_frame_log["sum"]) / float(_frame_log["n"]), float(_frame_log["worst"]), int(_frame_log["slow"]), float(_frame_log["t"]), str(body.global_position) if body != null else "?"])

	_frame_log = {"t": 0.0, "n": 0, "sum": 0.0, "worst": 0.0, "slow": 0}


# The frames right after the welcome (Low-quality lag runs, 5 Nov: stuck 0.8 to 2.2 s there with no probe finishing): length, script
# and physics time of each, printed once as one line after AFTER_WELCOME_FRAMES frames.
const AFTER_WELCOME_FRAMES := 4
var _after_welcome: Variant = null   # null: not timing; an Array of "frame ms (script, physics)" texts while timing


func _note_after_welcome(delta: float) -> void:
	if _after_welcome == null:
		return

	(_after_welcome as Array).append("%.0f ms (script %.0f, physics %.0f, draw calls %d)" % [delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

	if (_after_welcome as Array).size() >= AFTER_WELCOME_FRAMES:
		FreezeWatchScript.printer.line("Terrain client: frames after the welcome: " + ", ".join(PackedStringArray(_after_welcome as Array)))
		_after_welcome = null



# Tells the server where we are and how fast we move (every 0.2 s from _process, and just before a blow, held_item report_now, so the server
# judges the blow from where we stand: server_items strike_origin).
func send_position_now() -> void:
	var now: int = Time.get_ticks_msec()

	if now - _aim_msec < 20:
		return   # one went this moment: fresh enough
	var here: Vector3 = _anchor
	var seconds: float = maxf(float(now - _aim_msec) / 1000.0, 0.02)

	if _aim_msec > 0 and not (cavein_death != null and cavein_death.active):   # the server already has the character at the respawn point
		net.report_position.rpc_id(1, here, (here - _aim_pos) / seconds, body.rotation.y)   # protocol 151: the facing, for the other players

	_aim_msec = now
	_aim_pos = here

# Runs last among the physics callbacks (process_physics_priority, set in _ready): a FREEZE gap after this note was in the physics engine's own
# step (colliders added or moved); one after "drawn" was in the window's present (Lane A 25 Nov 2026: a 1.1 s gap after "drawn" running into new ground).
func _physics_process(_delta: float) -> void:
	FreezeWatchScript.physics_mark()


func _process(delta: float) -> void:
	FreezeWatchScript.beat()
	# Right after the beat, so the frame just ended is judged with its own timed pieces (they were all stopped since the last call), its wall
	# time and its monitors; called later in this function it saw the next frame's first pieces instead (PR #1952 review).
	Probe.frame(delta)
	_note_after_welcome(delta)
	_tick_hint_card()
	_log_frame(delta)
	if _water_spam_per_s > 0.0 and flora != null and Time.get_ticks_msec() >= _dig_spam_next_msec and Time.get_ticks_msec() - connected_msec > 8000:
		_dig_spam_next_msec = Time.get_ticks_msec() + int(1000.0 / _water_spam_per_s)
		var spam_chunks: PackedInt32Array = PackedInt32Array()

		for chunk in flora.held_chunks():
			spam_chunks.append_array(PackedInt32Array([chunk.x, chunk.y]))

		net.request_water.rpc_id(1, spam_chunks)

	if _dig_spam_per_s > 0.0 and world.has("spawn") and Time.get_ticks_msec() >= _dig_spam_next_msec and Time.get_ticks_msec() - connected_msec > 8000:
		_dig_spam_next_msec = Time.get_ticks_msec() + int(1000.0 / _dig_spam_per_s)
		net.dig.rpc_id(1, Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0), 0.9)

	if _act_test and world.has("spawn") and Time.get_ticks_msec() - connected_msec > 10000 and _act_test_step < 3 and Time.get_ticks_msec() >= _act_test_next:
		_act_test_next = Time.get_ticks_msec() + 2000
		_act_test_step += 1

		if _act_test_step == 1:
			net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 5, Vector3.ZERO)
		elif _act_test_step == 2:
			net.inventory_action.rpc_id(1, NetScript.ACT_DROP, 0, 0, 1, Vector3(world["spawn"]))
		else:
			net.inventory_action.rpc_id(1, NetScript.ACT_DIG, 0, 0, 0, Vector3(world["spawn"]))

	if _tunnel_per_s > 0.0 and world.has("spawn") and Time.get_ticks_msec() >= _dig_spam_next_msec and Time.get_ticks_msec() - connected_msec > 8000:
		_dig_spam_next_msec = Time.get_ticks_msec() + int(1000.0 / _tunnel_per_s)
		var i: int = _tunnel_spam_count
		_tunnel_spam_count += 1

		# Admin digs on a 9 x 9 grid by the spawn, layer by layer downward, plus a drop every 10th request.
		if i == 0:
			net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, items.table.number_of("wooden_shovel"), 0, 1, Vector3.ZERO)
			net.inventory_action.rpc_id(1, NetScript.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 20, Vector3.ZERO)
		elif i % 10 == 0:
			net.inventory_action.rpc_id(1, NetScript.ACT_DROP, 1, 0, 1, Vector3(world["spawn"]))
		else:
			var cell: int = i % 81
			var layer: int = int(floorf(float(i) / 81.0)) % 12
			net.dig.rpc_id(1, Vector3(world["spawn"]) + Vector3(float(cell % 9 - 4) * 0.5, -2.0 - 0.4 * float(layer), float(int(floorf(float(cell) / 9.0)) - 4) * 0.5), 0.9)

	if link_bars != null:
		link_bars.client_stalled(delta)

	if _spawn_test != "":
		_spawn_test_step(Time.get_ticks_msec())

	if _tunnel_test > 0:
		_tunnel_step()

	_update_pit_shadow()
	_update_spring_heads(delta)

	_run_ground_watchdog()

	if _connect_window != null:
		_update_connect_window()

	if _lose_after_s > 0.0 and connected_msec > 0 and Time.get_ticks_msec() - connected_msec > int(_lose_after_s * 1000.0):
		_lose_after_s = 0.0
		_on_server_lost()

	if OS.get_cmdline_user_args().has("--lost-notice") and link_bars != null and Time.get_ticks_msec() - _link_print_msec > 2000:
		_link_print_msec = Time.get_ticks_msec()
		FreezeWatchScript.printer.line("Terrain client: " + str(link_bars.text()))

	if crash_report != null:
		var tc: int = Probe.start()
		crash_report.tick(_crash_state)
		Probe.stop("crash report", tc)
		tc = Probe.start()
		_telemetry.tick(_telemetry_state, 1000, 500)
		Probe.stop("telemetry", tc)

	if pickup_feed != null:
		pickup_feed.update(delta)

	var tp: int = Probe.start()
	_step_player(delta)
	Probe.stop("step player", tp)
	tp = Probe.start()
	_update_view(delta)
	_update_spyglass()
	Probe.stop("update view", tp)
	tp = Probe.start()

	if harvest != null:
		harvest.update(delta, KeyBindings.held("interact") and not _screen_up() and not (items != null and items.body_out()))   # no harvest under any screen (the Journal, Tab), not only the inventory

	Probe.stop("harvest", tp)
	tp = Probe.start()
	game_clock.tick()

	if grass != null:
		grass.today = int(floor(game_clock.seconds / 86400.0))   # taken branches of an earlier day have grown back (protocol 160)
	_update_weather()
	Probe.stop("clock, weather", tp)

	# The world's sounds keep the season where the player is (the row's, across the equator half a year on), not the starter island's calendar.
	var here_season: String = season_here()

	if sound_tests.time_at < 0 and sound != null and sound.ambient != null:
		sound.ambient.set_conditions(game_clock.hour(), here_season)

	if critters != null and body != null and sound != null and sound.ambient != null:
		critters.update(delta, body.global_position, sound.ambient.weights, here_season, game_clock.hour(), float(weather.get("rain", 0.0)))

	_flame_wet(delta)

	if _water_label != null and _water_label.text != "" and Time.get_ticks_msec() > _water_label_until_msec:
		_water_label.text = ""

	_frame_ms.append(delta * 1000.0)

	var tq_arms: int = Probe.start()
	DynastyArmsScript.prebuild()   # the first-person arms are cut out and skinned on a worker once their file is loaded (2 s on the main thread at the welcome); arms made before that get their meshes here
	Probe.stop("arms prebuild", tq_arms)

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

		@warning_ignore("integer_division")
		FreezeWatchScript.printer.line("Terrain client: probe %d s after the welcome, player at %s: %s" % [(Time.get_ticks_msec() - connected_msec) / 1000, str(body.global_position.round()), ", ".join(probes)])

	ground_debug.ground_check_step(Time.get_ticks_msec())
	ground_debug.hole_probe_step(Time.get_ticks_msec())

	if test_menu and not _test_menu_done and Time.get_ticks_msec() - connected_msec > 6000:
		_test_menu_done = true
		_set_menu(true)
		var seen: int = 0

		for page_name in game_menu._pages:
			game_menu.show_page(page_name)
			seen += 1 if game_menu._pages[page_name].visible and game_menu._pages[page_name].get_child_count() > 0 else 0

		for found in game_menu.root.find_children("*", "Control", true, false):
			if found.has_signal("toggled") and found.has_method("set_on"):
				found.set_on(not found.on)
				found.toggled.emit(found.on)
				found.set_on(not found.on)
				found.toggled.emit(found.on)

		drip_view.on_leak(PackedVector3Array([body.global_position + Vector3(0.0, 2.0, 0.0)]), PackedByteArray([200]), body.global_position)
		drip_view.step(0.1)
		FreezeWatchScript.printer.line("Terrain client: drip view: gap %.1f m, wet here %s" % [drip_view.gap_m, str(drip_view.wet_here)])
		drip_view.step(2.0)
		FreezeWatchScript.printer.line("Terrain client: drip view after fade: gap %.1f m" % drip_view.gap_m)
		FreezeWatchScript.printer.line("Terrain client: menu test: %d pages with content of %d, panel opaque %s, layer %d" % [seen, game_menu._pages.size(), str(game_menu.root.get_child(1).get_child(0).get_theme_stylebox("panel").bg_color.a == 1.0), (game_menu.root.get_parent() as CanvasLayer).layer])
		_set_menu(false)
		var esc: InputEventKey = InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		_unhandled_input(esc)
		var opened: bool = menu_open and game_menu._pages["main"].visible
		_unhandled_input(esc)
		var closed: bool = not menu_open
		var screen_ok: bool = true

		if items != null:
			items.toggle()
			_unhandled_input(esc)
			screen_ok = not items.screen_open() and not menu_open

		FreezeWatchScript.printer.line("Terrain client: esc test: opens the menu %s, closes it %s, closes an open screen first without opening the menu %s" % [str(opened), str(closed), str(screen_ok)])

	if test_dump and not _test_dump_done and Time.get_ticks_msec() - connected_msec > 14000:
		_test_dump_done = true
		ground_debug.dump_ground_here(body.global_position + Vector3(0.0, -1.0, 0.0))

	if test_clear and not _test_clear_done and Time.get_ticks_msec() - connected_msec > 12000:
		_test_clear_done = true
		_ask_clear_cache()

	var ta0: int = Probe.start()
	_update_anchor(Time.get_ticks_msec(), delta)
	Probe.stop("anchor", ta0)
	# Owner (2026-10-19): while a bake runs, ask only for the ground the game is waiting on
	# right now, not the extra ground around it (it is all thrown away when the bake ends).
	stream.only_urgent = _bake != null and _bake.running
	link.pump()

	if link.take_lost_line():   # what the lost line carried and never answered goes again over the game connection, now
		FreezeWatchScript.printer.line("Terrain client: asked again over the game connection for %d blocks the block line had not delivered" % stream.ask_again_waiting())

	var wanted: Array = [PackedInt32Array(), 0] if _building_paused else stream.take_requests()

	if not wanted[0].is_empty() and not link.send_request(wanted[0], wanted[1]):
		net.request_blocks.rpc_id(1, wanted[0], wanted[1])

	var now: int = Time.get_ticks_msec()

	# Tell the server where we are heading so it makes that ground first.
	if now - _aim_msec >= 200:
		send_position_now()

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
					FreezeWatchScript.printer.line("Terrain client: cache over %d MB, removed %d far tiles" % [cache_mb, _cache_removed])

			var p: Vector3 = body.global_position
			_cache_tile = cache.tile_of_block(Vector3i(int(floor(p.x / 16.0)), 0, int(floor(p.z / 16.0))), 0)
			_cache_removed = 0
			_cache_task = WorkerThreadPool.add_task(_cache_upkeep)

	settled_msec = stream.last_load_msec - connected_msec

	var ti: int = Probe.start()
	_send_water_request(now)
	_apply_incoming()
	_apply_flow()
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

	if body != null and items != null and trail_signs != null:
		trail_signs.update(body.global_position, int(items.skill_level_of("tracking")), _world_loading())   # at most twice a second, never while loading

	if fresh_tracks != null and items != null:
		fresh_tracks.tracking = int(items.skill_level_of("tracking"))
		fresh_tracks.update()

	if (not flying or grass_while_flying) and body != null:
		var tg: int = Probe.start()
		grass.update(body.global_position)
		var tg_stamp: int = Probe.start()

		# Stamped behind the player, out of view, so no grass is seen dropping flat in front of the camera
		# (owner, 2026-10-20: "popping in and out of existence right in front of me").
		var walk: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)

		if body.is_on_floor() and walk.length() > 0.5:
			grass.stamp(body.global_position - walk.normalized() * 1.3)

		_stamp_walkers(now)
		Probe.stop("grass: stamp", tg_stamp)
		Probe.stop("grass", tg)

	if _bake != null and _bake.running and now >= _bake_check_msec:
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
			FreezeWatchScript.printer.line("Terrain client: " + str(finished))

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
			@warning_ignore("integer_division")
			var kind: String = kinds[step / moods.size()]
			var at: Vector3 = body.global_position + Vector3(30.0, 2.0, 0.0)
			FreezeWatchScript.printer.line("Terrain client: creature test %s %s -> %s" % [kind, moods[step % moods.size()], sound.creatures.call_at(kind, at, moods[step % moods.size()])])
		elif step < kinds.size() * moods.size() + 8:
			FreezeWatchScript.printer.line("Terrain client: creature zone test -> %s" % sound.creatures.call_in_zone(["forest", "meadow", "highland", "water"][step % 4], "idle"))
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
			FreezeWatchScript.printer.line("Terrain client: exertion check done: %d breaths, %d heartbeats, last %s" % [sound.breath.breaths_played, sound.breath.beats_played, sound.breath.last])
		else:
			sound.breath.set_exertion(levels[step])
			if fmod(_test_exertion_t, 5.0) < get_process_delta_time():
				FreezeWatchScript.printer.line("Terrain client: exertion %.2f: %d breaths, %d heartbeats so far" % [levels[step], sound.breath.breaths_played, sound.breath.beats_played])

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
			FreezeWatchScript.printer.line("Terrain client: flame held '%s', loops %d, last %s" % [sound.flame.held, sound.flame._loops.size(), sound.flame.last])
			sound.weather.set_weather("rain", 1.0)

		if before < 9.0 and _test_flame_t >= 9.0:
			FreezeWatchScript.printer.line("Terrain client: flame in rain: loops %s" % str(sound.flame._loops.keys()))
			held.select(7)

		if before < 12.0 and _test_flame_t >= 12.0:
			FreezeWatchScript.printer.line("Terrain client: flame put away: held '%s', loops %d" % [sound.flame.held, sound.flame._loops.size()])
			test_flame = false

	# Headless check: make twine (twine), a stone axe (knap) and a campfire (stack) through the panel's craft timer.
	if test_craft_sounds and now - connected_msec > 18000:
		if _test_craft_t < 0.0:
			_test_craft_t = 0.0
			items.admin_give_test_set()

		var before: float = _test_craft_t
		_test_craft_t += get_process_delta_time()

		for at in [[2.0, 1], [6.0, 2], [11.0, 4]]:
			if before < at[0] and _test_craft_t >= at[0]:
				items._start_craft(at[1])
				FreezeWatchScript.printer.line("Terrain client: craft %d started, can_make %s, queue %d" % [at[1], items.recipes.can_make(at[1], items.inventory), items.craft_entries.size()])

		for at in [5.0, 10.0, 16.0]:
			if before < at and _test_craft_t >= at:
				FreezeWatchScript.printer.line("Terrain client: craft work sounds %d, last %s" % [sound.itemfx.work_played, sound.itemfx.last_work])

		if _test_craft_t > 16.5:
			test_craft_sounds = false

	# Headless check: strikes at 300, 1000 and 2500 m take the plain, mid and far thunder buses with a scaled, capped delay.
	if test_distant and now - connected_msec > 18000:
		test_distant = false

		for metres in [300.0, 1000.0, 2500.0]:
			sound.weather.strike(metres)
			FreezeWatchScript.printer.line("Terrain client: thunder %s" % sound.weather.last_thunder)

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
			FreezeWatchScript.printer.line("Terrain client: wear sounds %s, last %s" % [str(sound.placed.played), sound.placed.last])

	# Headless check: the tree counts around the player and the wind-in-trees loops they start.
	if test_treewind and now - connected_msec > 18000:
		var before_tw: float = _test_treewind_t
		_test_treewind_t = maxf(_test_treewind_t, 0.0) + get_process_delta_time()

		for at in [4.0, 12.0, 20.0]:
			if before_tw < at and _test_treewind_t >= at:
				FreezeWatchScript.printer.line("Terrain client: tree wind: conifer %.2f, broadleaf %.2f, wind %.2f, playing %s" % [sound.treewind._density["conifer"], sound.treewind._density["broadleaf"], sound.wind_strength, sound.treewind.summary])

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
			FreezeWatchScript.printer.line("Terrain client: workshop sounds %s, saw loops %d, last %s" % [str(sound.workshop.played), sound.workshop.loops_playing, sound.workshop.last])
			sound.workshop.set_saws([])

		if before_ws < 9.0 and _test_workshop_t >= 9.0:
			FreezeWatchScript.printer.line("Terrain client: workshop saw loops after stop %d" % sound.workshop.loops_playing)
			test_workshop = false

	# Headless check: the cooking and eating sounds play (sizzle and fuel at a spot beside the player, then each way of eating).
	if test_cooking and now - connected_msec > 18000:
		test_cooking = false
		var spot: Vector3 = body.global_position + Vector3(1.5, 0.0, 0.0)
		sound.fire.cook(spot)
		sound.fire.fuel(spot)

		for kind in ["drink", "roast_forage", "raspberries", "poultice_plantain", "bandage_plantain"]:   # food is silent (Dave 17 Nov 2026): 3 sounds
			sound.itemfx.eat(kind)

		# A mouthful at the water's edge (Dave 2026-10-21): E sends the drink, the server raises thirst, the gulp plays; a rise without E is silent.
		items.thirst = 50
		var before_drink: int = sound.itemfx.eat_played
		items._on_vitals(items.hunger, items.health, int(items.weight_kg * 10.0), 60, items.luck, items.fitness)
		var silent_rise: int = sound.itemfx.eat_played - before_drink
		items._drink_msec = Time.get_ticks_msec()
		items._on_vitals(items.hunger, items.health, int(items.weight_kg * 10.0), 70, items.luck, items.fitness)
		FreezeWatchScript.printer.line("Terrain client: drink check: %d gulps without E, %d gulp after E, last %s" % [silent_rise, sound.itemfx.eat_played - before_drink - silent_rise, sound.itemfx.last])

		FreezeWatchScript.printer.line("Terrain client: cooking sounds: sizzle %d, fuel %d, eaten %d, last fire %s, last item %s" % [sound.fire.cook_played, sound.fire.fuel_played, sound.itemfx.eat_played, sound.fire.last, sound.itemfx.last])

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
		sound.placed.quiet = false   # this check hears the hooks, not the join
		sound.placed.watch_world({}, here)
		sound.placed.watch_world({7: {"state": 6, "pos": here}}, here)
		sound.placed.watch_world({}, here)
		FreezeWatchScript.printer.line("Terrain client: placed sounds %s, last %s" % [str(sound.placed.played), sound.placed.last])
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
		FreezeWatchScript.printer.line("Terrain client: structure check: %d uses, unknown %s, lock and knock %d, played %d, watched flips %d, last %s" % [kinds_played, str(unknown_kind), lock_knock, direct, sound.interior.objects_played - objects_before, sound.interior.last])
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

		FreezeWatchScript.printer.line("Terrain client: levels set:%s" % report)

		@warning_ignore("shadowed_variable_base_class")
		for name in sound.levels:
			sound.set_level(name, 1.0)

		FreezeWatchScript.printer.line("Terrain client: levels back to 100 %%: %s" % str(sound.levels))

	# Headless check: place, light, grow, rain on, put out, light, remove.
	if test_fire and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 1200
		FreezeWatchScript.printer.line("Terrain client: fire step %d: %s" % [_test_fire_step, sound_tests.fire_step(_test_fire_step, body.global_position + Vector3(3.0, 0.0, 0.0))])
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
			FreezeWatchScript.printer.line("Terrain client: ui sounds: %d hotbar ticks, last %s" % [sound.itemfx.hotbar_played, sound.itemfx.last])
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
			FreezeWatchScript.printer.line("Terrain client: lake laps: %d laps calm, %d laps windy, last %s; brook loop %s; kinds %s; flowing near lake kept %d of 3 (silenced %d)" % [_lake_calm_laps, water.laps_played - _lake_calm_laps, water.last_lap, water.brook_tag(), table, kept, water.lake_silenced])
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
			FreezeWatchScript.printer.line("Terrain client: ice: frozen walkable %s, %d groans, %d laps, %d cracks in 40 hard steps, last %s; thaw walkable %s, %d new groans, %d new laps" % [
				_ice_report.get_slice(" ", 0), int(_ice_report.get_slice(" ", 1)), int(_ice_report.get_slice(" ", 2)), int(_ice_report.get_slice(" ", 3)),
				_ice_report.get_slice(" ", 4, ), str(ice.walkable()), ice.groans_played - int(_ice_report.get_slice(" ", 1)), water2.laps_played - int(_ice_report.get_slice(" ", 2))])
			water2.test_shore = []

	# Wind in structures (job 89): five set-ups three seconds each; the report holds whistle and moan levels in dB (-80 stopped).
	if test_windhole and now - connected_msec > 18000:
		var hole = sound.windhole
		var phases: Array = [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.5), Vector3(1.0, 1.0, 1.0), Vector3(0.2, 1.0, 0.0)]
		@warning_ignore("integer_division")
		var step: int = int((now - connected_msec - 18000) / 3000)

		if step < phases.size():
			hole.test_inputs = phases[step]

			if (now - connected_msec - 18000) % 3000 > 2500 and _windhole_report.size() == step:
				_windhole_report.append("%.0f %.0f" % [hole.player_db("wind_whistle"), hole.player_db("wind_hollow")])
		elif test_windhole:
			test_windhole = false
			hole.test_inputs = Vector3(-1.0, 0.0, 0.0)
			FreezeWatchScript.printer.line("Terrain client: wind hole: open %s, lean-to %s, mouth %s, tunnel %s, calm %s (whistle and moan dB, -80 off)" % _windhole_report)

	if test_voice_priority and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		FreezeWatchScript.printer.line("Terrain client: voice priority: " + sound.test_priority(body))

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
				@warning_ignore("integer_division")
				FreezeWatchScript.printer.line("Terrain client: sweep cell %s %02d:00 calls %d voices %d  %s" % [seasons[done / 8], (done % 8) * 3, total, _sweep_peak, str(sound.ambient.calls_played)])

		if _sweep_step < cells:
			_sweep_step += 1

			if _sweep_step < cells:
				@warning_ignore("integer_division")
				sound.ambient.set_conditions(float((_sweep_step % 8) * 3), seasons[_sweep_step / 8], "clear")
				sound.ambient.calls_played = {}
				_sweep_peak = 0
		elif _sweep_step == cells:
			_sweep_step += 1
			FreezeWatchScript.printer.line("Terrain client: sweep done: %d cells, peak %d of %d voices, shed %d" % [cells, _sweep_max, sound.voice_cap, sound.shed_count])

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
		FreezeWatchScript.printer.line("Terrain client: emitter test: creature wolf %s deer %s, burst %d of 6 played, %d dropped, unknown %s, 17 rows -> %d loops, %d merged" % [str(wolf), str(deer), burst, em.dropped_rate, str(nothing), em.loops_playing(), em.merged_loops])

	if test_mix_levels:
		sound.track_peaks = now - connected_msec > 20000

		if now - connected_msec > 50000 and test_mix_levels:
			test_mix_levels = false
			sound.track_peaks = false
			FreezeWatchScript.printer.line("Terrain client: mix levels: " + sound.mix_table())

	if test_landing and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		sound.landing.hurt.connect(func(drop, severity): _hurts.append([drop, severity]))

		sound.landing.landings = {}
		_hurts = []

		for drop in [1.0, 3.0, 7.0]:
			sound.landing.land(body, drop)

		var counts: Dictionary = sound.landing.landings
		FreezeWatchScript.printer.line("Terrain client: landing check: step %d thud %d hard %d, %d hurt signals, severity %.2f, last %s" % [int(counts.get("step", 0)), int(counts.get("thud", 0)), int(counts.get("hard", 0)), _hurts.size(), float(_hurts[0][1]) if not _hurts.is_empty() else -1.0, sound.landing.last])

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

		FreezeWatchScript.printer.line("Terrain client: stepfx check: wet %.2f, %d squelches in 10 steps, wetness after 10 s %.2f, after 25 s %.2f, %d squelches when dry, %d cloth steps, last %s" % [wet_start, squelched, half, fx.wetness, fx.squelches - dry_before, fx.cloth_steps, fx.last])

	if test_swing and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var before: int = sound.hits.swings_played
		var heard: Array = []

		for tool in sound.hits.TOOLS:
			heard.append(sound.hits.swing(tool, body.global_position + Vector3(0.0, 1.0, -0.6)))

		FreezeWatchScript.printer.line("Terrain client: swing check: %d swings, unknown tool %s, last %s" % [sound.hits.swings_played - before, str(sound.hits.swing("sword", body.global_position)), sound.hits.last_swing])

	if test_insects and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0, "wetland": 0.0}
		var levels: Array = []
		sound.weather.rain = 0.0
		sound.wind_strength = 0.3
		sound.cave.enclosure = 0.0

		for combo in [["summer", 13.0], ["summer", 2.0], ["winter", 13.0], ["spring", 13.0], ["summer", 5.7], ["summer", 20.8]]:
			amb.set_conditions(float(combo[1]), str(combo[0]), "clear")
			levels.append("%.2f" % sound.insects.target())

		amb.set_conditions(13.0, "summer", "clear")
		amb.weights = {"forest": 0.0, "meadow": 0.0, "water": 1.0, "highland": 0.0, "wetland": 0.0}
		var lake_noon: String = "%.2f" % sound.insects.target()
		var lake_cricket: bool = amb._water_day()
		amb.set_conditions(2.0, "summer", "clear")
		var lake_night: String = "%.2f" % sound.insects.target()
		amb.set_conditions(13.0, "summer", "clear")
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0, "wetland": 0.0}
		sound.weather.rain = 1.0
		levels.append("%.2f" % sound.insects.target())
		sound.weather.rain = 0.0
		sound.insects.level = 0.9
		sound.insects.update(0.1)
		FreezeWatchScript.printer.line("Terrain client: insect check: summer noon %s, summer 2h %s, winter noon %s, spring noon %s, sunrise edge %s, sunset edge %s, rain %s, playing %d, lake noon %s, lake 2h %s, lake day %s" % (levels + [sound.insects.voices_playing(), lake_noon, lake_night, str(lake_cricket)]))

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

		FreezeWatchScript.printer.line("Terrain client: variety check: whistle by hour %s, crow at noon %.1f, trill/crow by season %s, repeats in a minute %d, back-to-back %d, back-to-back of 3 %d" % [",".join(ratios), crow_noon, ",".join(seasons), repeats, run_repeats, small_repeats])

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
		FreezeWatchScript.printer.line("Terrain client: meters check: calls before %d, %d lines, Master line %s, World line %s, latency line %s, calls after %d, repeat same size %s" % [before_calls, meter_lines, str(meter_text.contains("Master")), str(meter_text.contains("World")), str(meter_text.contains("latency")), sound.meters_calls, str(second.split("\n").size() == meter_lines)])

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
		@warning_ignore("shadowed_variable")
		var weather = sound.weather
		weather.rain = 1.0
		weather.rain_heard = 1.0   # the drops read the level the sky shows (BUG-004)
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
		weather.rain_heard = 0.5
		before = sp.drops_played

		for n in 50:
			sp.update(0.1, body, false)
			sp.test_release()

		var half_drops: int = sp.drops_played - before
		weather.rain = 0.0
		weather.rain_heard = 0.0
		weather.covered = 0.0
		FreezeWatchScript.printer.line("Terrain client: splash check: %d grounds played, unknown %s, burst %d of 40 (cap %d, live %d), 5 s of heavy rain %d, covered %d, roofed %d, half rain %d, rate %.1f %.1f %.1f, last %s" % [
			played, str(unknown), burst, cap_now, live_now, open_drops, covered_drops, roofed_drops, half_drops, sp.rate(1.0, 0.0, 0.0, false), sp.rate(1.0, 0.0, 0.0, true), sp.rate(0.05, 0.0, 0.0, false), sp.last])
		sound.set_quality(1)

	if test_reverb and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		@warning_ignore("shadowed_variable")
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

		FreezeWatchScript.printer.line("Terrain client: reverb check: %s; reverbs %d, World sends %s, Foley sends %s, Nature sends %s, World before Foley %s" % ["; ".join(rows), reverbs, AudioServer.get_bus_send(world), AudioServer.get_bus_send(AudioServer.get_bus_index("Foley")), AudioServer.get_bus_send(AudioServer.get_bus_index("Nature")), str(world < AudioServer.get_bus_index("Foley"))])
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

		sound.ambient.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0, "wetland": 0.0}
		sound.weather.roofed = 0.0
		sound.cave.enclosure = 0.0
		sound.occlusion._scan(body, false)
		var open_buses: Array = []

		for voice in made:
			open_buses.append(str(voice.bus))

		sound.ambient.weights = {"forest": 1.0, "meadow": 0.0, "water": 0.0, "highland": 0.0, "wetland": 0.0}
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

		FreezeWatchScript.printer.line("Terrain client: air check: open falls %s, forest falls %s, open fires %s, forest fires %s, roofed fire %s, thunder %s %s %s, hold %d up %d, filters %d, shed parent %s" % [
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

		@warning_ignore("unused_variable")
		var crow: bool = amb.flush(body.global_position + Vector3(20.0, 2.0, 0.0), 0.0, "large")
		var crow_file: String = amb.last_file
		FreezeWatchScript.printer.line("Terrain client: flush check: %d flushes, small %d, medium %d, large %d, files used %d, repeats %d, crow file %s, source %s" % [300, sizes["small"], sizes["medium"], sizes["large"], files.size(), repeats, crow_file, amb._source.get("wing_small", "?")])
		# Flying high above the forest (Dave 2026-10-21): no take-off, no alarm, no bird calls.
		var low_before: float = amb.low_factor()
		amb.forced_agl = 120.0
		amb.agl_m = 120.0
		FreezeWatchScript.printer.line("Terrain client: high birds: low factor %.2f then %.2f, flush %s, alarm %s" % [low_before, amb.low_factor(), str(amb.flush(body.global_position + Vector3(20.0, 2.0, 0.0), 0.0)), str(amb.alarm(body.global_position + Vector3(20.0, 2.0, 0.0)))])
		amb.forced_agl = -1.0

	if test_reject and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var first: bool = sound.itemfx.reject("far")
		var again: bool = sound.itemfx.reject("far")
		FreezeWatchScript.printer.line("Terrain client: reject check: first %s, held key %s, played %d, last %s" % [str(first), str(again), sound.itemfx.rejects_played, sound.itemfx.last])

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
		FreezeWatchScript.printer.line("Terrain client: step levels: source %s, grass walk %.1f, stone run %.1f, plank walk %.1f, tweaked grass walk %.1f, after a broken file %.1f" % [source, grass_walk, stone_run, plank_walk, tweaked, sound.step_level_db("grass", 0)])

	if test_night and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 10000000
		var amb = sound.ambient
		amb.weights = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0, "wetland": 0.0}
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
		FreezeWatchScript.printer.line("Terrain client: night check: insects summer %s, spring %s, winter %s, day %s; wolf factor winter %.1f summer %.1f; owl answers %d; wild %s" % [night_levels[0], night_levels[1], night_levels[2], night_levels[3], wolf_winter, wolf_summer, amb.answers_played, str(sound.creatures.wild)])

	# Stance sounds: crouch, stand, sit, stand, lie (and sit for 20 s to hear settles), stand.
	if test_stance and now - connected_msec > 18000 and now >= _test_fire_at:
		_test_fire_at = now + 1500
		var order: Array = ["crouch", "stand", "sit", "stand", "lie", "stand"]

		if _stance_step < order.size():
			sound.gear.set_worn(["cloth", "plate"])
			sound.stance.set_stance(order[_stance_step])
			_stance_step += 1
		elif _stance_step == order.size():
			FreezeWatchScript.printer.line("Terrain client: stance check: %d changes, %d settles, crouch step %.0f dB, last %s" % [sound.stance.changes_played, sound.stance.settles_played, sound.stance.step_db(), sound.stance.last])
			_stance_step += 1

	# Distant fires and falls merge: one near fire and six far hearths, five far falls in a valley.
	if test_merge and now - connected_msec > 18000:
		sound.fire.hold_manual(60.0)
		var base: Vector3 = body.global_position

		if _merge_step == 0:
			var list: Array = [{"id": 1, "at": base + Vector3(5.0, 0.0, 0.0), "size": 0.5, "lit": true, "open": true}]

			for n in range(6):
				@warning_ignore("integer_division")
				list.append({"id": 10 + n, "at": base + Vector3(27.0 + float(n % 3) * 3.0, 0.0, float(n / 3) * 3.0), "size": 0.5, "lit": true, "open": true})

			sound.fire.set_fires(list)
			var falls: Array = []

			for n in range(5):
				falls.append({"kind": "fall", "at": base + Vector3(150.0 + float(n) * 8.0, 0.0, 0.0), "distance": 150.0 + float(n) * 8.0, "drop": 6.0, "speed": -1.0, "width": 4.0, "score": 0.6})

			falls.append({"kind": "fall", "at": base + Vector3(60.0, 0.0, 0.0), "distance": 60.0, "drop": 6.0, "speed": -1.0, "width": 4.0, "score": 0.3})
			var out: Array = sound.water._merge_far_falls(falls, base)
			FreezeWatchScript.printer.line("Terrain client: merge check: falls 6 -> %d voices, %d merged, widest %.0f" % [out.size(), sound.water.merged_falls, out.reduce(func(m, f): return maxf(m, float(f["width"])), 0.0)])

		if _merge_step == 0:
			sound.water._pick_base([{"kind": "fall", "at": base + Vector3(10.0, 0.0, 0.0), "distance": 10.0, "drop": 8.0, "width": 8.0}])

		if _merge_step == 120:
			FreezeWatchScript.printer.line("Terrain client: fall base: playing %s at %.1f dB (target %.1f), drop %.0f m" % [str(sound.water._base.playing), sound.water._base.volume_db, sound.water._base_db, sound.water.base_fall_drop])
			FreezeWatchScript.printer.line("Terrain client: merge check: fires 7 -> %d loops, %d merged" % [sound.fire._loops.size(), sound.fire.merged_fires])

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
					@warning_ignore("shadowed_variable")
					var stream: AudioStream = sound.load_for_audit(dir, file.get_basename())
					count += 1 if stream != null else 0

		FreezeWatchScript.printer.line("Terrain client: sound memory audit: %d files loaded, %s, static memory +%.1f MB" % [count, sound.audit_text(), float(OS.get_static_memory_usage() - before) / 1048576.0])

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
			FreezeWatchScript.printer.line("Terrain client: spear jab -> %s" % sound.spear.jab(body.global_position + Vector3(1.0, 0.0, 0.0)))
		elif _test_spear_step <= spear_materials.size():
			var material: String = spear_materials[_test_spear_step - 1]
			var flight_s: float = sound.spear.throw(body.global_position + Vector3(0.0, 1.5, 0.0), body.global_position + Vector3(25.0, 1.0, 5.0), 28.0, material)
			FreezeWatchScript.printer.line("Terrain client: spear throw into %s -> flight %.2f s" % [material, flight_s])
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
			FreezeWatchScript.printer.line("Terrain client: interior check: amount %.2f, enclosure %.2f, covered %.1f" % [sound.interior.amount, sound.cave.enclosure, sound.weather.covered])
			sound.interior.set_inside(0.0)

	# Headless check: more sounds than the tier's voice cap, then the shedding.
	if test_flood and now - connected_msec > 18000:
		test_flood = false

		for n in range(80):
			@warning_ignore("integer_division")
			sound.hits.hit("axe", "wood", body.global_position + Vector3(float(n % 20) * 5.0 + 3.0, 0.0, float(n / 20) * 10.0), 1.0)

		var before: int = sound.voices_playing()
		sound._shed(body, maxi(before - sound.voice_cap, 0))
		FreezeWatchScript.printer.line("Terrain client: flood: %d playing before (cap %d, tier %s), shed %d, %d playing right after" % [before, sound.voice_cap, sound.Presets.NAMES[sound.tier], sound.shed_count, sound.voices_playing()])

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

	if not _ditch.is_empty() and now - connected_msec > 20000 and now >= _ditch_next_msec:
		_ditch_next_msec = now + 500
		var at: Vector2 = _ditch.pop_front()
		var hit = terrain.get_voxel_tool().raycast(Vector3(at.x, 400.0, at.y), Vector3.DOWN, 800.0)

		if hit != null:
			net.dig.rpc_id(1, Vector3(at.x, hit.position.y, at.y), 1.5)
			FreezeWatchScript.printer.line("Terrain client: ditch dig at %.1f, %.1f, %.1f (%d left)" % [at.x, float(hit.position.y), at.y, _ditch.size()])
		else:
			FreezeWatchScript.printer.line("Terrain client: ditch dig at %.1f, %.1f: no ground loaded there yet" % [at.x, at.y])

	if test_dig_check and now - connected_msec > 24000:
		test_dig_check = false
		var probe_tool: VoxelTool = terrain.get_voxel_tool()
		var centre: Vector3 = Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0)
		FreezeWatchScript.printer.line("Terrain client: dig check: ground value at the old hole %.2f (above 0 is open), 12 m away %.2f" % [probe_tool.get_voxel_f(Vector3i(centre.round())), probe_tool.get_voxel_f(Vector3i((centre + Vector3(12.0, 0.0, 0.0)).round()))])

	if frames_left > 0 and now >= _report_msec:
		_report_msec = now + 10000
		@warning_ignore("integer_division")
		FreezeWatchScript.printer.line("client: %d s, %d blocks loaded, %d from the server (%.1f MB), %d waiting, %d fps, at %s" % [
			(now - connected_msec) / 1000, stream.loads, stream.blocks_received,
			float(stream.bytes_received) / 1048576.0, stream.pending(), Engine.get_frames_per_second(), str(body.global_position.round())
		])

	# No movement-state label (flying, running): the player knows. Only status notices show here.
	var mode: String = ""

	if inspecting:
		_update_inspect()

	if _inspect_plus != null:
		_inspect_plus.show_if(InspectReticleScript.shown(inspecting, held != null and held.aim_cross_shown(), not photo.active and not spyglass.active and (shot_lock or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)))

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
	_note_sound_now(delta)
	hud.text = "build %d (%s)  %d fps (vsync %s)  %s (Ctrl+Shift+F2)\nx %.0f  y %.1f  z %.0f\nlast sound: %s\nplaying: %s" % [BUILD, _commit, Engine.get_frames_per_second(), "off" if display.vsync_index == 2 else display.VSYNC_NAMES[display.vsync_index], QUALITY_NAMES[quality], body.global_position.x, body.global_position.y, body.global_position.z, _last_sound, _sound_now]
	hud.text += "\n" + _ground_health_line()

	if crash_report != null and crash_report.last_report != "" and Time.get_ticks_msec() < _previous_run_note_until_msec:
		hud.text += "\nLast run did not close cleanly. %s\nReport: %s" % [crash_report.last_plain if crash_report.last_plain != "" else "The game quit for a bad reason.", crash_report.last_report]

	if debug_hud.enabled:
		hud.text += "\n" + _debug_text(avg_ms, worst_ms)

	if _bake_status != "":
		hud.text += "\n" + _bake_status

	if frames_left > 0:
		frames_left -= 1

		if frames_left == 0:
			if test_fly and _fly_stop_msec > 0:
				FreezeWatchScript.printer.line("Terrain client: ground collider under the player %s ms after stopping (altitude %.0f)" % [str(_fly_ground_msec - _fly_stop_msec) if _fly_ground_msec > 0 else "never", body.global_position.y])

				for lod in range(6):
					FreezeWatchScript.printer.line("Terrain client: under the stop point, LOD %d first asked %s, loaded %s (ms after stopping)" % [
						lod,
						str(stream.watch_asked[lod] - _fly_stop_msec) if stream.watch_asked.has(lod) else "never",
						str(stream.watch_loaded[lod] - _fly_stop_msec) if stream.watch_loaded.has(lod) else "never",
					])

			FreezeWatchScript.printer.line("Terrain client: last block asked for %d ms after the welcome; %d blocks loaded; %d from the server (%.2f MB, %.0f bytes each), %d from the cache, %d cache misses, %d timeouts, %d still waiting, %d prefetched blocks used" % [
				settled_msec, stream.loads, stream.blocks_received, float(stream.bytes_received) / 1048576.0,
				float(stream.bytes_received) / maxf(float(stream.blocks_received), 1.0), cache.hits, cache.misses, stream.timeouts, stream.pending(), stream.prefetch_used
			])
			FreezeWatchScript.printer.line("Terrain client: cache folder %.1f MB" % (float(cache.size_bytes()) / 1048576.0))
			FreezeWatchScript.printer.line("Terrain client: flora %d chunks (%.2f MB with water, last %d ms after the welcome), %d items held, %d drawn, %d colliders, %d cuts; water in %d chunks, %d cells" % [
				_flora_chunks, float(_flora_bytes) / 1048576.0, _flora_done_msec, flora.item_count(), flora.instances, flora.colliders, _flora_cuts,
				flora.water_chunks, flora.water_cells
			])
			var stats: Dictionary = flora.draw_stats()
			FreezeWatchScript.printer.line("Terrain client: flora draws: %s nodes (tree, shrub, plant) for %s instances, %d nodes under 50 instances" % [str(stats["nodes"]), str(stats["instances"]), int(stats["small"])])
			FreezeWatchScript.printer.line("Terrain client: fall columns: %d meshes drawn (cap %d per chunk)" % [flora.falls_drawn, flora.fall_cap])
			FreezeWatchScript.printer.line("Terrain client: cover index %d tree crowns in %d chunks" % [flora.cover.trees, flora.cover.chunk_count()])
			FreezeWatchScript.printer.line("Terrain client: grass %d tufts in %d cells (radius %.0f m), %d MultiMesh draws" % [grass.tufts, grass.cells_built, grass.radius_m, grass.draw_nodes])
			FreezeWatchScript.printer.line("Terrain client: water sounds: %s (%d falls known)" % [sound.water.summary, flora.fall_list().size()])
			FreezeWatchScript.printer.line("Terrain client: nature calls %s, zones %s" % [str(sound.ambient.calls_played), str(sound.ambient.weights)])
			FreezeWatchScript.printer.line("Terrain client: tree sounds: %d falls, %d stump sprays, last %s" % [sound.trees.falls_played, sound.trees.chips_played, sound.trees.last])
			FreezeWatchScript.printer.line("Terrain client: faint run: world muted to %.2f, heart gain down to %.2f, %d heaves, %d heartbeats, done %s, breaths while fainted %d, wake mute %.2f, bpm max %.0f, step %.2f" % [sound.breath.peak_mute, sound.breath.demo_min_gain, sound.breath.heaves_played, sound.breath.beats_played, str(sound.breath.demo_done), sound.breath.fainted_breaths, sound.breath.wake_mute_mid, sound.breath.bpm_max, sound.breath.bpm_step_max])
			FreezeWatchScript.printer.line("Terrain client: fire world: %d fuel, %d lit, %d out" % [sound.fire.fuel_played, sound.fire.lit_played, sound.fire.out_played])
			FreezeWatchScript.printer.line("Terrain client: fire sounds: %d lit, %d put out, %d loops, last %s" % [sound.fire.lit_played, sound.fire.out_played, sound.fire.loops_playing, sound.fire.last])
			FreezeWatchScript.printer.line("Terrain client: item sounds %d, last %s" % [sound.itemfx.played, sound.itemfx.last])
			var kinds: Dictionary = {}

			for row_id in harvest._flora_by_id:
				var row: Dictionary = harvest._flora_by_id[row_id]

				if row.get("kind", "") != "tree":
					var k: String = sound.harvestfx.pick_kind(row)
					kinds[k] = int(kinds.get(k, 0)) + 1

			FreezeWatchScript.printer.line("Terrain client: harvest sounds %s, last %s; plant kinds %s" % [str(sound.harvestfx.played), sound.harvestfx.last, str(kinds)])
			FreezeWatchScript.printer.line("Terrain client: spear sounds %s, last %s" % [str(sound.spear.played), sound.spear.last])
			FreezeWatchScript.printer.line("Terrain client: interior sounds: %d objects, %d creaks, last %s" % [sound.interior.objects_played, sound.interior.creaks_played, sound.interior.last])
			FreezeWatchScript.printer.line("Terrain client: gear: worn %s, %d steps, last %s" % [str(sound.gear.worn), sound.gear.steps_played, sound.gear.last])
			FreezeWatchScript.printer.line("Terrain client: creature calls %s, last %s" % [str(sound.creatures.calls_played), sound.creatures.last])
			FreezeWatchScript.printer.line("Terrain client: sounds shed over the cap: %d" % sound.shed_count)
			FreezeWatchScript.printer.line("Terrain client: interface sounds %d played, last %s" % [sound.ui.played, sound.ui.last])
			FreezeWatchScript.printer.line("Terrain client: swim sounds %d splashes, %d strokes, %d dives, %d surfacings, last %s" % [sound.swim.splashes, sound.swim.strokes, sound.swim.dives, sound.swim.surfaces, sound.swim.last])
			FreezeWatchScript.printer.line("Terrain client: town sounds %d loops, %d bells" % [sound.town.loops_playing, sound.town.bells_rung])
			FreezeWatchScript.printer.line("Terrain client: tool hits %d, last %s" % [sound.hits.hits_played, sound.hits.last_hit])
			FreezeWatchScript.printer.line("Terrain client: muffled sounds: %d filtered, %d behind hills" % [sound.occlusion.filtered, sound.occlusion.occluded])
			FreezeWatchScript.printer.line("Terrain client: cave enclosure %.2f, drips %d" % [sound.cave.enclosure, sound.cave.drips_played])
			FreezeWatchScript.printer.line("Terrain client: dig sounds %s, last %s" % [str(sound.dig.digs_played), sound.dig.last_dig])
			FreezeWatchScript.printer.line("Terrain client: " + str(sound.wind_text()))
			FreezeWatchScript.printer.line("Terrain client: " + str(sound.heard_text(body).replace("\n", " | ")))
			FreezeWatchScript.printer.line("Terrain client: " + str(sound.ambient_dump(body).replace("\n", " | ")))
			FreezeWatchScript.printer.line("Terrain client: sound budget: %s, %d loads refused" % [sound.budget_text(), sound.refused_loads])
			FreezeWatchScript.printer.line("Terrain client: snow hush %.2f (nature bus %.1f dB, wind bus %.1f dB)" % [sound.weather.snow_hush, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Nature")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Wind"))])
			FreezeWatchScript.printer.line("Terrain client: rain ground %s (weights %s)" % [sound.weather.ground_class, str(sound.weather._ground_w)])
			FreezeWatchScript.printer.line("Terrain client: weather %s rain %.2f wind %.2f calls %.2f thunders %d; ground wet %.2f snow %.2f, covered %.1f, puddle splashes %d, leaf drips %d, roofed %.1f, loops %s" % [sound.weather.kind, sound.weather.rain, sound.weather.wind, sound.weather.calls, sound.weather.thunders_played, sound.weather.ground_wet, sound.weather.ground_snow, sound.weather.covered, sound.puddles_played, sound.weather.drips_played, sound.weather.roofed, str(sound.weather.active_loops().map(func(entry): return entry[0]))])
			FreezeWatchScript.printer.line("Terrain client: sound: footsteps %s, grass swishes %d, last ground %s, gust %.2f" % [str(sound.steps_played), sound.swishes_played, sound.surface, sound.gust])
			if _npc_view != null:
				var near_npc: Dictionary = _npc_view.nearest(body.global_position, 100000.0)
				FreezeWatchScript.printer.line("Terrain client: npcs drawn %d (roster %d), nearest %s, player at %.0f %.0f" % [_npc_view.drawn_count(), _npc_view.roster.size(), str(near_npc.get("name", "none")) + (" %.1f m away" % Vector2(near_npc["pos"].x - body.global_position.x, near_npc["pos"].z - body.global_position.z).length() if not near_npc.is_empty() else ""), body.global_position.x, body.global_position.z])

			FreezeWatchScript.printer.line("Terrain client: blocks waited for %d times, %.0f ms on average, worst %d ms; at most %d loader threads waiting at once; %d blocks came on the block line" % [stream.waits, float(stream.wait_msec_total) / maxf(float(stream.waits), 1.0), stream.wait_msec_worst, stream.most_waiting, link.blocks_in])
			FreezeWatchScript.printer.line(str(Probe.report()))
			var probe: Vector3i = Vector3i((Vector3(world["spawn"]) + Vector3(0.0, -3.0, 0.0)).round())
			FreezeWatchScript.printer.line("Terrain client: ground value 3 m under the spawn %.2f (above 0 is open)" % terrain.get_voxel_tool().get_voxel_f(probe))
			_finish(0)


# Headless walking check (--walk): lands on the ground, walks east without
# falling through, and is stopped by a tree trunk.

# Debug details (Dave 2026-10-20: the default HUD is only build, position and the last sound).
# Any thread that wants a diagnostic line on screen registers a Callable returning a String with
# debug_hud (debug_hud.add_line(name, callable), see src/client/debug_hud.gd); it is only called
# while Debug details is on (Ctrl+Shift+F3, or Esc > Settings).
func _debug_text(avg_ms: float, worst_ms: float) -> String:
	var text: String = "avg %.1f ms  worst %.1f ms  quality %s (Ctrl+Shift+F2)\nmem %.0f MB\nblocks: %d from server (%.1f MB), %d from cache\nflora: %d drawn, %d colliders, grass %d" % [
		avg_ms, worst_ms, QUALITY_NAMES[quality],
		float(OS.get_static_memory_usage()) / 1048576.0,
		stream.blocks_received, float(stream.bytes_received) / 1048576.0, cache.hits, flora.instances, flora.colliders, grass.tufts
	]

	var vp: RID = get_viewport().get_viewport_rid()
	text += "\ngame time: year %d, day %d (%s here), %02d:%02d" % [game_clock.year() + 1, game_clock.day_of_year() + 1, season_here(), int(game_clock.hour()), int(fposmod(game_clock.hour(), 1.0) * 60.0)]   # starter-calendar: the calendar's day, the season where the player is
	if not weather.is_empty():
		text += "\nweather: rain %.2f snow %.2f storm %.2f sun %.2f wind %.2f, %.0f C, %s" % [weather["rain"], weather["snow"], weather["storm"], weather["sun"], weather["wind"], weather["temp_c"], "under cover" if under_cover > 0.0 else "open"]

		text += "\n" + wind_line(weather)

	var win: Vector2i = get_window().size
	@warning_ignore("static_called_on_instance")
	text += "\n3D %dx%d 16:9 in window %dx%d (scale %.2f)%s, %s, %s" % [int(display.BASE.x * _render_scale), int(display.BASE.y * _render_scale), win.x, win.y, _render_scale, " (embedded: editor owns the window)" if display.embedded() else "", RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()]
	text += "\nGPU breakdown: Ctrl+Shift+P or Esc > Advanced; table shows top left, press again to close; also in the log and user://gpu_probe.txt"
	text += "\nlast step: " + sound.last_step
	text += "\nsound budget: " + sound.budget_text()
	text += "\n" + sound.debug_sound_text(body)       # cached half a second: it walks every player in the scene (was every frame)
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

	if sound.occlusion.outdoors:
		text += "; open air: %d shadowed by the wind, %d carried, %d masked by rain or gale, %d echoes; snow fresh %.2f" % [sound.occlusion.air_shadowed, sound.occlusion.air_carried, sound.occlusion.air_masked, sound.occlusion.echoes_played, sound.weather.snow_fresh]

	text += "\ncave: enclosure %.2f, drips %d" % [sound.cave.enclosure, sound.cave.drips_played]
	text += "\nlast dig sound: %s" % sound.dig.last_dig
	text += "\nweather sounds follow: %s" % ("the TEST button (press it until it says follow the world)" if sound_tests.weather_at >= 0 else "the world weather above")
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
		["dig", sound.dig.last_dig], ["nature", sound.ambient.last_call], ["ambience", sound.ambience.last], ["npc voice", _npc_voice.last if _npc_voice != null else ""], ["inner voice", sound.inner.last],
	]

	for n in range(sources.size()):
		var now: String = str(sources[n][1])

		if now != "" and now != _last_sound_seen.get(sources[n][0], ""):
			_last_sound = "%s: %s" % [sources[n][0], now]

		_last_sound_seen[sources[n][0]] = now


# The loudest sounds playing now, loops and beds too (Dave 2 Nov 2026: a deep wobbling sound all day never showed as the last sound).
# Twice a second for the HUD's "playing:" line; the log gets a "sound now:" line when the loudest one changes, at most every 10 s.
func _note_sound_now(delta: float) -> void:
	_sound_now_left -= delta

	if _sound_now_left > 0.0 or sound == null:
		return

	_sound_now_left = 0.5
	var list: Array = SoundNow.loudest(sound, camera.global_position if camera != null else body.global_position, 3)
	_sound_now = SoundNow.line(list)
	var top: String = str(list[0][0]) if not list.is_empty() else "none"
	var now: int = Time.get_ticks_msec()

	if top != _sound_now_logged and now - _sound_now_log_msec >= 10000:
		_sound_now_logged = top
		_sound_now_log_msec = now
		FreezeWatchScript.printer.line("sound now: %s at %s" % [_sound_now, str(body.global_position.round())])   # on a worker (D-LAG-1: a main-thread line here was followed by a 0.8-1.3 s freeze in the PC standing plays, 23 Nov 2026)


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
				FreezeWatchScript.printer.line("Terrain client: walk: dropping from %s, ground below %.1f" % [str(body.global_position.round()), _ground_below(body.global_position)])
				_walk_stats = {"start_y": body.global_position.y, "fell_through": 0, "floor_frames": 0, "frames": 0, "lowest_gap": INF}
		1:
			if body.is_on_floor():
				_walk_stats["landed_s"] = float(now - _walk_msec) / 1000.0
				_walk_stats["drop_m"] = float(_walk_stats["start_y"]) - body.global_position.y
				_walk_stats["start_x"] = body.global_position.x
				_walk_phase = 2
				_walk_msec = now
				_walk_dir = Vector3(1.0, 0.0, 0.0)

				if test_crouch_walk:
					_crouch_walk_start()
			elif now - _walk_msec > 20000:
				_walk_stats["landed_s"] = -1.0
				_walk_phase = 4
				_walk_report()
		6:
			_crouch_walk_step(now)
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
	var down: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 1.0, 0.0), here + Vector3(0.0, -3000.0, 0.0))   # 3000 m: a start high in the air finds the collider once the column below is built
	down.exclude = [body.get_rid()]

	if not space.intersect_ray(down).is_empty():
		return true

	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here + Vector3(0.0, 800.0, 0.0), here + Vector3(0.0, -1.0, 0.0))
	up.exclude = [body.get_rid()]
	var hit: Dictionary = space.intersect_ray(up)

	rescue.lift_when_no_ground_below(here, hit)
	return false


# Headless check (--dig-next-test): dig rings of ground around and beside the standing player; he may sink with the ground he
# stands on but must never end up below the world.
func _run_dig_next_test() -> void:
	await get_tree().create_timer(25.0).timeout
	var start: Vector3 = body.global_position
	var lowest: float = start.y
	var off_floor_max: int = 0
	var off_floor: int = 0
	var spots: Array = []

	for ring in [1.2, 1.8]:
		for k in range(8):
			for drop in [0.0, -0.9, -1.8]:
				spots.append(start + Vector3(cos(TAU * k / 8.0) * ring, -0.9 + drop, sin(TAU * k / 8.0) * ring))

	for spot in spots:
		net.dig.rpc_id(1, spot, 0.9)

		for frame in range(20):
			await get_tree().physics_frame
			lowest = minf(lowest, body.global_position.y)
			off_floor = 0 if body.is_on_floor() else off_floor + 1
			off_floor_max = maxi(off_floor_max, off_floor)

	await get_tree().create_timer(4.0).timeout
	FreezeWatchScript.printer.line("Dig-next test: %d digs around the player; start y %.1f, lowest y %.1f, now y %.1f, longest time off the floor %d frames, rescues %d, %s" % [spots.size(), start.y, lowest, body.global_position.y, off_floor_max, rescue.rescued, "NEVER BELOW THE WORLD" if lowest > start.y - 6.0 else "FELL THROUGH"])


# Headless check (--resume-test=logout|drop|stay|check): two runs against one server. "logout"/"drop" walk 60 m from the spawn and leave
# with or without telling the server; "stay" then moves on to 90 m and stays in while the server is stopped; "check" prints how far
# from the spawn the game starts (a resume puts it back at the spot).
func _run_resume_test() -> void:
	var waited: float = 0.0

	while arrival_protect_until_msec == 0 and waited < 300.0:   # landed: before that the body glides and a slow lane's run left before it moved
		await get_tree().create_timer(1.0).timeout
		waited += 1.0

	await _server_caught_up()
	var spawn: Vector3 = world["spawn"]

	if test_resume == "check":
		FreezeWatchScript.printer.line("Resume test: started %.0f m from the spawn, at %s" % [Vector2(body.global_position.x - spawn.x, body.global_position.z - spawn.z).length(), str(body.global_position.round())])
		_finish(0)
		return

	body.global_position = spawn + Vector3(60.0, 4.0, 0.0)
	body.velocity = Vector3.ZERO
	await _server_caught_up()   # the server has read the reports from the new spot (a slow first save can hold its tick for a minute)
	await get_tree().create_timer(12.0).timeout   # past one 10 s spot note (server_items SAVE_SPOT_EVERY_MSEC): a drop is saved without the leave note
	await _server_caught_up()

	if test_resume == "stay":   # tools/dedicated_stop_smoke.sh: the server knows 60 m; only its save at the stop can keep 90 m
		body.global_position = spawn + Vector3(90.0, 4.0, 0.0)
		body.velocity = Vector3.ZERO
		await _server_caught_up()
		FreezeWatchScript.printer.line("Resume test: staying in at %s" % str(body.global_position.round()))
		return

	FreezeWatchScript.printer.line("Resume test: leaving (%s) at %s" % [test_resume, str(body.global_position.round())])

	if test_resume == "logout":
		_say_logout()
		await get_tree().create_timer(0.5).timeout

	_finish(0)


# Asks the server for the ground here and waits for the answer (up to 300 s): everything sent before has then reached a server that is ticking.
func _server_caught_up() -> void:
	var asked: int = Time.get_ticks_msec()
	net.request_surface.rpc_id(1, body.global_position.x, body.global_position.z)

	while _surface_answered_msec < asked and Time.get_ticks_msec() - asked < 300000:
		await get_tree().create_timer(0.5).timeout


# Headless check (--embed-test): put the body 4 m inside the ground; it must be out within 3 s.
func _run_embed_test() -> void:
	await get_tree().create_timer(25.0).timeout
	var start: Vector3 = body.global_position
	FreezeWatchScript.printer.line("Embed test: embed rescues while standing %d" % rescue.embed_rescues)
	var column: Array = []

	for k in range(-8, 6):
		column.append("%d:%.1f" % [k, terrain.get_voxel_tool().get_voxel_f(Vector3i((start + Vector3(0.0, float(k), 0.0)).round()))])

	FreezeWatchScript.printer.line("Embed test: sdf column (m from feet): " + str(" ".join(column)))
	rescue.note_dig(start)      # as after a dig here: the surface rescue is off, only the embedded check can free the player
	body.global_position = start + Vector3(0.0, -4.0, 0.0)
	body.velocity = Vector3.ZERO
	await get_tree().create_timer(3.0).timeout
	FreezeWatchScript.printer.line("Embed test: put at y %.1f (4 m under y %.1f), after 3 s y %.1f, embed rescues %d, %s" % [start.y - 4.0, start.y, body.global_position.y, rescue.embed_rescues, "FREED" if body.global_position.y > start.y - 1.0 else "STILL INSIDE"])
	body.global_position = start + Vector3(0.0, -150.0, 0.0)
	body.velocity = Vector3.ZERO
	await get_tree().create_timer(5.0).timeout
	FreezeWatchScript.printer.line("Embed test: put in the void 150 m under, after 5 s y %.1f, %s" % [body.global_position.y, "BACK ON THE SURFACE" if body.global_position.y > start.y - 1.0 else "STILL UNDER THE WORLD"])


# Blue tint and thick blue fog while the camera is below the sea or a lake.
func _update_underwater() -> void:
	var eye: Vector3 = camera.global_position
	# Owner report (2026-10-20, build 145): beside a cliff gorge with a thin film of water the
	# view turned blue with nothing drawn. The highest wet corner of an 8 m square (water_level_at)
	# is the top of the film, tens of m above the eye. Now the blended surface at the eye's own
	# spot, and the water there must be deeper than a film.
	# Under the island (_under_land, Dave 20 Nov 2026) below 0 m is no sea, so a lake's or cave pool's water there is read too.
	var land: bool = _under_land(eye)
	var surface: float = flora.water_surface_at(eye.x, eye.z) if eye.y >= 0.0 or land else NAN

	# Dino's cave retake 5 Nov 2026 (x 52107 z 70264): 2.6 m over the cave mouth's floor the view was under water. The water grid's level there is
	# the film on the hillside over the cave roof, 1 m above the eye, and the ray down from the eye found the cave floor 3.7 m under that level.
	if not is_nan(surface) and eye.y < surface and _rock_over(eye, surface):
		surface = NAN

	if (eye.y >= 0.0 or land) and (is_nan(surface) or surface < eye.y - 3.0) and _cave_streams != null:
		var pool: float = _cave_streams.pool_surface_at(eye)   # a spring cave's deep pool (BUG-008)

		if not is_nan(pool):
			surface = pool

	# The sea's surface at the eye is the swell's (M5): a crest over the eye is under water, but only where the ground is under the sea.
	# Under the island (_under_land) there is no sea below 0 m: a deep tunnel is dry (Dave 20 Nov 2026).
	var sea_y: float = _sea_height_at(eye)
	var under: bool = not land and eye.y < minf(sea_y, 0.0)

	if not under and not land and eye.y < sea_y:
		var bed: float = _ground_below(eye)
		under = is_nan(bed) or bed < 0.0   # no ground found: open deep sea

	if not under and not is_nan(surface) and eye.y < surface:
		under = WaterVolume.submerged(eye.y, surface, _ground_below(eye))

	if under:
		underwater_surface = surface if not is_nan(surface) and surface > 0.0 else sea_y

	var daylight: float = 1.0 - float(weather_look.day.night) if weather_look != null else 1.0
	UnderwaterLook.set_caustics(terrain.material as ShaderMaterial if terrain != null else null, under, underwater_surface, daylight)

	if under == underwater:
		return

	underwater = under
	_tint.visible = under
	# The fog itself follows the day and the depth every frame (weather_look.gd _underwater_fog); this is the switch.
	_environment.fog_density = WeatherLookScript.UNDER_FOG_DENSITY if under else LookSettings.FOG_DENSITY
	_environment.fog_light_color = WeatherLookScript.UNDER_DAY_COLOR if under else SkyClouds.HORIZON
	_environment.fog_sky_affect = 1.0 if under else 0.0
	_environment.fog_height_density = WeatherLookScript.UNDER_DEEP_DENSITY if under else 0.0
	_environment.fog_height = underwater_surface
	_environment.fog_aerial_perspective = 0.0 if under else LookSettings.FOG_AERIAL


# Ground height under a point, from the terrain colliders (NAN if none).
# In a pit or under a roof the sun's shadow biases (set for open ground, where large ones stop acne stripes) are too coarse for walls
# a few metres away: they show as hard-edged panels of different brightness (Dave's pit, x 53320 y 10.5 z 68418). While the player is
# in a pit or tunnel the biases are small; open ground keeps the old values. Checked twice a second.
func _update_pit_shadow() -> void:
	var now: int = Time.get_ticks_msec()

	if now < _pit_shadow_msec or _sun == null or body == null:
		return

	_pit_shadow_msec = now + 500
	var here: Vector3 = body.global_position + Vector3(0.0, 1.6, 0.0)
	var up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(here, here + Vector3(0.0, 40.0, 0.0))
	up.exclude = [body.get_rid()]
	var enclosed: bool = not body.get_world_3d().direct_space_state.intersect_ray(up).is_empty()

	if not enclosed:
		var higher: int = 0

		for offset in [Vector3(6.0, 0.0, 0.0), Vector3(-6.0, 0.0, 0.0), Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -6.0)]:
			var ground: float = _ground_below(here + offset + Vector3(0.0, 30.0, 0.0))

			if not is_nan(ground) and ground > here.y + 3.0:
				higher += 1

		enclosed = higher >= 3

	if enclosed != _in_pit:
		_in_pit = enclosed
		_sun.shadow_bias = 0.1 if enclosed else 0.3
		_sun.shadow_normal_bias = 0.8 if enclosed else 3.0


# Rock between a point and the outside water surface over it: a ray down from just over the surface meets the ground (terrain or a boulder; plants
# and placed pieces such as a jetty do not count) before the point, so the point is inside a cave under that water's bed. Under a sea overhang
# the ray starts inside the rock or in the air under it and meets nothing on the way down, so the water there stays water.
func _rock_over(p: Vector3, surface: float) -> bool:
	if body == null:
		return false

	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var skip: Array = [body.get_rid()]
	var from: Vector3 = Vector3(p.x, surface + 0.5, p.z)

	for _attempt in range(3):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, p + Vector3(0.0, 0.5, 0.0), 1)   # layer 1 only (sea ice is 2); stops short of a wader's own bed
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty():
			return false

		if hit["collider"] != null and CaveSoundsScript.is_not_rock(hit["collider"]):
			skip.append(hit["rid"])
			continue

		return true

	return false


# The wind where the viewer stands (docs/design/prevailing_wind.md section 3): Weather.local_wind on `state` with the ground measured
# round the viewer. The shot runner calls it on its forced weather too.
func wind_onto(state: Dictionary) -> Dictionary:
	if body == null or not body.is_inside_tree():
		return state

	_measure_wind_here(float(state.get("wind_dir", 0.0)))
	return WeatherScript.local_wind(state, wind_here, game_clock.seconds, _row_here, _eq_row)   # the row's own sun and summer


const WIND_SLOPE_STEP_M := 20.0                    # the slope: ground heights this far either side of the viewer, east-west and north-south
const WIND_LEE_AT_M := [30.0, 60.0, 120.0]         # the lee: how steeply the ground rises upwind at these distances
const WIND_LEE_DEG := [14.0, 22.0]                 # sheltered from a crest rising at 18 degrees or more (wind-over-terrain.md)
const WIND_SEA_UPWIND_AT_M := [100.0, 250.0, 450.0]   # sea upwind: open water at these distances upwind
const WIND_SEA_NEAR_M := 300.0                     # the sea or land breeze: open water this far off on eight bearings
const WIND_SEA_Y_M := 0.25                         # ground at or under this height (sea level 0) is open sea or its floor
const WIND_HERE_EASE := 0.4                        # each new measure moves the kept one this share of the way (walking does not jerk it)


# Measures the ground round the viewer for Weather.local_wind, every 2 s: 19 rays straight down, nothing sent.
func _measure_wind_here(heading: float) -> void:
	var now: int = Time.get_ticks_msec()

	if now < _wind_here_next_msec and not wind_here.is_empty():
		return

	_wind_here_next_msec = now + 2000
	var p: Vector3 = _anchor
	var h0: float = _ground_column(p.x, p.z, p.y)
	var east: float = _ground_column(p.x + WIND_SLOPE_STEP_M, p.z, p.y) - _ground_column(p.x - WIND_SLOPE_STEP_M, p.z, p.y)
	var south: float = _ground_column(p.x, p.z + WIND_SLOPE_STEP_M, p.y) - _ground_column(p.x, p.z - WIND_SLOPE_STEP_M, p.y)
	var uphill: Vector2 = Vector2(east, south) / (2.0 * WIND_SLOPE_STEP_M)
	var known_slope: bool = is_finite(uphill.x) and is_finite(uphill.y)
	var upwind: Vector2 = -Vector2.from_angle(heading)
	var rise_deg: float = 0.0

	if is_finite(h0):
		for d in WIND_LEE_AT_M:
			var h: float = _ground_column(p.x + upwind.x * d, p.z + upwind.y * d, p.y)

			if is_finite(h):
				rise_deg = maxf(rise_deg, rad_to_deg(atan2(h - h0, d)))

	var sea_hits: int = 0
	var sea_known: int = 0

	for d in WIND_SEA_UPWIND_AT_M:
		var h: float = _ground_column(p.x + upwind.x * d, p.z + upwind.y * d, p.y)

		if is_finite(h):
			sea_known += 1
			sea_hits += 1 if h <= WIND_SEA_Y_M else 0

	var sea_way: Vector2 = Vector2.ZERO

	for k in range(8):
		var way: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0)
		var h: float = _ground_column(p.x + way.x * WIND_SEA_NEAR_M, p.z + way.y * WIND_SEA_NEAR_M, p.y)

		if is_finite(h) and h <= WIND_SEA_Y_M:
			sea_way += way / 8.0

	var fresh: Dictionary = {
		"downhill": -uphill.normalized() if known_slope and uphill.length() > 0.001 else Vector2.ZERO,
		"grade": uphill.length() if known_slope else 0.0,
		"lee": smoothstep(WIND_LEE_DEG[0], WIND_LEE_DEG[1], rise_deg),
		"sea_upwind": float(sea_hits) / float(sea_known) if sea_known > 0 else 0.0,
		"sea_way": sea_way,
		"canopy": under_cover,
	}

	if wind_here.is_empty():
		wind_here = fresh
		return

	for key in fresh:
		wind_here[key] = lerp(wind_here[key], fresh[key], WIND_HERE_EASE) if key != "canopy" else fresh[key]


# The ground's height under (x, z) near the height `near_y` (NAN where it is not loaded): a ray from 150 m above to 400 m below.
func _ground_column(x: float, z: float, near_y: float) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, near_y + 150.0, z), Vector3(x, near_y - 400.0, z))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else NAN


# One line on the wind here, for F3 and the shot runner's log.
func wind_line(state: Dictionary) -> String:
	var down: Vector2 = wind_here.get("downhill", Vector2.ZERO)
	return "wind: from %03d deg (world from %03d), %.1f m/s, gust x%.2f | slope %.2f downhill toward %03d, slope breeze %+.1f m/s | sea upwind %.2f, sea breeze %+.1f m/s | lee %.2f, canopy %.1f" % [
		int(round(WeatherScript.bearing_of_heading(float(state.get("wind_dir", 0.0)) + PI))),
		int(round(WeatherScript.bearing_of_heading(world_wind_dir + PI))),
		float(state.get("wind_mps", WeatherScript.wind_mps(float(state.get("wind", 0.0))))), float(state.get("wind_gust", 1.5)),
		float(wind_here.get("grade", 0.0)), int(round(WeatherScript.bearing_of_heading(down.angle()))) if down.length() > 0.01 else 0,
		float(state.get("wind_slope_mps", 0.0)), float(wind_here.get("sea_upwind", 0.0)), float(state.get("wind_sea_mps", 0.0)),
		float(wind_here.get("lee", 0.0)), float(wind_here.get("canopy", 0.0))]


# Water within m of a spot (a deer trail's prints show where it crosses wet ground, stage 2d): the spot and four round it.
func _wet_near(x: float, z: float, m: float) -> bool:
	if flora == null:
		return false

	for d in [Vector2.ZERO, Vector2(m, 0.0), Vector2(-m, 0.0), Vector2(0.0, m), Vector2(0.0, -m)]:
		if not is_nan(float(flora.water_wet_at(x + d.x, z + d.y))):
			return true

	return false


func _ground_below(p: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -200.0, 0.0))
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else NAN


# --crouchwalk: from 2 m before each of the nearest trees, 0.8 m to one side (clear of the trunk), 0.35 m (brushing it) and 0.12 m (nearly head on, about 10 degrees off), a crouched walk
# at the crouch pace (or --runspeed) up beside it from four sides, 3 s each. A walk past or brushing that covers under 60 percent of its distance is stuck. Nearly head
# on the walker starts already against the trunk (as the robots were: a stop leaves you there) and has to slide round it, slowly at first, so it is stuck under a
# quarter of its distance (the robots' stop: 0.03 m in 2 s); a standing walk (at walking pace, or --runspeed) goes from there first, and when that covers under
# a quarter of its own distance too, the trunk is a real obstacle and the crouched walk is not counted; nor is either when the walker did not reach the trunk.
# Prints "crouch walk: N of M stuck, K head on" and ends the walk test.
var _crouch_trees: Array = []
var _crouch_case: int = -1
var _crouch_case_msec: int = 0
var _crouch_from: Vector3 = Vector3.ZERO
var _crouch_stuck: int = 0
var _crouch_counted: int = 0
var _crouch_stand_ok: Array = [false, false, false, false]   # per side: the standing head-on walk got past
var _crouch_placed: bool = false   # this head-on walk started against the trunk
var _crouch_head_on: int = 0       # head-on crouched walks counted
const CROUCH_WALK_TREES := 4    # each from four sides, past, brushing, head on standing and head on crouched: 64 walks
const CROUCH_WALK_S := 3.0


func _crouch_walk_start() -> void:
	var here: Vector3 = body.global_position

	for chunk in flora._chunks:
		@warning_ignore("shadowed_variable")
		var items: Dictionary = flora._chunks[chunk]["items"]

		for n in range(items["ids"].size()):
			var info: Dictionary = flora._species.get(items["ids"][n] >> 16, {})

			if info.get("kind", 2) == 0 and float(info.get("trunk", 0.0)) >= 0.1 and (items["positions"][n] - here).length() < 120.0:
				_crouch_trees.append([(items["positions"][n] - here).length(), items["positions"][n]])

	_crouch_trees.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_crouch_trees = _crouch_trees.slice(0, CROUCH_WALK_TREES)
	_set_stance(StanceScript.CROUCH)
	_walk_dir = Vector3.ZERO
	_walk_phase = 6


func _crouch_walk_step(now: int) -> void:
	var want: float = (run_speed if run_speed > 0.0 else WALK_SPEED * float(StanceScript.SPEED[StanceScript.CROUCH])) * CROUCH_WALK_S

	if _crouch_case >= 0 and float(now - _crouch_case_msec) < CROUCH_WALK_S * 1000.0:
		return

	if _crouch_case >= 0:
		var kind: int = floori((_crouch_case % 16) / 4.0)   # 0 past, 1 brushing, 2 head on standing, 3 head on crouched
		var moved: float = Vector2(body.global_position.x - _crouch_from.x, body.global_position.z - _crouch_from.z).length()

		if kind == 2:
			_crouch_stand_ok[_crouch_case % 4] = _crouch_placed and moved >= (run_speed if run_speed > 0.0 else WALK_SPEED) * CROUCH_WALK_S * 0.25
		elif kind < 2 or (_crouch_placed and _crouch_stand_ok[_crouch_case % 4]):
			_crouch_counted += 1
			_crouch_head_on += 1 if kind == 3 else 0

			if not (moved >= want * (0.6 if kind < 2 else 0.25)):   # NAN (no ground) counts as stuck
				_crouch_stuck += 1
				FreezeWatchScript.printer.line("Terrain client: crouch walk: stuck at %s heading %s" % [str(body.global_position), str(_walk_dir)])

	_crouch_case += 1

	if _crouch_trees.is_empty():
		FreezeWatchScript.printer.line("Terrain client: crouch walk: no trees within 120 m, nothing tested")
		_walk_phase = 4
		return

	if _crouch_case >= _crouch_trees.size() * 16:
		FreezeWatchScript.printer.line("Terrain client: crouch walk: %d of %d stuck, %d head on" % [_crouch_stuck, _crouch_counted, _crouch_head_on])
		_set_stance(StanceScript.STAND)
		_walk_dir = Vector3.ZERO
		_walk_phase = 4
		return

	var tree: Vector3 = _crouch_trees[floori(_crouch_case / 16.0)][1]
	var ang: float = deg_to_rad(90.0 * (_crouch_case % 4))
	var toward: Vector3 = Vector3(-sin(ang), 0.0, -cos(ang))
	var kind_now: int = floori((_crouch_case % 16) / 4.0)
	var aside: float = [0.8, 0.35, 0.12, 0.12][kind_now]   # past the trunk, brushing it, then nearly head on (the robots' stops: sliding along it or round it)
	var start: Vector3 = tree - toward * 2.0 + Vector3(toward.z, 0.0, -toward.x) * aside
	var ground: float = _ground_below(Vector3(start.x, tree.y + 30.0, start.z))
	body.global_position = Vector3(start.x, (tree.y if is_nan(ground) else ground) + 1.0, start.z)
	body.velocity = Vector3.ZERO
	_slide_carry = Vector3.ZERO
	body.rotation.y = atan2(-toward.x, -toward.z)
	_set_stance(StanceScript.STAND if kind_now == 2 else StanceScript.CROUCH)   # 2 m out from the trunk (a stand refused for lack of room: the walk is not placed below)
	_crouch_placed = kind_now < 2

	if kind_now >= 2:
		body.move_and_collide(Vector3.UP * 0.1)
		var hit: KinematicCollision3D = body.move_and_collide(toward * 2.0)   # up against the trunk
		_crouch_placed = hit != null and hit.get_normal().y < 0.5 and (kind_now == 3 or stance.stance == StanceScript.STAND)   # a trunk, not a rise of the ground
	_crouch_from = body.global_position
	_crouch_case_msec = now
	_walk_dir = toward


# Puts the player 3 m west of the nearest tree with a trunk collider.
func _place_by_tree() -> bool:
	var here: Vector3 = body.global_position
	var best: Array = []

	for chunk in flora._chunks:
		@warning_ignore("shadowed_variable")
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
	@warning_ignore("integer_division")
	FreezeWatchScript.printer.line("Terrain client: walk: landed %.1f s after dropping %.0f m; walked %.0f m east in 30 s, on the ground %d%% of frames, %d frames below the ground (lowest gap %.2f m); tree trunk at x %.1f, furthest reached %.1f; put 60 m under the ground, then %.1f m above it (%d rescues); waited for ground %d of %d frames, slowest frame %.0f ms" % [
		float(s.get("landed_s", -1.0)), float(s.get("drop_m", 0.0)), float(s.get("walked_m", 0.0)),
		100 * int(s.get("floor_frames", 0)) / maxi(int(s.get("frames", 0)), 1), int(s.get("fell_through", 0)), float(s.get("lowest_gap", 0.0)),
		float(s.get("tree_x", NAN)), float(s.get("tree_max_x", NAN)), float(s.get("rescued_gap", NAN)), rescue.rescued,
		_wait_frames, int(s.get("frames", 0)), _slowest_frame * 1000.0
	])


func _finish(code: int) -> void:
	_telemetry.event("EXIT: quitting with code %d" % code)

	if code != 0 and crash_report != null:
		crash_report.report_now("the game quits with code %d" % code)

	_drain_incoming()

	if link != null:
		link.close()

	if stream != null:
		stream.close()

	_finish_cache_task()

	if cache != null:
		cache.flush()

	_telemetry.drain()   # its lines are written on a worker
	quitting = true
	_close_line()
	get_tree().quit(code)


# The game connection is closed as the game quits, so the server hears it at once (robots, 23 Nov 2026: a quit game's connection stayed up
# 15 s and more, until the server's 15 s absent rule took the body out, and its line's timeout 60 to 120 s later).
func _close_line() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		multiplayer.multiplayer_peer.close()


# Worker thread: writes pending blocks and keeps the cache folder inside its size limit.
func _cache_upkeep() -> void:
	cache.flush()
	_cache_removed = cache.enforce_budget(_cache_tile)


func _finish_cache_task() -> void:
	if _cache_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_cache_task)
		_cache_task = -1


func _exit_tree() -> void:
	_telemetry.event("EXIT: game closed (exit_tree)")
	_freeze_watch.stop()
	OceanMesh.finish()   # a sea grid worker still running at a quit before the welcome
	DynastyBodyScript.finish_clips()   # the body's clip worker still running at a quick quit (dynasty_body.gd), before the drain so its line is logged
	FreezeWatchScript.printer.drain()   # the diagnostic lines still queued reach the log before the game closes
	DynastyArmsScript.settle()   # an arms prebuild still running at a quick quit: let it finish rather than hang the quit
	DynastyBodyScript.clips_on_worker = false   # the menus after the game (death screen, launcher) make a body's clips at once again

	if crash_report != null:
		crash_report.mark_clean()

	_finish_cache_task()
	_finish_ice_task()
	_drain_incoming()
	if stream != null:
		stream.close()

	_telemetry.drain()   # its lines are written on a worker: the EXIT line reaches the file before the process ends
	FreezeWatchScript.printer.drain()   # again: lines the last server messages queued above, before the exported game's _end_now kills the process
	# The freeze lines' context is a lambda of this script held in a static var. Left there, the engine frees it last, after this script's
	# own code is gone: "free(): invalid pointer" / "corrupted size vs. prev_size" and an abort at every quit after joining a world
	# (headless robot clients, 23 Nov 2026, dev 2aa2ea24; GDScript lambda freed from Callable in GDScript's cleanup). A scene change makes a new one.
	Probe.context = Callable()

	if quitting:
		_close_line()   # the window's X comes here without _finish()

	if _ends_at_exit_tree():
		_end_now()


# The exported Windows game crashed in the engine's own teardown, about 6 s after this _exit_tree (release check build 9193, 22 Nov
# 2026: 0xC0000005 in ntdll.dll after "EXIT: game closed (exit_tree)"). Everything the client keeps is written by then: settings are
# saved when changed, the block cache is flushed below and is only a cache (the server holds the world and the players). So the exported
# Windows game ends here instead of tearing the world down; the editor and tests keep the normal quit. Only when the game is closing:
# the death screen's new character and the lost-connection Retry also take this scene out of the tree, and the game goes on.
func _ends_at_exit_tree() -> bool:
	return quitting and OS.has_feature("template") and OS.get_name() == "Windows"


func _end_now() -> void:
	if cache != null:
		cache.flush()   # the window-close path comes here without _finish()
	if link != null:
		link.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()   # the server sees a disconnect now, not a timeout
	InstanceLockScript.release()   # the "already open" note: its own node under the root leaves after this scene, too late once the process is killed
	printerr("EXIT: process ends after exit_tree (exported Windows game)")   # an error-level line: the log file is flushed before the kill (release_first_run.ps1 reads it)
	OS.kill(OS.get_process_id())   # Windows: TerminateProcess with exit code 0


# Why a torch cannot be lit right now: "water" (the eye is under water), "rain" (open rain, no tree, rock or roof over you; a cave is cover), or "".
# Asked at the moment of the key press, so it reads the state of that frame.
func _light_block() -> String:
	var wet: float = float(weather.get("rain", 0.0))
	FreezeWatchScript.printer.line("torch light check: rain %.2f (puts out from %.2f), eye under water %s, depth %.2f" % [wet, FlameRules.RAIN_DOUSE, str(underwater), underwater_surface - camera.global_position.y if underwater else 0.0])

	if underwater or not FlameRules.in_rain(wet, false):
		return FlameRules.light_block(underwater, wet, false)

	var rock: float = sound.cave.rock_enclosure if sound != null and sound.cave != null else 0.0
	return FlameRules.light_block(false, wet, WeatherLookScript.sky_share(rock) < 0.5 or held.flame_covered())


# A torch in either hand goes out under water or after a few seconds in the open rain (Dave, 4 Nov 2026; flame_rules.gd). The client knows the held slot,
# so it asks the server to put the torch out (the same torch, marked out); a carried lantern (buildables plan B4) only goes out under water. Both burn only in the hand
# (ACT_TORCH_BURN): a torch down to nothing, a lantern through its candle or lamp oil.
func _flame_wet(delta: float) -> void:
	if held == null or items == null or items.inventory == null or net == null:
		return

	var slot: int = held.flame_slot()
	# A torch can only be lit where it would not go out at once: not under water, not in the open rain (rock or a roof or a crown over you is cover, so a cave works).
	if slot < 0:
		_flame_rain_s = 0.0
		return

	var entry: Dictionary = items.table.entry(items.table.id_of(items.inventory.numbers[slot]))
	var rain: float = float(weather.get("rain", 0.0))
	# Cover from the rain: a tree's crown over the eye, or rock (a cave or an overhang: the same enclosure that stops the rain particles, weather_look.gd).
	# A built roof is the server's to see: it refuses the douse there.
	var enclosed: float = sound.cave.rock_enclosure if sound != null and sound.cave != null else 0.0
	var covered: bool = WeatherLookScript.sky_share(enclosed) < 0.5 or held.flame_covered() if FlameRules.in_rain(rain, false) else true    # the cover lookup only while it rains
	_flame_rain_s = _flame_rain_s + delta if FlameRules.in_rain(rain, covered) else 0.0
	var reason: String = FlameRules.douse_reason(entry, underwater, rain, covered, _flame_rain_s)

	if reason == "" and float(entry.get("burn_s", 0.0)) > 0.0 and Time.get_ticks_msec() - _torch_burn_msec >= 1000:
		_torch_burn_msec = Time.get_ticks_msec()      # it burns: the server wears it down and counts the bearer as a small fire to animals
		net.inventory_action.rpc_id(1, NetScript.ACT_TORCH_BURN, slot, 0, 0, Vector3.ZERO)

	if reason == "" or Time.get_ticks_msec() - _flame_asked_msec < 1000:
		return

	_flame_asked_msec = Time.get_ticks_msec()
	net.inventory_action.rpc_id(1, NetScript.ACT_DOUSE, slot, 1 if reason == "rain" else 0, 0, Vector3.ZERO)
