# Head tracking: animals that look at the player (MikeW, 8 Nov 2026; built on the eye-placement branch)

Reuses the bone layer (`bone_offsets.gd`) that already does the crow's posture, tails, ears and breathing.

## What it does
- **Grazers** (deer, elk, moose, horse, donkey, cattle, sheep and goats, pronghorn, camel, wildebeest): while grazing, when the player comes within 30 m the animal lifts its head and looks at the player for 2 to 4 s, then goes back to grazing; again if the player keeps coming closer (each 5 m nearer). If the player comes within the species' `spook_m` it is no longer grazing (the server makes it alert or flee) and the clip takes over.
- **Predators** (wolf, fox, lynx, puma, lion, leopard, tiger, hyena, bears): while stalking (6), alert (3) or warning (10) the head keeps turned to the player the whole time, as far as the neck allows.
- **Everyone else** (birds, small animals): no tracking; their clips already look about.

## How
1. **Look target:** the camera position (the client's player), like the ears.
2. **The turn:** split over the neck and head bones (`"look": {"bones": ["Neck1", "Neck2", "Head"], "yaw_max_deg": 70, "pitch_max_deg": 30}`): each bone takes a share of the yaw and pitch toward the target, measured in the animal's own frame (it faces -Z), clamped to the maximum, so the neck curves instead of the head snapping round.
3. **Lift (grazers):** the "look up" is a pitch toward the target plus an extra lift that undoes the graze clip's head-down pose: the head bone's pitch is blended toward the rest pose by `lift` (0 to 1) while looking. The graze clip keeps playing underneath, so the legs and body do not freeze.
4. **Timing (client only):** per animal, `look_until` (when a glance ends) and `next_glance_m` (the distance that triggers the next one). No wire change: the server already sends the state, the client knows the camera.
5. **Easing:** the look weight rises and falls over about 0.3 s.

## Data
Grazer rows: `"look": {"bones": [...], "yaw_max_deg": 60, "pitch_max_deg": 40, "mode": "glance", "range_m": 30, "hold_s": [2, 4]}`. Predator rows: `"mode": "track"`. Bone names from the files (deer `Neck1`, `Neck2`, `Head`; horse `neck_01`..., read the same way as the tail and ear bones).

## Check
A short series of frames with the camera moving round a grazing deer and a stalking wolf (the creature check gains a `--orbit` option), then Kathleen's look in the live game.

**Built:** the turn is axis-free (the line from the neck base to the head is turned onto the line to the target, clamped, shared equally over the bones), so no per-rig axes are needed. Rows: glance for deer, moose, elk, wildebeest, bighorn, mountain goat, chamois, pronghorn, cow, goat; track for wolf, fox, hyena, lynx, puma, lion, leopard, tiger, both bears. 
## Horse, donkey and camel
Their rigs carry many helper bones (`dyn_new_neck_*`, `*_middleslider_*`, `*_correctiveRoot`, the horse's mane and bounce chains) beside the real neck chain. Turning a helper bone does nothing visible or fights the rig's own correction, so the look and sleep poses use the **real chain only**:
- horse and donkey: `neck_02`, `neck_03`, `neck_04`, `head` (the chain runs `neck_01` to `neck_05`; the base stays still so the shoulders do not twist);
- camel: `Camel_1humpM2015_Neck_01SHJnt`, `_Neck_02SHJnt`, `_Neck_TopSHJnt`, `_Head_TopSHJnt` (the long neck takes most of the turn, so `max_deg` 70).
All three glance like the other grazers. The horse and donkey also doze standing (sleep pose `-1`: neck and head lowered on the same chain).
