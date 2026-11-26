"""Every animal model data/animals/models.json draws (each kind's row, looks and young model) has its kept clip answers in
data/animals/clip_answers.json, or is listed there as absent. A model with neither measures its clips in the frame when the first animal of
its kind comes into view (Lane A r4 at Low, 26 Nov 2026: 76-106 ms). Fix: run tools/clip_answers.gd on a machine with the model pack
(Lane A) and commit the file it writes. Prints one FAIL line per model; exit 1 when there is any.
    python3 tools/check_clip_answers.py
"""
import json, re, sys


def kinds_drawn():
    text = open("src/client/animal_view.gd", encoding="utf-8").read()
    line = re.search(r"^const KIND_OF_SPECIES := \{(.*)\}$", text, re.M).group(1)
    return set(re.findall(r'"([a-z_]+)"', line))


def scene_of(row, look, young):
    merged = dict(row)
    looks = row.get("variants", [])
    if looks:
        merged.update(looks[look % len(looks)])
    if young and isinstance(merged.get("young_model"), dict):
        merged.update(merged["young_model"])
    return str(merged.get("scene", ""))


def wanted():
    species = json.load(open("data/animals/models.json", encoding="utf-8")).get("species", {})
    kinds = kinds_drawn()
    out = []
    for kind, row in species.items():
        if kind not in kinds or not isinstance(row, dict):
            continue
        for look in range(max(1, len(row.get("variants", [])))):
            for young in (False, True):
                if young and not isinstance(row.get("young_model"), dict):
                    continue
                key = "%s|%s" % (kind, scene_of(row, look, young))
                if key not in out:
                    out.append(key)
    return out


def main():
    table = json.load(open("data/animals/clip_answers.json", encoding="utf-8"))
    known = set(table.get("models", {})) | set(table.get("absent", []))
    keys = wanted()
    missing = [k for k in keys if k not in known]
    for k in missing:
        print("FAIL %s has no kept clip answers in data/animals/clip_answers.json: run tools/clip_answers.gd on Lane A" % k)
    print("clip answers: %d models drawn, %d without answers" % (len(keys), len(missing)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
