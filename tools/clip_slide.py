"""Does a character clip slide? Reads bone positions straight from a glb (no Godot) over a time window of one clip.

Usage: python3 tools/clip_slide.py assets/character/Humanoid/Dynasty_Base_Male.glb Crawl_and_Look_Back 0.833 1.633 [game_m_per_clip_s [back]]
Prints the hips travel and speed over the window, and for each hand, knee and foot: its height range, how much of the window it is
down (within 4 cm of its lowest), and while down how fast it moves against the body along the travel (`against body`, m/s; minus is
backwards) and over the ground (`slip`, which includes the limb's sideways sway). A limb that is really on the ground moves against the
body at about minus the body's speed; one that hardly moves against the body while the body travels slides. Used for the stealthy crawl
(Dave QA #10, 25 Nov 2026): on Crawl_Backward the hands move 0.0 to -0.3 m/s against a 0.30 to 0.33 m/s body and the left knee not at all
(it slides); on Crawl_and_Look_Back 0.83 to 1.63 s the hands move -0.50 to -0.61 against 0.59 to 0.64 (they stay down). Bone joints,
not the skin: a knee joint sits about 0.1 m over the ground when it is down.

With `game_m_per_clip_s` (the game's travel per second of the source clip: pace x retime / speed scale; the crawl 0.4 x 1.4 = 0.56) it also prints the
drift in the world as the game plays it (the clip's own hips travel taken out, the game's travel put in; `back` plays it backwards): for each stretch a
limb is down, how far it moves along the travel and sideways, in cm. A limb that is really planted drifts about 0.
"""
import json
import struct
import sys

import numpy as np

LIMBS = ["LeftHand", "RightHand", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]
DOWN_M = 0.04
SAMPLES = 48


def load(path):
    with open(path, "rb") as f:
        f.read(12)
        size, _ = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(size))
        size, _ = struct.unpack("<II", f.read(8))
        blob = f.read(size)
    return gltf, blob


def accessor(gltf, blob, i):
    a = gltf["accessors"][i]
    view = gltf["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    off = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", 4 * n)
    return np.array([struct.unpack_from("<%df" % n, blob, off + k * stride) for k in range(a["count"])])


def quat_matrix(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


class Rig:
    def __init__(self, path, clip):
        self.gltf, blob = load(path)
        self.nodes = self.gltf["nodes"]
        self.parent = {c: i for i, n in enumerate(self.nodes) for c in n.get("children", [])}
        anims = [a for a in self.gltf["animations"] if a["name"] == clip]
        if not anims:
            sys.exit("no clip %s in %s" % (clip, path))
        self.tracks = {}
        for ch in anims[0]["channels"]:
            s = anims[0]["samplers"][ch["sampler"]]
            self.tracks[(ch["target"]["node"], ch["target"]["path"])] = (accessor(self.gltf, blob, s["input"])[:, 0], accessor(self.gltf, blob, s["output"]))
        self.length = max(t[0][-1] for t in self.tracks.values())
        self.index = {n.get("name", ""): i for i, n in enumerate(self.nodes)}

    def sample(self, key, t, default):
        if key not in self.tracks:
            return np.array(default, float)
        times, values = self.tracks[key]
        if t <= times[0]:
            return values[0]
        if t >= times[-1]:
            return values[-1]
        k = np.searchsorted(times, t) - 1
        u = (t - times[k]) / (times[k + 1] - times[k])
        a, b = values[k], values[k + 1]
        if key[1] == "rotation":
            b = -b if np.dot(a, b) < 0 else b
            q = a * (1 - u) + b * u
            return q / np.linalg.norm(q)
        return a * (1 - u) + b * u

    def local(self, i, t):
        n = self.nodes[i]
        m = np.eye(4)
        m[:3, :3] = quat_matrix(self.sample((i, "rotation"), t, n.get("rotation", [0, 0, 0, 1]))) * self.sample((i, "scale"), t, n.get("scale", [1, 1, 1]))
        m[:3, 3] = self.sample((i, "translation"), t, n.get("translation", [0, 0, 0]))
        return m

    def at(self, bone, t):
        i = next(j for name, j in self.index.items() if name.endswith(":" + bone) or name.endswith("_" + bone) or name == bone)
        m = self.local(i, t)
        while i in self.parent:
            i = self.parent[i]
            m = self.local(i, t) @ m
        return m[:3, 3]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    rig = Rig(sys.argv[1], sys.argv[2])
    start = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    end = float(sys.argv[4]) if len(sys.argv) > 4 else rig.length
    times = np.linspace(start, end, SAMPLES + 1)
    dt = (end - start) / SAMPLES
    hips = np.array([rig.at("Hips", t) for t in times])
    travel = hips[-1] - hips[0]
    flat = np.array([travel[0], 0.0, travel[2]])
    ahead = flat / max(np.linalg.norm(flat), 1e-6)
    print("%s %.2f to %.2f s: hips travel %.2f m, %.2f m/s" % (sys.argv[2], start, end, np.linalg.norm(flat), np.linalg.norm(flat) / (end - start)))
    for limb in LIMBS:
        p = np.array([rig.at(limb, t) for t in times])
        low = p[:, 1].min()
        down = (p[:-1, 1] < low + DOWN_M) & (p[1:, 1] < low + DOWN_M)
        step = np.diff(p, axis=0)
        slip = np.linalg.norm(step[:, [0, 2]], axis=1) / dt
        along = (step @ ahead) / dt - np.linalg.norm(flat) / (end - start)   # along the travel, against the body
        print("  %-10s height %.2f-%.2f m, down %3.0f%%, against body %5.2f m/s, slip %.2f m/s" % (
            limb, low, p[:, 1].max(), 100.0 * down.mean(), along[down].mean() if down.any() else 0.0, slip[down].mean() if down.any() else 0.0))
    if len(sys.argv) > 5:
        drift(rig, start, end, float(sys.argv[5]), len(sys.argv) > 6 and sys.argv[6] == "back")


def drift(rig, start, end, game_mps, back):
    times = np.linspace(start, end, 2 * SAMPLES + 1)
    hips = np.array([rig.at("Hips", t) for t in times])
    line = hips[0] + np.outer((times - start) / (end - start), hips[-1] - hips[0])
    line[:, 1] = 0.0
    flat = hips[-1] - hips[0]
    flat[1] = 0.0
    ahead = flat / max(np.linalg.norm(flat), 1e-6)
    side = np.cross([0.0, 1.0, 0.0], ahead)
    print("drift in the world at %.2f m per clip second%s:" % (game_mps, " backwards" if back else ""))
    for limb in LIMBS:
        p = np.array([rig.at(limb, t) for t in times]) - line
        if back:
            p = p[::-1]
        world = p + np.outer((times - start) * game_mps * (-1.0 if back else 1.0), ahead)
        down = p[:, 1] < p[:, 1].min() + DOWN_M
        runs, begin = [], None
        for i, d in enumerate(down):
            if d and begin is None:
                begin = i
            if begin is not None and (not d or i == len(down) - 1):
                last = i if d else i - 1
                if last > begin:
                    runs.append((begin, last))
                begin = None
        parts = []
        for a, b in runs:
            seg = world[a:b + 1]
            along, across = seg @ ahead, seg @ side
            parts.append("%.0f%% of the stride: %.1f cm along, %.1f cm sideways" % (100.0 * (b - a) / (len(times) - 1), 100.0 * np.ptp(along), 100.0 * np.ptp(across)))
        print("  %-10s lowest %.0f cm; %s" % (limb, 100.0 * p[:, 1].min(), "; ".join(parts) if parts else "never down"))


if __name__ == "__main__":
    main()
