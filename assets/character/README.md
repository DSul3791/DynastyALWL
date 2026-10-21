# Ragdoll character

The plain character (no features): body, head, arms, legs, hands. Built in code by `src/client/ragdoll_body.gd`,
so there is nothing to import. About 1.86 m tall, 0.26 m half width (the player capsule is 0.35 m), about 1.5 thousand
triangles in one skinned mesh (one draw call), 17 bones, one neutral skin colour. Check: `godot --headless --path . --script res://tools/check_ragdoll.gd`.

## Use

```gdscript
const Ragdoll := preload("res://src/client/ragdoll_body.gd")
var body := Ragdoll.new()        # full body for third person; feet at the node's origin, facing -Z
var arms := Ragdoll.new(true)    # first person: only arms and hands, rooted at the chest
body.play("walk")                # idle walk run crouch sit lie  (loops)  swing jab throw use  (one shots)
```

The third-person camera in `terrain_client.gd` already uses it (`_make_avatar`, `_update_view`): the clip follows
the stance (idle, crouch, sit, lie) and the walking speed (walk, run).

## Animations (all key every bone, so a switch never leaves a bone in the old pose)
| name | length | kind | what |
|---|---|---|---|
| idle | 3 s | loop | breathing, arms slightly out |
| walk | 1 s | loop | one cycle = two steps (about 1.6 m of ground) |
| run | 0.6 s | loop | leaning, bent elbows (about 2.8 m a cycle) |
| crouch | 2 s | loop | held low |
| sit | 3 s | loop | seated, hips 0.45 m down, thighs horizontal |
| lie | 4 s | loop | on the back, head toward +Z, hips 0.18 m up |
| swing | 0.7 s | once | both hands, over the head and down (axe, pick) |
| jab | 0.5 s | once | thrust straight ahead (spear) |
| throw | 0.8 s | once | wind up behind, let go forward |
| use | 0.6 s | once | reach out and touch, a small push in the middle |

`body.is_one_shot_playing()` says whether a one-shot is still running; `body.current()` is the clip name.
For a swing in step with a hit, play it at the speed you need: `body.play("swing", 1.3)`.

## Where the held tool goes (Items: hotbar, equip, held tool)
`body.hand_mount_r` (and `hand_mount_l`) is a `Marker3D` on the hand bone. Parent the tool to it:

* the mount's origin is the grip, in the palm, 7 cm below the wrist;
* its **-Z axis points out along the fingers** (the way the tool points: a spear tip or an axe head is at -Z);
* its **+Y axis points forward (-Z of the hand bone) when the arm hangs at the side**, so with the arm hanging a
  tool's -Z points down along the fingers and its +Y points forward;
  rotate the tool under the mount if it sits wrong (it is a plain Marker3D).

The same mounts exist on the first-person arms model: `arms.hand_mount_r`. `body.head_mount` is the middle of the head
(a hat, or a head camera).

## First person
`Ragdoll.new(true)` has only the chest as a root and the two arms and hands (7 bones, 480 vertices) and plays the same
ten animations (the arm tracks of each). Put its origin about 0.28 m below and 0.05 m behind the camera so the shoulders
sit at the screen's lower corners; the arms hang down along -Y and swing forward along -Z.

## Changing it
Bones and shapes are the `BONES` and `PARTS` tables at the top of the script; animations are the `_idle`, `_walk` ...
functions (a pose per phase, bone name to X/Y/Z radians: for an arm or leg hanging down, + X swings it forward, elbows
bend with +, knees with -). A modelled replacement can later keep the same bone names and animation names.
