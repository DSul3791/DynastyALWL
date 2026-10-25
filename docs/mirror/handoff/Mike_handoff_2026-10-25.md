# Mike (MikeW) handoff, 25 Oct 2026 08:00 ADT (11:00 UTC)

## Standing rules I follow
- Dave's PC: only close windows/processes my own run started (look_rig records its server window pid). Never kill a Godot process (refused anyway). Nothing runs while Dave plays; he was away 25 Oct until ~14:55 UTC.
- Pictures: tools/LOOK_RIG_SETUP.md (branch claude/mike-rig-v4/v5 in my clone). Held set = first person 35 deg down (`--realview`), third person a-d (camera orbit 0/45/90/315 at 1.3 m, body still), top at 1 m up. Ground views: Steve's `--shot-item` job (claude/steve-item-shots), four views, log lines per view. Always check the push with `git ls-tree -r origin/claude/mike-evidence-kathleen-13df38ae --name-only | grep <label>` (an empty-folder variable once pushed an empty commit).
- Clones: C:\GodotProjects\DynastyALWL_test (rig source and script base, branch local-k1f49), _shoot4 (held views), _shoot5 (item job), _proof (bakes/settle, reference tiles), _gate (test gates); all are worktrees of _test. Scripts in the session scratchpad: held_batch.sh, held_batch_hr.sh, item_batch.sh, gate_win.sh, pipeline793.sh, bake9.ps1, bake_one.ps1, settle9.sh.

## Pictures (all on branch claude/mike-evidence-kathleen-13df38ae under evidence/)
Kathleen tool pass: held and ground views for spades (large iron/steel on a01d6527, ad1f2632, f20c8d87, 133fe9ad, acf53a86; 97ae9633), hoes, hand saw, axe, hammers, knife (3585a763 latest: hammer, saw, stone hoe, knife, axe held 30 files + knife ground 6), fishing rod, spears, wooden pin (30397923, 8eb5280b, 4a6c1a82, 7d992966 rod, 4ccc83d4 rod+hoe+axe+hammer+saw+knife), torch rounds 1-6 (sal-torch-head 0aae4af6 ... 302f8279). Open: f04af328 (stone hoe first person, stone knife on the ground four views) queued, not shot yet.

## Gates (BP-T77, Windows) all pass vs baseline (five known fails: drainage_flow, head_pond_fill, pond_outlet, showroom, water_soak)
bend-swing-fade 5dffc0de, ore-near-rivers 313a172b, river-ore-guarantee 1d3182cc, sonny-test-fixes 3908aca3, remove-old-builder 3a497531 (229 warnings), tile-lake-guarantee 3a94898e. Results E:\Software\godotDev\gate_results\gate_<name>.txt. test_water_soak is flaky on this PC (walk loads 3 of 9 tiles). Godot's first import makes 5 new untracked .uid files in every head.

## Generator
- speedup 690ee171 proof: tile (3,4) md5 4fc5650d identical, 499 s to 341 s (171 s with cache).
- 3b: 1a7fa6b3 (141.3 s), c8fae6e7 (119.2 s cache / 118.6 s no cache), md5 4fc5650db635d44b374df76474485abd.
- Nine-tile bake merge-793 11f363d9: 382.4 s on 4 threads, peak 3729 MB, branch claude/mike-bake-793 (tiles 35b5f886, water f6bbca1d, island table 09014e2c: 75 checks, 2 FAIL = summit plateau 100/200 m).
- RE-BAKE from lake-size 2a2b97ab (bigger lakes, outlet notch, summit crown): nine tiles 377.4 s on 4 threads, peak 3722 MB, no warnings; settled in 497 s (3,4 243 s), stitch 110 edge cells in 6 tiles; island table 73 checks, 0 FAIL (summit plateau rows now PASS: 88 m / 168 m). Pushed to claude/mike-bake-793 tip f0c13a66 (+ md5 fix commit). Full md5 lists docs/bake793_lake2a2b/md5_tiles_and_water.txt: tile_3_4 2250f662621990fe55ac5c7e95b34af1, tile_4_4 9624ed03b47458fc32d9394288ef6280. Changed vs the 11f363d9 bake: tiles 3,3 3,4 4,3 4,4 4,5 only. test_tile_lakes: 53 head ponds (16.9 ha), 20 lakes (63.2 ha) in tile (3,4), all inside their tile.
- Note: earlier md5 list files (docs/bake793/md5.txt) had lost their hashes; rewritten in the fix commit.

## Backup
- 25 Oct 07:27 ADT: DynastyALWL_ProjectBackup_2026-10-25_0727.zip, 5813 MB, restore test OK, cull dry-run (0). Size jump = .git objects (5735 MB vs 1399 MB): a `git gc` in the main clone would shrink it, not done without Dave's go.
- The 24 Oct 21:00 ADT nightly did not run (Dave playing). Another backup to run after this handoff and the merges, when the coordinator says. Cull is still DRY-RUN (first 14 nights).

## Open items / watch
- David3 takeover list: clean checkout per hash, baseline in box-results results/20261025_baseline, results/david3_scripts ported to Windows; no Linux .so proofs possible.
- Steve's item job: the long-item top view needs re-aims (measures before the item settles); stone hoe roll 40 deg about the haft: check the blade faces the camera in the 046a3e8f/f04af328 shots.
- Dave's rule: leave windows alone; no test while he plays.
