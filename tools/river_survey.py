#!/usr/bin/env python3
# River survey (Sonny, 3 Nov 2026; Dave: "no more patchy riverbeds"). Reads a baked tile and its settled water and prints, by ground slope:
#   - painted river cells, how many are dry in the settled water, how many hold only the 13 cm film
#   - side slope: river cells more than 0.5 m above the lowest ground of their own cross-section (48 m each way, across the river's direction):
#     the channel runs along a hillside instead of the valley's low line, and its water has no bank on the downhill side
#   - dry reaches: groups of dry river cells, and how many start at a river head (a spring moved away from its brook)
#   - unheld edges: wet river cells beside dry ground lower than their water (no bank holds it); sea cells do not count as dry ground
# Run before and after a bake to compare (A/B for #221):
#   python3 tools/river_survey.py [--tile 3,4] [--world worlds/base_world]
# Needs numpy and zstandard (pip install numpy zstandard). No Godot.
import argparse, json, struct, sys

import numpy as np
import zstandard

SIDE_SLOPE_M = 0.5
FILM_MAX_M = 0.15
CROSS_CELLS = 6        # 48 m each way at 8 m spacing
BANDS = [(0.0, 0.05), (0.05, 0.1), (0.1, 0.2), (0.2, 99.0)]


def read_tile(path, names):
    data = open(path, 'rb').read()
    header_len, table_len = struct.unpack('<II', data[8:16])
    header = json.loads(data[16:16 + header_len])
    table = json.loads(data[16 + header_len:16 + header_len + table_len])
    out = {}

    for entry in table:
        if entry['name'] in names:
            raw = data[entry['offset']:entry['offset'] + entry['size']]

            if entry['compression'] == 'zstd':
                raw = zstandard.ZstdDecompressor().decompress(raw, max_output_size=entry['raw_size'])

            out[entry['name']] = raw

    return header, out


def heights(raw, step, base=-4000.0):
    n = len(raw) // 2
    a = np.frombuffer(raw, np.uint8)
    return (a[:n].astype(np.int32) | (a[n:].astype(np.int32) << 8)) * step + base


def water_depth(path, side):
    data = open(path, 'rb').read()

    if data[:4] != b'DWAT':
        sys.exit('not a water file: ' + path)

    count, raw_size = struct.unpack('<II', data[8:16])
    depth = np.zeros(side * side, np.float32)

    if count:
        raw = zstandard.ZstdDecompressor().decompress(data[16:], max_output_size=raw_size)
        rec = np.frombuffer(raw, dtype=np.dtype([('k', '<u4'), ('d', '<u2')]), count=count)
        depth[rec['k']] = rec['d'] / 100.0

    return depth


def label(mask):
    # 8-connected components without scipy
    lab = np.zeros(mask.shape, np.int32)
    n = 0
    side = mask.shape[0]

    for j, i in zip(*np.nonzero(mask)):
        if lab[j, i]:
            continue

        n += 1
        stack = [(j, i)]
        lab[j, i] = n

        while stack:
            a, b = stack.pop()

            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    c, d = a + da, b + db

                    if 0 <= c < side and 0 <= d < side and mask[c, d] and not lab[c, d]:
                        lab[c, d] = n
                        stack.append((c, d))

    return lab, n


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tile', default='3,4')
    parser.add_argument('--world', default='worlds/base_world')
    args = parser.parse_args()
    tx, tz = args.tile.split(',')
    header, sections = read_tile('%s/tiles/tile_%s_%s.tile' % (args.world, tx, tz), ['height', 'water_class'])
    n = int(header['samples'])
    spacing = float(header['map_spacing_m'])
    h = heights(sections['height'], float(header.get('height_step_m', 0.1))).reshape(n, n)
    w = np.frombuffer(sections['water_class'], np.uint8).reshape(n, n)
    d = water_depth('%s/water/tile_%s_%s.water' % (args.world, tx, tz), n).reshape(n, n)
    river = w == 3
    gy, gx = np.gradient(h, spacing)
    slope = np.hypot(gx, gy)
    side = np.zeros((n, n), bool)
    measured = np.zeros((n, n), bool)
    m = CROSS_CELLS + 2

    for j, i in zip(*np.nonzero(river)):
        if j < m or i < m or j >= n - m or i >= n - m:
            continue

        yy, xx = np.nonzero(river[j - 2:j + 3, i - 2:i + 3])

        if len(xx) < 3:
            continue

        _, vectors = np.linalg.eigh(np.cov(np.vstack([xx, yy]).astype(float)))
        along = vectors[:, 1]
        px, pz = -along[1], along[0]
        cross = [h[int(round(j + pz * r)), int(round(i + px * r))] for r in range(-CROSS_CELLS, CROSS_CELLS + 1)]
        measured[j, i] = True
        side[j, i] = h[j, i] - min(cross) > SIDE_SLOPE_M

    print('tile %s,%s: %d painted river cells' % (tx, tz, river.sum()))
    print('%-10s %7s %6s %6s %10s' % ('slope', 'cells', 'dry', 'film', 'side slope'))

    for lo, hi in BANDS:
        band = river & (slope >= lo) & (slope < hi)
        cells = band.sum()

        if cells == 0:
            continue

        dry = (band & (d == 0)).sum()
        film = (band & (d > 0) & (d <= FILM_MAX_M)).sum()
        side_share = side[band & measured].mean() if (band & measured).any() else 0.0
        print('%-10s %7d %5.0f%% %5.0f%% %9.0f%%' % ('%g-%g' % (lo, hi if hi < 99 else 9), cells, 100.0 * dry / cells, 100.0 * film / cells, 100.0 * side_share))

    dry = river & (d == 0)
    lab, count = label(dry)
    from_head = 0

    for k in range(1, count + 1):
        js, iss = np.nonzero(lab == k)
        top = np.argmax(h[js, iss])
        j, i = js[top], iss[top]
        above = river[max(j - 1, 0):j + 2, max(i - 1, 0):i + 2] & (h[max(j - 1, 0):j + 2, max(i - 1, 0):i + 2] > h[j, i])

        if not above.any():
            from_head += 1

    print('dry reaches: %d (%d cells), %d of them start at a river head' % (count, dry.sum(), from_head))

    # Unheld edge: a wet river cell next to dry ground lower than its water level (nothing holds the water there; it shows as a ragged patch).
    wet = river & (d > 0)
    level = h + d
    unheld = 0
    cells = 0

    for j, i in zip(*np.nonzero(wet)):
        if j < 1 or i < 1 or j >= n - 1 or i >= n - 1:
            continue

        cells += 1
        dry_round = (d[j - 1:j + 2, i - 1:i + 2] == 0) & (w[j - 1:j + 2, i - 1:i + 2] != 1)   # the sea is not in the .water file: a river mouth is not a leak

        if (dry_round & (h[j - 1:j + 2, i - 1:i + 2] < level[j, i] - 0.05)).any():
            unheld += 1

    print('unheld edges: %d of %d wet river cells (%.0f%%) touch dry ground lower than their water' % (unheld, cells, 100.0 * unheld / max(cells, 1)))


if __name__ == '__main__':
    main()
