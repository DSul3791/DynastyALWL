"""Every colour texture data/animals/models.json names ("albedo") has its see-through answer in data/animals/texture_alpha.json, or is
listed there as absent (no source image in the pack). A texture with neither is read back from the graphics card in the frame when its
kind's files come in (Lane A r4 at Low, 26 Nov 2026: 23 ms on average, up to 170 ms). Fix: run tools/texture_alpha.gd on a machine with
the model pack (Lane A) and commit the file it writes. Prints one FAIL line per texture; exit 1 when there is any.
    python3 tools/check_texture_alpha.py
"""
import json, sys


def albedo_paths(data):
    out, stack = set(), [data]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            for k, v in item.items():
                if k == "albedo" and isinstance(v, str) and v:
                    out.add(v)
                else:
                    stack.append(v)
        elif isinstance(item, list):
            stack.extend(item)
    return sorted(out)


def main():
    models = json.load(open("data/animals/models.json", encoding="utf-8"))
    table = json.load(open("data/animals/texture_alpha.json", encoding="utf-8"))
    known = set(table.get("textures", {})) | set(table.get("absent", []))
    missing = [p for p in albedo_paths(models) if p not in known]
    for p in missing:
        print("FAIL %s has no see-through answer in data/animals/texture_alpha.json: run tools/texture_alpha.gd on Lane A" % p)
    print("texture alpha: %d textures named, %d without an answer" % (len(albedo_paths(models)), len(missing)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
