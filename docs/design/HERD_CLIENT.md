# Herds and flocks on the client (MikeW, 8 Nov 2026; built on the eye-placement branch)

The server already keeps herds together (`herd`, `herd_pull_m`), raises the alarm through a herd (`alarm_s`: one bolts, the rest follow), keeps young beside their mother, and moves flocks as one record (ducks, gulls). What looks wrong up close is that herd mates graze facing every way, overlap, and each looks up on its own. The client fixes that from what it already receives; nothing on the wire changes and the server's positions are never moved.

**Built (model rows with `"herd": true`: deer, elk, moose, wildebeest, cow, goat, bighorn, chamois, mountain goat, pronghorn, wild ox, horse, donkey, camel, kangaroo, boar, warthog, elephant, mammoth, lion, hyena):**
1. **Facing:** a grazing animal turns up to 20 degrees toward the mean facing of its kind within 12 m, eased over a few seconds. Done on the model's rig, not its node, so the node still follows the server's heading exactly.
2. **Spacing:** mates closer than 2 m are drawn pushed apart inside their nodes (at most 1 m), so bodies never overlap on screen; the server's positions stay as sent.
3. **Looking up together:** when one grazer starts a glance at the player (HEAD_TRACKING.md), every grazing mate of its kind within 12 m looks up 0.3 to 2 s later and holds for 1.5 to 3 s.
4. **Young:** they already stay at their offset beside their mother (server); nothing to add.

**Birds on the ground** (crow, pheasant, guineafowl, chicken): each flees on the server's alarm already, and the duck and gull flocks take off as one record. A tighter "scatter together" for ground birds needs the server's alarm to reach them, which `alarm_s` does for herd species; giving these rows a `herd` on the server is Steve's call, not a client change.

**Cost:** one pass over the drawn animals per herd animal per frame (at most MAX_DRAWN, small); only for grazing animals.
