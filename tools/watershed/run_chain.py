"""Runs the watershed chain from the landform export to the water record, and skips each stage whose inputs, code and params
have not changed since it last ran (Sonny, 9 Nov 2026; docs/water/generation_cost_audit.md section 4, "a runner that skips").

    python tools/watershed/run_chain.py CHAIN_DIR RUN [params.json] [--godot=godot] [--plan]

Run it from the repo root, on Dave's PC only. It writes the folders the job files name: CHAIN_DIR/RUN_landform, RUN_geology,
RUN_inputs, RUN_b1, RUN (glacial), RUN_r3, RUN_r4, RUN_r5 and RUN_rec. params.json defaults to the repo's tools/watershed/params.json.
--plan prints what would run, and why, and runs nothing.

How a stage is skipped: after it succeeds, its folder gets run_chain_stamp.json, a hash of
- its command;
- every file it reads, by content (an .npz by its arrays, so the same arrays saved at another time are the same);
- its code: the stage script and every local module it imports, here and in tools/erosion_precarve;
- the params blocks its code reads (P['name'] in that code; text notes, keys starting with _, are left out);
- and world.json when its code reads the world block.
A stage runs again when any of those has changed or its outputs are missing. Its stamp is removed before it starts, so a stage
that stops part way never looks done. A stage that runs again and writes the same arrays lets the next stages skip.
The two Godot exports hash every file under src/worldgen and data/tables, and the world's world.json, plan/ and
erosion_delta_v2.bin.

Nine threads (Dave, 9 Nov 2026): every stage gets NUMBA_NUM_THREADS=9 (evolve's creep and the rock lookups in rock.py run on
numba's threads; the rest of each stage is one thread) and the two exports run side by side. Each stage prints its start and end on the PC clock. check_record.py, the bake, settle, refilm and rebake_check are
not part of it: the job file runs them after.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
CODE_DIRS = [HERE, os.path.normpath(os.path.join(HERE, '..', 'erosion_precarve'))]
STAMP = 'run_chain_stamp.json'
THREADS = 9                                   # Dave, 9 Nov 2026: nine threads for every bake and water stage on his PC
SPACING = 8.0                                 # the game's sample spacing (inputs.py): the model grid is SPACING * model_step
GODOT_INPUTS = ['src/worldgen', 'data/tables', 'worlds/base_world/world.json', 'worlds/base_world/plan', 'worlds/base_world/erosion_delta_v2.bin']

_hash_cache = {}


def file_sha(path):
    """The content hash of one file: an .npz by its arrays (name, dtype, shape, bytes), anything else by its bytes."""
    st = os.stat(path)
    key = (os.path.abspath(path), st.st_size, st.st_mtime_ns)
    if key in _hash_cache:
        return _hash_cache[key]
    h = hashlib.sha256()
    try:
        if not path.endswith('.npz'):
            raise ValueError('not an npz')
        with np.load(path, allow_pickle=False) as z:
            for name in sorted(z.files):
                a = np.ascontiguousarray(z[name])
                h.update(f'{name} {a.dtype.str} {a.shape}\n'.encode())
                h.update(a.tobytes())
    except ValueError:                                     # not an npz, or one holding objects: its bytes
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for block in iter(lambda: f.read(1 << 22), b''):
                h.update(block)
    _hash_cache[key] = h.hexdigest()
    return _hash_cache[key]


def tree_sha(paths):
    """{relative path: content hash} for every file under each path (a file or a folder), relative to the repo."""
    out = {}
    for p in paths:
        full = os.path.join(REPO, p)
        if os.path.isfile(full):
            out[p] = file_sha(full)
            continue
        for root, dirs, files in os.walk(full):
            dirs[:] = sorted(d for d in dirs if not d.startswith('.') and d != '__pycache__')
            for f in sorted(files):
                fp = os.path.join(root, f)
                out[os.path.relpath(fp, REPO).replace(os.sep, '/')] = file_sha(fp)
    return out


def _module_path(name):
    for d in CODE_DIRS:
        p = os.path.join(d, name + '.py')
        if os.path.isfile(p):
            return p
    return None


IMPORT_RE = re.compile(r'^\s*(?:import\s+([\w, ]+)|from\s+(\w+)\s+import)', re.M)
PARAM_RE = re.compile(r"\bP_?(?:\[\s*|\.get\(\s*)['\"](\w+)['\"]")


def code_closure(script):
    """The stage script and every local module it imports, directly or through another local module."""
    seen, todo = [], [os.path.join(HERE, script)]
    while todo:
        p = todo.pop()
        if p in seen:
            continue
        seen.append(p)
        text = open(p, encoding='utf-8').read()
        for m in IMPORT_RE.finditer(text):
            names = m.group(1).split(',') if m.group(1) else [m.group(2)]
            for name in names:
                q = _module_path(name.strip().split(' ')[0])
                if q:
                    todo.append(q)
    return sorted(seen)


def param_blocks(paths):
    """The top-level params keys the code reads as P['name'] or P.get('name')."""
    keys = set()
    for p in paths:
        keys.update(PARAM_RE.findall(open(p, encoding='utf-8').read()))
    return sorted(keys)


def _strip_notes(v):
    if isinstance(v, dict):
        return {k: _strip_notes(x) for k, x in v.items() if not str(k).startswith('_')}
    if isinstance(v, list):
        return [_strip_notes(x) for x in v]
    return v


def _canon(v):
    return hashlib.sha256(json.dumps(v, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def stage_key(stage, P, params_file):
    """Everything a stage's result depends on, as one dictionary (written to its stamp) and its hash."""
    parts = dict(command=[os.path.basename(c) if os.path.isabs(c) else c for c in stage['cmd']], reads={})
    for path in stage['reads']:
        if not os.path.isfile(path):
            return None, f'{path} is missing'
        parts['reads'][os.path.relpath(path, stage['chain']).replace(os.sep, '/')] = file_sha(path)
    if stage.get('script'):
        code = code_closure(stage['script'])
        parts['code'] = {os.path.relpath(p, REPO).replace(os.sep, '/'): file_sha(p) for p in code}
        blocks = param_blocks(code)
        parts['params'] = {b: _canon(_strip_notes(P.get(b))) for b in blocks}
        if 'world' in blocks:
            wj = P['world']['world_json']
            wj = wj if os.path.isabs(wj) else os.path.join(REPO, wj)
            parts['world_json'] = file_sha(wj)
    else:
        parts['code'] = tree_sha(GODOT_INPUTS)
    return parts, _canon(parts)


def _matching(pattern, folder):
    if not os.path.isdir(folder):
        return []
    rx = re.compile('^' + re.escape(pattern).replace(r'\*', '.*') + '$')
    return [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if rx.match(f)]


def stages(chain, run, params_file, godot):
    """The chain's stages in order, as the job files run them."""
    P = json.load(open(params_file))
    x0, z0, x1, z1 = P['tiles']
    d = {k: os.path.join(chain, f'{run}{s}') for k, s in [('landform', '_landform'), ('geology', '_geology'), ('inputs', '_inputs'),
                                                            ('b1', '_b1'), ('b2', ''), ('r3', '_r3'), ('r4', '_r4'), ('r5', '_r5'), ('rec', '_rec')]}
    py = sys.executable
    tiles = f'--tiles={x0},{z0},{x1},{z1}'
    geo_step = f'--step={SPACING * float(P["model_step"]):g}'

    def reads(*pairs):
        out = []
        for folder, pattern in pairs:
            out += _matching(pattern, d[folder]) if '*' in pattern else [os.path.join(d[folder], pattern)]
        return out

    geology = ('geology', 'geology*')            # rock.py's geology.json and rasters (the Godot exports take / paths on Windows too)
    W = lambda s: os.path.join('tools', 'watershed', s)
    return P, [
        dict(name='landform export', out=d['landform'], outputs=['raw_manifest.json'], reads=[], godot=True,
             cmd=[godot, '--headless', '--path', '.', '--script', 'res://src/worldgen/tools/export_raw_heights.gd', '--', '--landform', tiles,
                  '--out=' + d['landform'].replace(os.sep, '/')]),
        dict(name='geology export', out=d['geology'], outputs=['geology.json'], reads=[], godot=True,
             cmd=[godot, '--headless', '--path', '.', '--script', 'res://src/worldgen/tools/export_geology.gd', '--', geo_step, tiles,
                  '--out=' + d['geology'].replace(os.sep, '/')]),
        dict(name='inputs', script='inputs.py', out=d['inputs'], outputs=['inputs.npz'],
             reads=lambda: reads(('landform', '*.f32'), ('landform', 'raw_manifest.json'), geology),
             cmd=[py, W('inputs.py'), d['landform'], d['geology'], d['inputs'], params_file]),
        dict(name='evolve', script='evolve.py', out=d['b1'], outputs=['ground.npz'],
             reads=lambda: reads(('inputs', 'inputs.npz'), geology),
             cmd=[py, W('evolve.py'), d['inputs'], d['geology'], d['b1'], params_file]),
        dict(name='glacial', script='glacial.py', out=d['b2'], outputs=['glacial.npz'],
             reads=lambda: reads(('inputs', 'inputs.npz'), geology, ('b1', 'ground.npz')),
             cmd=[py, W('glacial.py'), d['inputs'], d['geology'], d['b1'], d['b2'], params_file]),
        dict(name='lakes', script='lakes.py', out=d['r3'], outputs=['lakes.npz', 'lakes.json'],
             reads=lambda: reads(('inputs', 'inputs.npz'), geology, ('b2', 'glacial.npz')),
             cmd=[py, W('lakes.py'), d['inputs'], d['geology'], d['b2'], d['r3'], params_file]),
        dict(name='groundwater', script='groundwater.py', out=d['r4'], outputs=['groundwater.npz'],
             reads=lambda: reads(('inputs', 'inputs.npz'), geology, ('b2', 'glacial.npz'), ('r3', 'lakes.npz')),
             cmd=[py, W('groundwater.py'), d['inputs'], d['geology'], d['b2'], d['r3'], d['r4'], params_file]),
        dict(name='network', script='network.py', out=d['r5'], outputs=['network.npz', 'network.json'],
             reads=lambda: reads(('inputs', 'inputs.npz'), geology, ('b2', 'glacial.npz'), ('r3', 'lakes.npz'), ('r3', 'lakes.json'),
                                 ('r4', 'groundwater.npz')),
             cmd=[py, W('network.py'), d['inputs'], d['geology'], d['b2'], d['r3'], d['r4'], d['r5'], params_file]),
        dict(name='record', script='record.py', out=d['rec'], outputs=['record/manifest.json'],
             # record.py also reads the stages' manifests (their hashes go into the record's), so those count too.
             reads=lambda: reads(('inputs', 'inputs.npz'), ('inputs', 'inputs_manifest.json'), ('b2', 'glacial.npz'), ('b2', 'glacial_manifest.json'),
                                 ('r3', 'lakes.npz'), ('r3', 'lakes.json'), ('r3', 'lakes_manifest.json'), ('r4', 'groundwater.npz'),
                                 ('r4', 'groundwater_manifest.json'), ('r5', 'network.npz'), ('r5', 'network.json'), ('r5', 'network_manifest.json')),
             cmd=[py, W('record.py'), d['inputs'], d['b2'], d['r3'], d['r4'], d['rec'], params_file, f'--network={d["r5"]}']),
    ]


def _clock():
    return time.strftime('%H:%M:%S')


def decide(stage, P, params_file, chain):
    """(key parts, key, why it runs) for one stage; why is None when it can be skipped."""
    stage = dict(stage, chain=chain, reads=stage['reads']() if callable(stage['reads']) else stage['reads'])
    parts, key = stage_key(stage, P, params_file)
    if parts is None:
        return None, None, key
    missing = [o for o in stage['outputs'] if not os.path.exists(os.path.join(stage['out'], o))]
    if missing:
        return parts, key, f'no {missing[0]} yet'
    stamp_path = os.path.join(stage['out'], STAMP)
    if not os.path.isfile(stamp_path):
        return parts, key, 'never run by run_chain.py (no stamp)'
    old = json.load(open(stamp_path))
    if old.get('key') == key:
        return parts, key, None
    changed = [k for k in ('command', 'reads', 'code', 'params', 'world_json') if old.get('parts', {}).get(k) != parts.get(k)]
    detail = []
    for k in changed:
        if isinstance(parts.get(k), dict):
            was = old.get('parts', {}).get(k) or {}
            detail += [f'{k} {n}' for n in sorted(set(was) | set(parts[k])) if was.get(n) != parts[k].get(n)]
        else:
            detail.append(k)
    return parts, key, 'changed: ' + ', '.join(detail[:6]) + (' ...' if len(detail) > 6 else '')


def _start(stage):
    os.makedirs(stage['out'], exist_ok=True)
    stamp_path = os.path.join(stage['out'], STAMP)
    if os.path.exists(stamp_path):
        os.remove(stamp_path)
    env = dict(os.environ, NUMBA_NUM_THREADS=str(THREADS))
    print(f"{stage['name']}: start {_clock()}", flush=True)
    return subprocess.Popen(stage['cmd'], cwd=REPO, env=env), time.time()


def _finish(stage, proc, t0, chain, P, params_file):
    code = proc.wait()
    print(f"{stage['name']}: end {_clock()} ({time.time() - t0:.0f} s){'' if code == 0 else f', FAILED with exit {code}'}", flush=True)
    if code != 0:
        return False
    parts, key, _ = decide(stage, P, params_file, chain)      # the files it read, hashed again after it ran
    json.dump(dict(stage=stage['name'], key=key, parts=parts, finished=time.strftime('%Y-%m-%d %H:%M:%S')),
              open(os.path.join(stage['out'], STAMP), 'w'), indent=1)
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict((a[2:].split('=', 1) + [''])[:2] for a in sys.argv[1:] if a.startswith('--'))
    if len(args) < 2:
        raise SystemExit(__doc__)
    chain, run = os.path.abspath(args[0]), args[1]
    params_file = os.path.abspath(args[2] if len(args) > 2 else os.path.join(HERE, 'params.json'))
    P, plan = stages(chain, run, params_file, opts.get('godot') or 'godot')
    t_all = time.time()
    print(f'run_chain {run}: chain folder {chain}, params {params_file}, start {_clock()}', flush=True)
    if 'plan' in opts:
        print('--plan: nothing runs. It reads the files as they are now, so a stage below one that runs may run too.', flush=True)

    # The two exports first, side by side.
    exports = plan[:2]
    todo = []
    for st in exports:
        _, _, why = decide(st, P, params_file, chain)
        print(f"{st['name']}: {'skip (nothing it reads has changed)' if why is None else 'run: ' + why}", flush=True)
        if why is not None:
            todo.append(st)
    if 'plan' not in opts:
        running = [(st,) + _start(st) for st in todo]
        if not all([_finish(st, proc, t0, chain, P, params_file) for st, proc, t0 in running]):
            raise SystemExit('run_chain: an export failed; stopped')

    for st in plan[2:]:
        parts, _, why = decide(st, P, params_file, chain)
        if parts is None:                                  # a file it reads is not there
            if 'plan' in opts:
                print(f"{st['name']}: run (after the stages above; {why})", flush=True)
                continue
            raise SystemExit(f"run_chain: {st['name']} cannot start: {why}")
        print(f"{st['name']}: {'skip (nothing it reads has changed)' if why is None else 'run: ' + why}", flush=True)
        if why is None or 'plan' in opts:
            continue
        proc, t0 = _start(st)
        if not _finish(st, proc, t0, chain, P, params_file):
            raise SystemExit(f"run_chain: {st['name']} failed; stopped (the stages after it did not run)")

    print(f'run_chain {run}: done {_clock()} ({time.time() - t_all:.0f} s). Next: check_record.py, then the bake (the job file).', flush=True)


if __name__ == '__main__':
    main()
