# Steve: item-on-the-ground shots (branch claude/steve-item-shots)

Problem (Mike's rig): a tool lying on the ground cannot be photographed. --shot-drop drops the item but the camera ends up looking at trees or an NPC, and --shot-showroom logs no row.
Change (DEBUG only, src/debug/shot_runner.gd, no game code, no protocol): new job `--shot-item=ITEM` (item id or name; optional `--shot-item-at=x,z`, default 2 m ahead of the shot position).
1. Gives the player the item (existing admin give), drops it with the existing real drop at the spot, waits until the server's world item shows up in client.items (looked up by id, nearest to the spot).
2. Clears the view: player body, arms, HUD, compass and debug text hidden, grass hidden (existing --shot-nograss path), flora hidden (existing --shot-cost path), so nothing stands behind the item.
3. Camera math in a pure static helper (ItemCam.views(item_pos, item_size_m, yaw_deg, fov_deg) -> 4 views {name, cam_pos, yaw, pitch}): distance d = clamp(1.5 x longest side / (2 tan(fov/2)), 0.6, 1.5) m so the item fills at least a third of the frame (the item's size comes from its drawn node's AABB); views: front (d, 0.5 m up, pitch aimed at the item), side (90 deg round, same), top (1.0 m straight up, pitch -90... -85), and 45 deg (d, 45 deg round, 0.8 m up). Each aimed at the item centre. Clamped above the ground so the camera never sits in it.
4. Four pictures `<name>_item_front|side|top|diag.png`, 2 s settle each, and a log line per picture: item id, size, distance, camera, "fills N % of the frame" (projects the AABB corners with the camera; the line says FAILED if under 33 %).
Test (headless, pure math, no Godot scene): test_item_cam.gd: for sizes 0.2, 0.6 and 1.5 m checks distance in 0.6..1.5, camera aimed at the item (angle error under 1 degree), the four views distinct, top view straight down, camera above the ground, projected fill at least a third for sizes up to 0.9 m (larger items stay at 1.5 m and are logged, not failed).
Gate (David3): `--shot-item=iron_pickaxe`, 4 pictures, no debug text, the tool filling a third or more, log lines present; Kathleen/Tyler judge the pictures.
Risk: none to the game (runner only). A very small item (a seed) may need 0.6 m; the clamp is the limit.

## Build notes (Tyler GO, with pose read-back and exit code)
src/debug/item_cam.gd (pure maths: distance_for on the frame WIDTH, 0.2..1.5 m, views, fill_fraction), shot_runner.gd (--shot-item, --shot-item-at, _build_item_views, _node_aabb, _check_item_view; exit code 1 when any view's pose is off by over 0.1 m / 2 degrees or the fill is under 32 %), test_item_cam.gd. Distance is on the frame width because a tool lies across the picture; tiny items go down to 0.2 m (the range Tyler gave, 1.0-1.5, applies to items of a metre or more).
Run: godot ... -- --shots="item:X,1.7,Z,0,-30,12" --shot-item=iron_pickaxe --shot-wait=40 ; look for "shot runner: item view front ok ..." x4 and the exit code.

## Fit-first (25 Oct, Mike's 1.2 m spade run)
Camera distance is now the smallest at which every box corner lies within 90 % of the half-frame (bisection, 0.2 to 3 m), per view, aimed at the box centre; elevations 25 / 25 / 90 / 35 degrees for front / side / top / diag. test_item_cam.gd covers 0.2, 0.6, 1.2, 1.8 m items along X and Z in all four views plus a tall post, centring (<= 10 %), inside-with-margin, fill (>= 32 % unless the item points at the camera).
